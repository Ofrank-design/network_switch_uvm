// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_base_test.svh
// Common skeleton for every test: builds the environment, owns the objection,
// waits for the switch to drain and prints one clear verdict line.
//
// A test only overrides run_traffic(). The objection is raised before any
// traffic starts and dropped after the drain check, so the run can neither hang
// on a forgotten objection nor end before the scoreboard has seen the outputs.
//
// Plusargs understood by every test
//   +READY_MODE=always|never|random|burst   initial output ready policy
//   +READY_PCT=<0..100>                      chance of ready in random mode
//   +NUM_PKTS=<n>                            packets per port, where a test uses it

class router_base_test extends uvm_test;

    router_env  env;
    router_cfg  cfg;

    `uvm_component_utils(router_base_test)

    function new(string name = "router_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        string mode;
        super.build_phase(phase);

        cfg = router_cfg::type_id::create("cfg");
        if (!uvm_config_db#(router_vif_t)::get(this, "", "vif", cfg.vif))
            `uvm_fatal("NOVIF", "the testbench top did not publish the router interface")

        if ($value$plusargs("READY_MODE=%s", mode)) begin
            case (mode)
                "always": cfg.ready_mode = RDY_ALWAYS;
                "never":  cfg.ready_mode = RDY_NEVER;
                "random": cfg.ready_mode = RDY_RANDOM;
                "burst":  cfg.ready_mode = RDY_BURST;
                default:  `uvm_fatal("PLUSARG", $sformatf("unknown +READY_MODE=%s", mode))
            endcase
        end
        cfg.ready_pct = plusarg_int("READY_PCT", cfg.ready_pct);

        uvm_config_db#(router_cfg)::set(this, "env*", "cfg", cfg);
        env = router_env::type_id::create("env", this);
    endfunction

    function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        uvm_top.set_timeout(`ROUTER_SIM_TIMEOUT_NS * 1ns, 0);
    endfunction

    // Integer plusarg with a default.
    function int unsigned plusarg_int(string name, int unsigned fallback);
        int unsigned v;
        if ($value$plusargs({name, "=%d"}, v)) return v;
        return fallback;
    endfunction

    // Wait for the DUT to leave reset. The top releases it after a few cycles.
    protected task wait_reset_release();
        while (!cfg.vif.rst_n) @(posedge cfg.vif.clk);
        repeat (2) @(posedge cfg.vif.clk);
    endtask

    // Tests put their stimulus here.
    virtual task run_traffic();
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this, "traffic running");

        wait_reset_release();
        `uvm_info("TEST", $sformatf("starting %s", get_type_name()), UVM_LOW)

        run_traffic();

        // Make sure the sink is listening before judging the drain.
        cfg.ready_mode = RDY_ALWAYS;
        env.wait_for_drain();

        phase.drop_objection(this, "traffic drained");
    endtask

    function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        int unsigned      errs;
        super.report_phase(phase);

        svr  = uvm_report_server::get_server();
        errs = svr.get_severity_count(UVM_ERROR) + svr.get_severity_count(UVM_FATAL);

        if (errs == 0)
            `uvm_info("RESULT", $sformatf("*** TEST PASSED *** %s", get_type_name()), UVM_NONE)
        else
            `uvm_info("RESULT", $sformatf("*** TEST FAILED *** %s (%0d error(s))", get_type_name(), errs), UVM_NONE)
    endfunction

endclass
