# network_switch_uvm

A UVM verification environment for a multi port packet switch, written in
SystemVerilog. It generates constrained random traffic, drives it into the
switch, watches every port, and checks each packet against an independent
reference model. It ships with the switch RTL it verifies, six deliberately
broken variants of that RTL to prove the testbench can fail, and everything
needed to run it from a clean checkout.

[![CI](https://github.com/frankoduro1912/network_switch_uvm/actions/workflows/ci.yml/badge.svg)](https://github.com/frankoduro1912/network_switch_uvm/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Results

Run on Verilator 5.4x with the pinned Accellera UVM source, on the real RTL.

| Check | Result |
|---|---|
| Tests | 8 tests, 3 seeds each, **24 of 24 pass** |
| Merged functional coverage | **100 percent** (38 of 38 bins) |
| Scoreboard | every accepted packet matched, none lost, none unexpected |
| Fault campaign | **all 6 injected bugs caught**, each by the check meant to catch it |
| Eight port build | smoke, contention, random and reset in flight tests pass |
| RTL lint | clean at 1, 2, 4 and 8 ports with `-Wall` |

Detailed logs for any run land in `logs/`. Reproduce all of this with the
commands in [Quick start](#quick-start).

## What it verifies

- Every packet leaves on the output its destination field names.
- Payload and source tag arrive unchanged.
- Nothing is lost, duplicated or invented.
- Packets from one input to one output keep their order.
- Several inputs aiming at one output are all served.
- Outputs that refuse data never cause a beat to change or vanish.
- Reset, when the switch is idle and when it is full of packets.
- Forward progress. A test that cannot drain fails with a clear message instead
  of hanging.

## Architecture

```
                         router_*_test
                               |
                            router_env
        +------------+---------+-----------+--------------+
        |            |                     |              |
  in_agent_N    out_agent_N          router_scoreboard  router_coverage
  sqr drv mon   mon  sink             reference model    functional bins
        |            |                     ^   ^
        |            +---- delivered ------+   |
        +----------------- accepted ----------+

  tb_top:   clk, reset, router_if (with assertions), network_switch (DUT)
```

- **Input agent** (one per input): sequencer, driver and monitor. The agent owns
  its port number, so a driver can never drift onto a pin that belongs to someone
  else.
- **Output agent** (one per output): a passive monitor and a small sink that
  drives `ready_out`. Its behaviour (always, never, random, bursty) is set from
  the test and can change at any time.
- **Scoreboard**: keeps one expected queue per source and destination pair, which
  is exactly the ordering the switch promises. An output beat that shows up
  before its input beat is held and matched later, so monitor timing never
  causes a false failure.
- **Coverage**: routes, payload patterns, stalls, blocked inputs, contention,
  parallel transfers and reset timing. Collected in plain classes so the numbers
  are the same on every simulator.
- **Assertions** in `router_if` check stability, framing, routing and reset on
  every cycle of every test.

The contract between testbench and switch is in
[docs/protocol.md](docs/protocol.md). The plan, with a feature to check mapping,
is in [docs/verification_plan.md](docs/verification_plan.md).

## Repository layout

```
rtl/                 switch under test: sw_fifo, rr_arbiter, network_switch
tb/
  interfaces/        router_if with protocol assertions
  packages/          router_uvm_pkg (compile order), router_defs.svh (knobs)
  agents/            packet, sequencer, driver, monitor, sink, agents
  env/               config, scoreboard, coverage, virtual sequencer, env
  sequences/         per port sequences and system level virtual sequences
  tests/             base test and the eight tests
  top/               tb_top
scripts/             run_sim, regress, fault_campaign, merge_cov, lint, fetch_uvm
docs/                protocol, verification plan, coverage plan
.github/             CI, issue and pull request templates, code owners
```

## Quick start

You need Verilator 5.x with timing support, the Z3 solver, a C++20 compiler, make
and Python 3. On Ubuntu:

```bash
sudo apt-get install -y g++ make z3
pip install verilator            # or any Verilator 5 build with --timing
```

Then:

```bash
git clone https://github.com/frankoduro1912/network_switch_uvm.git
cd network_switch_uvm
make setup                                        # fetch the pinned UVM source
export UVM_HOME=$PWD/third_party/uvm-core/src

make smoke                                        # first packet through the switch
make regress                                      # all tests, 3 seeds, merged coverage
make faults                                       # prove the testbench catches bugs
```

The pip build of Verilator keeps its path in a package folder. If `verilator` is
not on your path, point the scripts at it:

```bash
export VERILATOR_ROOT=$(python -c 'import verilator,os;print(os.path.dirname(verilator.__file__))')
```

### Run one test

```bash
scripts/run_sim.sh -t router_rand_test -n 7           # seed 7
scripts/run_sim.sh -t router_stress_test -p "+NUM_PKTS=5000"
scripts/run_sim.sh -t router_smoke_test -v UVM_HIGH -w # full trace and waves.vcd
```

### Other simulators

```bash
scripts/run_sim.sh -s questa -t router_rand_test
scripts/run_sim.sh -s vcs    -t router_rand_test
scripts/run_sim.sh -s xrun   -t router_rand_test
```

Those use the UVM that ships with the tool. Only Verilator has been run for this
release, see [Known limitations](#known-limitations).

### Change the design size

Port count, data width and FIFO depth are compile time knobs. Pass them as
defines, for example an eight port switch:

```bash
scripts/run_sim.sh -t router_rand_test -d "+define+ROUTER_NUM_PORTS=8"
```

The defaults (4 ports, 32 bit data, FIFO depth 8) live in
`tb/packages/router_defs.svh`. Each combination of defines gets its own build
directory, so changing size never reuses a stale build.

## Tests

| Test | Purpose |
|---|---|
| `router_smoke_test` | One packet from input 0 to output 1. First thing to run. |
| `router_route_sweep_test` | Every input to every output |
| `router_contention_test` | All inputs hammer one output, fast and slow sink |
| `router_backpressure_test` | Sinks refuse, FIFOs fill, then release in bursts |
| `router_reset_idle_test` | Reset on an empty switch |
| `router_reset_inflight_test` | Reset with packets queued inside |
| `router_rand_test` | Payload corner cases, then random traffic in four timing profiles |
| `router_stress_test` | Long run, the sink changes behaviour every few hundred cycles |

Useful plusargs: `+READY_MODE=always|never|random|burst`, `+READY_PCT=<0..100>`,
`+NUM_PKTS=<n>`, `+COV_FILE=<path>`.

## Proving the testbench can fail

A passing run says little if the testbench cannot fail. The switch RTL has a
`FAULT_MODE` parameter that plants one bug at a time. `make faults` runs the
tests against each one and fails if any bug goes unnoticed.

| Fault | Bug | Caught by |
|---|---|---|
| 1 | one packet routed to the neighbouring output | `MISROUTE` (scoreboard) |
| 2 | one payload bit flipped | `PAYLOAD_MISMATCH` |
| 3 | one packet silently dropped | `ORDER_OR_LOSS`, then `MISSING_PACKET` |
| 4 | one packet delivered twice | `DUPLICATE` |
| 5 | forwarding stops after 20 packets | `HS_TIMEOUT` |
| 6 | `last` cleared on one packet | assertion `a_last_out`, monitor `LAST_OUT` |

The scoreboard sorts each unmatched output beat into one of six classes, so a
single bug gives one or two clear errors rather than a flood. Fault 1 is a good
example: the planted bug rewrites the destination consistently, so the routing
assertion cannot see it, and the scoreboard finds it by matching source and
payload against the route where the packet was expected.

## Known limitations

- Packets are one beat. Multi beat packets, interleaving and length coverage are
  the next step, and the monitor and scoreboard are structured to take them.
- The testbench was developed and run on Verilator with the Accellera UVM
  reference source and no DPI backend, so UVM's HDL back door and regex features
  are unavailable. UVM prints two warnings about this at time zero in every run,
  and they are expected. The Questa, VCS and Xcelium paths in `run_sim.sh` follow the
  documented command lines for those tools but have not been run.
- The eight port build passes its tests, but a single random run does not reach
  every contention and parallel bin at that size (for example eight inputs
  hitting one output in the same cycle). Closing those needs a longer merged
  regression.
- Verilator solves constraints with Z3, whose value distribution is not uniform.
  Destinations are therefore drawn in the sequence with `$urandom_range`, so
  traffic stays balanced on every tool.
- The switch is a clean reference design. It has no error responses, no packet
  priority and no multiple clock domains, so none of those are verified.
- Formal verification is not included. The assertions in `router_if` are written
  as ordinary concurrent assertions and can be reused in a formal flow.
- This is a verification environment. The RTL is not a hardened or production
  design, see [SECURITY.md](SECURITY.md).

## Roadmap

1. Multi beat packets with framing, length coverage and interleave checks.
2. Credit based flow control variant of the interface.
3. Throughput and latency checks.
4. Formal properties for the arbiter and FIFO.
5. Run and document the Questa, VCS and Xcelium flows.

## Contributing and security

Read [CONTRIBUTING.md](CONTRIBUTING.md) first. Report vulnerabilities privately,
as described in [SECURITY.md](SECURITY.md). Everyone taking part follows the
[Code of Conduct](CODE_OF_CONDUCT.md). Changes are listed in
[CHANGELOG.md](CHANGELOG.md).

## Licence

MIT. Copyright (c) 2026 Frank Oduro, frankoduro1912@gmail.com. See
[LICENSE](LICENSE).

The UVM source fetched by `make setup` belongs to Accellera and is distributed
under its own Apache 2.0 licence. It is not part of this repository.
