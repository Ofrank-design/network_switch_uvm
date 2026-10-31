# DUT contract

This is the contract the testbench checks. If you point the environment at a
different router, this page is what you compare it against.

## Ports

`NUM_PORTS` input ports and `NUM_PORTS` output ports, default 4. Every port has
a `valid`, `ready`, `data` and `last` signal. One clock, one synchronous active
low reset.

| Signal | Direction | Meaning |
|---|---|---|
| `valid_in[i]`, `data_in[i]`, `last_in[i]` | into the switch | beat offered on input `i` |
| `ready_in[i]` | out of the switch | input `i` can take the beat |
| `valid_out[o]`, `data_out[o]`, `last_out[o]` | out of the switch | beat presented on output `o` |
| `ready_out[o]` | into the switch | the receiver on output `o` can take the beat |

## Transfer rule

A beat moves on a rising clock edge where `valid` and `ready` are both high.

Once `valid` is high it stays high, with the same data, until `ready` is high.
This applies to the testbench on the inputs and to the switch on the outputs.
Both are checked by assertions in `tb/interfaces/router_if.sv`.

## Packet format

One packet is one beat, and `last` is always high. The data word is:

```
 DATA_W-1                                              0
 +------------+---------------+------------------------+
 | destination| source tag    | payload                |
 | PORT_W bits| PORT_W bits   | DATA_W - 2*PORT_W bits |
 +------------+---------------+------------------------+
```

With the defaults (32 bit data, 4 ports) `PORT_W` is 2 and the payload is 28 bits.
The switch reads only the destination. The source tag and payload pass through
unchanged, and the source tag lets the scoreboard know where a packet came from.

## Routing

A packet accepted on any input leaves on the output named by its destination
field. A destination outside `0 .. NUM_PORTS-1` is illegal. The testbench never
generates one, and the input monitor reports one if it ever sees it.

## Ordering

Packets from one input to one output leave in the order they entered. Packets
from different inputs to the same output may interleave in any order, because
that depends on arbitration. The scoreboard keeps one queue per
(source, destination) pair so it checks exactly the promise above and no more.

## Arbitration and buffering (reference RTL)

- Every input has a FIFO, depth 8 by default. `ready_in` drops when it is full.
- Each output has a round robin arbiter over the FIFO heads that target it.
- Each output has a one entry register. It holds its beat while `ready_out` is low.
- The arbiter moves on only when its grant is used, so a stalled output does not
  cost the winner its turn.

These choices belong to the reference RTL. The testbench does not depend on
them, apart from FIFO depth appearing in the backpressure test.

## Reset

Synchronous, active low. While reset is low the switch discards everything it
holds, and no output may be valid in the cycle after reset is seen. The
scoreboard discards its expected packets on the falling edge of reset, and the
monitors ignore beats while reset is low, so both sides agree on what was lost.
A packet a driver was offering when reset hit is withdrawn and offered again
after reset releases.

## Not covered

Multi beat packets, error responses, credit based flow control, multiple clocks
and packet dropping on purpose. See the known limitations in the README.
