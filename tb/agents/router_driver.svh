// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_driver.svh
// Drives one input port. It offers a packet, holds valid and the data steady
// until the switch accepts it, then drops valid. Back to back packets (gap 0)
// keep valid high across the boundary.
//
// Reset: if reset arrives while a packet is on the pins the driver withdraws
// it, waits for reset to release and offers the same packet again. Nothing the
// sequence generated is lost, and the monitor only reports accepted beats, so
// the scoreboard never counts a withdrawn packet.

class router_driver extends uvm_driver #(router_packet);

    router_cfg    cfg;
    router_vif_t  vif;
    int unsigned  port_idx = 0;
    int unsigned  sent_cnt = 0;

    `uvm_component_utils(router_driver)

    function new(string name = "router_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(router_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "router_driver: router_cfg was not set")
    endfunction

    task run_phase(uvm_phase phase);
        vif = cfg.vif;
        vif.valid_in[port_idx] <= 1'b0;

        forever begin
            seq_item_port.get_next_item(req);
            drive_packet(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_packet(router_packet tr);
        bit          accepted = 1'b0;
        int unsigned waited;

        repeat (tr.gap) @(posedge vif.clk);

        while (!accepted) begin
            while (!vif.rst_n) @(posedge vif.clk);

            vif.valid_in[port_idx] <= 1'b1;
            vif.data_in[port_idx]  <= tr.to_word();
            vif.last_in[port_idx]  <= 1'b1;

            waited = 0;
            forever begin
                @(posedge vif.clk);

                if (!vif.rst_n) begin
                    // reset hit while the packet was offered, start over
                    vif.valid_in[port_idx] <= 1'b0;
                    break;
                end

                if (vif.ready_in[port_idx]) begin
                    accepted = 1'b1;
                    break;
                end

                waited++;
                if (waited >= cfg.handshake_timeout) begin
                    // Withdrawing valid here would break the stability rule the
                    // interface assertions check, so end the run instead.
                    `uvm_fatal("HS_TIMEOUT",
                        $sformatf("port %0d: switch did not accept %s within %0d cycles, it has stopped taking traffic",
                                  port_idx, tr.convert2string(), cfg.handshake_timeout))
                end
            end
        end

        vif.valid_in[port_idx] <= 1'b0;
        sent_cnt++;
        `uvm_info("DRV", $sformatf("port %0d sent %s", port_idx, tr.convert2string()), UVM_HIGH)
    endtask

endclass
