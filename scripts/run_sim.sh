#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
#
# run_sim.sh  build and run one test on the chosen simulator.
#
#   scripts/run_sim.sh -t router_smoke_test [-s verilator] [-n seed] [-f fault]
#                      [-v UVM_MEDIUM] [-p "+NUM_PKTS=50"] [-d "+define+X=Y"] [-w] [-b]
#
#   -t  test name (+UVM_TESTNAME)            default router_smoke_test
#   -s  verilator | questa | vcs | xrun      default verilator
#   -n  random seed                          default 1
#   -f  fault mode 0..6, 0 is the real RTL   default 0
#   -v  UVM verbosity                        default UVM_MEDIUM
#   -p  extra plusargs, quoted
#   -d  extra compile defines, quoted, for example "+define+ROUTER_NUM_PORTS=8"
#   -w  dump waves (waves.vcd)
#   -b  build only
#
# Environment
#   UVM_HOME       path to the Accellera UVM "src" directory
#                  default: <repo>/third_party/uvm-core/src (see scripts/fetch_uvm.sh)
#   VERILATOR_ROOT optional, points at a Verilator install such as the pip wheel
#
# Exit code is 0 only when the log holds the "*** TEST PASSED ***" line.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST=router_smoke_test; SIM=verilator; SEED=1; FAULT=0; VERB=UVM_MEDIUM
EXTRA=""; DEFINES=""; WAVES=0; BUILD_ONLY=0

while getopts "t:s:n:f:v:p:d:wb" o; do
  case $o in
    t) TEST=$OPTARG;; s) SIM=$OPTARG;; n) SEED=$OPTARG;; f) FAULT=$OPTARG;;
    v) VERB=$OPTARG;; p) EXTRA=$OPTARG;; d) DEFINES=$OPTARG;; w) WAVES=1;; b) BUILD_ONLY=1;;
    *) sed -n '5,24p' "$0"; exit 2;;
  esac
done

UVM_HOME="${UVM_HOME:-$ROOT/third_party/uvm-core/src}"
[ -f "$UVM_HOME/uvm_pkg.sv" ] || { echo "UVM not found at $UVM_HOME, run scripts/fetch_uvm.sh or set UVM_HOME" >&2; exit 2; }

TAG=""
[ -n "$DEFINES" ] && TAG="_$(printf '%s' "$DEFINES" | cksum | cut -d' ' -f1)"
BUILD="$ROOT/build/${SIM}_fault${FAULT}${TAG}"
LOGDIR="$ROOT/logs"; mkdir -p "$BUILD" "$LOGDIR"
LOG="$LOGDIR/${TEST}_${SIM}_f${FAULT}${TAG}_s${SEED}.log"

DEFS=(+define+ROUTER_FAULT_MODE=$FAULT)
# shellcheck disable=SC2206  # DEFINES is a space separated list on purpose
DEFS+=($DEFINES)
[ "$WAVES" = 1 ] && DEFS+=(+define+ROUTER_WAVES)

RTL=("$ROOT/rtl/sw_fifo.sv" "$ROOT/rtl/rr_arbiter.sv" "$ROOT/rtl/network_switch.sv")
TB=("$ROOT/tb/interfaces/router_if.sv" "$ROOT/tb/packages/router_uvm_pkg.sv" "$ROOT/tb/top/tb_top.sv")

build_verilator() {
  local vbin=verilator
  if [ -n "${VERILATOR_ROOT:-}" ] && [ -x "$VERILATOR_ROOT/bin/verilator" ]; then vbin="$VERILATOR_ROOT/bin/verilator"; fi
  # The pip wheel ships a verilated.mk with empty compiler settings. Fill them in.
  local mk=()
  local mkfile
  mkfile="$(dirname "$(dirname "$vbin")")/include/verilated.mk"
  if [ -f "$mkfile" ] && grep -q '^CFG_CXXFLAGS_COROUTINES = *$' "$mkfile"; then
    mk=(-MAKEFLAGS "CXX=g++ CFG_CXXFLAGS_STD=-std=gnu++20 CFG_CXXFLAGS_COROUTINES=-fcoroutines CFG_CXXFLAGS_PCH_I=-include")
  fi
  (cd "$BUILD" && "$vbin" --binary --timing --assert -j 0 \
      --timescale 1ns/1ps -Wno-fatal -Wno-lint -Wno-style -Wno-WIDTH -Wno-CASEINCOMPLETE \
      --top-module tb_top --Mdir obj_dir -o sim "${mk[@]}" \
      +define+UVM_NO_DPI "${DEFS[@]}" \
      -I"$UVM_HOME" -I"$ROOT/tb" \
      "$UVM_HOME/uvm_pkg.sv" "${RTL[@]}" "${TB[@]}") 
}
run_verilator() {
  "$BUILD/obj_dir/sim" +UVM_TESTNAME="$TEST" +UVM_VERBOSITY="$VERB" \
      +verilator+seed+"$SEED" +verilator+rand+reset+2 $EXTRA
}

build_questa() {
  (cd "$BUILD" && vlib work >/dev/null && vlog -sv -timescale 1ns/1ps +incdir+"$UVM_HOME" +incdir+"$ROOT/tb" \
      "${DEFS[@]}" "$UVM_HOME/uvm_pkg.sv" "${RTL[@]}" "${TB[@]}")
}
run_questa() {
  (cd "$BUILD" && vsim -c -sv_seed "$SEED" work.tb_top +UVM_TESTNAME="$TEST" +UVM_VERBOSITY="$VERB" $EXTRA -do "run -all; quit -f")
}
build_vcs() {
  (cd "$BUILD" && vcs -full64 -sverilog -timescale=1ns/1ps -ntb_opts uvm-1.2 +incdir+"$ROOT/tb" \
      "${DEFS[@]}" "${RTL[@]}" "${TB[@]}" -o simv)
}
run_vcs() { (cd "$BUILD" && ./simv +UVM_TESTNAME="$TEST" +UVM_VERBOSITY="$VERB" +ntb_random_seed="$SEED" $EXTRA); }
build_xrun() { :; }
run_xrun() {
  (cd "$BUILD" && xrun -64bit -sv -uvm -timescale 1ns/1ps -incdir "$ROOT/tb" "${DEFS[@]}" \
      "${RTL[@]}" "${TB[@]}" +UVM_TESTNAME="$TEST" +UVM_VERBOSITY="$VERB" -svseed "$SEED" $EXTRA)
}

case "$SIM" in verilator|questa|vcs|xrun) ;; *) echo "unknown simulator $SIM" >&2; exit 2;; esac

STALE=0
if [ ! -e "$BUILD/.built" ] || [ -n "$(find "$ROOT/rtl" "$ROOT/tb" -type f -newer "$BUILD/.built" -print -quit)" ]; then STALE=1; fi
if [ "$STALE" = 1 ]; then
  echo "[build] $SIM fault=$FAULT" >&2
  if ! build_$SIM > "$LOGDIR/build_${SIM}_f${FAULT}${TAG}.log" 2>&1; then
    tail -40 "$LOGDIR/build_${SIM}_f${FAULT}${TAG}.log" >&2; echo "build failed, full log: $LOGDIR/build_${SIM}_f${FAULT}.log" >&2; exit 1
  fi
  touch "$BUILD/.built"
fi
[ "$BUILD_ONLY" = 1 ] && exit 0

echo "[run]   $TEST seed=$SEED" >&2
( cd "$BUILD" && run_$SIM ) > "$LOG" 2>&1 || true
grep -E "UVM_(ERROR|FATAL)|TEST (PASSED|FAILED)|SVA" "$LOG" | head -20 || true
if grep -q "\*\*\* TEST PASSED \*\*\*" "$LOG"; then echo "PASS $TEST seed=$SEED fault=$FAULT"; exit 0; fi
echo "FAIL $TEST seed=$SEED fault=$FAULT  (log: $LOG)"; exit 1
