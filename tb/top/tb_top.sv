// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// tb_top.sv
// Clock, power on reset, DUT, interface, and the hand over to UVM. The test is
// chosen with +UVM_TESTNAME=<test>.

`include "packages/router_defs.svh"

module tb_top;

    import uvm_pkg::*;
    import router_uvm_pkg::*;
    `include "uvm_macros.svh"

    logic clk = 1'b0;
    always #5 clk = ~clk;                       // 100 MHz

    router_if #(.NUM_PORTS(NUM_PORTS), .DATA_W(DATA_W)) rif (.clk(clk));

    network_switch #(
        .NUM_PORTS  (NUM_PORTS),
        .DATA_W     (DATA_W),
        .FIFO_DEPTH (`ROUTER_FIFO_DEPTH),
        .FAULT_MODE (`ROUTER_FAULT_MODE)
    ) dut (
        .clk       (clk),
        .rst_n     (rif.rst_n),
        .valid_in  (rif.valid_in),
        .ready_in  (rif.ready_in),
        .data_in   (rif.data_in),
        .last_in   (rif.last_in),
        .valid_out (rif.valid_out),
        .ready_out (rif.ready_out),
        .data_out  (rif.data_out),
        .last_out  (rif.last_out)
    );

    // Power on reset: held for five clocks, then released on a clock edge.
    initial begin
        rif.rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rif.rst_n <= 1'b1;
    end

    initial begin
        uvm_config_db#(router_vif_t)::set(null, "uvm_test_top", "vif", rif);
        run_test();
    end

    // Optional waveform dump, enabled with +define+ROUTER_WAVES
`ifdef ROUTER_WAVES
    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_top);
    end
`endif

endmodule
