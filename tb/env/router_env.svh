// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_env.svh
// One active agent per input port, one output agent per output port, one
// scoreboard shared by all of them, plus coverage and a virtual sequencer.

class router_env extends uvm_env;

    router_cfg                cfg;
    router_in_agent           in_agents  [NUM_PORTS];
    router_out_agent          out_agents [NUM_PORTS];
    router_scoreboard         sb;
    router_coverage           cov;
    router_virtual_sequencer  vseqr;

    `uvm_component_utils(router_env)

    function new(string name = "router_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(router_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "router_env: router_cfg was not set")

        for (int unsigned p = 0; p < NUM_PORTS; p++) begin
            in_agents[p] = router_in_agent::type_id::create($sformatf("in_agent_%0d", p), this);
            in_agents[p].port_idx = p;

            out_agents[p] = router_out_agent::type_id::create($sformatf("out_agent_%0d", p), this);
            out_agents[p].port_idx = p;
        end

        sb    = router_scoreboard::type_id::create("sb", this);
        cov   = router_coverage::type_id::create("cov", this);
        vseqr = router_virtual_sequencer::type_id::create("vseqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        for (int unsigned p = 0; p < NUM_PORTS; p++) begin
            in_agents[p].mon.ap.connect(sb.in_export);
            in_agents[p].mon.ap.connect(cov.analysis_export);
            out_agents[p].mon.ap.connect(sb.out_export);
            vseqr.in_sqr[p] = in_agents[p].sqr;
        end

        cov.sb    = sb;
        vseqr.cfg = cfg;
    endfunction

    // Pulse reset for a few cycles. Everything in flight is discarded, which
    // the scoreboard mirrors on the falling edge.
    task do_reset(int unsigned cycles = 4);
        @(posedge cfg.vif.clk);
        cfg.vif.rst_n <= 1'b0;
        repeat (cycles) @(posedge cfg.vif.clk);
        cfg.vif.rst_n <= 1'b1;
        @(posedge cfg.vif.clk);
    endtask

    // Wait until the switch is empty and quiet. A fixed delay would pass a
    // broken switch that is merely slow, so this waits for real emptiness and
    // gives up with an error if packets never come out.
    task wait_for_drain();
        int unsigned idle   = 0;
        int unsigned waited = 0;

        while (idle < cfg.drain_idle_cycles) begin
            @(posedge cfg.vif.clk);
            waited++;

            if (sb.outstanding() == 0 && !(|cfg.vif.valid_in) && !(|cfg.vif.valid_out))
                idle++;
            else
                idle = 0;

            if (waited >= cfg.drain_timeout) begin
                `uvm_error("DRAIN_TIMEOUT",
                    $sformatf("switch still holds %0d packet(s) after %0d cycles",
                              sb.outstanding(), cfg.drain_timeout))
                return;
            end
        end
    endtask

endclass
