"""dq.py : run the checks in sql/05_dq_checks.sql, record results in etl.dq_results.

Run alone:  python -m src.dq
"""
import re
from datetime import datetime
from pathlib import Path

import duckdb

CHECKS_FILE = Path("sql/05_dq_checks.sql")
EVIDENCE_FILE = Path("docs/evidence/dq_results.csv")

CHECK_PATTERN = re.compile(
    r"--\s*name:\s*(\S+)\s*\n--\s*severity:\s*(CRITICAL|WARNING)\s*\n(.*?)(?=\n--\s*name:|\Z)",
    re.S,
)


class DataQualityError(Exception):
    """Raised when a CRITICAL check fails."""


def parse_checks(text: str) -> list:
    """Return [(name, severity, sql), ...] from the checks file."""
    return [
        (name, severity, sql.strip().rstrip(";"))
        for name, severity, sql in CHECK_PATTERN.findall(text)
    ]


def run_checks(con, run_id: str) -> list:
    """Run every check, store one row each in etl.dq_results, return the results."""
    results = []
    checked_at = datetime.now()
    for name, severity, sql in parse_checks(CHECKS_FILE.read_text()):
        bad_rows = con.execute(sql).fetchone()[0]
        status = "PASS" if bad_rows == 0 else "FAIL"
        con.execute(
            "INSERT INTO etl.dq_results VALUES (?, ?, ?, ?, ?, ?)",
            [run_id, name, severity, bad_rows, status, checked_at],
        )
        results.append((name, severity, bad_rows, status))
        print(f"{status:<6}{severity:<10}{name:<44}bad rows: {bad_rows:,}")
    return results


def save_evidence(con, run_id: str) -> None:
    """Write this run's results to docs/evidence/dq_results.csv."""
    EVIDENCE_FILE.parent.mkdir(parents=True, exist_ok=True)
    con.execute(
        f"""
        COPY (
            SELECT run_id, check_name, severity, bad_row_count, status, checked_at
            FROM etl.dq_results
            WHERE run_id = '{run_id}'
            ORDER BY checked_at, check_name
        ) TO '{EVIDENCE_FILE}' (HEADER, DELIMITER ',')
        """
    )


def raise_on_critical(results: list) -> None:
    """CRITICAL failure stops the pipeline. WARNING does not."""
    critical = [name for name, severity, _, status in results
                if severity == "CRITICAL" and status == "FAIL"]
    if critical:
        raise DataQualityError("CRITICAL checks failed: " + ", ".join(critical))


if __name__ == "__main__":
    con = duckdb.connect("wwi.duckdb")
    run_id = f"manual-dq-{datetime.now():%Y%m%d%H%M%S}"
    results = run_checks(con, run_id)
    save_evidence(con, run_id)
    raise_on_critical(results)
    print("\nNo CRITICAL failures.")
