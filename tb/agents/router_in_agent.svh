// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_in_agent.svh
// Active agent for one input port: sequencer, driver and monitor. The port
// number is assigned by the environment before build_phase runs.

class router_in_agent extends uvm_agent;

    int unsigned port_idx = 0;

    router_sequencer sqr;
    router_driver    drv;
    router_monitor   mon;

    `uvm_component_utils(router_in_agent)

    function new(string name = "router_in_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        mon = router_monitor::type_id::create("mon", this);
        mon.port_idx  = port_idx;
        mon.is_output = 1'b0;

        sqr = router_sequencer::type_id::create("sqr", this);
        sqr.port_idx = port_idx;

        drv = router_driver::type_id::create("drv", this);
        drv.port_idx = port_idx;
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

endclass
