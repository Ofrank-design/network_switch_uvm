// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>
//
// router_cov_db.svh
// Small functional coverage store. It does the bookkeeping that SystemVerilog
// covergroups would do, but in plain classes, so the same coverage runs on
// every simulator including open source ones that ignore covergroups.
//
// A coverage point is a named list of bins. Every bin is declared up front, so
// a bin that never got hit shows up as a hole instead of being invisible.

class router_cov_db extends uvm_object;

    protected int unsigned hits     [string];   // key = "point/bin"
    protected string       keys     [$];        // declaration order
    protected string       points   [$];
    protected string       point_of [string];

    `uvm_object_utils(router_cov_db)

    function new(string name = "router_cov_db");
        super.new(name);
    endfunction

    function void declare(string point, string bin_name);
        string key = {point, "/", bin_name};
        if (hits.exists(key)) return;
        hits[key]      = 0;
        point_of[key]  = point;
        keys.push_back(key);
        if (!has_point(point)) points.push_back(point);
    endfunction

    function void hit(string point, string bin_name);
        string key = {point, "/", bin_name};
        if (!hits.exists(key)) declare(point, bin_name);
        hits[key]++;
    endfunction

    function bit has_point(string point);
        foreach (points[i]) if (points[i] == point) return 1'b1;
        return 1'b0;
    endfunction

    function int unsigned num_bins(string point);
        int unsigned n = 0;
        foreach (keys[i]) if (point_of[keys[i]] == point) n++;
        return n;
    endfunction

    function int unsigned num_hit(string point);
        int unsigned n = 0;
        foreach (keys[i]) if (point_of[keys[i]] == point && hits[keys[i]] > 0) n++;
        return n;
    endfunction

    function real point_pct(string point);
        int unsigned total = num_bins(point);
        if (total == 0) return 100.0;
        return 100.0 * real'(num_hit(point)) / real'(total);
    endfunction

    function real total_pct();
        int unsigned covered = 0;
        if (keys.size() == 0) return 100.0;
        foreach (keys[i]) if (hits[keys[i]] > 0) covered++;
        return 100.0 * real'(covered) / real'(keys.size());
    endfunction

    function void get_points(ref string out[$]);
        out = points;
    endfunction

    function string report();
        string s = "\n---------------- functional coverage ----------------\n";
        foreach (points[i]) begin
            s = {s, $sformatf("  %-18s %3d / %-3d  %6.2f%%\n", points[i],
                              num_hit(points[i]), num_bins(points[i]), point_pct(points[i]))};
            foreach (keys[k]) begin
                if (point_of[keys[k]] == points[i] && hits[keys[k]] == 0)
                    s = {s, $sformatf("      hole: %s\n", keys[k])};
            end
        end
        s = {s, $sformatf("  %-18s %6.2f%%\n", "TOTAL", total_pct())};
        s = {s, "-----------------------------------------------------\n"};
        return s;
    endfunction

    // One "point,bin,hits" line per bin. scripts/merge_cov.py adds these up
    // across a whole regression to get closure over all tests and seeds.
    function void dump(string path);
        int fd = $fopen(path, "w");
        if (fd == 0) begin
            `uvm_warning("COVDB", $sformatf("could not open %s for writing", path))
            return;
        end
        foreach (keys[i])
            $fdisplay(fd, "%s,%s,%0d", point_of[keys[i]],
                      keys[i].substr(point_of[keys[i]].len() + 1, keys[i].len() - 1),
                      hits[keys[i]]);
        $fclose(fd);
    endfunction

endclass
