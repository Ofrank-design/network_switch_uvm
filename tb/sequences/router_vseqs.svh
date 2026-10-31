// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_vseqs.svh
// System level sequences. They run on the virtual sequencer and start a
// per port sequence on every input at the same time, so contention between
// inputs is created on purpose instead of left to chance.

class router_vseq_base extends uvm_sequence;

    `uvm_object_utils(router_vseq_base)
    `uvm_declare_p_sequencer(router_virtual_sequencer)

    function new(string name = "router_vseq_base");
        super.new(name);
    endfunction

endclass

// Random traffic from every port together.
class router_rand_vseq extends router_vseq_base;

    int unsigned num_pkts = 100;
    int unsigned dest_lo  = 0;
    int unsigned dest_hi  = NUM_PORTS - 1;
    gap_mode_e   gap_mode = GAP_MIXED;

    `uvm_object_utils(router_rand_vseq)

    function new(string name = "router_rand_vseq");
        super.new(name);
    endfunction

    task body();
        for (int unsigned p = 0; p < NUM_PORTS; p++) begin
            automatic int unsigned pp = p;
            fork
                begin
                    router_rand_seq s = router_rand_seq::type_id::create($sformatf("rand_seq_%0d", pp));
                    s.num_pkts = num_pkts;
                    s.dest_lo  = dest_lo;
                    s.dest_hi  = dest_hi;
                    s.gap_mode = gap_mode;
                    s.start(p_sequencer.in_sqr[pp]);
                end
            join_none
        end
        wait fork;
    endtask

endclass

// Every input sends to every output.
class router_sweep_vseq extends router_vseq_base;

    int unsigned per_dest = 3;

    `uvm_object_utils(router_sweep_vseq)

    function new(string name = "router_sweep_vseq");
        super.new(name);
    endfunction

    task body();
        for (int unsigned p = 0; p < NUM_PORTS; p++) begin
            automatic int unsigned pp = p;
            fork
                begin
                    router_sweep_seq s = router_sweep_seq::type_id::create($sformatf("sweep_seq_%0d", pp));
                    s.per_dest = per_dest;
                    s.start(p_sequencer.in_sqr[pp]);
                end
            join_none
        end
        wait fork;
    endtask

endclass

// All inputs aim at one output with no idle cycles. With target set to a port
// number only that output is hit. With target left at -1 each output takes a
// turn as the hot spot.
class router_contention_vseq extends router_vseq_base;

    int          target   = -1;
    int unsigned num_pkts = 30;

    `uvm_object_utils(router_contention_vseq)

    function new(string name = "router_contention_vseq");
        super.new(name);
    endfunction

    protected task hammer(int unsigned dest);
        for (int unsigned p = 0; p < NUM_PORTS; p++) begin
            automatic int unsigned pp = p;
            fork
                begin
                    router_rand_seq s = router_rand_seq::type_id::create($sformatf("hot_seq_%0d", pp));
                    s.num_pkts = num_pkts;
                    s.dest_lo  = dest;
                    s.dest_hi  = dest;
                    s.gap_mode = GAP_NONE;
                    s.start(p_sequencer.in_sqr[pp]);
                end
            join_none
        end
        wait fork;
    endtask

    task body();
        if (target >= 0) hammer(target);
        else for (int unsigned d = 0; d < NUM_PORTS; d++) hammer(d);
    endtask

endclass

// Payload corner cases from every port.
class router_pattern_vseq extends router_vseq_base;

    `uvm_object_utils(router_pattern_vseq)

    function new(string name = "router_pattern_vseq");
        super.new(name);
    endfunction

    task body();
        for (int unsigned p = 0; p < NUM_PORTS; p++) begin
            automatic int unsigned pp = p;
            fork
                begin
                    router_pattern_seq s = router_pattern_seq::type_id::create($sformatf("pat_seq_%0d", pp));
                    s.start(p_sequencer.in_sqr[pp]);
                end
            join_none
        end
        wait fork;
    endtask

endclass
