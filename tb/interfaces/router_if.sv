// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_if.sv
// Pin level boundary between the testbench and the switch. It also carries the
// protocol assertions, so every test is checked by them without extra wiring.
//
// Transfer rule: a beat moves on a rising clock edge where valid and ready are
// both high. Once valid is high it must stay high with stable data until ready.

import uvm_pkg::*;
`include "uvm_macros.svh"

interface router_if #(
    parameter int unsigned NUM_PORTS = 4,
    parameter int unsigned DATA_W    = 32,
    parameter int unsigned DEST_W    = (NUM_PORTS <= 1) ? 1 : $clog2(NUM_PORTS)
) (
    input logic clk
);

    logic rst_n;

    // testbench to switch
    logic [NUM_PORTS-1:0]             valid_in;
    logic [NUM_PORTS-1:0][DATA_W-1:0] data_in;
    logic [NUM_PORTS-1:0]             last_in;
    logic [NUM_PORTS-1:0]             ready_out;

    // switch to testbench
    logic [NUM_PORTS-1:0]             ready_in;
    logic [NUM_PORTS-1:0]             valid_out;
    logic [NUM_PORTS-1:0][DATA_W-1:0] data_out;
    logic [NUM_PORTS-1:0]             last_out;

    // Everything the testbench drives starts quiet. rst_n is owned by tb_top.
    initial begin
        valid_in  = '0;
        data_in   = '0;
        last_in   = '0;
        ready_out = '0;
    end

    // Number of assertion failures seen so far. The scoreboard reads this at the
    // end of the test so an assertion failure always fails the run.
    int unsigned sva_errors = 0;

    modport dut (
        input  clk, rst_n,
        input  valid_in, data_in, last_in, ready_out,
        output ready_in, valid_out, data_out, last_out
    );

`ifndef ROUTER_NO_SVA
    for (genvar p = 0; p < NUM_PORTS; p++) begin : g_sva

        // Input side: a beat that was offered and not accepted may not change.
        a_in_hold: assert property (
            @(posedge clk) disable iff (!rst_n)
            (valid_in[p] && !ready_in[p]) |=> (valid_in[p] && $stable(data_in[p]))
        ) else begin
            sva_errors++;
            `uvm_error("SVA", $sformatf("SVA a_in_hold: port %0d changed or dropped a beat before it was accepted", p))
        end

        // Output side: same rule for the beat the switch is presenting.
        a_out_hold: assert property (
            @(posedge clk) disable iff (!rst_n)
            (valid_out[p] && !ready_out[p]) |=> (valid_out[p] && $stable(data_out[p]))
        ) else begin
            sva_errors++;
            `uvm_error("SVA", $sformatf("SVA a_out_hold: output %0d changed or dropped a beat under backpressure", p))
        end

        // Single beat packets, so every beat is also the last one.
        a_last_out: assert property (
            @(posedge clk) disable iff (!rst_n)
            valid_out[p] |-> last_out[p]
        ) else begin
            sva_errors++;
            `uvm_error("SVA", $sformatf("SVA a_last_out: output %0d presented a beat without last", p))
        end

        a_last_in: assert property (
            @(posedge clk) disable iff (!rst_n)
            valid_in[p] |-> last_in[p]
        ) else begin
            sva_errors++;
            `uvm_error("SVA", $sformatf("SVA a_last_in: input %0d offered a beat without last", p))
        end

        // Routing: a word leaving output p must be addressed to p.
        a_route: assert property (
            @(posedge clk) disable iff (!rst_n)
            valid_out[p] |-> (data_out[p][DATA_W-1 -: DEST_W] == DEST_W'(p))
        ) else begin
            sva_errors++;
            `uvm_error("SVA", $sformatf("SVA a_route: output %0d presented a word addressed elsewhere", p))
        end

        // The outputs must be empty once reset has taken effect.
        a_reset_out: assert property (
            @(posedge clk) !rst_n |=> !valid_out[p]
        ) else begin
            sva_errors++;
            `uvm_error("SVA", $sformatf("SVA a_reset_out: output %0d still valid after reset", p))
        end
    end
`endif

endinterface
