// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_scoreboard.svh
// Checks the switch against a reference model that only knows the routing rule.
//
// Model
//   Every accepted input packet is expected at its destination output. The
//   queues are kept per (source, destination) pair, because that is the order
//   the switch promises: packets from one input to one output stay in order,
//   while the interleave between different inputs is up to the arbiter.
//   Nothing here looks at the DUT's internals.
//
// Classifying an output beat
//   1. It matches the head of its route queue          -> good
//   2. It matches a later entry of that queue          -> ORDER_OR_LOSS, the
//                                                         entries ahead of it are lost
//   3. It repeats a word delivered a moment ago        -> DUPLICATE
//   4. Same source and payload wait on another route   -> MISROUTE
//   5. Nothing is expected on that route               -> held as an orphan,
//                                                         reported at the end
//   6. Anything else                                   -> PAYLOAD_MISMATCH, the
//                                                         head is taken as damaged
//   Sorting the failure like this keeps one bug to one or two clear errors
//   instead of a flood that buries the cause.
//
// Race handling
//   The two monitors are independent, so an output beat could in principle be
//   reported before the matching input beat. Case 5 covers it: the orphan is
//   matched when the input shows up. Orphans left at the end are reported as
//   unexpected output.
//
// Reset
//   Reset throws away everything in flight, so every queue is cleared on the
//   falling edge of rst_n. The monitors skip beats while reset is low, which
//   keeps both sides consistent.

class router_scoreboard extends uvm_scoreboard;

    uvm_analysis_imp_in  #(router_packet, router_scoreboard) in_export;
    uvm_analysis_imp_out #(router_packet, router_scoreboard) out_export;

    router_cfg   cfg;
    router_vif_t vif;

    // How many delivered words per route are remembered for duplicate detection
    localparam int unsigned HISTORY = 32;

    protected router_packet  exp_q    [NUM_PORTS * NUM_PORTS][$];
    protected router_packet  orphan_q [NUM_PORTS * NUM_PORTS][$];
    protected router_word_t  recent_q [NUM_PORTS * NUM_PORTS][$];

    int unsigned in_count  [NUM_PORTS];
    int unsigned out_count [NUM_PORTS];
    int unsigned matched    = 0;
    int unsigned corrupted  = 0;
    int unsigned lost       = 0;
    int unsigned unexpected = 0;
    int unsigned duplicates = 0;
    int unsigned misrouted  = 0;
    int unsigned flushed    = 0;
    int unsigned resets     = 0;

    `uvm_component_utils(router_scoreboard)

    function new(string name = "router_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        in_export  = new("in_export",  this);
        out_export = new("out_export", this);
        foreach (in_count[i])  in_count[i]  = 0;
        foreach (out_count[i]) out_count[i] = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(router_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "router_scoreboard: router_cfg was not set")
    endfunction

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    protected function int unsigned key_of(int unsigned src, int unsigned dst);
        return src * NUM_PORTS + dst;
    endfunction

    protected function bit same_word(router_packet a, router_packet b);
        return a.to_word() == b.to_word();
    endfunction

    // Index of the first packet in q with the same wire word, or -1.
    protected function int find_word(ref router_packet q[$], router_packet p);
        foreach (q[i]) if (same_word(q[i], p)) return i;
        return -1;
    endfunction

    // Index of the first packet in q carrying this payload, or -1.
    protected function int find_payload(ref router_packet q[$], router_payload_t pl);
        foreach (q[i]) if (q[i].payload == pl) return i;
        return -1;
    endfunction

    protected function void remember(int unsigned key, router_word_t w);
        recent_q[key].push_back(w);
        if (recent_q[key].size() > HISTORY) void'(recent_q[key].pop_front());
    endfunction

    protected function bit was_recently_delivered(int unsigned key, router_word_t w);
        foreach (recent_q[key][i]) if (recent_q[key][i] == w) return 1'b1;
        return 1'b0;
    endfunction

    // Packets that were accepted but have not come out yet.
    function int unsigned outstanding();
        int unsigned n = 0;
        foreach (exp_q[k]) n += exp_q[k].size();
        return n;
    endfunction

    function int unsigned total_in();
        int unsigned n = 0;
        foreach (in_count[i]) n += in_count[i];
        return n;
    endfunction

    function int unsigned total_out();
        int unsigned n = 0;
        foreach (out_count[i]) n += out_count[i];
        return n;
    endfunction

    function int unsigned error_events();
        return corrupted + lost + unexpected + duplicates + misrouted;
    endfunction

    // ------------------------------------------------------------------
    // Input side: a packet was accepted by the switch
    // ------------------------------------------------------------------
    function void write_in(router_packet pkt);
        router_packet copy;
        int unsigned  key;
        int           idx;

        if (pkt.source >= NUM_PORTS || pkt.destination >= NUM_PORTS) return;  // monitor reported it

        in_count[pkt.source]++;
        key = key_of(pkt.source, pkt.destination);

        if (!$cast(copy, pkt.clone()))
            `uvm_fatal("CAST", "router_scoreboard: clone of router_packet failed")

        // The output beat may already have been seen, see "Race handling".
        idx = find_word(orphan_q[key], copy);
        if (idx >= 0) begin
            orphan_q[key].delete(idx);
            remember(key, copy.to_word());
            matched++;
        end else begin
            exp_q[key].push_back(copy);
        end
    endfunction

    // ------------------------------------------------------------------
    // Output side: the switch delivered a packet
    // ------------------------------------------------------------------
    function void write_out(router_packet pkt);
        router_packet copy;
        int unsigned  key;
        int           idx;
        int           j;

        out_count[pkt.out_port]++;

        if (pkt.source >= NUM_PORTS) begin
            unexpected++;
            `uvm_error("BAD_SRC_TAG",
                $sformatf("output %0d delivered a word with source tag %0d", pkt.out_port, pkt.source))
            return;
        end

        // The word itself names another output than the one it left on.
        if (pkt.destination != pkt.out_port) begin
            misrouted++;
            `uvm_error("MISROUTE",
                $sformatf("word addressed to output %0d appeared on output %0d (%s)",
                          pkt.destination, pkt.out_port, pkt.convert2string()))
            if (pkt.destination < NUM_PORTS) begin
                key = key_of(pkt.source, pkt.destination);
                idx = find_word(exp_q[key], pkt);
                if (idx >= 0) exp_q[key].delete(idx);   // it did arrive, just not where it should
            end
            return;
        end

        key = key_of(pkt.source, pkt.out_port);

        // 1 and 2: a packet we were waiting for
        idx = find_word(exp_q[key], pkt);
        if (idx >= 0) begin
            if (idx > 0) begin
                lost += idx;
                `uvm_error("ORDER_OR_LOSS",
                    $sformatf("route %0d->%0d: %0d packet(s) ahead of %s never arrived first",
                              pkt.source, pkt.out_port, idx, pkt.convert2string()))
                repeat (idx) void'(exp_q[key].pop_front());
            end
            void'(exp_q[key].pop_front());
            remember(key, pkt.to_word());
            matched++;
            return;
        end

        // 3: a word that was just delivered
        if (was_recently_delivered(key, pkt.to_word())) begin
            duplicates++;
            `uvm_error("DUPLICATE",
                $sformatf("output %0d delivered %s a second time", pkt.out_port, pkt.convert2string()))
            return;
        end

        // 4: the same source and payload are waiting on a different route
        for (int unsigned d = 0; d < NUM_PORTS; d++) begin
            if (d == pkt.out_port) continue;
            j = find_payload(exp_q[key_of(pkt.source, d)], pkt.payload);
            if (j >= 0) begin
                misrouted++;
                `uvm_error("MISROUTE",
                    $sformatf("packet %s was expected on output %0d but appeared on output %0d",
                              exp_q[key_of(pkt.source, d)][j].convert2string(), d, pkt.out_port))
                exp_q[key_of(pkt.source, d)].delete(j);
                return;
            end
        end

        // 5: nothing is expected here. Hold it, the input beat may still be on its way.
        if (exp_q[key].size() == 0) begin
            if (!$cast(copy, pkt.clone()))
                `uvm_fatal("CAST", "router_scoreboard: clone of router_packet failed")
            orphan_q[key].push_back(copy);
            return;
        end

        // 6: something is expected but this is not it, so the head came out damaged
        corrupted++;
        `uvm_error("PAYLOAD_MISMATCH",
            $sformatf("route %0d->%0d: expected %s, got payload 0x%0h",
                      pkt.source, pkt.out_port, exp_q[key][0].convert2string(), pkt.payload))
        void'(exp_q[key].pop_front());
    endfunction

    // ------------------------------------------------------------------
    // Reset
    // ------------------------------------------------------------------
    function void flush();
        foreach (exp_q[k]) begin
            flushed += exp_q[k].size();
            exp_q[k].delete();
        end
        foreach (orphan_q[k]) orphan_q[k].delete();
        foreach (recent_q[k]) recent_q[k].delete();
    endfunction

    task run_phase(uvm_phase phase);
        vif = cfg.vif;
        forever begin
            @(negedge vif.rst_n);
            resets++;
            `uvm_info("SB_RESET", $sformatf("reset: dropping %0d in flight packet(s)", outstanding()), UVM_MEDIUM)
            flush();
        end
    endtask

    // ------------------------------------------------------------------
    // End of test
    // ------------------------------------------------------------------
    function void check_phase(uvm_phase phase);
        int unsigned reported;
        super.check_phase(phase);

        foreach (exp_q[k]) begin
            reported = 0;
            foreach (exp_q[k][i]) begin
                lost++;
                if (reported < 5)
                    `uvm_error("MISSING_PACKET",
                        $sformatf("never delivered: %s", exp_q[k][i].convert2string()))
                reported++;
            end
            if (reported > 5)
                `uvm_error("MISSING_PACKET", $sformatf("route %0d->%0d: %0d more packets also missing",
                                                       k / NUM_PORTS, k % NUM_PORTS, reported - 5))
        end

        foreach (orphan_q[k]) begin
            reported = 0;
            foreach (orphan_q[k][i]) begin
                unexpected++;
                if (reported < 5)
                    `uvm_error("UNEXPECTED_OUTPUT",
                        $sformatf("no matching input for: out %0d %s",
                                  orphan_q[k][i].out_port, orphan_q[k][i].convert2string()))
                reported++;
            end
        end

        if (vif != null && vif.sva_errors != 0)
            `uvm_error("SVA", $sformatf("%0d protocol assertion failure(s), see log above", vif.sva_errors))
    endfunction

    function void report_phase(uvm_phase phase);
        string s;
        super.report_phase(phase);

        s = $sformatf("\n---------------- scoreboard ----------------\n");
        s = {s, $sformatf("  accepted at inputs   : %0d\n", total_in())};
        s = {s, $sformatf("  delivered at outputs : %0d\n", total_out())};
        s = {s, $sformatf("  matched              : %0d\n", matched)};
        s = {s, $sformatf("  corrupted            : %0d\n", corrupted)};
        s = {s, $sformatf("  lost                 : %0d\n", lost)};
        s = {s, $sformatf("  duplicated           : %0d\n", duplicates)};
        s = {s, $sformatf("  misrouted            : %0d\n", misrouted)};
        s = {s, $sformatf("  unexpected           : %0d\n", unexpected)};
        s = {s, $sformatf("  discarded by reset   : %0d (%0d reset(s))\n", flushed, resets)};
        foreach (in_count[i])
            s = {s, $sformatf("  port %0d  in %0d  out %0d\n", i, in_count[i], out_count[i])};
        s = {s, "--------------------------------------------\n"};
        `uvm_info("SB_SUMMARY", s, UVM_LOW)
    endfunction

endclass
