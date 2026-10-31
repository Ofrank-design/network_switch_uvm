// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_sequences.svh
// Per port sequences. Each one runs on a single input sequencer and stamps that
// port's number on every packet it creates. Several of them started together,
// one per port, give system level traffic (see router_vseqs.svh).

typedef enum { GAP_NONE, GAP_MIXED, GAP_SPARSE } gap_mode_e;

// ----------------------------------------------------------------------
// Base: helpers every sequence uses
// ----------------------------------------------------------------------
class router_base_seq extends uvm_sequence #(router_packet);

    `uvm_object_utils(router_base_seq)
    `uvm_declare_p_sequencer(router_sequencer)

    function new(string name = "router_base_seq");
        super.new(name);
    endfunction

    // Idle cycles to leave before the next packet.
    protected function int unsigned pick_gap(gap_mode_e mode);
        int unsigned roll;
        case (mode)
            GAP_NONE:   return 0;
            GAP_SPARSE: return $urandom_range(10, 32);
            default: begin
                roll = $urandom_range(99);
                if      (roll < 50) return 0;
                else if (roll < 85) return $urandom_range(1, 4);
                else                return $urandom_range(5, 20);
            end
        endcase
    endfunction

    // One packet with every field chosen by the caller.
    protected task send(int unsigned dest, router_payload_t payload, int unsigned gap = 0);
        router_packet tr = router_packet::type_id::create("tr");
        start_item(tr);
        tr.destination = dest;
        tr.payload     = payload;
        tr.gap         = gap;
        tr.source      = p_sequencer.port_idx;
        finish_item(tr);
    endtask

    // One packet with a random payload and a destination inside [lo:hi].
    protected task send_random(int unsigned lo, int unsigned hi, gap_mode_e mode);
        router_packet tr  = router_packet::type_id::create("tr");
        int unsigned  g   = pick_gap(mode);
        // The destination is drawn here, not by the constraint solver. Some
        // solvers favour low values, which would starve the higher ports.
        int unsigned  dst = $urandom_range(hi, lo);

        start_item(tr);
        if (!tr.randomize() with { destination == dst; gap == g; })
            `uvm_fatal("RAND", "router_packet randomization failed")
        tr.source = p_sequencer.port_idx;
        finish_item(tr);
    endtask

endclass

// ----------------------------------------------------------------------
// One packet to a chosen destination
// ----------------------------------------------------------------------
class router_single_seq extends router_base_seq;

    int unsigned     dest    = 0;
    router_payload_t payload = 'hA5A5A5A;

    `uvm_object_utils(router_single_seq)

    function new(string name = "router_single_seq");
        super.new(name);
    endfunction

    task body();
        send(dest, payload, 0);
    endtask

endclass

// ----------------------------------------------------------------------
// Constrained random traffic
// ----------------------------------------------------------------------
class router_rand_seq extends router_base_seq;

    int unsigned num_pkts = 100;
    int unsigned dest_lo  = 0;
    int unsigned dest_hi  = NUM_PORTS - 1;
    gap_mode_e   gap_mode = GAP_MIXED;

    `uvm_object_utils(router_rand_seq)

    function new(string name = "router_rand_seq");
        super.new(name);
    endfunction

    task body();
        repeat (num_pkts) send_random(dest_lo, dest_hi, gap_mode);
    endtask

endclass

// ----------------------------------------------------------------------
// Every destination, a few packets each. Run on all ports, this walks every
// source to destination route.
// ----------------------------------------------------------------------
class router_sweep_seq extends router_base_seq;

    int unsigned per_dest = 3;
    gap_mode_e   gap_mode = GAP_MIXED;

    `uvm_object_utils(router_sweep_seq)

    function new(string name = "router_sweep_seq");
        super.new(name);
    endfunction

    task body();
        for (int unsigned d = 0; d < NUM_PORTS; d++)
            repeat (per_dest) send_random(d, d, gap_mode);
    endtask

endclass

// ----------------------------------------------------------------------
// Payload corner cases: all zeros, all ones, both alternating patterns and a
// walking one across every payload bit.
// ----------------------------------------------------------------------
class router_pattern_seq extends router_base_seq;

    `uvm_object_utils(router_pattern_seq)

    function new(string name = "router_pattern_seq");
        super.new(name);
    endfunction

    task body();
        router_payload_t alt10;
        router_payload_t alt01;
        int unsigned     d = p_sequencer.port_idx;

        for (int unsigned b = 0; b < PAYLOAD_W; b++) begin
            alt10[b] = (b % 2) == 1;
            alt01[b] = (b % 2) == 0;
        end

        send(d % NUM_PORTS, '0,    1);
        send(d % NUM_PORTS, '1,    1);
        send((d + 1) % NUM_PORTS, alt10, 1);
        send((d + 2) % NUM_PORTS, alt01, 1);

        for (int unsigned b = 0; b < PAYLOAD_W; b++) begin
            router_payload_t one = '0;
            one[b] = 1'b1;
            send((d + b) % NUM_PORTS, one, 0);
        end
    endtask

endclass
