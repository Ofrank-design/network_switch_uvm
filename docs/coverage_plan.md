# Coverage plan

Coverage answers "which situations did we actually create", which a count of
simulated cycles cannot. A percentage also proves nothing about correctness, so
it is read together with the scoreboard result and the fault campaign.

## How it is collected

`router_coverage` holds the points below. The bookkeeping lives in plain classes
(`router_cov_db`) rather than SystemVerilog covergroups, so the same numbers come
out of every simulator, including the open source ones that ignore covergroups.
Every bin is declared at the start, so a bin that never fires appears as a hole.

Each run writes its hit counts when started with `+COV_FILE=<path>`.
`scripts/merge_cov.py` adds those files together. The goal is closure over the
whole regression, because the dedicated tests, such as reset, cover points that
the random test does not.

## Points

| Point | Bins | Meaning |
|---|---|---|
| `route` | `NUM_PORTS` squared | every source and destination pair was accepted |
| `payload` | all zeros, all ones, `1010...`, `0101...`, one hot, other | data patterns |
| `out_stall` | one per output | an output held a valid beat while its sink was not ready |
| `in_blocked` | one per input | an input offered a beat while its FIFO was full |
| `contention` | 2 up to `NUM_PORTS` inputs | that many inputs offered to one output in the same cycle |
| `parallel` | 2 up to `NUM_PORTS` outputs | that many outputs delivered in the same cycle |
| `reset` | during idle, with traffic | reset hit an empty switch, and a busy one |

## Goals

| Scope | Goal |
|---|---|
| `router_rand_test`, route point | 100 percent, checked by the test itself |
| Merged regression, all points | 100 percent, checked by `merge_cov.py` |

## Not collected yet

Packet length (single beat design), arbitration winner order, maximum FIFO
occupancy as a cross with stall length. They become relevant with multi beat
packets and are listed in the roadmap.
