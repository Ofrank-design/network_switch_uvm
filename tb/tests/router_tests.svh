// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_tests.svh
// The test list, ordered from the simplest check to the heaviest.
//
//   router_smoke_test           one packet, one route
//   router_route_sweep_test     every source to every destination
//   router_contention_test      all inputs fight for one output
//   router_backpressure_test    outputs stall, FIFOs fill, then release
//   router_reset_idle_test      reset with an empty switch
//   router_reset_inflight_test  reset while packets are queued
//   router_rand_test            constrained random, patterns, coverage gate
//   router_stress_test          long run with the sink changing behaviour

// ----------------------------------------------------------------------
class router_smoke_test extends router_base_test;
    `uvm_component_utils(router_smoke_test)

    function new(string name = "router_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_traffic();
        router_single_seq seq = router_single_seq::type_id::create("seq");
        seq.dest    = 1;
        seq.payload = 'hC0FFEE;
        seq.start(env.in_agents[0].sqr);
    endtask
endclass

// ----------------------------------------------------------------------
class router_route_sweep_test extends router_base_test;
    `uvm_component_utils(router_route_sweep_test)

    function new(string name = "router_route_sweep_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_traffic();
        router_sweep_vseq vseq = router_sweep_vseq::type_id::create("vseq");
        vseq.per_dest = 4;
        vseq.start(env.vseqr);
    endtask
endclass

// ----------------------------------------------------------------------
class router_contention_test extends router_base_test;
    `uvm_component_utils(router_contention_test)

    function new(string name = "router_contention_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_traffic();
        router_contention_vseq vseq = router_contention_vseq::type_id::create("vseq");
        vseq.num_pkts = plusarg_int("NUM_PKTS", 40);
        vseq.target   = -1;

        // once with a fast sink, once with a sink that makes the arbiter wait
        cfg.ready_mode = RDY_ALWAYS;
        vseq.start(env.vseqr);

        cfg.ready_mode = RDY_RANDOM;
        cfg.ready_pct  = 50;
        vseq.start(env.vseqr);
    endtask
endclass

// ----------------------------------------------------------------------
class router_backpressure_test extends router_base_test;
    `uvm_component_utils(router_backpressure_test)

    function new(string name = "router_backpressure_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_traffic();
        router_rand_vseq vseq = router_rand_vseq::type_id::create("vseq");
        vseq.num_pkts = plusarg_int("NUM_PKTS", 60);
        vseq.gap_mode = GAP_NONE;

        // Sinks refuse everything, so the FIFOs fill and the inputs get blocked.
        // The release sequence runs beside the traffic: stuck, then bursty, then random.
        cfg.ready_mode = RDY_NEVER;
        fork
            vseq.start(env.vseqr);
            begin
                repeat (300) @(posedge cfg.vif.clk);
                cfg.ready_mode = RDY_BURST;
                cfg.burst_on   = 3;
                cfg.burst_off  = 40;
                repeat (600) @(posedge cfg.vif.clk);
                cfg.ready_mode = RDY_RANDOM;
                cfg.ready_pct  = 25;
            end
        join
    endtask
endclass

// ----------------------------------------------------------------------
class router_reset_idle_test extends router_base_test;
    `uvm_component_utils(router_reset_idle_test)

    function new(string name = "router_reset_idle_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_traffic();
        router_rand_vseq vseq = router_rand_vseq::type_id::create("vseq");
        vseq.num_pkts = 15;

        vseq.start(env.vseqr);
        env.wait_for_drain();

        // nothing is in flight now, so reset should change nothing visible
        env.do_reset(5);
        repeat (3) @(posedge cfg.vif.clk);

        vseq.start(env.vseqr);
    endtask
endclass

// ----------------------------------------------------------------------
class router_reset_inflight_test extends router_base_test;
    `uvm_component_utils(router_reset_inflight_test)

    function new(string name = "router_reset_inflight_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_traffic();
        router_rand_vseq vseq = router_rand_vseq::type_id::create("vseq");
        vseq.num_pkts = plusarg_int("NUM_PKTS", 50);
        vseq.gap_mode = GAP_NONE;

        // A stuck sink keeps packets inside the switch when reset hits.
        cfg.ready_mode = RDY_NEVER;
        fork
            vseq.start(env.vseqr);
            begin
                repeat (120) @(posedge cfg.vif.clk);
                env.do_reset(6);
                cfg.ready_mode = RDY_RANDOM;
                cfg.ready_pct  = 60;
            end
        join
    endtask
endclass

// ----------------------------------------------------------------------
class router_rand_test extends router_base_test;
    `uvm_component_utils(router_rand_test)

    function new(string name = "router_rand_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_traffic();
        router_pattern_vseq pat  = router_pattern_vseq::type_id::create("pat");
        router_rand_vseq    rnd  = router_rand_vseq::type_id::create("rnd");
        int unsigned        n    = plusarg_int("NUM_PKTS", 200);

        // 1. payload corner cases
        pat.start(env.vseqr);

        // 2. mixed gaps against a fast sink
        cfg.ready_mode = RDY_ALWAYS;
        rnd.num_pkts   = n;
        rnd.gap_mode   = GAP_MIXED;
        rnd.start(env.vseqr);

        // 3. no gaps against a sink that is only ready half the time
        cfg.ready_mode = RDY_RANDOM;
        cfg.ready_pct  = 50;
        rnd.gap_mode   = GAP_NONE;
        rnd.start(env.vseqr);

        // 4. sparse traffic, outputs mostly idle
        cfg.ready_mode = RDY_ALWAYS;
        rnd.num_pkts   = n / 4 + 1;
        rnd.gap_mode   = GAP_SPARSE;
        rnd.start(env.vseqr);
    endtask

    // Route coverage has to be complete. Other points need the dedicated
    // tests, so they are judged over the whole regression by merge_cov.py.
    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (env.cov.route_pct() < 100.0)
            `uvm_error("COV_GOAL", $sformatf("route coverage is %0.2f%%, goal is 100%%", env.cov.route_pct()))
    endfunction
endclass

// ----------------------------------------------------------------------
class router_stress_test extends router_base_test;
    `uvm_component_utils(router_stress_test)

    function new(string name = "router_stress_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_traffic();
        router_rand_vseq vseq    = router_rand_vseq::type_id::create("vseq");
        bit              running = 1'b1;

        vseq.num_pkts = plusarg_int("NUM_PKTS", 2000);
        vseq.gap_mode = GAP_NONE;

        fork
            begin
                vseq.start(env.vseqr);
                running = 1'b0;
            end
            // The sink changes personality every few hundred cycles.
            begin
                while (running) begin
                    case ($urandom_range(3))
                        0: cfg.ready_mode = RDY_ALWAYS;
                        1: begin cfg.ready_mode = RDY_RANDOM; cfg.ready_pct = $urandom_range(10, 90); end
                        2: begin cfg.ready_mode = RDY_BURST;  cfg.burst_on = $urandom_range(1, 10);
                                 cfg.burst_off = $urandom_range(1, 60); end
                        3: cfg.ready_mode = RDY_NEVER;
                    endcase
                    repeat ($urandom_range(40, 400)) @(posedge cfg.vif.clk);
                    // never leave the sink stuck for long
                    if (cfg.ready_mode == RDY_NEVER) begin
                        cfg.ready_mode = RDY_ALWAYS;
                        repeat (30) @(posedge cfg.vif.clk);
                    end
                end
            end
        join
    endtask
endclass
