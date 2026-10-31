// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// rr_arbiter.sv
// Round robin arbiter. Grant is combinational. The priority pointer only moves
// when the caller reports that the grant was actually used (advance), so a
// stalled output does not burn the winner's turn.

module rr_arbiter #(
    parameter int unsigned N = 4
) (
    input  logic         clk,
    input  logic         rst_n,

    input  logic [N-1:0] req,
    input  logic         advance,

    output logic [N-1:0] grant,
    output logic         any_grant
);

    localparam int unsigned PTR_W = (N <= 1) ? 1 : $clog2(N);

    logic [PTR_W-1:0] ptr;
    logic [PTR_W-1:0] grant_idx;

    always_comb begin
        grant     = '0;
        any_grant = 1'b0;
        grant_idx = '0;
        for (int unsigned k = 0; k < N; k++) begin
            // idx is wider than the port index on purpose, the modulo keeps it in range
            /* verilator lint_off UNUSEDSIGNAL */
            automatic int unsigned idx = (int'(ptr) + k) % N;
            /* verilator lint_on UNUSEDSIGNAL */
            if (req[idx] && !any_grant) begin
                grant[idx] = 1'b1;
                any_grant  = 1'b1;
                grant_idx  = PTR_W'(idx);
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ptr <= '0;
        end else if (advance && any_grant) begin
            ptr <= (int'(grant_idx) == int'(N) - 1) ? '0 : grant_idx + 1'b1;
        end
    end

endmodule
