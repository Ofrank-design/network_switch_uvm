// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_coverage.svh
// Functional coverage for the switch. Packet level points come from the input
// monitors. Cycle level points (backpressure, contention, parallel transfers,
// reset timing) are sampled straight off the interface.
//
// Coverage points
//   route          every source to destination pair
//   payload        data patterns: zeros, ones, alternating, one hot, other
//   out_stall      each output held off by its sink while it had data
//   in_blocked     each input held off by a full FIFO
//   contention     2..N inputs offering to the same output in one cycle
//   parallel       2..N outputs delivering in the same cycle
//   reset          reset during idle and reset with packets in flight
//
// Set +COV_FILE=<path> to write the hit counts for scripts/merge_cov.py.

class router_coverage extends uvm_subscriber #(router_packet);

    router_cfg           cfg;
    router_vif_t         vif;
    router_scoreboard    sb;       // set by the environment, used for reset timing
    router_cov_db        db;

    `uvm_component_utils(router_coverage)

    function new(string name = "router_coverage", uvm_component parent = null);
        super.new(name, parent);
        db = router_cov_db::type_id::create("db");
        declare_bins();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(router_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "router_coverage: router_cfg was not set")
    endfunction

    protected function void declare_bins();
        for (int unsigned s = 0; s < NUM_PORTS; s++)
            for (int unsigned d = 0; d < NUM_PORTS; d++)
                db.declare("route", $sformatf("src%0d_dst%0d", s, d));

        db.declare("payload", "all_zeros");
        db.declare("payload", "all_ones");
        db.declare("payload", "alt_10");
        db.declare("payload", "alt_01");
        db.declare("payload", "one_hot");
        db.declare("payload", "other");

        for (int unsigned p = 0; p < NUM_PORTS; p++) begin
            db.declare("out_stall",  $sformatf("out%0d", p));
            db.declare("in_blocked", $sformatf("in%0d",  p));
        end

        for (int unsigned n = 2; n <= NUM_PORTS; n++) begin
            db.declare("contention", $sformatf("%0d_inputs", n));
            db.declare("parallel",   $sformatf("%0d_outputs", n));
        end

        db.declare("reset", "during_idle");
        db.declare("reset", "with_traffic");
    endfunction

    // ------------------------------------------------------------------
    // Packet level
    // ------------------------------------------------------------------
    function void write(router_packet t);
        router_payload_t p = t.payload;
        router_payload_t alt10;
        router_payload_t alt01;

        if (!cfg.coverage_en) return;
        if (t.source >= NUM_PORTS || t.destination >= NUM_PORTS) return;

        db.hit("route", $sformatf("src%0d_dst%0d", t.source, t.destination));

        for (int unsigned b = 0; b < PAYLOAD_W; b++) begin
            alt10[b] = (b % 2) == 1;
            alt01[b] = (b % 2) == 0;
        end

        if      (p == '0)            db.hit("payload", "all_zeros");
        else if (p == '1)            db.hit("payload", "all_ones");
        else if (p == alt10)         db.hit("payload", "alt_10");
        else if (p == alt01)         db.hit("payload", "alt_01");
        else if ((p & (p - 1)) == 0) db.hit("payload", "one_hot");
        else                         db.hit("payload", "other");
    endfunction

    // ------------------------------------------------------------------
    // Cycle level
    // ------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        bit          rst_prev = 1'b0;
        int unsigned srcs;
        int unsigned xfers;

        vif = cfg.vif;

        forever begin
            @(posedge vif.clk);
            if (!cfg.coverage_en) continue;

            if (rst_prev && !vif.rst_n) begin
                bit busy = (|vif.valid_in) || (|vif.valid_out) || (sb != null && sb.outstanding() > 0);
                db.hit("reset", busy ? "with_traffic" : "during_idle");
            end
            rst_prev = vif.rst_n;

            if (!vif.rst_n) continue;

            xfers = 0;
            for (int unsigned p = 0; p < NUM_PORTS; p++) begin
                if (vif.valid_out[p] && !vif.ready_out[p]) db.hit("out_stall",  $sformatf("out%0d", p));
                if (vif.valid_in[p]  && !vif.ready_in[p])  db.hit("in_blocked", $sformatf("in%0d",  p));
                if (vif.valid_out[p] &&  vif.ready_out[p]) xfers++;
            end
            if (xfers >= 2) db.hit("parallel", $sformatf("%0d_outputs", xfers));

            for (int unsigned d = 0; d < NUM_PORTS; d++) begin
                srcs = 0;
                for (int unsigned s = 0; s < NUM_PORTS; s++)
                    if (vif.valid_in[s] && (vif.data_in[s][DATA_W-1 -: PORT_W] == PORT_W'(d))) srcs++;
                if (srcs >= 2) db.hit("contention", $sformatf("%0d_inputs", srcs));
            end
        end
    endtask

    function real route_pct();
        return db.point_pct("route");
    endfunction

    function void report_phase(uvm_phase phase);
        string path;
        super.report_phase(phase);
        `uvm_info("COVERAGE", db.report(), UVM_LOW)
        if ($value$plusargs("COV_FILE=%s", path)) db.dump(path);
    endfunction

endclass
