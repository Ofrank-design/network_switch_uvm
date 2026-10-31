#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
#
# lint.sh  lint the RTL with Verilator -Wall for several port counts.
# Any warning fails the run.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VBIN=verilator
[ -n "${VERILATOR_ROOT:-}" ] && [ -x "$VERILATOR_ROOT/bin/verilator" ] && VBIN="$VERILATOR_ROOT/bin/verilator"

for ports in 1 2 4 8; do
  echo "lint: NUM_PORTS=$ports"
  "$VBIN" --lint-only -Wall -GNUM_PORTS=$ports --top-module network_switch \
      "$ROOT/rtl/sw_fifo.sv" "$ROOT/rtl/rr_arbiter.sv" "$ROOT/rtl/network_switch.sv"
done
echo "lint clean"
