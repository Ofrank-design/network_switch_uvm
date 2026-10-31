# Contributing

Thanks for helping. This project is small and the bar is simple: a change has to
keep the testbench honest. It should still pass on the real RTL and still fail
on the broken one.

## Set up

```bash
git clone https://github.com/frankoduro1912/network_switch_uvm.git
cd network_switch_uvm
make setup                    # fetches the pinned UVM source
export UVM_HOME=$PWD/third_party/uvm-core/src
make smoke
```

You need Verilator 5.x with timing support, the Z3 solver (Verilator uses it for
`randomize()`), a C++20 compiler, make and Python 3. Questa, VCS and Xcelium
also work through `scripts/run_sim.sh -s <simulator>`.

## Before you open a pull request

1. `make lint` is clean.
2. `make regress` passes, with at least three seeds.
3. `make faults` reports every injected bug as caught. If you change the
   scoreboard, a monitor or an assertion, this one matters most.
4. New files start with the SPDX line and the copyright line used in the
   existing files.
5. `CHANGELOG.md` has an entry for anything a user would notice.

## Style

- SystemVerilog: four space indent, one class per file, `snake_case` names,
  types end in `_t` or `_e`. Comment why a thing exists, not what the next line
  does.
- RTL: `always_ff` and `always_comb`, no latches, no blocking assignments in
  clocked blocks. Verilator `-Wall` must stay clean.
- UVM: every component takes its configuration from `router_cfg`. Raise and drop
  the objection only in the test. Never end a test with a fixed delay when a
  drain condition is available.
- Shell: `set -euo pipefail`, quote every expansion.

## Adding a test

1. Add the class to `tb/tests/router_tests.svh`, extending `router_base_test` and
   overriding `run_traffic()` only.
2. Add it to the list in `scripts/regress.sh`.
3. Add a row to the test table in `docs/verification_plan.md`.

## Adding a bug to the fault campaign

New checks deserve a bug that proves they work. Add a `FAULT_MODE` case to
`rtl/network_switch.sv`, document it in the header comment, and add it to
`scripts/fault_campaign.sh`.

## Commits

Short imperative subject, details in the body. One logical change per commit.

## Licence

By contributing you agree that your work is released under the MIT licence in
`LICENSE`.
