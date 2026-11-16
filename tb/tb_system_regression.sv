// ==============================================================================
// Testbench: tb_system_regression
// Description: Targeted self-checking system regression testbench for MCA Project 7.
//              Covers previously unexercised system-level behaviors:
//              1. Full-capacity population across all sets and ways
//              2. Synchronous reset while fully populated & request suppression during reset
//              3. Post-reset cold access verification across all sets (proving complete invalidation)
//              4. Back-to-back request acceptance on the first available ready cycle (no idle penalty)
//              5. System-level cross-set LRU independence under interleaved traffic
//              6. Direct-mapped cache reset, invalidation, and back-to-back streaming regressions
// Standard: SystemVerilog (iverilog -g2012)
// Author: Kushal (Phase I, Handoff 4)
// ==============================================================================

`timescale 1ns / 1ps

module tb_system_regression;

    // --------------------------------------------------------------------------
    // Clock and Reset Signals
    // --------------------------------------------------------------------------
    reg clk;
    reg rst;

    // --------------------------------------------------------------------------
    // 2-Way Cache DUT Signals
    // --------------------------------------------------------------------------
    reg         tw_req_valid;
    reg  [31:0] tw_req_addr;
    wire        tw_req_ready;
    wire        tw_resp_valid;
    wire        tw_resp_hit;
    wire [31:0] tw_resp_data;
    wire [31:0] tw_mem_block_addr;
    wire [127:0] tw_mem_block_data;

    // --------------------------------------------------------------------------
    // Direct-Mapped Cache DUT Signals
    // --------------------------------------------------------------------------
    reg         dm_req_valid;
    reg  [31:0] dm_req_addr;
    wire        dm_req_ready;
    wire        dm_resp_valid;
    wire        dm_resp_hit;
    wire [31:0] dm_resp_data;
    wire [31:0] dm_mem_block_addr;
    wire [127:0] dm_mem_block_data;

    // Pass / Fail Bookkeeping
    int pass_count = 0;
    int fail_count = 0;

    // --------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiations
    // --------------------------------------------------------------------------
    cache_2way u_cache_2way (
        .clk            (clk),
        .rst            (rst),
        .req_valid      (tw_req_valid),
        .req_addr       (tw_req_addr),
        .req_ready      (tw_req_ready),
        .resp_valid     (tw_resp_valid),
        .resp_hit       (tw_resp_hit),
        .resp_data      (tw_resp_data),
        .mem_block_addr (tw_mem_block_addr),
        .mem_block_data (tw_mem_block_data)
    );

    mem_block_model u_mem_2way (
        .mem_block_addr (tw_mem_block_addr),
        .mem_block_data (tw_mem_block_data)
    );

    cache_direct u_cache_direct (
        .clk            (clk),
        .rst            (rst),
        .req_valid      (dm_req_valid),
        .req_addr       (dm_req_addr),
        .req_ready      (dm_req_ready),
        .resp_valid     (dm_resp_valid),
        .resp_hit       (dm_resp_hit),
        .resp_data      (dm_resp_data),
        .mem_block_addr (dm_mem_block_addr),
        .mem_block_data (dm_mem_block_data)
    );

    mem_block_model u_mem_direct (
        .mem_block_addr (dm_mem_block_addr),
        .mem_block_data (dm_mem_block_data)
    );

    // --------------------------------------------------------------------------
    // 100 MHz Clock Generation (10 ns period)
    // --------------------------------------------------------------------------
    always #5 clk = ~clk;

    // Watchdog Timeout (100 us)
    initial begin
        #100000;
        $display("\n[FATAL] Watchdog timeout reached in tb_system_regression! Simulation killed.");
        $finish(1);
    end

    // Assertion Helper
    task check(input string msg, input logic condition);
        if (condition) begin
            $display("  [PASS] %s", msg);
            pass_count++;
        end else begin
            $display("  [FAIL] %s", msg);
            fail_count++;
        end
    endtask

    // --------------------------------------------------------------------------
    // 2-Way Cache Transaction Helper
    // --------------------------------------------------------------------------
    task automatic tw_exec(
        input [31:0] addr,
        input        exp_hit,
        input [31:0] exp_data,
        input string desc
    );
        int timeout_cycles;
        logic sampled_hit;
        logic [31:0] sampled_data;

        // Wait until cache is ready
        timeout_cycles = 0;
        while (!tw_req_ready && timeout_cycles < 30) begin
            @(posedge clk);
            timeout_cycles++;
        end
        check($sformatf("%s: tw_req_ready became high within bounds", desc), tw_req_ready === 1'b1);

        // Assert request on negedge for clean setup
        @(negedge clk);
        tw_req_valid = 1'b1;
        tw_req_addr  = addr;

        // Latch on posedge
        @(posedge clk);
        #1;

        // Deassert request
        @(negedge clk);
        tw_req_valid = 1'b0;
        tw_req_addr  = 32'hDEADBEEF;

        // Wait for response
        timeout_cycles = 0;
        while (!tw_resp_valid && timeout_cycles < 30) begin
            @(posedge clk);
            timeout_cycles++;
        end

        check($sformatf("%s: tw_resp_valid asserted within bounds", desc), tw_resp_valid === 1'b1);
        sampled_hit  = tw_resp_hit;
        sampled_data = tw_resp_data;

        check($sformatf("%s: hit classification (exp=%0b, got=%0b)", desc, exp_hit, sampled_hit), sampled_hit === exp_hit);
        check($sformatf("%s: returned data (exp=0x%08h, got=0x%08h)", desc, exp_data, sampled_data), sampled_data === exp_data);

        // Verify single cycle pulse
        @(posedge clk);
        #1;
        check($sformatf("%s: tw_resp_valid pulse ended after 1 cycle", desc), tw_resp_valid === 1'b0);
    endtask

    // --------------------------------------------------------------------------
    // Direct-Mapped Cache Transaction Helper
    // --------------------------------------------------------------------------
    task automatic dm_exec(
        input [31:0] addr,
        input        exp_hit,
        input [31:0] exp_data,
        input string desc
    );
        int timeout_cycles;
        logic sampled_hit;
        logic [31:0] sampled_data;

        timeout_cycles = 0;
        while (!dm_req_ready && timeout_cycles < 30) begin
            @(posedge clk);
            timeout_cycles++;
        end
        check($sformatf("%s: dm_req_ready became high within bounds", desc), dm_req_ready === 1'b1);

        @(negedge clk);
        dm_req_valid = 1'b1;
        dm_req_addr  = addr;

        @(posedge clk);
        #1;

        @(negedge clk);
        dm_req_valid = 1'b0;
        dm_req_addr  = 32'hDEADBEEF;

        timeout_cycles = 0;
        while (!dm_resp_valid && timeout_cycles < 30) begin
            @(posedge clk);
            timeout_cycles++;
        end

        check($sformatf("%s: dm_resp_valid asserted within bounds", desc), dm_resp_valid === 1'b1);
        sampled_hit  = dm_resp_hit;
        sampled_data = dm_resp_data;

        check($sformatf("%s: hit classification (exp=%0b, got=%0b)", desc, exp_hit, sampled_hit), sampled_hit === exp_hit);
        check($sformatf("%s: returned data (exp=0x%08h, got=0x%08h)", desc, exp_data, sampled_data), sampled_data === exp_data);

        @(posedge clk);
        #1;
        check($sformatf("%s: dm_resp_valid pulse ended after 1 cycle", desc), dm_resp_valid === 1'b0);
    endtask

    // --------------------------------------------------------------------------
    // Main Verification Flow
    // --------------------------------------------------------------------------
    initial begin
        clk          = 0;
        rst          = 1;
        tw_req_valid = 0;
        tw_req_addr  = 32'h0;
        dm_req_valid = 0;
        dm_req_addr  = 32'h0;

        $display("==================================================================");
        $display("Starting Targeted System Regressions: tb_system_regression");
        $display("==================================================================");

        // Power-on reset
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 0;
        @(posedge clk);
        #1;

        // ======================================================================
        // REGRESSION 1: Full-Capacity Population & Reset After Population
        // ======================================================================
        $display("\n--- Regression 1: Full Population & Reset After Population (2-Way) ---");
        // Populate all 8 cache blocks in 2-way cache:
        // Set 0: Way 0 = 0x00000000, Way 1 = 0x00000080
        // Set 1: Way 0 = 0x00000010, Way 1 = 0x00000090
        // Set 2: Way 0 = 0x00000020, Way 1 = 0x000000A0
        // Set 3: Way 0 = 0x00000030, Way 1 = 0x000000B0
        tw_exec(32'h00000000, 1'b0, 32'h00000000, "Populate Set 0 Way 0 (0x00)");
        tw_exec(32'h00000080, 1'b0, 32'h00000080, "Populate Set 0 Way 1 (0x80)");
        tw_exec(32'h00000010, 1'b0, 32'h00000010, "Populate Set 1 Way 0 (0x10)");
        tw_exec(32'h00000090, 1'b0, 32'h00000090, "Populate Set 1 Way 1 (0x90)");
        tw_exec(32'h00000020, 1'b0, 32'h00000020, "Populate Set 2 Way 0 (0x20)");
        tw_exec(32'h000000A0, 1'b0, 32'h000000A0, "Populate Set 2 Way 1 (0xA0)");
        tw_exec(32'h00000030, 1'b0, 32'h00000030, "Populate Set 3 Way 0 (0x30)");
        tw_exec(32'h000000B0, 1'b0, 32'h000000B0, "Populate Set 3 Way 1 (0xB0)");

        // Verify all 8 blocks are resident hits
        $display("  Verifying all 8 populated blocks are active hits...");
        tw_exec(32'h00000000, 1'b1, 32'h00000000, "Verify Hit Set 0 Way 0 (0x00)");
        tw_exec(32'h00000080, 1'b1, 32'h00000080, "Verify Hit Set 0 Way 1 (0x80)");
        tw_exec(32'h00000010, 1'b1, 32'h00000010, "Verify Hit Set 1 Way 0 (0x10)");
        tw_exec(32'h00000090, 1'b1, 32'h00000090, "Verify Hit Set 1 Way 1 (0x90)");
        tw_exec(32'h00000020, 1'b1, 32'h00000020, "Verify Hit Set 2 Way 0 (0x20)");
        tw_exec(32'h000000A0, 1'b1, 32'h000000A0, "Verify Hit Set 2 Way 1 (0xA0)");
        tw_exec(32'h00000030, 1'b1, 32'h00000030, "Verify Hit Set 3 Way 0 (0x30)");
        tw_exec(32'h000000B0, 1'b1, 32'h000000B0, "Verify Hit Set 3 Way 1 (0xB0)");

        // Assert reset while fully populated
        $display("  Asserting reset on fully-populated cache...");
        @(negedge clk);
        rst = 1;
        // Present spurious request while reset is asserted to test suppression
        tw_req_valid = 1'b1;
        tw_req_addr  = 32'h00000000;

        @(posedge clk);
        #1;
        check("2-way req_ready must be deasserted during reset", tw_req_ready === 1'b0);
        check("2-way resp_valid must be deasserted during reset", tw_resp_valid === 1'b0);

        @(posedge clk);
        #1;
        check("2-way req_ready remains deasserted on cycle 2 of reset", tw_req_ready === 1'b0);
        check("2-way resp_valid remains deasserted on cycle 2 of reset", tw_resp_valid === 1'b0);

        @(negedge clk);
        tw_req_valid = 1'b0;
        rst = 0;

        @(posedge clk);
        #1;
        check("2-way req_ready asserts on first cycle post-reset", tw_req_ready === 1'b1);
        check("2-way resp_valid is deasserted post-reset", tw_resp_valid === 1'b0);

        // ======================================================================
        // REGRESSION 2: Cold Access After Reset (Proving Invalidation)
        // ======================================================================
        $display("\n--- Regression 2: Cold Accesses After Reset (2-Way Invalidation) ---");
        // Every single address that was previously a hit MUST now be a cold MISS!
        tw_exec(32'h00000000, 1'b0, 32'h00000000, "Post-Reset Cold Miss Set 0 (0x00)");
        tw_exec(32'h00000080, 1'b0, 32'h00000080, "Post-Reset Cold Miss Set 0 (0x80)");
        tw_exec(32'h00000010, 1'b0, 32'h00000010, "Post-Reset Cold Miss Set 1 (0x10)");
        tw_exec(32'h00000090, 1'b0, 32'h00000090, "Post-Reset Cold Miss Set 1 (0x90)");
        tw_exec(32'h00000020, 1'b0, 32'h00000020, "Post-Reset Cold Miss Set 2 (0x20)");
        tw_exec(32'h000000A0, 1'b0, 32'h000000A0, "Post-Reset Cold Miss Set 2 (0xA0)");
        tw_exec(32'h00000030, 1'b0, 32'h00000030, "Post-Reset Cold Miss Set 3 (0x30)");
        tw_exec(32'h000000B0, 1'b0, 32'h000000B0, "Post-Reset Cold Miss Set 3 (0xB0)");

        // After refilling, they must all be hits again
        tw_exec(32'h00000000, 1'b1, 32'h00000000, "Re-verified Hit Set 0 (0x00)");
        tw_exec(32'h00000080, 1'b1, 32'h00000080, "Re-verified Hit Set 0 (0x80)");
        tw_exec(32'h00000010, 1'b1, 32'h00000010, "Re-verified Hit Set 1 (0x10)");
        tw_exec(32'h00000090, 1'b1, 32'h00000090, "Re-verified Hit Set 1 (0x90)");

        // ======================================================================
        // REGRESSION 3: Back-to-Back Request Acceptance on First Ready Cycle
        // ======================================================================
        $display("\n--- Regression 3: Back-to-Back Acceptance on First Available Ready Cycle ---");
        // Test back-to-back streaming without idle delay cycles:
        // When resp_valid is pulsed, the very next cycle is IDLE where req_ready = 1.
        // Presenting req_valid on that exact cycle MUST be accepted immediately!
        begin: b2b_test
            int r_idx;
            logic [31:0] test_addrs [0:5];
            logic        exp_hits   [0:5];
            logic [31:0] exp_datas  [0:5];

            // Define stream:
            // 0: 0x00000000 -> HIT (cached)
            // 1: 0x00000004 -> HIT (Word 1 of cached block 0x00)
            // 2: 0x00000040 -> MISS (new block in Set 0, replaces 0x80 because 0x00 was touched!)
            // 3: 0x00000048 -> HIT (Word 2 of newly refilled block 0x40)
            // 4: 0x00000010 -> HIT (cached in Set 1)
            // 5: 0x00000050 -> MISS (new block in Set 1)
            test_addrs[0] = 32'h00000000; exp_hits[0] = 1'b1; exp_datas[0] = 32'h00000000;
            test_addrs[1] = 32'h00000004; exp_hits[1] = 1'b1; exp_datas[1] = 32'h00000004;
            test_addrs[2] = 32'h00000040; exp_hits[2] = 1'b0; exp_datas[2] = 32'h00000040;
            test_addrs[3] = 32'h00000048; exp_hits[3] = 1'b1; exp_datas[3] = 32'h00000048;
            test_addrs[4] = 32'h00000010; exp_hits[4] = 1'b1; exp_datas[4] = 32'h00000010;
            test_addrs[5] = 32'h00000050; exp_hits[5] = 1'b0; exp_datas[5] = 32'h00000050;

            for (r_idx = 0; r_idx < 6; r_idx++) begin
                // Wait until ready
                while (!tw_req_ready) @(posedge clk);

                // Assert on negedge right before posedge acceptance
                @(negedge clk);
                tw_req_valid = 1'b1;
                tw_req_addr  = test_addrs[r_idx];

                // Acceptance edge
                @(posedge clk);
                #1;
                check($sformatf("Stream Req %0d: accepted on first ready cycle (addr=0x%08h)", r_idx, test_addrs[r_idx]),
                      u_cache_2way.state !== 2'b00); // Has moved out of IDLE to LOOKUP

                // Deassert request
                @(negedge clk);
                tw_req_valid = 1'b0;
                tw_req_addr  = 32'hDEADBEEF;

                // Wait for resp_valid
                while (!tw_resp_valid) @(posedge clk);

                check($sformatf("Stream Req %0d: resp_hit matches expected (%0b)", r_idx, exp_hits[r_idx]),
                      tw_resp_hit === exp_hits[r_idx]);
                check($sformatf("Stream Req %0d: resp_data matches expected (0x%08h)", r_idx, exp_datas[r_idx]),
                      tw_resp_data === exp_datas[r_idx]);

                // On the very next clock edge, state returns to IDLE and tw_req_ready rises!
                @(posedge clk);
                #1;
                check($sformatf("Stream Req %0d: tw_req_ready asserted immediately on following cycle", r_idx),
                      tw_req_ready === 1'b1);
            end
        end

        // ======================================================================
        // REGRESSION 4: Cross-Set LRU Independence Under Interleaved Traffic
        // ======================================================================
        $display("\n--- Regression 4: Independent LRU State Across Sets Under Interleaved Traffic ---");
        // Reset cache to establish clean baseline
        @(negedge clk);
        rst = 1;
        @(posedge clk);
        @(negedge clk);
        rst = 0;
        @(posedge clk);
        #1;

        // Populate Set 0 (Way 0 = 0x000, Way 1 = 0x080)
        tw_exec(32'h00000000, 1'b0, 32'h00000000, "Set 0 Way 0 Fill (0x00)");
        tw_exec(32'h00000080, 1'b0, 32'h00000080, "Set 0 Way 1 Fill (0x80)");
        // At this point in Set 0: Way 1 was filled last -> Way 0 is LRU victim.

        // Populate Set 2 (Way 0 = 0x020, Way 1 = 0x0A0)
        tw_exec(32'h00000020, 1'b0, 32'h00000020, "Set 2 Way 0 Fill (0x20)");
        tw_exec(32'h000000A0, 1'b0, 32'h000000A0, "Set 2 Way 1 Fill (0xA0)");
        // At this point in Set 2: Way 1 was filled last -> Way 0 is LRU victim.

        // Now touch Set 0 Way 0 (0x00).
        // This touches Way 0, flipping Set 0's LRU victim to Way 1 (0x80)!
        tw_exec(32'h00000000, 1'b1, 32'h00000000, "Touch Set 0 Way 0 (0x00) -> Way 1 becomes victim");

        // Now perform heavy traffic on Set 1 and Set 3 (different sets)
        tw_exec(32'h00000010, 1'b0, 32'h00000010, "Set 1 Fill Block 1 (0x10)");
        tw_exec(32'h00000090, 1'b0, 32'h00000090, "Set 1 Fill Block 2 (0x90)");
        tw_exec(32'h00000010, 1'b1, 32'h00000010, "Set 1 Hit Block 1 (0x10)");
        tw_exec(32'h00000030, 1'b0, 32'h00000030, "Set 3 Fill Block 1 (0x30)");
        tw_exec(32'h000000B0, 1'b0, 32'h000000B0, "Set 3 Fill Block 2 (0xB0)");
        tw_exec(32'h00000130, 1'b0, 32'h00000130, "Set 3 Eviction Miss (0x130)");

        // Now trigger an eviction in Set 0 by accessing 0x100 (maps to Set 0)
        // Because Set 0's victim was flipped to Way 1 (0x80), Way 1 MUST be evicted!
        // Way 0 (0x00) MUST survive!
        tw_exec(32'h00000100, 1'b0, 32'h00000100, "Set 0 Miss Eviction (0x100) -> evicts 0x80");

        // Verify Set 0 Way 0 (0x00) survived and is a HIT!
        tw_exec(32'h00000000, 1'b1, 32'h00000000, "Verify Set 0 (0x00) SURVIVED in Way 0 (HIT!)");

        // Verify Set 0 Way 1 (0x80) was evicted (MISS!)
        tw_exec(32'h00000080, 1'b0, 32'h00000080, "Verify Set 0 (0x80) was EVICTED from Way 1 (MISS!)");

        // Now verify Set 2's LRU state was completely isolated:
        // In Set 2, Way 0 (0x20) was the LRU victim before the interleaved traffic.
        // It was NEVER touched! So Way 0 MUST still be the LRU victim in Set 2!
        // A miss in Set 2 (0x120) MUST evict Way 0 (0x20) and preserve Way 1 (0xA0)!
        tw_exec(32'h00000120, 1'b0, 32'h00000120, "Set 2 Miss Eviction (0x120) -> must evict Way 0");

        // Verify Set 2 Way 1 (0xA0) SURVIVED in Set 2 (HIT!)
        tw_exec(32'h000000A0, 1'b1, 32'h000000A0, "Verify Set 2 Way 1 (0xA0) SURVIVED (HIT!)");

        // Verify Set 2 Way 0 (0x20) was EVICTED (MISS!)
        tw_exec(32'h00000020, 1'b0, 32'h00000020, "Verify Set 2 Way 0 (0x20) was EVICTED (MISS!)");

        // ======================================================================
        // REGRESSION 5: Direct-Mapped Cache Reset & Request Regressions
        // ======================================================================
        $display("\n--- Regression 5: Direct-Mapped Cache System Regressions ---");
        // Populate all 8 sets in direct-mapped cache
        dm_exec(32'h00000000, 1'b0, 32'h00000000, "Direct Populate Set 0 (0x00)");
        dm_exec(32'h00000010, 1'b0, 32'h00000010, "Direct Populate Set 1 (0x10)");
        dm_exec(32'h00000020, 1'b0, 32'h00000020, "Direct Populate Set 2 (0x20)");
        dm_exec(32'h00000030, 1'b0, 32'h00000030, "Direct Populate Set 3 (0x30)");
        dm_exec(32'h00000040, 1'b0, 32'h00000040, "Direct Populate Set 4 (0x40)");
        dm_exec(32'h00000050, 1'b0, 32'h00000050, "Direct Populate Set 5 (0x50)");
        dm_exec(32'h00000060, 1'b0, 32'h00000060, "Direct Populate Set 6 (0x60)");
        dm_exec(32'h00000070, 1'b0, 32'h00000070, "Direct Populate Set 7 (0x70)");

        // Verify all 8 sets hit
        dm_exec(32'h00000000, 1'b1, 32'h00000000, "Direct Verify Hit Set 0 (0x00)");
        dm_exec(32'h00000040, 1'b1, 32'h00000040, "Direct Verify Hit Set 4 (0x40)");
        dm_exec(32'h00000070, 1'b1, 32'h00000070, "Direct Verify Hit Set 7 (0x70)");

        // Reset direct-mapped cache
        @(negedge clk);
        rst = 1;
        dm_req_valid = 1'b1;
        dm_req_addr  = 32'h00000000;
        @(posedge clk);
        #1;
        check("Direct req_ready deasserted during reset", dm_req_ready === 1'b0);
        check("Direct resp_valid deasserted during reset", dm_resp_valid === 1'b0);

        @(negedge clk);
        dm_req_valid = 1'b0;
        rst = 0;
        @(posedge clk);
        #1;
        check("Direct req_ready asserted on first cycle post-reset", dm_req_ready === 1'b1);

        // Verify cold misses post-reset across direct-mapped sets
        dm_exec(32'h00000000, 1'b0, 32'h00000000, "Direct Post-Reset Cold Miss Set 0 (0x00)");
        dm_exec(32'h00000040, 1'b0, 32'h00000040, "Direct Post-Reset Cold Miss Set 4 (0x40)");
        dm_exec(32'h00000070, 1'b0, 32'h00000070, "Direct Post-Reset Cold Miss Set 7 (0x70)");

        // Direct-mapped back-to-back streaming on first ready cycle
        begin: dm_b2b_test
            int d_idx;
            logic [31:0] dm_addrs [0:3];
            logic        dm_hits  [0:3];
            logic [31:0] dm_datas [0:3];

            dm_addrs[0] = 32'h00000000; dm_hits[0] = 1'b1; dm_datas[0] = 32'h00000000; // Hit (cached above)
            dm_addrs[1] = 32'h00000004; dm_hits[1] = 1'b1; dm_datas[1] = 32'h00000004; // Hit Word 1
            dm_addrs[2] = 32'h00000080; dm_hits[2] = 1'b0; dm_datas[2] = 32'h00000080; // Conflict Miss in Set 0
            dm_addrs[3] = 32'h00000088; dm_hits[3] = 1'b1; dm_datas[3] = 32'h00000088; // Hit Word 2

            for (d_idx = 0; d_idx < 4; d_idx++) begin
                while (!dm_req_ready) @(posedge clk);

                @(negedge clk);
                dm_req_valid = 1'b1;
                dm_req_addr  = dm_addrs[d_idx];

                @(posedge clk);
                #1;
                check($sformatf("Direct Stream %0d: accepted on first ready cycle", d_idx),
                      u_cache_direct.state !== 2'b00);

                @(negedge clk);
                dm_req_valid = 1'b0;
                dm_req_addr  = 32'hDEADBEEF;

                while (!dm_resp_valid) @(posedge clk);

                check($sformatf("Direct Stream %0d: hit match (%0b)", d_idx, dm_hits[d_idx]),
                      dm_resp_hit === dm_hits[d_idx]);
                check($sformatf("Direct Stream %0d: data match (0x%08h)", d_idx, dm_datas[d_idx]),
                      dm_resp_data === dm_datas[d_idx]);

                @(posedge clk);
                #1;
                check($sformatf("Direct Stream %0d: req_ready asserted on subsequent cycle", d_idx),
                      dm_req_ready === 1'b1);
            end
        end

        // ----------------------------------------------------------------------
        // Final Summary
        // ----------------------------------------------------------------------
        $display("\n==================================================================");
        $display("System Regression Verification Complete: %0d Passed, %0d Failed", pass_count, fail_count);
        $display("==================================================================");

        if (fail_count == 0) begin
            $display("TEST RESULT: ALL %0d CHECKS PASSED SUCCESSFULLY", pass_count);
            $finish(0);
        end else begin
            $display("TEST RESULT: %0d ASSERTIONS FAILED!", fail_count);
            $finish(1);
        end
    end

endmodule
