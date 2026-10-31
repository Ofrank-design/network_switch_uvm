// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// network_switch.sv
// Input buffered, output queued packet switch. One packet is one beat.
//
// Structure
//   input port i  -> sw_fifo -> head of FIFO requests output[dest]
//   output port o -> rr_arbiter picks among FIFO heads that target o
//                 -> one entry output register with valid/ready
//
// Word format on data_in / data_out
//   [DATA_W-1 -: DEST_W]          destination output port
//   [DATA_W-DEST_W-1 -: DEST_W]   source tag, carried through untouched
//   [PAYLOAD_W-1:0]               payload, carried through untouched
// The switch only reads the destination field.
//
// Ordering
//   Packets from one input to one output keep their order. Packets from
//   different inputs to the same output are interleaved by the round robin
//   arbiter, which is legal behaviour.
//
// Reset
//   Synchronous, active low. Everything in flight is discarded.
//
// FAULT_MODE exists only to prove that the testbench catches real bugs. Keep it
// at 0 for normal use.
//   0 none                         4 duplicate one output packet
//   1 misroute one packet          5 stop forwarding after 20 packets
//   2 flip a payload bit           6 drop last on one output packet
//   3 silently drop one packet

module network_switch #(
    parameter int unsigned NUM_PORTS  = 4,
    parameter int unsigned DATA_W     = 32,
    parameter int unsigned FIFO_DEPTH = 8,
    parameter int unsigned FAULT_MODE = 0,
    parameter int unsigned DEST_W     = (NUM_PORTS <= 1) ? 1 : $clog2(NUM_PORTS)
) (
    input  logic                              clk,
    input  logic                              rst_n,

    input  logic [NUM_PORTS-1:0]              valid_in,
    output logic [NUM_PORTS-1:0]              ready_in,
    input  logic [NUM_PORTS-1:0][DATA_W-1:0]  data_in,
    input  logic [NUM_PORTS-1:0]              last_in,

    output logic [NUM_PORTS-1:0]              valid_out,
    input  logic [NUM_PORTS-1:0]              ready_out,
    output logic [NUM_PORTS-1:0][DATA_W-1:0]  data_out,
    output logic [NUM_PORTS-1:0]              last_out
);

    localparam int unsigned FIFO_W = DATA_W + 1;   // data plus last

    // ------------------------------------------------------------------
    // Input side
    // ------------------------------------------------------------------
    logic [NUM_PORTS-1:0]              f_empty;
    logic [NUM_PORTS-1:0]              f_full;
    logic [NUM_PORTS-1:0][FIFO_W-1:0]  f_rdata;
    logic [NUM_PORTS-1:0]              f_push;
    logic [NUM_PORTS-1:0]              f_pop;
    logic [NUM_PORTS-1:0][FIFO_W-1:0]  f_wdata;

    logic [7:0] in_cnt0;        // accepted packets on port 0, fault trigger only
    logic       stall_all;      // sticky, used by FAULT_MODE 5

    assign ready_in = ~f_full;

    wire fault_in_hit = valid_in[0] && ready_in[0] && (in_cnt0 == 8'd11);

    always_comb begin
        for (int unsigned i = 0; i < NUM_PORTS; i++) begin
            f_wdata[i] = {last_in[i], data_in[i]};
            f_push[i]  = valid_in[i] && ready_in[i];
        end

        if (fault_in_hit) begin
            unique case (FAULT_MODE)
                1: begin
                    // send it to the neighbouring port
                    automatic logic [DEST_W-1:0] d = data_in[0][DATA_W-1 -: DEST_W];
                    f_wdata[0][DATA_W-1 -: DEST_W] =
                        (int'(d) == int'(NUM_PORTS) - 1) ? '0 : d + 1'b1;
                end
                2: f_wdata[0][0] = ~data_in[0][0];
                3: f_push[0]     = 1'b0;
                default: ;
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            in_cnt0   <= '0;
            stall_all <= 1'b0;
        end else begin
            if (valid_in[0] && ready_in[0] && in_cnt0 != 8'hFF)
                in_cnt0 <= in_cnt0 + 1'b1;
            if (FAULT_MODE == 5 && in_cnt0 == 8'd20)
                stall_all <= 1'b1;
        end
    end

    for (genvar i = 0; i < NUM_PORTS; i++) begin : g_in
        sw_fifo #(.WIDTH(FIFO_W), .DEPTH(FIFO_DEPTH)) u_fifo (
            .clk   (clk),
            .rst_n (rst_n),
            .push  (f_push[i]),
            .wdata (f_wdata[i]),
            .pop   (f_pop[i]),
            .rdata (f_rdata[i]),
            .full  (f_full[i]),
            .empty (f_empty[i])
        );
    end

    // ------------------------------------------------------------------
    // Output side
    // ------------------------------------------------------------------
    // pop_from[o][i] is high when output o takes the head of input FIFO i.
    logic [NUM_PORTS-1:0] pop_from [NUM_PORTS];

    for (genvar o = 0; o < NUM_PORTS; o++) begin : g_out
        logic [NUM_PORTS-1:0] req;
        logic [NUM_PORTS-1:0] grant;
        logic                 any_grant;
        logic                 load;
        logic                 out_free;

        logic                 vld;
        logic [DATA_W-1:0]    dat;
        logic                 lst;
        logic                 dup_arm;
        logic [7:0]           out_cnt;

        logic [FIFO_W-1:0]    sel;

        for (genvar i = 0; i < NUM_PORTS; i++) begin : g_req
            assign req[i] = !f_empty[i]
                         && (f_rdata[i][DATA_W-1 -: DEST_W] == DEST_W'(o))
                         && !stall_all;
        end

        rr_arbiter #(.N(NUM_PORTS)) u_arb (
            .clk       (clk),
            .rst_n     (rst_n),
            .req       (req),
            .advance   (load),
            .grant     (grant),
            .any_grant (any_grant)
        );

        always_comb begin
            sel = '0;
            for (int unsigned i = 0; i < NUM_PORTS; i++)
                if (grant[i]) sel = f_rdata[i];
        end

        // The register can take a new packet when it is empty, or when the
        // current one is leaving this cycle. A pending duplicate keeps it busy.
        assign out_free = !vld || (ready_out[o] && !dup_arm);
        assign load     = any_grant && out_free;

        assign pop_from[o] = {NUM_PORTS{load}} & grant;

        always_ff @(posedge clk) begin
            if (!rst_n) begin
                vld     <= 1'b0;
                dat     <= '0;
                lst     <= 1'b0;
                dup_arm <= 1'b0;
                out_cnt <= '0;
            end else begin
                if (vld && ready_out[o]) begin
                    if (dup_arm) dup_arm <= 1'b0;   // send the same word once more
                    else         vld     <= 1'b0;
                end

                if (load) begin
                    vld     <= 1'b1;
                    dat     <= sel[DATA_W-1:0];
                    lst     <= sel[DATA_W];
                    dup_arm <= (FAULT_MODE == 4) && (o == 1) && (out_cnt == 8'd6);
                    if (FAULT_MODE == 6 && o == 0 && out_cnt == 8'd5)
                        lst <= 1'b0;
                    if (out_cnt != 8'hFF) out_cnt <= out_cnt + 1'b1;
                end
            end
        end

        assign valid_out[o] = vld;
        assign data_out[o]  = dat;
        assign last_out[o]  = lst;
    end

    always_comb begin
        for (int unsigned i = 0; i < NUM_PORTS; i++) begin
            f_pop[i] = 1'b0;
            for (int unsigned o = 0; o < NUM_PORTS; o++)
                f_pop[i] = f_pop[i] | pop_from[o][i];
        end
    end

endmodule
