#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
#
# fault_campaign.sh  prove that the testbench can fail.
#
# The RTL has six built in bugs, selected with FAULT_MODE (see
# rtl/network_switch.sv). For each one this script runs the tests against the
# broken design. A fault counts as CAUGHT when at least one test fails. A fault
# that passes everything is a hole in the testbench, and the script exits 1.
#
#   scripts/fault_campaign.sh [-s verilator] [-t "test1 test2"]
#
# Default tests are router_rand_test and router_contention_test.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM=verilator
TESTS="router_rand_test router_contention_test"

while getopts "s:t:" o; do
  case $o in s) SIM=$OPTARG;; t) TESTS=$OPTARG;; *) sed -n '5,17p' "$0"; exit 2;; esac
done

declare -A NAME=(
  [1]="misrouted packet"
  [2]="flipped payload bit"
  [3]="dropped packet"
  [4]="duplicated packet"
  [5]="forwarding stops"
  [6]="last flag dropped"
)

missed=0
mkdir -p "$ROOT/logs"
: > "$ROOT/logs/fault_campaign.txt"

for f in 1 2 3 4 5 6; do
  caught_by=""
  for t in $TESTS; do
    if ! "$ROOT/scripts/run_sim.sh" -s "$SIM" -f "$f" -t "$t" -v UVM_LOW > /dev/null 2>&1; then
      caught_by="$caught_by $t"
    fi
  done
  if [ -n "$caught_by" ]; then
    line=$(printf "CAUGHT  fault %s  %-22s by:%s" "$f" "${NAME[$f]}" "$caught_by")
  else
    line=$(printf "MISSED  fault %s  %-22s no test failed" "$f" "${NAME[$f]}")
    missed=$((missed + 1))
  fi
  echo "$line" | tee -a "$ROOT/logs/fault_campaign.txt"
done

echo "----"
echo "faults missed: $missed" | tee -a "$ROOT/logs/fault_campaign.txt"
[ "$missed" -eq 0 ]
