#!/usr/bin/env bash
# Clean rebuild + SCD2 demo through the real pipeline.
# Deletes the database and test evidence first, so the log holds only these runs.
set -euo pipefail

rm -f wwi.duckdb wwi.duckdb.wal \
      docs/evidence/pipeline_run.log docs/evidence/scd2_demo_stage2.md

python run_pipeline.py --batch 1
python -m tests.scd2_snapshot "After batch 1 (initial load)"

python run_pipeline.py --batch 2 --effective-date 2015-01-01
python -m tests.scd2_snapshot "After batch 2 (changes effective 2015-01-01)"

python run_pipeline.py --batch 2 --effective-date 2015-01-01
python -m tests.scd2_snapshot "After batch 2 re-run (no change expected)"

echo "DEMO COMPLETE"
