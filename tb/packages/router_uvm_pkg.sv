// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_uvm_pkg.sv
// One package for the whole environment. Include order matters: a class has to
// be seen before anything that holds a handle to it.
//
// Compile with +incdir+<repo>/tb and compile interfaces/router_if.sv first.

`include "packages/router_defs.svh"

package router_uvm_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // ------------------------------------------------------------------
    // Geometry
    // ------------------------------------------------------------------
    localparam int unsigned NUM_PORTS  = `ROUTER_NUM_PORTS;
    localparam int unsigned DATA_W     = `ROUTER_DATA_W;
    localparam int unsigned PORT_W     = (NUM_PORTS <= 1) ? 1 : $clog2(NUM_PORTS);
    localparam int unsigned PAYLOAD_W  = DATA_W - 2 * PORT_W;

    typedef virtual router_if #(.NUM_PORTS(NUM_PORTS), .DATA_W(DATA_W)) router_vif_t;
    typedef bit [DATA_W-1:0] router_word_t;
    typedef bit [PAYLOAD_W-1:0] router_payload_t;

    // The scoreboard listens to two independent monitor streams.
    `uvm_analysis_imp_decl(_in)
    `uvm_analysis_imp_decl(_out)

    // ------------------------------------------------------------------
    // Transaction, configuration, coverage storage
    // ------------------------------------------------------------------
    `include "agents/router_packet.svh"
    `include "env/router_cfg.svh"
    `include "env/router_cov_db.svh"

    // ------------------------------------------------------------------
    // Agents
    // ------------------------------------------------------------------
    `include "agents/router_sequencer.svh"
    `include "agents/router_driver.svh"
    `include "agents/router_monitor.svh"
    `include "agents/router_sink.svh"
    `include "agents/router_in_agent.svh"
    `include "agents/router_out_agent.svh"

    // ------------------------------------------------------------------
    // Environment
    // ------------------------------------------------------------------
    `include "env/router_scoreboard.svh"
    `include "env/router_coverage.svh"
    `include "env/router_virtual_sequencer.svh"
    `include "env/router_env.svh"

    // ------------------------------------------------------------------
    // Stimulus and tests
    // ------------------------------------------------------------------
    `include "sequences/router_sequences.svh"
    `include "sequences/router_vseqs.svh"
    `include "tests/router_base_test.svh"
    `include "tests/router_tests.svh"

endpackage
