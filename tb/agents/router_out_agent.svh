// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_out_agent.svh
// Agent for one output port. The monitor is passive. The sink only answers
// with ready, it never creates traffic.

class router_out_agent extends uvm_agent;

    int unsigned port_idx = 0;

    router_monitor mon;
    router_sink    sink;

    `uvm_component_utils(router_out_agent)

    function new(string name = "router_out_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        mon = router_monitor::type_id::create("mon", this);
        mon.port_idx  = port_idx;
        mon.is_output = 1'b1;

        sink = router_sink::type_id::create("sink", this);
        sink.port_idx = port_idx;
    endfunction

endclass
