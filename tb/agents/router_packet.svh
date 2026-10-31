// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_packet.svh
// One packet, one beat. The wire word is {destination, source tag, payload}.
//
// source is not random. The agent that owns an input port decides it, because a
// driver that picked its own source port per packet would break the link
// between an agent and its physical pins.

class router_packet extends uvm_sequence_item;

    rand router_payload_t payload;
    rand int unsigned     destination;
    rand int unsigned     gap;          // idle cycles before the driver offers this packet

    int unsigned source      = 0;       // input port that carries the packet
    int unsigned packet_id   = 0;       // bookkeeping for logs, not sent on the wire
    int          out_port    = -1;      // output port it was seen on, monitors only
    bit          last        = 1'b1;    // value seen on the last pin, monitors only
    time         accept_time = 0;

    constraint c_dest { destination < NUM_PORTS; }
    constraint c_gap  { gap <= 32; }

    `uvm_object_utils(router_packet)

    function new(string name = "router_packet");
        super.new(name);
    endfunction

    // Wire word for this packet.
    function router_word_t to_word();
        router_word_t w;
        w = '0;
        w[DATA_W-1 -: PORT_W]       = PORT_W'(destination);
        w[DATA_W-PORT_W-1 -: PORT_W] = PORT_W'(source);
        w[PAYLOAD_W-1:0]            = payload;
        return w;
    endfunction

    // Rebuild a packet from what was seen on the pins.
    static function router_packet from_word(router_word_t w, string name = "router_packet");
        router_packet p = new(name);
        p.destination = int'(w[DATA_W-1 -: PORT_W]);
        p.source      = int'(w[DATA_W-PORT_W-1 -: PORT_W]);
        p.payload     = w[PAYLOAD_W-1:0];
        return p;
    endfunction

    function void do_copy(uvm_object rhs);
        router_packet r;
        super.do_copy(rhs);
        if (!$cast(r, rhs)) `uvm_fatal("COPY", "router_packet::do_copy got a different type")
        payload     = r.payload;
        destination = r.destination;
        gap         = r.gap;
        source      = r.source;
        packet_id   = r.packet_id;
        out_port    = r.out_port;
        last        = r.last;
        accept_time = r.accept_time;
    endfunction

    // Two packets are the same when the wire word is the same.
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        router_packet r;
        if (!$cast(r, rhs)) return 0;
        return super.do_compare(rhs, comparer)
            && (payload     == r.payload)
            && (destination == r.destination)
            && (source      == r.source);
    endfunction

    function string convert2string();
        return $sformatf("id=%0d src=%0d dst=%0d payload=0x%0h gap=%0d",
                         packet_id, source, destination, payload, gap);
    endfunction

endclass
