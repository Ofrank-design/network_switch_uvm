// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_sink.svh
// The receiver behind one output port. The switch needs somebody to drive
// ready_out, so the output agent carries this small model next to its passive
// monitor. How eager the sink is comes from router_cfg and can change at any
// time, which is how the backpressure tests squeeze the switch.

class router_sink extends uvm_component;

    router_cfg    cfg;
    router_vif_t  vif;
    int unsigned  port_idx = 0;

    `uvm_component_utils(router_sink)

    function new(string name = "router_sink", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(router_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "router_sink: router_cfg was not set")
    endfunction

    task run_phase(uvm_phase phase);
        int unsigned cycle;
        int unsigned period;
        bit          rdy;

        vif   = cfg.vif;
        cycle = port_idx * 3;     // stagger the ports so they do not stall in lockstep

        forever begin
            @(posedge vif.clk);
            cycle++;

            case (cfg.ready_mode)
                RDY_ALWAYS: rdy = 1'b1;
                RDY_NEVER:  rdy = 1'b0;
                RDY_RANDOM: rdy = ($urandom_range(99) < cfg.ready_pct);
                RDY_BURST: begin
                    period = cfg.burst_on + cfg.burst_off;
                    rdy    = (period == 0) ? 1'b1 : ((cycle % period) < cfg.burst_on);
                end
                default:    rdy = 1'b1;
            endcase

            vif.ready_out[port_idx] <= rdy;
        end
    endtask

endclass
