// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_monitor.svh
// Passive observer for one port. It never drives a pin. A beat is reported only
// on an edge where valid and ready are both high and reset is released, which
// is exactly when the interface contract says a transfer happens.
//
// is_output = 0 : watches an input port, reports what the switch accepted.
// is_output = 1 : watches an output port, reports what the switch delivered.

class router_monitor extends uvm_monitor;

    router_cfg    cfg;
    router_vif_t  vif;
    int unsigned  port_idx  = 0;
    bit           is_output = 1'b0;
    int unsigned  seen      = 0;

    uvm_analysis_port #(router_packet) ap;

    `uvm_component_utils(router_monitor)

    function new(string name = "router_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(router_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "router_monitor: router_cfg was not set")
    endfunction

    task run_phase(uvm_phase phase);
        vif = cfg.vif;
        forever begin
            @(posedge vif.clk);
            if (!vif.rst_n) continue;

            if (is_output) sample_output();
            else           sample_input();
        end
    endtask

    protected task sample_input();
        router_packet pkt;

        if (!(vif.valid_in[port_idx] && vif.ready_in[port_idx])) return;

        pkt = router_packet::from_word(vif.data_in[port_idx], "in_pkt");
        pkt.last        = vif.last_in[port_idx];
        pkt.out_port    = -1;
        pkt.accept_time = $time;
        pkt.packet_id   = seen++;

        if (pkt.source != port_idx)
            `uvm_error("SRC_TAG", $sformatf("input %0d accepted a word tagged as source %0d",
                                            port_idx, pkt.source))
        if (pkt.destination >= NUM_PORTS)
            `uvm_error("ILLEGAL_DEST", $sformatf("input %0d accepted destination %0d, only %0d ports exist",
                                                 port_idx, pkt.destination, NUM_PORTS))
        if (!pkt.last)
            `uvm_error("LAST_IN", $sformatf("input %0d accepted a beat without last", port_idx))

        `uvm_info("MON_IN", pkt.convert2string(), UVM_HIGH)
        ap.write(pkt);
    endtask

    protected task sample_output();
        router_packet pkt;

        if (!(vif.valid_out[port_idx] && vif.ready_out[port_idx])) return;

        pkt = router_packet::from_word(vif.data_out[port_idx], "out_pkt");
        pkt.last        = vif.last_out[port_idx];
        pkt.out_port    = int'(port_idx);
        pkt.accept_time = $time;
        pkt.packet_id   = seen++;

        if (!pkt.last)
            `uvm_error("LAST_OUT", $sformatf("output %0d delivered a beat without last", port_idx))

        `uvm_info("MON_OUT", $sformatf("out %0d: %s", port_idx, pkt.convert2string()), UVM_HIGH)
        ap.write(pkt);
    endtask

endclass
