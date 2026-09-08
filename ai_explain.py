"""AI-assisted interpretation of Quality Check failures.

Given a failed QC, this module builds a context with its description, the SQL that
implements it, and a sample of the offending records) and asks an LLM to explain,
in plain language, what failed, why, and how to fix it. No separate knowledge
base is maintained: the QC's own metadata and SQL (already the source of truth
in ``qc.qc_definitions``) are the context, so new QCs are explained without
writing documentation by hand.

Provider is selected through environment variables so the same code works with
plain OpenAI, Azure OpenAI, GitHub Models, or a local Ollama model:

| AI_EXPLAIN_PROVIDER | required variables |
| --- | --- |
| `openai` (default) | `OPENAI_API_KEY`, optional `AI_EXPLAIN_MODEL` (default `gpt-4o-mini`) |
| `azure` | `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_DEPLOYMENT`, optional `AZURE_OPENAI_API_VERSION` |
| `github` | `GITHUB_TOKEN`, optional `AI_EXPLAIN_MODEL` (default `openai/gpt-4o-mini`) - GitHub Models is being retired, kept only for compatibility |
| `ollama` | none - runs fully offline against a local Ollama server; optional `OLLAMA_BASE_URL` (default `http://localhost:11434/v1`) and `AI_EXPLAIN_MODEL` (default `llama3.1`) |

Data privacy: every provider except `ollama` sends the QC's SQL and a sample of the
offending records, which are real reported data, to an external API. Use `ollama` if that data
cannot leave the machine; a `UserWarning` is raised once per process for every other
provider as a reminder.
"""

from __future__ import annotations

import os
import warnings
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import duckdb
import pandas as pd
from dotenv import load_dotenv

# Setting $env:GITHUB_TOKEN in a terminal does not reach a Jupyter kernel VS Code
# already spawned as its own child process, so credentials are loaded from a
# .env file (repo root, git-ignored) instead - see .env.example.
load_dotenv(Path(__file__).resolve().parent / ".env")

MAX_SAMPLE_ROWS = 15
MAX_SQL_CHARS = 4000

SYSTEM_PROMPT = """You are an expert in the WISE / Reportnet 3 reporting obligations and in \
data quality checks (QCs) for environmental spatial and descriptive data.

You will be given a QC's description, the SQL that implements it (it returns the \
offending records) and a sample of the records it flagged. Answer in this exact \
structure, in markdown, and keep it concise:

**What failed**: one sentence, referencing the affected records.
**Root cause**: which field(s)/comparison in the SQL caused the mismatch, deduced from the query itself.
**Likely reasons**: 2-4 bullet points of plausible real-world causes.
**Recommended actions**: 2-4 concrete, actionable bullet points a Member State reporter could follow.

Do not invent field values that are not present in the SQL or the sample rows."""

ERROR_SYSTEM_PROMPT = """You are an expert in DuckDB SQL and in the WISE / Reportnet 3 local QC \
runtime described below: QCs are plain SQL views executed against a `spatial_reporting` / \
`descriptive_reporting` / `reference` schema that only contains the tables exported for the \
active dataflow - a QC referencing a table or column that was never exported for this \
dataflow will fail with a binder/catalog error, which is not a data quality problem.

You will be given a QC's description, its SQL, and the exception message DuckDB raised while \
running it. Answer in this exact structure, in markdown, and keep it concise:

**What failed**: one sentence describing the execution error (not a data violation).
**Root cause**: which table/column/expression in the SQL the error points to.
**Likely reasons**: 2-4 bullet points (e.g. table not exported for this dataflow, renamed column, missing extension).
**Recommended actions**: 2-4 concrete bullet points (e.g. check meta.datasets, adjust the SQL, confirm this QC applies to this dataflow).

Do not invent table or column names that are not present in the SQL or the error message."""


def _client_and_model():
    """Build an OpenAI-compatible client from environment variables."""
    provider = os.environ.get("AI_EXPLAIN_PROVIDER", "openai").lower()

    if provider != "ollama":
        warnings.warn(
            f"AI_EXPLAIN_PROVIDER='{provider}' sends the QC's SQL and a sample of the "
            "reported records to a third-party API. Use 'ollama' to keep everything local.",
            UserWarning,
            stacklevel=2,
        )

    def _require(var: str, hint: str) -> str:
        value = os.environ.get(var)
        if not value:
            raise RuntimeError(f"{var} is not set. {hint}")
        return value

    if provider == "azure":
        from openai import AzureOpenAI

        endpoint = _require("AZURE_OPENAI_ENDPOINT", "Set it to your Azure OpenAI resource endpoint.")
        api_key = _require("AZURE_OPENAI_API_KEY", "Set it to an API key for that resource.")
        deployment = _require("AZURE_OPENAI_DEPLOYMENT", "Set it to the name of your chat model deployment.")
        api_version = os.environ.get("AZURE_OPENAI_API_VERSION", "2024-10-21")
        client = AzureOpenAI(azure_endpoint=endpoint, api_key=api_key, api_version=api_version)
        return client, deployment

    from openai import OpenAI

    if provider == "openai":
        api_key = _require("OPENAI_API_KEY", "Set it to an API key from https://platform.openai.com/api-keys.")
        model = os.environ.get("AI_EXPLAIN_MODEL", "gpt-4o-mini")
        return OpenAI(api_key=api_key), model

    if provider == "github":
        token = _require(
            "GITHUB_TOKEN",
            "Create a fine-grained personal access token with read-only 'Models' permission at "
            "https://github.com/settings/personal-access-tokens/new, then set it e.g. "
            '`$env:GITHUB_TOKEN = "..."` and restart the kernel.',
        )
        model = os.environ.get("AI_EXPLAIN_MODEL", "openai/gpt-4o-mini")
        client = OpenAI(base_url="https://models.github.ai/inference", api_key=token)
        return client, model

    if provider == "ollama":
        # No API key needed: Ollama's local server exposes an OpenAI-compatible endpoint.
        base_url = os.environ.get("OLLAMA_BASE_URL", "http://localhost:11434/v1")
        model = os.environ.get("AI_EXPLAIN_MODEL", "llama3.1")
        client = OpenAI(base_url=base_url, api_key="ollama")
        return client, model

    raise ValueError(f"Unknown AI_EXPLAIN_PROVIDER '{provider}'. Use 'openai', 'azure', 'github' or 'ollama'.")


def _truncate_sql(sql_text: str) -> str:
    """Cap the SQL sent to the LLM, flagging the cut so it doesn't reason over a query
    that silently ends mid-statement."""
    if len(sql_text) <= MAX_SQL_CHARS:
        return sql_text
    return sql_text[:MAX_SQL_CHARS] + f"\n-- [truncated: {len(sql_text) - MAX_SQL_CHARS} more characters]"


@dataclass
class QcContext:
    code: str
    error_level: str
    description: str
    sql_text: str
    sample_csv: str
    total_records: int


def build_qc_context(con: duckdb.DuckDBPyConnection,code: str,result: pd.DataFrame,) -> QcContext:
    row = con.execute(
        """
        SELECT error_level, description, sql_text
        FROM qc.qc_definitions
        WHERE code = ?
        """,
        [code],
    ).fetchone()

    if row is None:
        raise LookupError(f"No QC definition found for code: {code}")

    error_level, description, sql_text = row

    return QcContext(
        code=code,
        error_level=error_level,
        description=description,
        sql_text=_truncate_sql(sql_text),
        sample_csv=result.head(MAX_SAMPLE_ROWS).to_csv(index=False),
        total_records=len(result),
    )


def explain_qc(con: duckdb.DuckDBPyConnection, code: str, result: pd.DataFrame, error_message: str = "") -> str:
    """Ask the configured LLM to explain why a QC failed (or errored) and how to fix it."""
    if not error_message and result.empty:
        return f"### {code}\n\nPassed - no offending records."

    client, model = _client_and_model()

    if error_message:
        row = con.execute(
            """
            SELECT error_level, description, sql_text
            FROM qc.qc_definitions
            WHERE code = ?
            """,
            [code],
        ).fetchone()

        if row is None:
            return (
                f"### {code}\n\n"
                f"Unable to explain this QC: no definition was found."
            )

        error_level, description, sql_text = row
        sql_text = _truncate_sql(sql_text)

        user_prompt = f"""QC code: {code}
Error level: {error_level}
Description: {description}

SQL:
```sql
{sql_text}
```

Exception raised while running it:
```
{error_message}
```"""
        response = client.chat.completions.create(
            model=model,
            temperature=0.2,
            messages=[
                {"role": "system", "content": ERROR_SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
        )
        answer = response.choices[0].message.content
        return f"### {code} (ERROR - execution failed)\n\n{answer}"

    context = build_qc_context(con, code, result)

    user_prompt = f"""QC code: {context.code}
Error level: {context.error_level}
Description: {context.description}
Offending records: {context.total_records} (showing up to {MAX_SAMPLE_ROWS})

SQL:
```sql
{context.sql_text}
```

Sample of offending records (CSV):
```csv
{context.sample_csv}
```"""

    response = client.chat.completions.create(
        model=model,
        temperature=0.2,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
    )
    answer = response.choices[0].message.content
    return f"### {code} ({context.error_level}, {context.total_records} record(s))\n\n{answer}"


def explain_failures(
    con: duckdb.DuckDBPyConnection,
    summary: pd.DataFrame,
    results: dict[str, pd.DataFrame],
    statuses: tuple[str, ...] = ("FAILED", "ERROR"),
    codes: Iterable[str] | None = None,
) -> str:
    """Explain every QC in `summary` whose status is in `statuses`.

    `FAILED` QCs are explained from their offending records; `ERROR` QCs (the SQL itself
    raised an exception, e.g. a table not exported for this dataflow) are explained from
    the exception message in `summary`'s `message` column instead.

    `codes`, if given, restricts the report to that subset of QC codes (e.g. a user's
    selection from the notebook) instead of every failing/erroring QC.

    A QC whose LLM call itself fails (rate limit, timeout, provider outage) does not
    abort the rest of the report - its section just notes the failure instead.

    Returns a single markdown report, ready to be rendered with
    `IPython.display.Markdown` or written to a file.
    """
    rows = summary.loc[summary["status"].isin(statuses)]
    if codes is not None:
        rows = rows.loc[rows["code"].isin(codes)]
    if rows.empty:
        return "No matching QCs to explain." if codes is not None else "All checked QCs passed - nothing to explain."

    sections = []
    for _, row in rows.iterrows():
        code = row["code"]
        try:
            sections.append(
                explain_qc(con, code, results[code], error_message=row.get("message", "") or "")
            )
        except Exception as exc:
            sections.append(f"### {code}\n\n_Could not get an AI explanation: {exc}_")
    return "\n\n---\n\n".join(sections)
