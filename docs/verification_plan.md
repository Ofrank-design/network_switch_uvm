# Verification plan

## Goal

Show that the switch delivers every accepted packet, once, to the right output,
unchanged, in the order the contract promises, under random traffic, heavy
contention, output backpressure and reset. Equally important, show that the
testbench would notice if it did not.

## Features and how each is checked

| # | Feature | Checked by | Exercised by |
|---|---|---|---|
| F1 | Correct output for every destination | scoreboard (`MISROUTE`), assertion `a_route` | route sweep, random |
| F2 | Payload and source tag unchanged | scoreboard (`PAYLOAD_MISMATCH`) | random, pattern sequences |
| F3 | No packet lost | scoreboard (`MISSING_PACKET`, `ORDER_OR_LOSS`) | every test, drain check |
| F4 | No packet duplicated or invented | scoreboard (`DUPLICATE`, `UNEXPECTED_OUTPUT`) | every test |
| F5 | Order kept per source and destination | scoreboard (`ORDER_OR_LOSS`) | contention, random |
| F6 | Fair handling of several inputs to one output | no loss under sustained contention, drain check | contention |
| F7 | Input stable until accepted | assertion `a_in_hold` | all |
| F8 | Output stable under backpressure | assertion `a_out_hold` | backpressure, stress |
| F9 | Framing (`last`) | assertions `a_last_in`, `a_last_out`, monitors | all |
| F10 | Backpressure and FIFO full handling | scoreboard, drain, assertions | backpressure, stress |
| F11 | Reset while idle | assertion `a_reset_out`, scoreboard | reset idle |
| F12 | Reset with packets in flight | scoreboard flush, assertion `a_reset_out` | reset in flight |
| F13 | Forward progress | `HS_TIMEOUT` in driver, `DRAIN_TIMEOUT` in env | every test |
| F14 | Protocol: legal destination | input monitor (`ILLEGAL_DEST`) | all |

## Environment

```
tb_top
 ├─ router_if            pin boundary, protocol assertions
 ├─ network_switch       DUT
 └─ uvm_test_top         router_*_test
     └─ env
         ├─ in_agent_N   sequencer, driver, monitor   (one per input)
         ├─ out_agent_N  passive monitor, ready sink  (one per output)
         ├─ sb           scoreboard, reference model
         ├─ cov          functional coverage
         └─ vseqr        virtual sequencer for system traffic
```

Input monitors send accepted packets to the scoreboard and to coverage. Output
monitors send delivered packets to the scoreboard. The reference model knows
only the routing rule and does not look inside the DUT.

## Tests

| Test | What it does | Features |
|---|---|---|
| `router_smoke_test` | One packet, input 0 to output 1 | F1 |
| `router_route_sweep_test` | Every input to every output, mixed gaps | F1 F2 |
| `router_contention_test` | All inputs hammer one output at a time, fast then half ready sink | F3 F4 F5 F6 |
| `router_backpressure_test` | Sinks refuse everything, then release in bursts, FIFOs fill | F7 F8 F10 |
| `router_reset_idle_test` | Reset on an empty switch, traffic before and after | F11 |
| `router_reset_inflight_test` | Reset while a stuck sink keeps packets inside | F12 |
| `router_rand_test` | Corner patterns, then random traffic across four timing profiles | F1 to F5 |
| `router_stress_test` | Long random run, the sink changes behaviour every few hundred cycles | all |

## Test termination

Every test raises its objection before traffic and drops it after
`wait_for_drain()`. The drain waits until the scoreboard has nothing outstanding,
no input or output is valid, and the switch has been quiet for a set number of
cycles. If packets never come out, the run ends with `DRAIN_TIMEOUT` instead of
hanging. A global timeout is set as a last resort.

## Proving the testbench can fail

`rtl/network_switch.sv` has a `FAULT_MODE` parameter with six built in bugs.
`scripts/fault_campaign.sh` runs the tests against each one. A bug that no test
catches is a hole in the testbench, and the script fails.

| Fault | Bug | Expected catch |
|---|---|---|
| 1 | One packet sent to the neighbouring output, destination rewritten to match | `MISROUTE` from the scoreboard. The assertion `a_route` cannot see it because the word is consistent with its new output. |
| 2 | One payload bit flipped | `PAYLOAD_MISMATCH` |
| 3 | One packet silently dropped | `ORDER_OR_LOSS`, then `MISSING_PACKET` at the end |
| 4 | One output packet sent twice | `DUPLICATE` |
| 5 | Forwarding stops after 20 packets | `HS_TIMEOUT`, the input FIFO fills and nothing is accepted |
| 6 | `last` cleared on one output packet | assertion `a_last_out`, monitor `LAST_OUT` |

The scoreboard sorts every unmatched output beat into one of six classes (see the
header of `router_scoreboard.svh`) so that one bug produces one or two clear
errors. Each fault in the table is checked for the error shown, not only for a
failing exit code.

## Exit criteria

1. All tests pass on the real RTL for every seed in the regression.
2. Merged functional coverage is 100 percent (see `coverage_plan.md`).
3. The fault campaign catches all six bugs.
4. The RTL lints clean for 1, 2, 4 and 8 ports.
5. No failing assertion and no unexplained warning in any log.

## Known gaps

Listed in the README under Known limitations.
