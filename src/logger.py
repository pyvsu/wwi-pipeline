"""logger.py : one logger that writes to the console AND a log file."""
import logging
import sys
from pathlib import Path

LOG_FILE = Path("docs/evidence/pipeline_run.log")


def get_logger(log_file: Path = LOG_FILE) -> logging.Logger:
    """Return the pipeline logger. Appends to log_file, so runs stack up."""
    log_file.parent.mkdir(parents=True, exist_ok=True)

    logger = logging.getLogger("wwi_pipeline")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()  # no duplicate lines if called twice
    logger.propagate = False

    formatter = logging.Formatter(
        "%(asctime)s | %(levelname)-7s | %(message)s", "%Y-%m-%d %H:%M:%S"
    )

    console = logging.StreamHandler(sys.stdout)
    console.setFormatter(formatter)
    logger.addHandler(console)

    to_file = logging.FileHandler(log_file, mode="a", encoding="utf-8")
    to_file.setFormatter(formatter)
    logger.addHandler(to_file)

    return logger
