// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// sw_fifo.sv
// Synchronous single clock FIFO used as the input buffer of every switch port.
// Reads are combinational (first word fall through), so the head of the queue
// is always visible on rdata while empty is low.

module sw_fifo #(
    parameter int unsigned WIDTH = 32,
    parameter int unsigned DEPTH = 8
) (
    input  logic             clk,
    input  logic             rst_n,

    input  logic             push,
    input  logic [WIDTH-1:0] wdata,
    input  logic             pop,
    output logic [WIDTH-1:0] rdata,

    output logic             full,
    output logic             empty
);

    localparam int unsigned PTR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
    localparam int unsigned CNT_W = $clog2(DEPTH + 1);

    logic [WIDTH-1:0] mem [DEPTH];
    logic [PTR_W-1:0] wr_ptr;
    logic [PTR_W-1:0] rd_ptr;
    logic [CNT_W-1:0] count;

    wire do_push = push && !full;
    wire do_pop  = pop  && !empty;

    assign full  = (count == CNT_W'(DEPTH));
    assign empty = (count == '0);
    assign rdata = mem[rd_ptr];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end else begin
            if (do_push) begin
                mem[wr_ptr] <= wdata;
                wr_ptr      <= (wr_ptr == PTR_W'(DEPTH - 1)) ? '0 : wr_ptr + 1'b1;
            end
            if (do_pop) begin
                rd_ptr <= (rd_ptr == PTR_W'(DEPTH - 1)) ? '0 : rd_ptr + 1'b1;
            end
            case ({do_push, do_pop})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule
