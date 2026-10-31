// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_defs.svh
// Compile time knobs shared by the RTL wrapper, interface, package and top.
// Override on the command line, for example +define+ROUTER_NUM_PORTS=8

`ifndef ROUTER_DEFS_SVH
`define ROUTER_DEFS_SVH

`ifndef ROUTER_NUM_PORTS
  `define ROUTER_NUM_PORTS 4
`endif

`ifndef ROUTER_DATA_W
  `define ROUTER_DATA_W 32
`endif

`ifndef ROUTER_FIFO_DEPTH
  `define ROUTER_FIFO_DEPTH 8
`endif

// 0 is the real design. 1 to 6 inject a known bug, see rtl/network_switch.sv
`ifndef ROUTER_FAULT_MODE
  `define ROUTER_FAULT_MODE 0
`endif

// Hard stop for any test, in nanoseconds of simulated time
`ifndef ROUTER_SIM_TIMEOUT_NS
  `define ROUTER_SIM_TIMEOUT_NS 20000000
`endif

`endif
