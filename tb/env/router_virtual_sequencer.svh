// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_virtual_sequencer.svh
// Holds a handle to every input sequencer so one virtual sequence can run
// traffic on all ports at once and create contention on purpose.

class router_virtual_sequencer extends uvm_sequencer;

    router_sequencer in_sqr [NUM_PORTS];
    router_cfg       cfg;

    `uvm_component_utils(router_virtual_sequencer)

    function new(string name = "router_virtual_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass
