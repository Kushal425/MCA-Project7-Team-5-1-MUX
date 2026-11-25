// ==============================================================================
// Testbench: tb_cache_compare
// Description: Shared self-checking comparison testbench.
//              Instantiates both cache_2way and cache_direct connected to
//              independent instances of mem_block_model.
//              Consumes checked-in trace files as the authoritative address source.
//              Replays identical aligned address sequences through both cold caches,
//              with equal data capacity (128 B), block size (16 B), and memory behavior.
//              Keeps expected outcomes independent of RTL output, using
//              hand-checked vectors and an independent golden reference model.
//              Verifies response data, hit/miss outcomes, transaction counts,
//              and measures acceptance-to-registered-response latency per transaction.
//
// Latency Sampling Convention:
//   Acceptance: Rising clock edge where (req_valid && req_ready) is sampled true.
//   Response  : Rising clock edge where resp_valid is sampled true.
//   Measured Latency = Response Edge - Acceptance Edge:
//     - Hit  : 2 clock cycles (IDLE -> LOOKUP -> RESP)
//     - Miss : 3 clock cycles (IDLE -> LOOKUP -> REFILL -> RESP with 1-cycle combinational block memory)
//
// Modeled AMAT vs Measured Cycles vs FPGA Frequency:
//   - Measured Simulation Cycles: Reflect the RTL pipeline timing with a 1-cycle
//     combinational memory model (Hit = 2 cycles, Miss = 3 cycles).
//   - Modeled AMAT (Average Memory Access Time): Assumes a realistic lower-memory
//     miss penalty of 20 cycles (e.g. DRAM refill): AMAT = 2.0 + (1 - HitRate) * 20.0 cycles.
//   - FPGA Clock Frequency: Constrained by critical path synthesis (e.g. 100 MHz / 10 ns clock),
//     converting cycles to wall-clock time (1 cycle = 10 ns).
//
// Traces:
//   TRACE A: 5-Access Conflict Trace (tb/traces/conflict_trace.hex)
//   TRACE B: 6-Access Within-Block Locality Trace (tb/traces/locality_trace.hex)
//   TRACE C: 16-Access Extended 2-Block Conflict Trace (tb/traces/conflict_long_trace.hex)
//   TRACE D: 32-Access Sequential Full-Capacity Locality Trace (tb/traces/sequential_trace.hex)
//   TRACE E: 30-Access Mapping-Sensitive 3-Block Cycle (tb/traces/mapping_sensitive_trace.hex)
//
// Author: Prachee
// Simulator: Icarus Verilog with -g2012
// ==============================================================================

`timescale 1ns / 1ps

module tb_cache_compare;

    // =========================================================================
    // Clock
    // =========================================================================
    reg clk;
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Watchdog: Terminate immediately via $fatal on timeout
    initial begin
        #2000000;
        $fatal(1, "[FATAL] Watchdog timeout -- simulation killed.");
    end

    // =========================================================================
    // Global counters
    // =========================================================================
    integer pass_count;
    integer fail_count;

    // Grand total accumulators across all benchmarks
    integer tw_grand_reads;
    integer tw_grand_hits;
    integer tw_grand_misses;
    integer tw_grand_lat;

    integer dm_grand_reads;
    integer dm_grand_hits;
    integer dm_grand_misses;
    integer dm_grand_lat;

    // =========================================================================
    // Helper: assertion with label
    // =========================================================================
    task check(input string label, input logic cond);
        begin
            if (cond) begin
                $display("    [PASS] %s", label);
                pass_count = pass_count + 1;
            end else begin
                $display("    [FAIL] %s", label);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =========================================================================
    // cache_2way DUT
    // =========================================================================
    reg          tw_rst;
    reg          tw_req_valid;
    reg  [31:0]  tw_req_addr;
    wire         tw_req_ready;
    wire         tw_resp_valid;
    wire         tw_resp_hit;
    wire [31:0]  tw_resp_data;
    wire [31:0]  tw_mem_block_addr;
    wire [127:0] tw_mem_block_data;

    cache_2way u_2way (
        .clk           (clk),
        .rst           (tw_rst),
        .req_valid     (tw_req_valid),
        .req_addr      (tw_req_addr),
        .req_ready     (tw_req_ready),
        .resp_valid    (tw_resp_valid),
        .resp_hit      (tw_resp_hit),
        .resp_data     (tw_resp_data),
        .mem_block_addr(tw_mem_block_addr),
        .mem_block_data(tw_mem_block_data)
    );

    mem_block_model u_mem_2way (
        .mem_block_addr(tw_mem_block_addr),
        .mem_block_data(tw_mem_block_data)
    );

    // =========================================================================
    // cache_direct DUT
    // =========================================================================
    reg          dm_rst;
    reg          dm_req_valid;
    reg  [31:0]  dm_req_addr;
    wire         dm_req_ready;
    wire         dm_resp_valid;
    wire         dm_resp_hit;
    wire [31:0]  dm_resp_data;
    wire [31:0]  dm_mem_block_addr;
    wire [127:0] dm_mem_block_data;

    cache_direct u_direct (
        .clk           (clk),
        .rst           (dm_rst),
        .req_valid     (dm_req_valid),
        .req_addr      (dm_req_addr),
        .req_ready     (dm_req_ready),
        .resp_valid    (dm_resp_valid),
        .resp_hit      (dm_resp_hit),
        .resp_data     (dm_resp_data),
        .mem_block_addr(dm_mem_block_addr),
        .mem_block_data(dm_mem_block_data)
    );

    mem_block_model u_mem_direct (
        .mem_block_addr(dm_mem_block_addr),
        .mem_block_data(dm_mem_block_data)
    );

    // =========================================================================
    // Per-trace hit/miss and latency accumulators
    // =========================================================================
    integer tw_hits;
    integer tw_misses;
    integer tw_lat_total;

    integer dm_hits;
    integer dm_misses;
    integer dm_lat_total;

    // =========================================================================
    // Independent Reference Models
    // =========================================================================
    reg        ref_dm_valid [0:7];
    reg [24:0] ref_dm_tag   [0:7];

    task ref_dm_reset;
        integer i;
        begin
            for (i = 0; i < 8; i = i + 1) begin
                ref_dm_valid[i] = 1'b0;
                ref_dm_tag[i]   = 25'h0;
            end
        end
    endtask

    task ref_dm_step(input [31:0] addr, output logic exp_hit, output [31:0] exp_data);
        reg [2:0]  s;
        reg [24:0] t;
        begin
            s = addr[6:4];
            t = addr[31:7];
            exp_hit = ref_dm_valid[s] && (ref_dm_tag[s] == t);
            if (!exp_hit) begin
                ref_dm_valid[s] = 1'b1;
                ref_dm_tag[s]   = t;
            end
            exp_data = addr;
        end
    endtask

    reg        ref_tw_valid0 [0:3];
    reg [25:0] ref_tw_tag0   [0:3];
    reg        ref_tw_valid1 [0:3];
    reg [25:0] ref_tw_tag1   [0:3];
    reg        ref_tw_lru    [0:3];

    task ref_tw_reset;
        integer i;
        begin
            for (i = 0; i < 4; i = i + 1) begin
                ref_tw_valid0[i] = 1'b0;
                ref_tw_tag0[i]   = 26'h0;
                ref_tw_valid1[i] = 1'b0;
                ref_tw_tag1[i]   = 26'h0;
                ref_tw_lru[i]    = 1'b0;
            end
        end
    endtask

    task ref_tw_step(input [31:0] addr, output logic exp_hit, output [31:0] exp_data);
        reg [1:0]  s;
        reg [25:0] t;
        reg        hit0, hit1, vict;
        begin
            s = addr[5:4];
            t = addr[31:6];
            hit0 = ref_tw_valid0[s] && (ref_tw_tag0[s] == t);
            hit1 = ref_tw_valid1[s] && (ref_tw_tag1[s] == t);
            exp_hit = hit0 || hit1;
            if (hit0) begin
                ref_tw_lru[s] = 1'b1; // Way 0 hit -> Way 1 becomes LRU victim
            end else if (hit1) begin
                ref_tw_lru[s] = 1'b0; // Way 1 hit -> Way 0 becomes LRU victim
            end else begin
                // Miss: determine victim
                if (!ref_tw_valid0[s])       vict = 1'b0;
                else if (!ref_tw_valid1[s])  vict = 1'b1;
                else                         vict = ref_tw_lru[s];

                if (vict == 1'b0) begin
                    ref_tw_valid0[s] = 1'b1;
                    ref_tw_tag0[s]   = t;
                    ref_tw_lru[s]    = 1'b1; // Way 0 filled -> Way 1 becomes LRU victim
                end else begin
                    ref_tw_valid1[s] = 1'b1;
                    ref_tw_tag1[s]   = t;
                    ref_tw_lru[s]    = 1'b0; // Way 1 filled -> Way 0 becomes LRU victim
                end
            end
            exp_data = addr;
        end
    endtask

    // =========================================================================
    // Trace Buffer & Loader
    // =========================================================================
    localparam MAX_TRACE_LEN = 256;
    reg [31:0] trace_mem [0:MAX_TRACE_LEN-1];

    task load_trace(
        input  string  filename,
        output integer count
    );
        integer fd, r, c;
        string line;
        reg [31:0] val;
        begin
            count = 0;
            fd = $fopen(filename, "r");
            if (fd == 0) begin
                $fatal(1, "    [FATAL] Failed to open trace file: %s", filename);
            end
            c = 0;
            while (!$feof(fd)) begin
                r = $fgets(line, fd);
                if (r > 0) begin
                    if (line.len() >= 2 && line.substr(0, 1) == "//") begin
                        // Skip comment lines
                    end else begin
                        r = $sscanf(line, "%h", val);
                        if (r == 1) begin
                            if (c < MAX_TRACE_LEN) begin
                                trace_mem[c] = val;
                                c = c + 1;
                            end
                        end
                    end
                end
            end
            $fclose(fd);
            count = c;
            $display("    [TRACE LOADER] Loaded %0d authoritative addresses from %s", count, filename);
        end
    endtask

    // =========================================================================
    // Helper: reset both caches and reference models from clean state
    // =========================================================================
    task reset_both;
        begin
            @(negedge clk);
            tw_rst = 1'b1; tw_req_valid = 1'b0; tw_req_addr = 32'h0;
            dm_rst = 1'b1; dm_req_valid = 1'b0; dm_req_addr = 32'h0;
            ref_dm_reset;
            ref_tw_reset;
            @(posedge clk); #1;
            @(posedge clk); #1;
            @(negedge clk);
            tw_rst = 1'b0;
            dm_rst = 1'b0;
            @(posedge clk); #1;
        end
    endtask

    // =========================================================================
    // Helper: send one request to cache_2way, measure latency in cycles
    // =========================================================================
    reg        tw_got_hit;
    reg [31:0] tw_got_data;

    task send_req_2way;
        input  [31:0]  addr;
        output integer lat_cycles;
        integer tout;
        begin
            lat_cycles = 0;
            tout = 0;
            while (!tw_req_ready) begin
                @(posedge clk); #1;
                tout = tout + 1;
                if (tout > 100) begin
                    $fatal(1, "    [TIMEOUT] 2way req_ready never asserted for addr=0x%08h", addr);
                end
            end
            @(negedge clk);
            tw_req_valid = 1'b1; tw_req_addr = addr;
            @(posedge clk); #1; // Request accepted at this clock edge (T0)
            @(negedge clk);
            tw_req_valid = 1'b0; tw_req_addr = 32'h0;

            // Acceptance-to-registered-response latency:
            // Request registered at posedge T0.
            // Hit: resp_valid asserted at posedge T1, registered by master at posedge T2 (2 cycles).
            // Miss: refill at posedge T2, resp_valid registered by master at posedge T3 (3 cycles).
            lat_cycles = 2;
            @(posedge clk); #1;
            tout = 0;
            while (!tw_resp_valid) begin
                @(posedge clk); #1;
                lat_cycles = lat_cycles + 1;
                tout = tout + 1;
                if (tout > 100) begin
                    $fatal(1, "    [TIMEOUT] 2way resp_valid never asserted for addr=0x%08h", addr);
                end
            end
            tw_got_hit  = tw_resp_hit;
            tw_got_data = tw_resp_data;
        end
    endtask

    // =========================================================================
    // Helper: send one request to cache_direct, measure latency in cycles
    // =========================================================================
    reg        dm_got_hit;
    reg [31:0] dm_got_data;

    task send_req_direct;
        input  [31:0]  addr;
        output integer lat_cycles;
        integer tout;
        begin
            lat_cycles = 0;
            tout = 0;
            while (!dm_req_ready) begin
                @(posedge clk); #1;
                tout = tout + 1;
                if (tout > 100) begin
                    $fatal(1, "    [TIMEOUT] direct req_ready never asserted for addr=0x%08h", addr);
                end
            end
            @(negedge clk);
            dm_req_valid = 1'b1; dm_req_addr = addr;
            @(posedge clk); #1; // Request accepted at this clock edge (T0)
            @(negedge clk);
            dm_req_valid = 1'b0; dm_req_addr = 32'h0;

            // Acceptance-to-registered-response latency:
            // Request registered at posedge T0.
            // Hit: resp_valid asserted at posedge T1, registered by master at posedge T2 (2 cycles).
            // Miss: refill at posedge T2, resp_valid registered by master at posedge T3 (3 cycles).
            lat_cycles = 2;
            @(posedge clk); #1;
            tout = 0;
            while (!dm_resp_valid) begin
                @(posedge clk); #1;
                lat_cycles = lat_cycles + 1;
                tout = tout + 1;
                if (tout > 100) begin
                    $fatal(1, "    [TIMEOUT] direct resp_valid never asserted for addr=0x%08h", addr);
                end
            end
            dm_got_hit  = dm_resp_hit;
            dm_got_data = dm_resp_data;
        end
    endtask

    // =========================================================================
    // Helper: run_one_access
    //   Issues the same address to BOTH caches sequentially.
    //   Each cache accepts the request exactly once and produces one response.
    //   Checks hit outcome and returned data word for both designs against
    //   independent expectations. Measures acceptance-to-response latency.
    // =========================================================================
    task run_one_access;
        input  [31:0]  addr;
        input         exp_tw_hit;
        input         exp_dm_hit;
        input  [31:0]  exp_data;
        input  string  label;
        integer tw_lat, dm_lat;
        begin
            // Issue to 2-way cache
            send_req_2way(addr, tw_lat);
            if (tw_got_hit) tw_hits = tw_hits + 1;
            else            tw_misses = tw_misses + 1;
            tw_lat_total = tw_lat_total + tw_lat;

            // Issue to direct-mapped cache
            send_req_direct(addr, dm_lat);
            if (dm_got_hit) dm_hits = dm_hits + 1;
            else            dm_misses = dm_misses + 1;
            dm_lat_total = dm_lat_total + dm_lat;

            // Assertions
            check({label, " 2way hit"},   tw_got_hit  === exp_tw_hit);
            check({label, " 2way data"},  tw_got_data === exp_data);
            check({label, " direct hit"}, dm_got_hit  === exp_dm_hit);
            check({label, " direct data"},dm_got_data === exp_data);
        end
    endtask

    // =========================================================================
    // Helper: print_trace_summary
    //   Prints comprehensive metrics for both designs on a given trace.
    // =========================================================================
    task print_trace_summary(
        input string trace_name,
        input integer total_reqs
    );
        real tw_hr, dm_hr;
        real tw_avg_lat, dm_avg_lat;
        real tw_amat_20, dm_amat_20;
        begin
            tw_hr = (real'(tw_hits) / real'(total_reqs)) * 100.0;
            dm_hr = (real'(dm_hits) / real'(total_reqs)) * 100.0;
            tw_avg_lat = real'(tw_lat_total) / real'(total_reqs);
            dm_avg_lat = real'(dm_lat_total) / real'(total_reqs);

            // Modeled AMAT under assumed miss penalty of 20 cycles (distinguished from 1-cycle RTL model):
            // AMAT = 2.0 (hit cycles) + (1.0 - hit_fraction) * 20.0 (assumed DRAM/L2 penalty)
            tw_amat_20 = 2.0 + (real'(tw_misses) / real'(total_reqs)) * 20.0;
            dm_amat_20 = 2.0 + (real'(dm_misses) / real'(total_reqs)) * 20.0;

            $display("\n  ------------------------------------------------------------------");
            $display("  %s Metrics Summary (Total Reads = %0d):", trace_name, total_reqs);
            $display("  ------------------------------------------------------------------");
            $display("    2-Way Cache   : Hits=%0d, Misses=%0d, HitRate=%0d/%0d (%0.2f%%)",
                     tw_hits, tw_misses, tw_hits, total_reqs, tw_hr);
            $display("                    Measured Latency Total=%0d cycles, Avg=%0.2f cycles/req",
                     tw_lat_total, tw_avg_lat);
            $display("                    Modeled AMAT (penalty=20 cycles): %0.2f cycles",
                     tw_amat_20);
            $display("    Direct Cache  : Hits=%0d, Misses=%0d, HitRate=%0d/%0d (%0.2f%%)",
                     dm_hits, dm_misses, dm_hits, total_reqs, dm_hr);
            $display("                    Measured Latency Total=%0d cycles, Avg=%0.2f cycles/req",
                     dm_lat_total, dm_avg_lat);
            $display("                    Modeled AMAT (penalty=20 cycles): %0.2f cycles",
                     dm_amat_20);
            $display("  ------------------------------------------------------------------");

            // Accumulate to grand totals
            tw_grand_reads  = tw_grand_reads  + total_reqs;
            tw_grand_hits   = tw_grand_hits   + tw_hits;
            tw_grand_misses = tw_grand_misses + tw_misses;
            tw_grand_lat    = tw_grand_lat    + tw_lat_total;

            dm_grand_reads  = dm_grand_reads  + total_reqs;
            dm_grand_hits   = dm_grand_hits   + dm_hits;
            dm_grand_misses = dm_grand_misses + dm_misses;
            dm_grand_lat    = dm_grand_lat    + dm_lat_total;
        end
    endtask

    // =========================================================================
    // TRACE A: Conflict Trace (Loaded from disk)
    // =========================================================================
    task run_trace_A;
        integer trace_len, i;
        logic exp_tw_hit, exp_dm_hit;
        reg [31:0] exp_tw_data, exp_dm_data;
        string lbl;
        begin
            tw_hits = 0; tw_misses = 0; tw_lat_total = 0;
            dm_hits = 0; dm_misses = 0; dm_lat_total = 0;

            $display("\n==================================================================");
            $display("--- TRACE A: Conflict Trace (5 accesses, Set 0 thrashing) ---");
            $display("==================================================================");
            load_trace("tb/traces/conflict_trace.hex", trace_len);
            $display("    All addresses map to Set 0 in both designs.");
            reset_both;

            for (i = 0; i < trace_len; i = i + 1) begin
                ref_tw_step(trace_mem[i], exp_tw_hit, exp_tw_data);
                ref_dm_step(trace_mem[i], exp_dm_hit, exp_dm_data);
                $sformat(lbl, "A.%0d addr=0x%08h", i+1, trace_mem[i]);
                run_one_access(trace_mem[i], exp_tw_hit, exp_dm_hit, exp_tw_data, lbl);
            end

            print_trace_summary("TRACE A (Conflict)", trace_len);

            check("TRACE A: 2way hits == 2",     tw_hits   === 2);
            check("TRACE A: 2way misses == 3",   tw_misses === 3);
            check("TRACE A: direct hits == 0",   dm_hits   === 0);
            check("TRACE A: direct misses == 5", dm_misses === 5);
        end
    endtask

    // =========================================================================
    // TRACE B: Within-Block Locality Trace (Loaded from disk)
    // =========================================================================
    task run_trace_B;
        integer trace_len, i;
        logic exp_tw_hit, exp_dm_hit;
        reg [31:0] exp_tw_data, exp_dm_data;
        string lbl;
        begin
            tw_hits = 0; tw_misses = 0; tw_lat_total = 0;
            dm_hits = 0; dm_misses = 0; dm_lat_total = 0;

            $display("\n==================================================================");
            $display("--- TRACE B: Within-Block Locality Trace (6 accesses) ---");
            $display("==================================================================");
            load_trace("tb/traces/locality_trace.hex", trace_len);
            $display("    0x040: 2way set=0 (tag=1), direct set=4 (tag=0)");
            $display("    0x0C0: 2way set=0 (tag=3), direct set=4 (tag=1)");
            $display("    Both 0x40 and 0xC0 map to direct set 4; held concurrently in 2way set 0.");
            reset_both;

            for (i = 0; i < trace_len; i = i + 1) begin
                ref_tw_step(trace_mem[i], exp_tw_hit, exp_tw_data);
                ref_dm_step(trace_mem[i], exp_dm_hit, exp_dm_data);
                $sformat(lbl, "B.%0d addr=0x%08h", i+1, trace_mem[i]);
                run_one_access(trace_mem[i], exp_tw_hit, exp_dm_hit, exp_tw_data, lbl);
            end

            print_trace_summary("TRACE B (Spatial Locality)", trace_len);

            check("TRACE B: 2way hits == 4",     tw_hits   === 4);
            check("TRACE B: 2way misses == 2",   tw_misses === 2);
            check("TRACE B: direct hits == 4",   dm_hits   === 4);
            check("TRACE B: direct misses == 2", dm_misses === 2);
        end
    endtask

    // =========================================================================
    // TRACE C: Extended 2-Block Conflict Trace (Loaded from disk)
    // =========================================================================
    task run_trace_C;
        integer trace_len, i;
        logic exp_tw_hit, exp_dm_hit;
        reg [31:0] exp_tw_data, exp_dm_data;
        string lbl;
        begin
            tw_hits = 0; tw_misses = 0; tw_lat_total = 0;
            dm_hits = 0; dm_misses = 0; dm_lat_total = 0;

            $display("\n==================================================================");
            $display("--- TRACE C: Extended 2-Block Conflict Trace (16 accesses) ---");
            $display("==================================================================");
            load_trace("tb/traces/conflict_long_trace.hex", trace_len);
            $display("    0x000 and 0x080 alternating 16 times.");
            reset_both;

            for (i = 0; i < trace_len; i = i + 1) begin
                ref_tw_step(trace_mem[i], exp_tw_hit, exp_tw_data);
                ref_dm_step(trace_mem[i], exp_dm_hit, exp_dm_data);
                $sformat(lbl, "C.%0d addr=0x%08h", i+1, trace_mem[i]);
                run_one_access(trace_mem[i], exp_tw_hit, exp_dm_hit, exp_tw_data, lbl);
            end

            print_trace_summary("TRACE C (Extended Conflict)", trace_len);

            check("TRACE C: 2way hits == 14",    tw_hits   === 14);
            check("TRACE C: 2way misses == 2",   tw_misses === 2);
            check("TRACE C: direct hits == 0",   dm_hits   === 0);
            check("TRACE C: direct misses == 16",dm_misses === 16);
        end
    endtask

    // =========================================================================
    // TRACE D: Sequential Locality Trace (Loaded from disk)
    // =========================================================================
    task run_trace_D;
        integer trace_len, i;
        logic exp_tw_hit, exp_dm_hit;
        reg [31:0] exp_tw_data, exp_dm_data;
        string lbl;
        begin
            tw_hits = 0; tw_misses = 0; tw_lat_total = 0;
            dm_hits = 0; dm_misses = 0; dm_lat_total = 0;

            $display("\n==================================================================");
            $display("--- TRACE D: Sequential Full-Capacity Locality Trace (32 accesses) ---");
            $display("==================================================================");
            load_trace("tb/traces/sequential_trace.hex", trace_len);
            $display("    32 accesses across 8 blocks (128 bytes full capacity).");
            reset_both;

            for (i = 0; i < trace_len; i = i + 1) begin
                ref_tw_step(trace_mem[i], exp_tw_hit, exp_tw_data);
                ref_dm_step(trace_mem[i], exp_dm_hit, exp_dm_data);
                $sformat(lbl, "D.%0d addr=0x%08h", i+1, trace_mem[i]);
                run_one_access(trace_mem[i], exp_tw_hit, exp_dm_hit, exp_tw_data, lbl);
            end

            print_trace_summary("TRACE D (Sequential Capacity)", trace_len);

            check("TRACE D: 2way hits == 24",    tw_hits   === 24);
            check("TRACE D: 2way misses == 8",   tw_misses === 8);
            check("TRACE D: direct hits == 24",  dm_hits   === 24);
            check("TRACE D: direct misses == 8", dm_misses === 8);
        end
    endtask

    // =========================================================================
    // TRACE E: Mapping-Sensitive 3-Block Cycle Trace (Loaded from disk)
    // =========================================================================
    task run_trace_E;
        integer trace_len, i;
        logic exp_tw_hit, exp_dm_hit;
        reg [31:0] exp_tw_data, exp_dm_data;
        string lbl;
        begin
            tw_hits = 0; tw_misses = 0; tw_lat_total = 0;
            dm_hits = 0; dm_misses = 0; dm_lat_total = 0;

            $display("\n==================================================================");
            $display("--- TRACE E: Mapping-Sensitive 3-Block Cycle Trace (30 accesses) ---");
            $display("==================================================================");
            load_trace("tb/traces/mapping_sensitive_trace.hex", trace_len);
            $display("    0x000, 0x040, 0x080 repeated 10 times.");
            $display("    2-Way: all 3 map to Set 0 -> 100%% conflict misses.");
            $display("    Direct: 0x040 maps to Set 4 -> isolated hits after cold miss.");
            reset_both;

            for (i = 0; i < trace_len; i = i + 1) begin
                ref_tw_step(trace_mem[i], exp_tw_hit, exp_tw_data);
                ref_dm_step(trace_mem[i], exp_dm_hit, exp_dm_data);
                $sformat(lbl, "E.%0d addr=0x%08h", i+1, trace_mem[i]);
                run_one_access(trace_mem[i], exp_tw_hit, exp_dm_hit, exp_tw_data, lbl);
            end

            print_trace_summary("TRACE E (Mapping Sensitive)", trace_len);

            check("TRACE E: 2way hits == 0",     tw_hits   === 0);
            check("TRACE E: 2way misses == 30",  tw_misses === 30);
            check("TRACE E: direct hits == 9",   dm_hits   === 9);
            check("TRACE E: direct misses == 21",dm_misses === 21);
        end
    endtask

    // =========================================================================
    // MAIN
    // =========================================================================
    initial begin
        pass_count = 0;
        fail_count = 0;
        tw_grand_reads  = 0;
        tw_grand_hits   = 0;
        tw_grand_misses = 0;
        tw_grand_lat    = 0;
        dm_grand_reads  = 0;
        dm_grand_hits   = 0;
        dm_grand_misses = 0;
        dm_grand_lat    = 0;

        tw_rst = 1'b1; tw_req_valid = 1'b0; tw_req_addr = 32'h0;
        dm_rst = 1'b1; dm_req_valid = 1'b0; dm_req_addr = 32'h0;

        $display("==================================================================");
        $display("Starting Comparative Verification: cache_2way vs cache_direct");
        $display("==================================================================");

        run_trace_A;
        run_trace_B;
        run_trace_C;
        run_trace_D;
        run_trace_E;

        // =====================================================================
        // Grand Benchmark Summary Table
        // =====================================================================
        $display("\n==================================================================");
        $display("            GRAND COMPARATIVE BENCHMARK SUMMARY (ALL 5 TRACES)");
        $display("==================================================================");
        $display("  Metric                          2-Way Set-Associative   Direct-Mapped Baseline");
        $display("  ------------------------------------------------------------------");
        $display("  Total Reads Evaluated           %0d                      %0d",
                 tw_grand_reads, dm_grand_reads);
        $display("  Total Cache Hits                %0d                      %0d",
                 tw_grand_hits, dm_grand_hits);
        $display("  Total Cache Misses              %0d                      %0d",
                 tw_grand_misses, dm_grand_misses);
        $display("  Aggregate Hit Rate              %0d/%0d (%0.2f%%)           %0d/%0d (%0.2f%%)",
                 tw_grand_hits, tw_grand_reads,
                 (real'(tw_grand_hits)/real'(tw_grand_reads))*100.0,
                 dm_grand_hits, dm_grand_reads,
                 (real'(dm_grand_hits)/real'(dm_grand_reads))*100.0);
        $display("  Total Measured Latency Cycles   %0d                     %0d",
                 tw_grand_lat, dm_grand_lat);
        $display("  Average Response Latency        %0.3f cycles/req         %0.3f cycles/req",
                 real'(tw_grand_lat)/real'(tw_grand_reads),
                 real'(dm_grand_lat)/real'(dm_grand_reads));
        $display("  Modeled AMAT (penalty=20 cyc)   %0.3f cycles             %0.3f cycles",
                 2.0 + (real'(tw_grand_misses)/real'(tw_grand_reads))*20.0,
                 2.0 + (real'(dm_grand_misses)/real'(dm_grand_reads))*20.0);
        $display("==================================================================");

        $display("\n==================================================================");
        $display("Comparative Verification Complete: %0d Passed, %0d Failed",
                 pass_count, fail_count);
        $display("==================================================================");
        if (fail_count == 0) begin
            $display("TEST RESULT: ALL %0d CHECKS PASSED SUCCESSFULLY", pass_count);
            $finish(0);
        end else begin
            $fatal(1, "TEST RESULT: %0d CHECKS FAILED", fail_count);
        end
    end

endmodule
