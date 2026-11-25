// ==============================================================================
// Testbench: tb_cache_compare
// Description: Shared self-checking comparison testbench.
//              Instantiates both cache_2way and cache_direct connected to
//              independent instances of mem_block_model.
//              Consumes checked-in trace files as the authoritative address source.
//              Replays identical aligned address sequences through both cold caches,
//              with equal data capacity, block size and memory behavior.
//              Keeps expected outcomes independent of RTL output, using
//              hand-checked vectors and an independent reference model.
//              Verifies response data, hit/miss outcomes, and transaction counts.
//
// TRACE A -- Conflict Trace (5 addresses all mapping to Set 0):
//   Trace file: tb/traces/conflict_trace.hex
//   Addresses: 0x00000000, 0x00000080, 0x00000000, 0x00000100, 0x00000000
//   Address mapping:
//     2-way  : set = addr[5:4] = 2'b00 (Set 0 for all three distinct blocks)
//     direct : set = addr[6:4] = 3'b000 (Set 0 for all three distinct blocks)
//   Expected 2way  : Miss, Miss, HIT, Miss, HIT  => 2/5 = 40% hit rate
//   Expected direct: Miss, Miss, Miss, Miss, Miss => 0/5 =  0% hit rate
//
// TRACE B -- Within-Block Locality Trace:
//   Trace file: tb/traces/locality_trace.hex
//   Addresses: 0x00000040, 0x00000044, 0x00000048, 0x0000004C, 0x000000C0, 0x000000C4
//   0x40 mapping:
//     2-way  : set = addr[5:4] = 2'b00 (Set 0), tag = addr[31:6] = 1
//     direct : set = addr[6:4] = 3'b100 (Set 4), tag = addr[31:7] = 0
//   0xC0 mapping:
//     2-way  : set = addr[5:4] = 2'b00 (Set 0), tag = addr[31:6] = 3
//     direct : set = addr[6:4] = 3'b100 (Set 4), tag = addr[31:7] = 1
//   => Note: 0x40 and 0xC0 both map to direct set 4, with tags 0 and 1 respectively.
//   => In 2-way, 0x40 and 0xC0 both map to set 0, with tags 1 and 3 respectively (held in ways 0 and 1).
//   Expected both designs: Miss, Hit, Hit, Hit, Miss, Hit => 4/6 = 67% hit rate
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

    // Watchdog
    initial begin
        #500000;
        $display("[FATAL] Watchdog timeout -- simulation killed.");
        $finish(1);
    end

    // =========================================================================
    // Global counters
    // =========================================================================
    integer pass_count;
    integer fail_count;

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
    // Per-trace hit/miss accumulators
    // =========================================================================
    integer tw_hits;
    integer tw_misses;
    integer dm_hits;
    integer dm_misses;

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
                $display("    [ERROR] Failed to open trace file: %s", filename);
                fail_count = fail_count + 1;
                $finish(1);
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
    // Helper: send one request to cache_2way, capture result in tw_got_hit/data
    // =========================================================================
    reg        tw_got_hit;
    reg [31:0] tw_got_data;

    task send_req_2way;
        input [31:0] addr;
        integer tout;
        begin
            tout = 0;
            while (!tw_req_ready) begin
                @(posedge clk); #1;
                tout = tout + 1;
                if (tout > 100) begin
                    $display("    [TIMEOUT] 2way req_ready for 0x%08h", addr);
                    fail_count = fail_count + 1;
                    tw_got_hit  = 1'bx; tw_got_data = 32'hx;
                    disable send_req_2way;
                end
            end
            @(negedge clk);
            tw_req_valid = 1'b1; tw_req_addr = addr;
            @(posedge clk); #1;
            @(negedge clk);
            tw_req_valid = 1'b0; tw_req_addr = 32'h0;
            @(posedge clk); #1;
            tout = 0;
            while (!tw_resp_valid) begin
                @(posedge clk); #1;
                tout = tout + 1;
                if (tout > 100) begin
                    $display("    [TIMEOUT] 2way resp_valid for 0x%08h", addr);
                    fail_count = fail_count + 1;
                    tw_got_hit  = 1'bx; tw_got_data = 32'hx;
                    disable send_req_2way;
                end
            end
            tw_got_hit  = tw_resp_hit;
            tw_got_data = tw_resp_data;
        end
    endtask

    // =========================================================================
    // Helper: send one request to cache_direct, capture result in dm_got_hit/data
    // =========================================================================
    reg        dm_got_hit;
    reg [31:0] dm_got_data;

    task send_req_direct;
        input [31:0] addr;
        integer tout;
        begin
            tout = 0;
            while (!dm_req_ready) begin
                @(posedge clk); #1;
                tout = tout + 1;
                if (tout > 100) begin
                    $display("    [TIMEOUT] direct req_ready for 0x%08h", addr);
                    fail_count = fail_count + 1;
                    dm_got_hit  = 1'bx; dm_got_data = 32'hx;
                    disable send_req_direct;
                end
            end
            @(negedge clk);
            dm_req_valid = 1'b1; dm_req_addr = addr;
            @(posedge clk); #1;
            @(negedge clk);
            dm_req_valid = 1'b0; dm_req_addr = 32'h0;
            @(posedge clk); #1;
            tout = 0;
            while (!dm_resp_valid) begin
                @(posedge clk); #1;
                tout = tout + 1;
                if (tout > 100) begin
                    $display("    [TIMEOUT] direct resp_valid for 0x%08h", addr);
                    fail_count = fail_count + 1;
                    dm_got_hit  = 1'bx; dm_got_data = 32'hx;
                    disable send_req_direct;
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
    //   independent expectations. Updates per-design hit/miss counters.
    // =========================================================================
    task run_one_access;
        input [31:0] addr;
        input        exp_tw_hit;
        input        exp_dm_hit;
        input [31:0] exp_data;
        input string label;
        begin
            // Issue to 2-way cache
            send_req_2way(addr);
            if (tw_got_hit) tw_hits   = tw_hits   + 1;
            else             tw_misses = tw_misses + 1;

            // Issue to direct-mapped cache
            send_req_direct(addr);
            if (dm_got_hit) dm_hits   = dm_hits   + 1;
            else             dm_misses = dm_misses + 1;

            // Assertions
            check({label, " 2way hit"},   tw_got_hit  === exp_tw_hit);
            check({label, " 2way data"},  tw_got_data === exp_data);
            check({label, " direct hit"}, dm_got_hit  === exp_dm_hit);
            check({label, " direct data"},dm_got_data === exp_data);
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
            tw_hits = 0; tw_misses = 0;
            dm_hits = 0; dm_misses = 0;

            $display("\n--- TRACE A: Conflict Trace ---");
            load_trace("tb/traces/conflict_trace.hex", trace_len);
            $display("    Addresses loaded: %0d", trace_len);
            $display("    All map to Set 0 in both designs.");
            reset_both;

            for (i = 0; i < trace_len; i = i + 1) begin
                ref_tw_step(trace_mem[i], exp_tw_hit, exp_tw_data);
                ref_dm_step(trace_mem[i], exp_dm_hit, exp_dm_data);
                $sformat(lbl, "A.%0d addr=0x%08h", i+1, trace_mem[i]);
                run_one_access(trace_mem[i], exp_tw_hit, exp_dm_hit, exp_tw_data, lbl);
            end

            $display("\n  TRACE A Summary:");
            $display("    2-Way  : %0d hits / %0d accesses = %0d%% hit rate",
                     tw_hits, tw_hits+tw_misses,
                     (tw_hits * 100) / (tw_hits + tw_misses));
            $display("    Direct : %0d hits / %0d accesses = %0d%% hit rate",
                     dm_hits, dm_hits+dm_misses,
                     (dm_hits * 100) / (dm_hits + dm_misses));

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
            tw_hits = 0; tw_misses = 0;
            dm_hits = 0; dm_misses = 0;

            $display("\n--- TRACE B: Within-Block Locality Trace ---");
            load_trace("tb/traces/locality_trace.hex", trace_len);
            $display("    Addresses loaded: %0d", trace_len);
            $display("    0x040: 2way set=0 (tag=1), direct set=4 (tag=0)");
            $display("    0x0C0: 2way set=0 (tag=3), direct set=4 (tag=1)");
            $display("    Both 0x40 and 0xC0 map to direct set 4; held concurrently in 2way set 0.");
            $display("    Expected both: Miss Hit Hit Hit Miss Hit => 4/6 = 67%%");
            reset_both;

            for (i = 0; i < trace_len; i = i + 1) begin
                ref_tw_step(trace_mem[i], exp_tw_hit, exp_tw_data);
                ref_dm_step(trace_mem[i], exp_dm_hit, exp_dm_data);
                $sformat(lbl, "B.%0d addr=0x%08h", i+1, trace_mem[i]);
                run_one_access(trace_mem[i], exp_tw_hit, exp_dm_hit, exp_tw_data, lbl);
            end

            $display("\n  TRACE B Summary:");
            $display("    2-Way  : %0d hits / %0d accesses = %0d%% hit rate",
                     tw_hits, tw_hits+tw_misses,
                     (tw_hits * 100) / (tw_hits + tw_misses));
            $display("    Direct : %0d hits / %0d accesses = %0d%% hit rate",
                     dm_hits, dm_hits+dm_misses,
                     (dm_hits * 100) / (dm_hits + dm_misses));

            check("TRACE B: 2way hits == 4",     tw_hits   === 4);
            check("TRACE B: 2way misses == 2",   tw_misses === 2);
            check("TRACE B: direct hits == 4",   dm_hits   === 4);
            check("TRACE B: direct misses == 2", dm_misses === 2);
        end
    endtask

    // =========================================================================
    // MAIN
    // =========================================================================
    initial begin
        pass_count = 0;
        fail_count = 0;
        tw_hits = 0; tw_misses = 0;
        dm_hits = 0; dm_misses = 0;
        tw_rst = 1'b1; tw_req_valid = 1'b0; tw_req_addr = 32'h0;
        dm_rst = 1'b1; dm_req_valid = 1'b0; dm_req_addr = 32'h0;

        $display("==================================================================");
        $display("Starting Comparative Verification: cache_2way vs cache_direct");
        $display("==================================================================");

        run_trace_A;
        run_trace_B;

        $display("\n==================================================================");
        $display("Comparative Verification Complete: %0d Passed, %0d Failed",
                 pass_count, fail_count);
        $display("==================================================================");
        if (fail_count == 0) begin
            $display("TEST RESULT: ALL %0d CHECKS PASSED SUCCESSFULLY", pass_count);
            $finish(0);
        end else begin
            $display("TEST RESULT: %0d CHECKS FAILED", fail_count);
            $finish(1);
        end
    end

endmodule
