// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_cfg.svh
// One configuration object shared by the whole environment. Components keep a
// handle to it, so a test can change a knob mid run (for example the output
// ready policy) and every component sees the change on the next cycle.

typedef enum { RDY_ALWAYS, RDY_NEVER, RDY_RANDOM, RDY_BURST } ready_mode_e;

class router_cfg extends uvm_object;

    router_vif_t vif;

    int unsigned num_ports = NUM_PORTS;

    // Output sink behaviour
    ready_mode_e ready_mode  = RDY_ALWAYS;
    int unsigned ready_pct   = 70;     // RDY_RANDOM: chance that ready is high on a cycle
    int unsigned burst_on    = 8;      // RDY_BURST: cycles ready, then
    int unsigned burst_off   = 24;     //            cycles not ready

    // Timeouts, in clock cycles
    int unsigned handshake_timeout = 4000;   // driver waits this long for ready_in
    int unsigned drain_idle_cycles = 40;     // quiet cycles that count as drained
    int unsigned drain_timeout     = 6000;   // give up waiting for the DUT to empty

    bit coverage_en = 1'b1;

    `uvm_object_utils(router_cfg)

    function new(string name = "router_cfg");
        super.new(name);
    endfunction

endclass
