"""Helpers shared by the prefill and check notebooks.

The module keeps the notebooks short: they only deal with the widgets and with
displaying results, while connection handling, parameterisation, export and QC
execution live here.
"""

from __future__ import annotations

import random
import re
from pathlib import Path

import duckdb
import pandas as pd

ROOT = Path(__file__).resolve().parent
DEFAULT_CATALOG = ROOT / "wise_rbdsuca.duckdb"
EXTENSIONS = ("spatial", "httpfs", "azure", "sqlite")

_COUNTRY_CODE_RE = re.compile(r"^[A-Za-z]{2}$")
_YEAR_RE = re.compile(r"^\d{4}$")


def _sql_literal(value: str) -> str:
    """Escape a value for safe embedding in a single-quoted SQL string literal.

    `SET VARIABLE`, `ATTACH` and `COPY ... TO` don't accept bound parameters for their
    string arguments in DuckDB, so those call sites build SQL text by interpolation;
    this is the one place that has to happen safely, by doubling embedded quotes.
    """
    return str(value).replace("'", "''")


def _sql_identifier(value: str) -> str:
    """Escape a value for safe embedding in a double-quoted SQL identifier.

    Applied to table/layer names discovered from an attached SQLite/GeoPackage file
    before they are spliced into `CREATE VIEW ... "<name>"` statements.
    """
    return str(value).replace('"', '""')


COUNTRIES = [
    ("Austria", "AT"), ("Belgium", "BE"), ("Bulgaria", "BG"), ("Croatia", "HR"),
    ("Cyprus", "CY"), ("Czechia", "CZ"), ("Denmark", "DK"), ("Estonia", "EE"),
    ("Finland", "FI"), ("France", "FR"), ("Germany", "DE"), ("Greece", "EL"),
    ("Hungary", "HU"), ("Iceland", "IS"), ("Ireland", "IE"), ("Italy", "IT"),
    ("Latvia", "LV"), ("Lithuania", "LT"), ("Luxembourg", "LU"), ("Malta", "MT"),
    ("Netherlands", "NL"), ("Norway", "NO"), ("Poland", "PL"), ("Portugal", "PT"),
    ("Romania", "RO"), ("Slovakia", "SK"), ("Slovenia", "SI"), ("Spain", "ES"),
    ("Sweden", "SE"),
]


def connect(catalog_path: str | Path = DEFAULT_CATALOG) -> duckdb.DuckDBPyConnection:
    """Open the catalog and load the extensions the views depend on."""
    catalog_path = Path(catalog_path)
    if not catalog_path.exists():
        raise FileNotFoundError(
            f"{catalog_path} not found. Run `python build_catalog.py` first."
        )
    con = duckdb.connect(str(catalog_path))
    for extension in EXTENSIONS:
        con.execute(f"INSTALL {extension}")
        con.execute(f"LOAD {extension}")
    set_parameters(con)
    return con


def set_parameters(
    con: duckdb.DuckDBPyConnection,
    country_code: str = "AT",
    cycle_year: str = "2022",
    reference_cycle_year: str = "2022",
) -> None:
    """Point every catalog view at one country and one reporting cycle."""
    if not _COUNTRY_CODE_RE.match(country_code):
        raise ValueError(f"country_code must be a 2-letter code, got {country_code!r}")
    for name, value in (("cycle_year", cycle_year), ("reference_cycle_year", reference_cycle_year)):
        if not _YEAR_RE.match(str(value)):
            raise ValueError(f"{name} must be a 4-digit year, got {value!r}")
    con.execute(f"SET VARIABLE country_code = '{_sql_literal(country_code)}'")
    con.execute(f"SET VARIABLE cycle_year = '{_sql_literal(cycle_year)}'")
    con.execute(f"SET VARIABLE reference_cycle_year = '{_sql_literal(reference_cycle_year)}'")


def current_parameters(con: duckdb.DuckDBPyConnection) -> dict[str, str]:
    return con.sql(
        """
        SELECT getvariable('country_code') AS country_code,
               getvariable('cycle_year') AS cycle_year,
               getvariable('reference_cycle_year') AS reference_cycle_year
        """
    ).df().iloc[0].to_dict()


def list_datasets(con: duckdb.DuckDBPyConnection) -> pd.DataFrame:
    return con.sql(
        "SELECT schema_name, table_name, kind, description FROM meta.datasets ORDER BY kind, table_name"
    ).df()


def preview(con: duckdb.DuckDBPyConnection, qualified_name: str, limit: int = 50) -> pd.DataFrame:
    schema, _, table = qualified_name.partition(".")
    return con.sql(f'SELECT * FROM {schema}."{_sql_identifier(table)}" LIMIT {int(limit)}').df()


def export_prefill(
    con: duckdb.DuckDBPyConnection,
    sqlite_path: str | Path,
    geopackage_path: str | Path,
) -> list[str]:
    """Materialise the prefill views into the SQLite and GeoPackage deliverables."""
    sqlite_path = Path(sqlite_path)
    geopackage_path = Path(geopackage_path)
    sqlite_path.parent.mkdir(parents=True, exist_ok=True)
    geopackage_path.parent.mkdir(parents=True, exist_ok=True)
    # The GDAL GPKG driver appends to an existing file, so start from a clean one.
    geopackage_path.unlink(missing_ok=True)

    scripts = con.sql(
        "SELECT name, target, sql_text FROM meta.scripts WHERE kind = 'export' ORDER BY target, name"
    ).fetchall()

    executed = []
    skipped = []
    con.execute("DETACH DATABASE IF EXISTS sqlite_db")
    con.execute(f"ATTACH '{_sql_literal(sqlite_path.as_posix())}' AS sqlite_db (TYPE sqlite)")
    try:
        for name, target, sql_text in scripts:
            if target == "geopackage":
                sql_text = sql_text.replace("{{output_path}}", _sql_literal(geopackage_path.as_posix()))
            try:
                con.execute(sql_text)
                executed.append(name)
            except duckdb.CatalogException as exc:
                # prefill view not yet available (e.g. remote Parquet missing for this dataflow)
                print(f"  WARNING: skipped export '{name}' — {exc}")
                skipped.append(name)
    finally:
        con.execute("DETACH DATABASE IF EXISTS sqlite_db")
    return executed


def attach_reporting(
    con: duckdb.DuckDBPyConnection,
    sqlite_path: str | Path,
    geopackage_path: str | Path,
) -> None:
    """Expose the exported files under the schema names the QCs use in RN3.

    ``descriptive_reporting`` and ``spatial_reporting`` are created at run time
    rather than persisted in the catalog because their paths depend on where the
    user saved the deliverables. The GeoPackage is read through ``ST_Read`` so
    that geometries arrive as GEOMETRY rather than as raw GeoPackage blobs.
    """
    sqlite_path = Path(sqlite_path).resolve()
    geopackage_path = Path(geopackage_path).resolve()
    for path in (sqlite_path, geopackage_path):
        if not path.exists():
            raise FileNotFoundError(f"{path} not found. Run the prefill notebook first.")

    attach_descriptive(con, sqlite_path)
    attach_spatial(con, geopackage_path)


def attach_descriptive(con: duckdb.DuckDBPyConnection, sqlite_path: str | Path) -> list[str]:
    """Expose every table in the exported SQLite file as a `descriptive_reporting` view.

    Shared by `attach_reporting()` and `benchmark.py`, which attach the descriptive and
    spatial deliverables independently (not every country export has both).
    """
    sqlite_path = Path(sqlite_path).resolve()
    con.execute("DETACH DATABASE IF EXISTS descriptive_source")
    con.execute(f"ATTACH '{_sql_literal(sqlite_path.as_posix())}' AS descriptive_source (TYPE sqlite, READ_ONLY)")
    con.execute("CREATE SCHEMA IF NOT EXISTS descriptive_reporting")
    tables = [
        row[0]
        for row in con.sql(
            "SELECT table_name FROM duckdb_tables() WHERE database_name = 'descriptive_source'"
        ).fetchall()
    ]
    for table in tables:
        con.execute(
            f'CREATE OR REPLACE VIEW descriptive_reporting."{_sql_identifier(table)}" AS '
            f'SELECT * FROM descriptive_source."{_sql_identifier(table)}"'
        )
    return tables


def attach_spatial(con: duckdb.DuckDBPyConnection, geopackage_path: str | Path) -> list[str]:
    """Expose every feature layer in the GeoPackage as a `spatial_reporting` view.

    Shared by `attach_reporting()` and `benchmark.py`. Layers are discovered from the
    GeoPackage's own SQLite metadata instead of hardcoded names; calling `ST_Read` for a
    non-existent layer crashes GDAL fatally instead of raising a Python exception.
    """
    geopackage_path = Path(geopackage_path).resolve()
    con.execute("CREATE SCHEMA IF NOT EXISTS spatial_reporting")
    con.execute(f"SET VARIABLE geopackage_path = '{_sql_literal(geopackage_path.as_posix())}'")
    import sqlite3
    with sqlite3.connect(str(geopackage_path)) as _gpkg:
        layers = [
            row[0]
            for row in _gpkg.execute(
                "SELECT table_name FROM gpkg_contents WHERE data_type = 'features' ORDER BY table_name"
            )
        ]
    for layer in layers:
        con.execute(
            f'CREATE OR REPLACE VIEW spatial_reporting."{_sql_identifier(layer)}" AS '
            f"SELECT * FROM ST_Read(getvariable('geopackage_path'), layer := '{_sql_literal(layer)}')"
        )
    return layers


def build_sandbox(
    con: duckdb.DuckDBPyConnection,
    geopackage_path: str | Path,
    sandbox_path: str | Path,
) -> Path:
    """Write a deliberately broken copy of the spatial deliverable and attach it.

    Prefilled data is by construction consistent, so every QC passes. This helper
    injects two known defects - an overlapping River Basin District and a shifted
    designationPeriodBegin - so that S016 and RF012_WFD can be seen firing while a
    QC is being developed.
    """
    sandbox_path = Path(sandbox_path)
    sandbox_path.parent.mkdir(parents=True, exist_ok=True)
    sandbox_path.unlink(missing_ok=True)

    # Read straight from the pristine GeoPackage, not spatial_reporting.RiverBasinDistrict:
    # that view may already point at a previous sandbox, which would break re-running this
    # (or stack defects) once the earlier sandbox file gets overwritten below.
    source = f"ST_Read('{_sql_literal(Path(geopackage_path).resolve().as_posix())}', layer := 'RiverBasinDistrict')"
    con.execute(
        f"""
        COPY (
            WITH numbered AS (
                SELECT *, ROW_NUMBER() OVER (ORDER BY thematicIdIdentifier) AS rn
                FROM {source}
            )
            SELECT * EXCLUDE (rn) REPLACE (
                       CASE WHEN rn = 1 THEN '1999-01-01' ELSE designationPeriodBegin END AS designationPeriodBegin
                   )
            FROM numbered
            UNION ALL
            SELECT * EXCLUDE (rn) REPLACE (
                       'XX9999' AS thematicIdIdentifier,
                       record_id || '-sandbox' AS record_id
                   )
            FROM numbered WHERE rn = 1
        ) TO '{_sql_literal(sandbox_path.as_posix())}' WITH (
            FORMAT gdal, DRIVER 'GPKG', SRS 'EPSG:3035',
            LAYER_NAME 'RiverBasinDistrict', LAYER_CREATION_OPTIONS 'GEOMETRY_NAME=geom'
        )
        """
    )
    con.execute(f"SET VARIABLE geopackage_path = '{_sql_literal(sandbox_path.resolve().as_posix())}'")
    return sandbox_path


# One entry per injectable defect: which QC(s) it is realistically expected to make
# fail (verified against each QC's SQL, not just the QC it primarily targets - e.g.
# breaking thematicIdIdentifier also breaks the reference QCs that join on it), a short
# explanation, and the REPLACE clause applied to the first (by thematicIdIdentifier)
# RiverBasinDistrict record. "overlapping_geometry" is special-cased in inject_fault()
# because it adds a row instead of replacing a field.
FAULT_LIBRARY: dict[str, dict[str, object]] = {
    "overlapping_geometry": {
        "qcs": ["S016"],
        "description": "duplicates the first RBD polygon under a new, well-formed code, so the two overlap",
    },
    "designation_date_mismatch": {
        "qcs": ["RF012_WFD"],
        "description": "shifts designationPeriodBegin so it no longer matches the reference data",
        "replace": "CASE WHEN rn = 1 THEN '1999-01-01' ELSE designationPeriodBegin END AS designationPeriodBegin",
    },
    "invalid_identifier_pattern": {
        "qcs": ["V005", "RF019_WFD", "T002_WFD"],
        "description": (
            "gives thematicIdIdentifier a value that breaks the country-prefixed code pattern; "
            "since the reported record no longer matches its reference entry, this also makes it "
            "look unreported (RF019_WFD) and its original reference RBD look dropped (T002_WFD)"
        ),
        "replace": "CASE WHEN rn = 1 THEN 'invalid id!!' ELSE thematicIdIdentifier END AS thematicIdIdentifier",
    },
    "unexpected_deletion": {
        "qcs": ["V068"],
        "description": "marks the first RBD as wiseEvolutionType = deletion, which is not allowed",
        "replace": "CASE WHEN rn = 1 THEN 'deletion' ELSE wiseEvolutionType END AS wiseEvolutionType",
    },
}


def inject_fault(
    con: duckdb.DuckDBPyConnection,
    geopackage_path: str | Path,
    sandbox_path: str | Path,
    fault: str | None = None,
) -> tuple[str, list[str]]:
    """Write a copy of the spatial deliverable with one defect from `FAULT_LIBRARY`.

    Meant to test `ai_explain.explain_failures` against a variety of QCs rather
    than just the two `build_sandbox` always breaks. If `fault` is not given, one
    is picked at random. Returns the fault name used and the QC codes it is
    expected to make fail, so the caller can check the AI's explanation against them.
    """
    fault = fault or random.choice(list(FAULT_LIBRARY))
    spec = FAULT_LIBRARY[fault]

    sandbox_path = Path(sandbox_path)
    sandbox_path.parent.mkdir(parents=True, exist_ok=True)
    sandbox_path.unlink(missing_ok=True)

    # Read straight from the pristine GeoPackage rather than spatial_reporting.RiverBasinDistrict:
    # that view may already point at a sandbox from a previous call, which would otherwise stack
    # faults on top of each other (or break entirely once the previous sandbox file is overwritten).
    source = f"ST_Read('{_sql_literal(Path(geopackage_path).resolve().as_posix())}', layer := 'RiverBasinDistrict')"
    numbered = f"""
        WITH numbered AS (
            SELECT *, ROW_NUMBER() OVER (ORDER BY thematicIdIdentifier) AS rn
            FROM {source}
        )
    """
    if fault == "overlapping_geometry":
        select_sql = f"""
            {numbered}
            SELECT * EXCLUDE (rn) FROM numbered
            UNION ALL
            SELECT * EXCLUDE (rn) REPLACE (
                       -- country-prefixed so V005 still passes, and 'creation' so RF019_WFD /
                       -- T002_WFD (which only look at noChange/change records) ignore this
                       -- duplicate: the fault should only trip S016.
                       getvariable('country_code') || 'ZZ99' AS thematicIdIdentifier,
                       record_id || '-sandbox' AS record_id,
                       'creation' AS wiseEvolutionType
                   )
            FROM numbered WHERE rn = 1
        """
    else:
        select_sql = f"""
            {numbered}
            SELECT * EXCLUDE (rn) REPLACE ({spec['replace']})
            FROM numbered
        """

    con.execute(
        f"""
        COPY ({select_sql}) TO '{_sql_literal(sandbox_path.as_posix())}' WITH (
            FORMAT gdal, DRIVER 'GPKG', SRS 'EPSG:3035',
            LAYER_NAME 'RiverBasinDistrict', LAYER_CREATION_OPTIONS 'GEOMETRY_NAME=geom'
        )
        """
    )
    con.execute(f"SET VARIABLE geopackage_path = '{_sql_literal(sandbox_path.resolve().as_posix())}'")
    return fault, spec["qcs"]


def list_qcs(con: duckdb.DuckDBPyConnection) -> pd.DataFrame:
    return con.sql(
        "SELECT code, table_name, error_level, description FROM qc.qc_definitions ORDER BY code"
    ).df()

def qc_sql(con: duckdb.DuckDBPyConnection, code: str) -> str:
    row = con.execute("SELECT sql_text FROM qc.qc_definitions WHERE code = ?", [code]).fetchone()
    if row is None:
        raise KeyError(f"QC {code} is not present in the catalog")
    return row[0]


def run_qc(con: duckdb.DuckDBPyConnection, code: str) -> pd.DataFrame:
    """Run one QC. A non-empty result means the check found offending records."""
    return con.sql(qc_sql(con, code)).df()


def run_qcs(con: duckdb.DuckDBPyConnection, codes: list[str] | None = None) -> tuple[pd.DataFrame, dict[str, pd.DataFrame]]:
    """Run several QCs and return a summary plus the individual result sets."""
    if codes is None:
        codes = con.sql("SELECT code FROM qc.qc_definitions ORDER BY code").df()["code"].tolist()

    summary_rows: list[dict[str, object]] = []
    results: dict[str, pd.DataFrame] = {}
    for code in codes:
        meta = con.execute(
            "SELECT error_level, description FROM qc.qc_definitions WHERE code = ?", [code]
        ).fetchone()
        try:
            result = run_qc(con, code)
            status = "PASSED" if result.empty else "FAILED"
            message = ""
        except Exception as error:  # surfaced in the summary instead of stopping the run
            result = pd.DataFrame()
            status = "ERROR"
            message = f"{type(error).__name__}: {error}"
        results[code] = result
        summary_rows.append(
            {
                "code": code,
                "error_level": meta[0],
                "status": status,
                "records": len(result),
                "description": meta[1],
                "message": message,
            }
        )
    return pd.DataFrame(summary_rows), results


def write_qc_results(results: dict[str, pd.DataFrame], output_dir: str | Path) -> list[Path]:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for code, result in results.items():
        if result.empty:
            continue
        path = output_dir / f"QC_{code}_results.csv"
        result.to_csv(path, sep=";", index=False)
        written.append(path)
    return written
