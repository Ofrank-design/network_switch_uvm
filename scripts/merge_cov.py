#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
"""Merge the per run coverage files written by the testbench.

Each input file holds lines of "point,bin,hits", written when a test is run
with +COV_FILE=<path>. The hit counts are added up across all files, and every
bin that stayed at zero is listed as a hole.

Usage: merge_cov.py [--goal PERCENT] file.csv [file.csv ...]
Exit status is 0 when merged coverage meets the goal, 1 otherwise, 2 on bad input.
"""

import argparse
import csv
import sys
from collections import OrderedDict


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("files", nargs="+", help="coverage CSV files from the regression")
    ap.add_argument("--goal", type=float, default=100.0, help="required total coverage in percent")
    args = ap.parse_args()

    bins: "OrderedDict[tuple[str, str], int]" = OrderedDict()
    used = 0

    for path in args.files:
        try:
            with open(path, newline="", encoding="utf-8") as fh:
                for row in csv.reader(fh):
                    if len(row) != 3:
                        continue
                    point, name, hits = row
                    try:
                        count = int(hits)
                    except ValueError:
                        print(f"merge_cov: bad hit count in {path}: {row}", file=sys.stderr)
                        return 2
                    bins[(point, name)] = bins.get((point, name), 0) + count
            used += 1
        except OSError as exc:
            print(f"merge_cov: cannot read {path}: {exc}", file=sys.stderr)

    if used == 0 or not bins:
        print("merge_cov: no coverage data found", file=sys.stderr)
        return 2

    points: "OrderedDict[str, list[tuple[str, int]]]" = OrderedDict()
    for (point, name), hits in bins.items():
        points.setdefault(point, []).append((name, hits))

    print(f"merged coverage from {used} run(s)")
    print("-" * 52)
    covered_total = 0
    for point, items in points.items():
        covered = sum(1 for _, h in items if h > 0)
        covered_total += covered
        print(f"  {point:<14} {covered:>3} / {len(items):<3}  {100.0 * covered / len(items):6.2f}%")
        for name, hits in items:
            if hits == 0:
                print(f"      hole: {point}/{name}")

    pct = 100.0 * covered_total / len(bins)
    print("-" * 52)
    print(f"  {'TOTAL':<14} {covered_total:>3} / {len(bins):<3}  {pct:6.2f}%   (goal {args.goal:.2f}%)")
    return 0 if pct >= args.goal else 1


if __name__ == "__main__":
    sys.exit(main())
