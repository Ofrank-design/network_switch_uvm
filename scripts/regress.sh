#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
#
# regress.sh  run every test over several seeds and merge the coverage.
#
#   scripts/regress.sh [-s verilator] [-n seeds] [-t "test1 test2"] [-j jobs]
#
#   -s  simulator                       default verilator
#   -n  number of seeds per test        default 3
#   -t  space separated test list       default: all tests
#   -j  parallel simulations            default 2
#
# Output
#   logs/regression_summary.txt   one line per run, plus totals
#   logs/cov/*.csv                per run coverage hit counts
#   logs/coverage_merged.txt      closure over the whole regression
#
# Exit code is 0 only if every run passed and merged coverage is complete.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM=verilator; SEEDS=3; JOBS=2
TESTS="router_smoke_test router_route_sweep_test router_contention_test router_backpressure_test router_reset_idle_test router_reset_inflight_test router_rand_test router_stress_test"

while getopts "s:n:t:j:" o; do
  case $o in s) SIM=$OPTARG;; n) SEEDS=$OPTARG;; t) TESTS=$OPTARG;; j) JOBS=$OPTARG;; *) sed -n '5,20p' "$0"; exit 2;; esac
done

mkdir -p "$ROOT/logs/cov"
rm -f "$ROOT/logs/cov/"*.csv "$ROOT/logs/regression_summary.txt"

# Build once up front so parallel runs do not race on the same build directory.
"$ROOT/scripts/run_sim.sh" -s "$SIM" -b || exit 1

run_one() {
  local t=$1 s=$2
  if "$ROOT/scripts/run_sim.sh" -s "$SIM" -t "$t" -n "$s" -v UVM_LOW \
        -p "+COV_FILE=$ROOT/logs/cov/${t}_s${s}.csv" > /dev/null 2>&1; then
    echo "PASS  $t  seed=$s"
  else
    echo "FAIL  $t  seed=$s"
  fi
}
export -f run_one
export ROOT SIM

jobs_list=()
for t in $TESTS; do for s in $(seq 1 "$SEEDS"); do jobs_list+=("$t $s"); done; done

printf '%s\n' "${jobs_list[@]}" | xargs -P "$JOBS" -L 1 bash -c 'run_one $0 $1' | sort | tee "$ROOT/logs/regression_summary.txt"

pass=$(grep -c '^PASS' "$ROOT/logs/regression_summary.txt" || true)
fail=$(grep -c '^FAIL' "$ROOT/logs/regression_summary.txt" || true)
echo "----"
echo "runs: $((pass + fail))   passed: $pass   failed: $fail" | tee -a "$ROOT/logs/regression_summary.txt"

python3 "$ROOT/scripts/merge_cov.py" "$ROOT"/logs/cov/*.csv | tee "$ROOT/logs/coverage_merged.txt"
cov_rc=${PIPESTATUS[0]}

[ "$fail" -eq 0 ] && [ "$cov_rc" -eq 0 ]
