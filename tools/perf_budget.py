#!/usr/bin/env python3
"""Enforces the frame-time and GPU budget from perf/report.json.

GitHub-hosted runners have no GPU, so they cannot produce a real report.  The
CI therefore runs this in advisory mode unless PERF_REQUIRED=1, which a
self-hosted GPU runner sets after running the benchmark scene.

Create perf/report.json from the benchmark:
  {
    "frame_ms": 11.8,
    "p99_frame_ms": 15.2,
    "draw_calls": 940,
    "triangles": 1450000,
    "vram_mb": 2100,
    "gpu": "RTX 3060"
  }
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPORT = ROOT / "perf" / "report.json"
BUDGET = ROOT / "perf" / "budget.json"

DEFAULTS = {
    "frame_ms": 16.6,
    "p99_frame_ms": 20.0,
    "draw_calls": 2000,
    "triangles": 5_000_000,
    "vram_mb": 4096,
}


def main() -> int:
    budget = dict(DEFAULTS)
    if BUDGET.exists():
        budget.update(json.loads(BUDGET.read_text()))

    if not REPORT.exists():
        message = f"no {REPORT.relative_to(ROOT)}; GPU budget not measurable on this runner"
        if os.environ.get("PERF_REQUIRED", "0") == "1":
            print(f"error: {message}")
            return 1
        print(f"warning: {message}")
        return 0

    report = json.loads(REPORT.read_text())
    failures = []
    for key, limit in budget.items():
        if key not in report:
            continue
        value = report[key]
        status = "ok" if value <= limit else "OVER"
        print(f"{key:14s} {value:>12}  budget {limit:>12}  {status}")
        if value > limit:
            failures.append(f"{key}={value} > {limit}")

    if failures:
        print("performance budget exceeded: " + ", ".join(failures))
        return 1

    print("performance budget passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
