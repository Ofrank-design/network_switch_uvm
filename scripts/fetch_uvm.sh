#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
#
# fetch_uvm.sh  download the Accellera UVM reference implementation.
#
# The commit is pinned, so every machine and every CI run builds against the
# same UVM source. To move to a newer UVM, change UVM_REF and rerun the
# regression before committing the new value.
#
# Commercial simulators (Questa, VCS, Xcelium) ship their own UVM. You only need
# this script for open source flows such as Verilator.

set -euo pipefail

UVM_REPO="https://github.com/accellera-official/uvm-core.git"
UVM_REF="78c06547a2a0a29b3dc9dcafae62b75b2ff61544"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/third_party/uvm-core"

if [ -f "$DEST/src/uvm_pkg.sv" ] && [ "$(git -C "$DEST" rev-parse HEAD 2>/dev/null)" = "$UVM_REF" ]; then
  echo "UVM already present at $DEST ($UVM_REF)"
  exit 0
fi

rm -rf "$DEST"
mkdir -p "$DEST"
git -C "$DEST" init -q
git -C "$DEST" remote add origin "$UVM_REPO"
git -C "$DEST" fetch -q --depth 1 origin "$UVM_REF"
git -C "$DEST" checkout -q FETCH_HEAD

echo "UVM fetched to $DEST"
echo "export UVM_HOME=$DEST/src"
