"""Small planar-geometry helpers used by the network builder."""

from __future__ import annotations

import math
from collections.abc import Sequence

Point = tuple[float, float]


def dist(a: Point, b: Point) -> float:
    return math.hypot(b[0] - a[0], b[1] - a[1])


def polyline_length(points: Sequence[Point]) -> float:
    return sum(dist(points[i], points[i + 1]) for i in range(len(points) - 1))


def split_polyline(points: Sequence[Point], at: float) -> tuple[list[Point], list[Point]]:
    """Split a polyline at arc-length ``at`` (0 < at < length) into two polylines sharing the split point."""
    if len(points) < 2:
        raise ValueError("polyline needs at least two points")
    remaining = at
    for i in range(len(points) - 1):
        a, b = points[i], points[i + 1]
        seg = dist(a, b)
        if remaining <= seg or i == len(points) - 2:
            t = 0.0 if seg == 0 else min(max(remaining / seg, 0.0), 1.0)
            p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            head = list(points[: i + 1]) + [p]
            tail = [p] + list(points[i + 1 :])
            return _dedupe(head), _dedupe(tail)
        remaining -= seg
    raise AssertionError("unreachable")


def _dedupe(points: list[Point]) -> list[Point]:
    out: list[Point] = []
    for p in points:
        if not out or dist(out[-1], p) > 1e-6:
            out.append(p)
    return out


def exit_circle(points: Sequence[Point], center: Point, radius: float) -> tuple[Point, list[Point]] | None:
    """Walk ``points`` (starting at/near ``center``) and return where the polyline leaves the circle.

    Returns (exit point, remainder of the polyline starting at the exit point),
    or None when the polyline never leaves the circle.
    """
    for i in range(len(points) - 1):
        a, b = points[i], points[i + 1]
        if dist(center, b) < radius:
            continue
        # Solve |a + t(b-a) - c| = r for the largest t in [0, 1].
        dx, dy = b[0] - a[0], b[1] - a[1]
        fx, fy = a[0] - center[0], a[1] - center[1]
        qa = dx * dx + dy * dy
        qb = 2 * (fx * dx + fy * dy)
        qc = fx * fx + fy * fy - radius * radius
        disc = qb * qb - 4 * qa * qc
        if qa == 0 or disc < 0:
            continue
        t = (-qb + math.sqrt(disc)) / (2 * qa)
        t = min(max(t, 0.0), 1.0)
        p = (a[0] + dx * t, a[1] + dy * t)
        return p, _dedupe([p] + list(points[i + 1 :]))
    return None


def arc_points(center: Point, radius: float, a0: float, a1: float, ccw: bool, step_deg: float = 6.0) -> list[Point]:
    """Points on a circular arc from angle a0 to a1 (radians), inclusive of both ends."""
    if ccw:
        sweep = (a1 - a0) % (2 * math.pi)
    else:
        sweep = -((a0 - a1) % (2 * math.pi))
    if abs(sweep) < 1e-9:
        sweep = 2 * math.pi if ccw else -2 * math.pi
    n = max(2, int(math.ceil(abs(math.degrees(sweep)) / step_deg)) + 1)
    return [
        (center[0] + radius * math.cos(a0 + sweep * k / (n - 1)), center[1] + radius * math.sin(a0 + sweep * k / (n - 1)))
        for k in range(n)
    ]


def angle_of(center: Point, p: Point) -> float:
    return math.atan2(p[1] - center[1], p[0] - center[0])
