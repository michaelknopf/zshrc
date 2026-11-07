# /// script
# requires-python = ">=3.13"
# dependencies = ["pytest>=8"]
# ///
"""Tests for the balance projections in charts.py. Run: uv run test_charts.py"""

import sys
from datetime import date

import pytest

from charts import Balance

AS_OF = date(2026, 11, 7)


def grant(used: float, burn: float, ends: date) -> Balance:
    return Balance("Grant", 100_000, used, burn, ends, "", "credits")


def test_unused_at_expiry() -> None:
    assert grant(10_000, 5_000, date(2027, 4, 29)).outcome(AS_OF, "October") == "~$62k expires unused at October's pace"


def test_runs_out_before_expiry() -> None:
    assert grant(90_000, 5_000, date(2027, 11, 30)).outcome(AS_OF, "October") == "Runs out ~Jan 6 at October's pace"


def test_projection_capped_at_grant() -> None:
    assert grant(90_000, 5_000, date(2027, 11, 30)).projected_used(AS_OF) == 100_000


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-q"]))
