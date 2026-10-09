"""Replication statistics: mean, standard deviation and Student-t confidence intervals."""

from __future__ import annotations

import math
from collections.abc import Sequence

# Two-sided 95 % Student-t critical values t(0.975, df) for df = 1..30.
_T975 = [
    12.706, 4.303, 3.182, 2.776, 2.571, 2.447, 2.365, 2.306, 2.262, 2.228,
    2.201, 2.179, 2.160, 2.145, 2.131, 2.120, 2.110, 2.101, 2.093, 2.086,
    2.080, 2.074, 2.069, 2.064, 2.060, 2.056, 2.052, 2.048, 2.045, 2.042,
]  # fmt: skip


def t975(df: int) -> float:
    if df < 1:
        return math.nan
    if df <= len(_T975):
        return _T975[df - 1]
    return 1.96 + 2.4 / df  # close to the exact value for df > 30


def summarize(values: Sequence[float | None]) -> dict:
    """Mean ± 95 % CI across replications; None values (metric undefined in a run) are skipped."""
    vals = [v for v in values if v is not None and math.isfinite(v)]
    n = len(vals)
    if n == 0:
        return {"mean": None, "sd": None, "ci95": None, "n": 0, "values": list(values)}
    mean = sum(vals) / n
    if n == 1:
        return {"mean": mean, "sd": None, "ci95": None, "n": 1, "values": list(values)}
    sd = math.sqrt(sum((v - mean) ** 2 for v in vals) / (n - 1))
    half = t975(n - 1) * sd / math.sqrt(n)
    return {"mean": mean, "sd": sd, "ci95": [mean - half, mean + half], "n": n, "values": list(values)}


def percentile(sorted_vals: Sequence[float], q: float) -> float:
    """Linear-interpolated percentile of an ascending sequence (q in [0, 100])."""
    if not sorted_vals:
        return 0.0
    if len(sorted_vals) == 1:
        return float(sorted_vals[0])
    pos = (len(sorted_vals) - 1) * q / 100.0
    lo = int(math.floor(pos))
    hi = min(lo + 1, len(sorted_vals) - 1)
    return float(sorted_vals[lo] + (sorted_vals[hi] - sorted_vals[lo]) * (pos - lo))
