"""Build the local DuckDB catalog used by the prefill and check notebooks.

The catalog is a single ``.duckdb`` file that holds, instead of a pile of loose
``.sql`` files:

``prefill``    views resolving the DiscoData / data lake sources for one country
``reference``  views over the reference datasets used by the reference QCs
``export``     -- not a schema: export statements live in ``meta.scripts`` (see below)
``qc``         the quality checks, stored as text in ``qc.qc_definitions``
``meta``       the ``stable_record_id`` macro, dataset inventory and export scripts

Views cannot express ``COPY``/``CREATE TABLE`` statements, so the export step is
persisted as text in ``meta.scripts`` and executed by the notebook helpers.

Run:  python build_catalog.py [--catalog wise_rbdsuca.duckdb]
"""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent
SQL_DIR = ROOT / "sql"
DEFAULT_CATALOG = ROOT / "wise_rbdsuca.duckdb"

EXTENSIONS = ("spatial", "httpfs", "azure", "sqlite")

# EU Member States report under the WFD, other Eionet countries under WISE-5.
# Country.parquet does not publish this attribute, so it is seeded here.
WFD_COUNTRIES = (
    "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "EL",
    "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK",
    "SI", "ES", "SE",
)
WISE5_COUNTRIES = ("IS", "NO")

# Only this dataflow is wired end-to-end (prefill -> export -> reporting views);
# QCs for other dataflows (e.g. DrinkingWaterDirective, ProtectedAreas) are kept
# in sql/qc for later but excluded here so they don't always error out.
CURRENT_DATAFLOW = "RiverBasinDistrictsAndCompetentAuthorities"

_VIEW_HEADER_RE = re.compile(r"^--\s*(prefill|reference) view:\s*\S+(?:\s*\(([^)]*)\))?", re.IGNORECASE)


def _load_extensions(con: duckdb.DuckDBPyConnection) -> None:
    for extension in EXTENSIONS:
        con.execute(f"INSTALL {extension}")
        con.execute(f"LOAD {extension}")


def _create_macro(con: duckdb.DuckDBPyConnection) -> None:
    # Deterministic surrogate key: the same input always yields the same value, so the
    # record_id exported to SQLite/GeoPackage matches the one reported by the QC results.
    con.execute(
        """
        CREATE OR REPLACE MACRO stable_record_id(business_key) AS (
            SUBSTR(md5(business_key), 1, 8) || '-' ||
            SUBSTR(md5(business_key), 9, 4) || '-' ||
            SUBSTR(md5(business_key), 13, 4) || '-' ||
            SUBSTR(md5(business_key), 17, 4) || '-' ||
            SUBSTR(md5(business_key), 21, 12)
        )
        """
    )


def _seed_reference_tables(con: duckdb.DuckDBPyConnection) -> None:
    rows = [(code, "WFD") for code in WFD_COUNTRIES] + [(code, "WISE5") for code in WISE5_COUNTRIES]
    con.execute("DROP TABLE IF EXISTS reference.CountryReportingType")
    con.execute(
        "CREATE TABLE reference.CountryReportingType (countryCode VARCHAR, reportingType VARCHAR)"
    )
    con.executemany("INSERT INTO reference.CountryReportingType VALUES (?, ?)", rows)


def _create_views(con: duckdb.DuckDBPyConnection, schema: str) -> list[str]:
    created = []
    for sql_file in sorted((SQL_DIR / schema).glob("*.sql")):
        body = sql_file.read_text(encoding="utf-8").rstrip().rstrip(";")
        try:
            con.execute(f'CREATE OR REPLACE VIEW {schema}."{sql_file.stem}" AS {body}')
            created.append(sql_file.stem)
        except duckdb.IOException as exc:
            # Remote Parquet files may not exist yet (e.g. new dataflows in progress).
            print(f"  WARNING: skipped {schema}.{sql_file.stem} — {exc}")
    return created


def _describe_view(schema: str, sql_file: Path) -> tuple[str, str]:
    """Derive (kind, description) for meta.datasets from the view's header comment."""
    first_line = sql_file.read_text(encoding="utf-8").splitlines()[0]
    match = _VIEW_HEADER_RE.match(first_line)
    if schema == "reference":
        return "reference", "Reference dataset from the reference reporting cycle, used for cross-checks."
    detail = match.group(2) if match else None
    kind, _, note = (detail or "descriptive").partition(",")
    kind = kind.strip() or "descriptive"
    description = f"Prefilled {kind} data for the selected country/cycle"
    description += f" ({note.strip()})." if note.strip() else "."
    return kind, description


def _store_export_scripts(con: duckdb.DuckDBPyConnection) -> list[str]:
    con.execute("DROP TABLE IF EXISTS meta.scripts")
    con.execute(
        "CREATE TABLE meta.scripts (name VARCHAR, kind VARCHAR, target VARCHAR, sql_text VARCHAR)"
    )
    stored = []
    for sql_file in sorted((SQL_DIR / "export").glob("*.sql")):
        target = "geopackage" if "SPATIAL_" in sql_file.stem else "sqlite"
        con.execute(
            "INSERT INTO meta.scripts VALUES (?, 'export', ?, ?)",
            [sql_file.stem, target, sql_file.read_text(encoding="utf-8")],
        )
        stored.append(sql_file.stem)
    return stored


def _store_qcs(con: duckdb.DuckDBPyConnection) -> list[str]:
    con.execute("DROP TABLE IF EXISTS qc.qc_definitions")
    con.execute(
        """
        CREATE TABLE qc.qc_definitions (
            code VARCHAR PRIMARY KEY,
            dataflow VARCHAR,
            table_name VARCHAR,
            error_level VARCHAR,
            description VARCHAR,
            sql_text VARCHAR
        )
        """
    )
    metadata_file = SQL_DIR / "qc" / "qc_metadata.csv"
    with metadata_file.open(encoding="utf-8", newline="") as handle:
        metadata = {row["code"]: row for row in csv.DictReader(handle)}

    stored = []
    for sql_file in sorted((SQL_DIR / "qc").glob("*.sql")):
        row = metadata.get(sql_file.stem)
        if row is None:
            raise ValueError(f"{sql_file.name} has no entry in {metadata_file.name}")
        if row["dataflow"] != CURRENT_DATAFLOW:
            # Not yet wired end-to-end (no matching prefill/export/reporting views).
            print(f"  WARNING: skipped QC {row['code']} — dataflow '{row['dataflow']}' is out of scope")
            continue
        con.execute(
            "INSERT INTO qc.qc_definitions VALUES (?, ?, ?, ?, ?, ?)",
            [
                row["code"],
                row["dataflow"],
                row["table_name"],
                row["error_level"],
                row["description"],
                sql_file.read_text(encoding="utf-8"),
            ],
        )
        stored.append(row["code"])
    return stored


def _store_dataset_inventory(con: duckdb.DuckDBPyConnection, schema: str, names: list[str]) -> None:
    rows = [(schema, name, *_describe_view(schema, SQL_DIR / schema / f"{name}.sql")) for name in names]
    con.executemany("INSERT INTO meta.datasets VALUES (?, ?, ?, ?)", rows)


def build(catalog_path: Path) -> None:
    if catalog_path.exists():
        catalog_path.unlink()
    wal = catalog_path.with_suffix(catalog_path.suffix + ".wal")
    if wal.exists():
        wal.unlink()

    con = duckdb.connect(str(catalog_path))
    try:
        _load_extensions(con)
        for schema in ("meta", "prefill", "reference", "qc"):
            con.execute(f"CREATE SCHEMA IF NOT EXISTS {schema}")

        # Defaults so the views can be bound at build time; notebooks override them.
        con.execute("SET VARIABLE country_code = 'AT'")
        con.execute("SET VARIABLE cycle_year = '2022'")
        con.execute("SET VARIABLE reference_cycle_year = '2022'")

        _create_macro(con)
        _seed_reference_tables(con)
        reference_views = _create_views(con, "reference")
        prefill_views = _create_views(con, "prefill")
        views = [f"reference.{v}" for v in reference_views] + [f"prefill.{v}" for v in prefill_views]

        con.execute("DROP TABLE IF EXISTS meta.datasets")
        con.execute(
            "CREATE TABLE meta.datasets (schema_name VARCHAR, table_name VARCHAR, kind VARCHAR, description VARCHAR)"
        )
        _store_dataset_inventory(con, "reference", reference_views)
        _store_dataset_inventory(con, "prefill", prefill_views)

        exports = _store_export_scripts(con)
        qcs = _store_qcs(con)
    finally:
        con.close()

    print(f"Catalog written to {catalog_path}")
    print(f"  views          : {', '.join(views)}")
    print(f"  export scripts : {', '.join(exports)}")
    print(f"  quality checks : {', '.join(qcs)}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    build(parser.parse_args().catalog)


if __name__ == "__main__":
    main()
