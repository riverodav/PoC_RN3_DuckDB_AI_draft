# PoC_RN3_DuckDB_AI

Proof of Concept that lets anyone run the Reportnet 3 Quality Checks (QCs) of a WISE
dataflow **locally**, using DuckDB as the analytical engine, with an LLM to help
interpret failures.

It removes the dependency on Reportnet 3 availability for testing and shortens the
feedback loop when debugging complex QCs: the same SQL that runs in production is
executed against the same (public) data, on a laptop, in seconds.

The dataflow used for the PoC is *River Basin Districts and Competent Authorities*
(4th River Basin Management Plans). Only the SQL, the notebooks and the compiled
DuckDB catalog live here, no reported data is stored in this repository; every run
pulls the current data straight from the public [DiscoData](https://discodata.eea.europa.eu/)
endpoint used by Reportnet 3.

## Quick start

```powershell
git clone https://github.com/riverodav/PoC_RN3_DuckDB_AI.git
cd PoC_RN3_DuckDB_AI
pip install -r requirements.txt
```

Open the repository in VS Code with the Jupyter extension (or start Jupyter Lab from
the repository root), select the Python environment where the requirements were
installed, and run the notebooks in order. No build step is needed:
`wise_rbdsuca.duckdb` ships precompiled in the repo.

```powershell
jupyter lab
```

The notebooks use the current public data exposed by DiscoData. The first run may
therefore take longer while DuckDB downloads the required Parquet files.

1. `0_prefill/Prefill_RiverBasinDistrictsAndCompetentAuthorities.ipynb` - pick a country,
  review the prefilled data and export it to
  `output/<CC>/RiverBasinDistrictsAndCompetentAuthorities.sqlite` plus
  `output/<CC>/RiverBasinDistrict.gpkg`.
2. `1_check/Check_RiverBasinDistrictsAndCompetentAuthorities.ipynb` - attach those files
   and execute the QCs against them.

The check notebook only lists countries that already have files under `output/<CC>/`.
Run the prefill notebook again when you want to regenerate a country's deliverables.

## Architecture

```
DiscoData (public parquet, https)
                |
                |  lazy, no materialisation
                v
   wise_rbdsuca.duckdb          <- precompiled, committed to this repo
   |- prefill.*     views       <- the data to be reported, for one country
   |- reference.*   views       <- reference datasets used by cross-check QCs
   |- qc.qc_definitions         <- QC code + metadata + SQL text
   `- meta.scripts / datasets   <- export statements, dataset inventory
                |
                |  export (COPY / CREATE TABLE)
                v
   output/<CC>/RiverBasinDistrictsAndCompetentAuthorities.sqlite   (descriptive, git-ignored)
   output/<CC>/RiverBasinDistrict.gpkg                             (spatial, git-ignored)
                |
                |  attach_reporting()
                v
   descriptive_reporting.*  /  spatial_reporting.*   <- the schema names RN3 uses
                |
                v
            QC execution -> summary + CSV results
```

### Why a `.duckdb` catalog instead of loose `.sql` files

The queries are compiled into **views**, so a table is a table, not a string to be
downloaded, and the QC definitions travel with the data model they check. The `.sql`
files under `sql/` remain the source of truth and are the thing to edit; `build_catalog.py`
compiles them into the catalog, which is then committed so nobody has to run a build
step just to try the notebooks. A GitHub Actions workflow
(`.github/workflows/rebuild-catalog.yml`) rebuilds and commits `wise_rbdsuca.duckdb`
automatically whenever `sql/**` changes, so the committed catalog never drifts from
its source.

If you edit anything under `sql/`, you can also rebuild locally with:

```powershell
python build_catalog.py
```

### Parameterisation

Views cannot take arguments, so the country and the reporting cycle are passed as
DuckDB **session variables** read by every view through `getvariable()`. See
`wise_local_qc.set_parameters()`.

## What is (and isn't) in this repository

This repo only contains what is needed to run the QCs on any machine, without any
reported or sensitive data:

- `sql/` — the QC, prefill, reference and export SQL (logic only, no data).
- `wise_rbdsuca.duckdb` — the compiled catalog: views and QC text, nothing
  materialised.
- `build_catalog.py`, `wise_local_qc.py`, `ai_explain.py` — the Python glue.
- `0_prefill/`, `1_check/` — the two notebooks.
- `output/` (ignored by Git) — deliverables generated locally when you run the prefill
  notebook. Nothing under here is ever committed.
- `.env` (ignored by Git) — your own AI provider credentials, if you use the
  AI assisted explanation step. Never commit this file.

## AI-assisted interpretation of QC failures

`ai_explain.py` asks an LLM to explain a failed QC in plain language: what failed, its
root cause deduced from the QC's own SQL, likely reasons and recommended actions, using
the QC's existing description and SQL from `qc.qc_definitions` plus a sample of the
offending records, so no separate knowledge base has to be maintained per QC. This step
is optional and only runs from section 6 of the check notebook.

> **Data privacy:** every provider except `ollama` sends the QC's SQL and a sample of the
> offending records to a third-party API (OpenAI, Azure OpenAI or GitHub Models). Use
> `AI_EXPLAIN_PROVIDER=ollama` if that data must stay on the machine.

Copy `.env.example` to `.env` (git-ignored) and set the variables for your provider -
`ai_explain.py` loads it automatically. See the module's docstring for every provider's
environment variables.

For a fully local run, install and start [Ollama](https://ollama.com/), pull the model,
and keep the provider in `.env` as follows:

```powershell
ollama pull llama3.1
ollama serve
```

```dotenv
AI_EXPLAIN_PROVIDER=ollama
OLLAMA_BASE_URL=http://localhost:11434/v1
AI_EXPLAIN_MODEL=llama3.1
```

The default provider is OpenAI. Azure OpenAI, GitHub Models (kept for compatibility),
and Ollama are also supported; the complete variable list is in `.env.example` and in
the module docstring.

### Testing a QC with known defects

The check notebook can create a disposable GeoPackage under
`output/<CC>/sandbox/` and attach it instead of the clean export. The sandbox helpers
in `wise_local_qc.py` inject controlled defects into `RiverBasinDistrict`, including:

- `overlapping_geometry` -> `S016`
- `designation_date_mismatch` -> `RF012_WFD`
- `invalid_identifier_pattern` -> `V005`, `RF019_WFD`, `T002_WFD`
- `unexpected_deletion` -> `V068`

This is useful for checking QC SQL and the optional AI explanation flow without editing
the prefilled output. The generated sandbox files are ignored by Git.

### Adding a QC

1. Drop the adapted SQL in `sql/qc/<CODE>.sql`.
2. Add a row to `sql/qc/qc_metadata.csv`.
3. Push. The GitHub Actions workflow rebuilds and commits the catalog automatically
   (or run `python build_catalog.py` locally and commit the result yourself).

## Known limitations

- `Country.parquet` does not publish `reportingType`, which the WFD/WISE-5 QCs branch
  on. It is seeded in `build_catalog.py` (`reference.CountryReportingType`) as EU-27 to
  `WFD` and IS/NO to `WISE5`, and should be replaced by the authoritative list.
- Only the spatial `RiverBasinDistrict` table has translated QCs available, so the
  descriptive tables are prefilled and exported but not yet checked.
- Some reference/prefill views (`S015`/`ProtectedArea`, `XC018` descriptive tables) are
  skipped at build time with a `WARNING` because the corresponding data lake paths have
  no files yet. This is expected, not an error.

## License

Licensed under the [EUPL-1.2](LICENSE).
