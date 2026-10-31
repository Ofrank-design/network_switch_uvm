// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_sequencer.svh
// Moves packets from sequences to the driver. It also remembers which input
// port its agent owns, so sequences can stamp the right source on every item.

class router_sequencer extends uvm_sequencer #(router_packet);

    int unsigned port_idx = 0;

    `uvm_component_utils(router_sequencer)

    function new(string name = "router_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass
