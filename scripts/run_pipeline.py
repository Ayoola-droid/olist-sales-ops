"""
Run the whole data pipeline with one command.

    py scripts/run_pipeline.py --db sqlite               # load + check SQLite
    py scripts/run_pipeline.py --db postgres             # load + check PostgreSQL
    py scripts/run_pipeline.py --db both                 # both, then compare them
    py scripts/run_pipeline.py --db both --skip-load     # re-run the checks only

Steps:
  1. LOAD     the 9 CSVs into the database (scripts/load_data.py)
  2. CHECK    run every query in sql/checks/ plus the monthly revenue query
  3. REPORT   write the results to reports/<db>_report.md (commit these to GitHub)
  4. COMPARE  with --db both, confirm the two databases give identical results

It stops with a non-zero exit code if a check fails, so it can later run
unattended (for example in GitHub Actions).
"""

import argparse
import sys
import time
from datetime import datetime
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import load_data  # noqa: E402  (same folder)

PROJECT = load_data.PROJECT
REPORTS = PROJECT / "reports"

# Query files, in report order. Check files run on both databases;
# the revenue query has one version per database.
CHECK_FILES = ["sql/checks/data_quality_checks.sql", "sql/checks/follow_up_checks.sql"]
REVENUE_FILE = {"sqlite": "sql/sqlite/02_monthly_revenue.sql",
                "postgres": "sql/postgres/04_monthly_revenue.sql"}

# Automatic pass/fail rules: (file, query number, column, rule, description)
ASSERTIONS = [
    ("sql/checks/data_quality_checks.sql", 1, None, "orders>0", "every table has rows"),
    ("sql/checks/data_quality_checks.sql", 7, "problem_rows", "zero_for_orphans",
     "no orphan customers, products or sellers"),
]


# ------------------------------------------------------------ reading SQL
def split_statements(path: Path) -> list[tuple[str, str]]:
    """Return (title, sql) pairs. The title is the comment line above each query."""
    statements, title, buf = [], "", []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith(("\\", ".")):          # psql or sqlite3 shell commands
            continue
        if not stripped and not buf:                  # blank line between queries
            continue
        if stripped.startswith("--"):
            text = stripped.lstrip("-").strip()
            if not buf and text and text[0].isdigit():   # "-- 1. Row counts ..."
                title = text
            continue
        buf.append(line)
        if stripped.endswith(";"):
            sql = "\n".join(buf).strip().rstrip(";")
            if sql:
                fallback = path.stem.lstrip("0123456789_").replace("_", " ").capitalize()
                statements.append((title or fallback, sql))
            title, buf = "", []
    return statements


def normalise(value):
    """Make SQLite and PostgreSQL values comparable (Decimal vs float, dates vs text)."""
    if value is None:
        return None
    if isinstance(value, (Decimal, float)):
        return round(float(value), 2)
    if hasattr(value, "isoformat"):
        return str(value)
    return value


# ------------------------------------------------------------ running SQL
def run_queries(db: str, conn, files: list[str]) -> list[dict]:
    results = []
    for rel in files:
        for number, (title, sql) in enumerate(split_statements(PROJECT / rel), start=1):
            cur = conn.cursor()
            cur.execute(sql)
            columns = [d[0] for d in cur.description]
            rows = [tuple(normalise(v) for v in row) for row in cur.fetchall()]
            cur.close()
            results.append({"file": rel, "number": number, "title": title,
                            "columns": columns, "rows": rows})
    return results


def open_connection(db: str, args):
    if db == "sqlite":
        import sqlite3
        if not args.sqlite_path.exists():
            sys.exit(f"{args.sqlite_path} not found. Run without --skip-load first.")
        return sqlite3.connect(args.sqlite_path)
    return load_data.connect_postgres(args)


# ------------------------------------------------------------ checking
def evaluate(results: list[dict]) -> list[tuple[bool, str]]:
    outcomes = []
    by_key = {(r["file"], r["number"]): r for r in results}
    for file, number, column, rule, description in ASSERTIONS:
        r = by_key.get((file, number))
        if r is None:
            outcomes.append((False, f"{description}: query not found"))
            continue
        if rule == "orders>0":
            ok = all(row[1] > 0 for row in r["rows"])
        elif rule == "zero_for_orphans":
            idx = r["columns"].index(column)
            ok = all(row[idx] == 0 for row in r["rows"] if "without" in row[0])
        else:
            ok = False
        outcomes.append((ok, description))
    return outcomes


# ------------------------------------------------------------ reporting
def markdown_table(columns, rows, limit=40) -> str:
    def cell(v):
        return "(blank)" if v is None or v == "" else f"{v:,}" if isinstance(v, int) else str(v)
    lines = ["| " + " | ".join(columns) + " |", "|" + "---|" * len(columns)]
    lines += ["| " + " | ".join(cell(v) for v in row) + " |" for row in rows[:limit]]
    if len(rows) > limit:
        lines.append(f"\n_{len(rows) - limit} more rows not shown._")
    return "\n".join(lines)


def write_report(db: str, results, outcomes, seconds: float) -> Path:
    REPORTS.mkdir(exist_ok=True)
    path = REPORTS / f"{db}_report.md"
    name = "SQLite" if db == "sqlite" else "PostgreSQL"
    out = [f"# {name} pipeline report",
           f"Generated {datetime.now():%Y-%m-%d %H:%M} by `scripts/run_pipeline.py` in {seconds:.1f}s.",
           "", "## Automatic checks", ""]
    out += [f"- {'PASS' if ok else 'FAIL'}: {text}" for ok, text in outcomes]
    current_file = None
    for r in results:
        if r["file"] != current_file:
            current_file = r["file"]
            out += ["", f"## `{current_file}`"]
        out += ["", f"### {r['title']}", "", markdown_table(r["columns"], r["rows"])]
    path.write_text("\n".join(out) + "\n", encoding="utf-8")
    return path


def compare(a: list[dict], b: list[dict]) -> list[str]:
    """Differences between SQLite and PostgreSQL on the shared check files."""
    differences = []
    for ra, rb in zip(a, b):
        if ra["file"] not in CHECK_FILES:
            continue
        if ra["rows"] != rb["rows"]:
            differences.append(f"{ra['file']} query {ra['number']} ({ra['title']})")
    return differences


# ------------------------------------------------------------ main
def run_one(db: str, args) -> tuple[list[dict], bool]:
    print(f"\n=== {db.upper()} ===")
    started = time.time()
    if not args.skip_load:
        print("Step 1/3  Loading data")
        load_data.check_files(args.data_dir)
        if db == "sqlite":
            load_data.load_sqlite(args.data_dir, args.sqlite_path)
        else:
            load_data.load_postgres(args.data_dir, args)
    else:
        print("Step 1/3  Load skipped (--skip-load)")

    print("Step 2/3  Running checks and queries")
    conn = open_connection(db, args)
    results = run_queries(db, conn, CHECK_FILES + [REVENUE_FILE[db]])
    conn.close()
    outcomes = evaluate(results)
    for ok, text in outcomes:
        print(f"  {'PASS' if ok else 'FAIL'}  {text}")

    print("Step 3/3  Writing report")
    path = write_report(db, results, outcomes, time.time() - started)
    print(f"  {path.relative_to(PROJECT)}  ({len(results)} queries)")
    return results, all(ok for ok, _ in outcomes)


def main() -> None:
    parser = argparse.ArgumentParser(description="Load, check and report on the Olist data.")
    parser.add_argument("--db", choices=["sqlite", "postgres", "both"], required=True)
    parser.add_argument("--skip-load", action="store_true", help="only re-run the checks")
    parser.add_argument("--data-dir", default=PROJECT / "data/raw", type=Path)
    parser.add_argument("--sqlite-path", default=PROJECT / "olist.db", type=Path)
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", default=5432, type=int)
    parser.add_argument("--user", default="postgres")
    parser.add_argument("--dbname", default="olist")
    args = parser.parse_args()

    dbs = ["sqlite", "postgres"] if args.db == "both" else [args.db]
    all_results, all_ok = {}, True
    for db in dbs:
        all_results[db], ok = run_one(db, args)
        all_ok &= ok

    if args.db == "both":
        print("\n=== COMPARE ===")
        diffs = compare(all_results["sqlite"], all_results["postgres"])
        if diffs:
            all_ok = False
            print("SQLite and PostgreSQL disagree on:")
            for d in diffs:
                print(f"  - {d}")
        else:
            print("SQLite and PostgreSQL give identical results on every check.")

    print("\nPipeline " + ("finished: all checks passed." if all_ok else "FAILED: see above."))
    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    main()
