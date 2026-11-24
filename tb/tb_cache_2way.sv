// ==============================================================================
// Testbench: tb_cache_2way
// Description: Self-checking integration testbench for cache_2way using the
//              reusable mem_block_model. Verifies:
//              1. Synchronous reset & busy timing
//              2. Five-request benchmark demo trace (Miss, Miss, Hit, Miss, Hit)
//              3. Returned data integrity across all word offsets (Word 0..3)
//              4. Request-address mutability after acceptance (isolation from bus)
//              5. Exact 1-cycle response pulse and single-outstanding-request rule
//              6. Multi-set independence and back-to-back transaction handling
//              7. Watchdog timeout enforcement
// Standard: SystemVerilog (iverilog -g2012)
// Author: Apoorva
// ==============================================================================

`timescale 1ns / 1ps

module tb_cache_2way;

    // Clock and reset signals
    reg         clk;
    reg         rst;

    // Cache request interface
    reg         req_valid;
    reg  [31:0] req_addr;
    wire        req_ready;

    // Cache response interface
    wire        resp_valid;
    wire        resp_hit;
    wire [31:0] resp_data;

    // Memory refill interface
    wire [31:0]  mem_block_addr;
    wire [127:0] mem_block_data;

    // Pass / Fail bookkeeping
    int pass_count = 0;
    int fail_count = 0;

    // Instantiate Device Under Test (DUT)
    cache_2way dut (
        .clk            (clk),
        .rst            (rst),
        .req_valid      (req_valid),
        .req_addr       (req_addr),
        .req_ready      (req_ready),
        .resp_valid     (resp_valid),
        .resp_hit       (resp_hit),
        .resp_data      (resp_data),
        .mem_block_addr (mem_block_addr),
        .mem_block_data (mem_block_data)
    );

    // Instantiate reusable deterministic block memory model
    mem_block_model u_mem (
        .mem_block_addr (mem_block_addr),
        .mem_block_data (mem_block_data)
    );

    // 100 MHz clock generation
    always #5 clk = ~clk;

    // Watchdog timeout to prevent infinite hangs (100 us)
    initial begin
        #100000;
        $display("\n[FATAL] Watchdog timeout reached! Simulation killed.");
        $finish(1);
    end

    // Assertion helper
    task check(input string msg, input logic condition);
        if (condition) begin
            $display("  [PASS] %s", msg);
            pass_count++;
        end else begin
            $display("  [FAIL] %s", msg);
            fail_count++;
        end
    endtask

    // Transaction execution and verification task
    task automatic execute_transaction(
        input [31:0] addr,
        input        exp_hit,
        input [31:0] exp_data,
        input        mutate_after_accept,
        input [31:0] mutated_addr,
        input string desc
    );
        int busy_cycles;
        logic sampled_hit;
        logic [31:0] sampled_data;

        // Wait for cache to be ready
        while (!req_ready) @(posedge clk);

        // Drive request at negative edge to guarantee setup time
        @(negedge clk);
        req_valid = 1'b1;
        req_addr  = addr;

        // Wait for acceptance on posedge clk
        @(posedge clk);
        #1; // Allow non-blocking assignments to settle

        // Post-acceptance behavior
        @(negedge clk);
        if (mutate_after_accept) begin
            req_addr = mutated_addr; // Alter address to test latching isolation
        end else begin
            req_addr = 32'hDEADBEEF; // Change address to ensure DUT ignores it
        end
        req_valid = 1'b0; // Deassert request valid

        // Monitor busy state until resp_valid asserts
        busy_cycles = 0;
        while (!resp_valid && busy_cycles < 20) begin
            check($sformatf("%s: req_ready must be low while busy (cycle %0d)", desc, busy_cycles), req_ready === 1'b0);
            @(posedge clk);
            busy_cycles++;
        end

        check($sformatf("%s: resp_valid asserted within bounds", desc), resp_valid === 1'b1);

        // Sample response signals
        sampled_hit  = resp_hit;
        sampled_data = resp_data;

        // Verify hit/miss classification and returned data
        check($sformatf("%s: hit outcome (exp=%0b, got=%0b)", desc, exp_hit, sampled_hit), sampled_hit === exp_hit);
        check($sformatf("%s: returned data (exp=0x%08h, got=0x%08h)", desc, exp_data, sampled_data), sampled_data === exp_data);

        // Verify that resp_valid is asserted for exactly ONE clock cycle
        @(posedge clk);
        #1;
        check($sformatf("%s: resp_valid deasserted exactly 1 cycle later", desc), resp_valid === 1'b0);

    endtask

    // Main verification sequence
    initial begin
        clk       = 0;
        rst       = 1;
        req_valid = 0;
        req_addr  = 32'h0;

        $display("==================================================================");
        $display("Starting Integration Verification: cache_2way & mem_block_model");
        $display("==================================================================");

        // ----------------------------------------------------------------------
        // Test 1: Reset & Protocol Invariants
        // ----------------------------------------------------------------------
        $display("\n--- Test 1: Reset & Protocol Invariants ---");
        repeat (4) @(posedge clk);
        check("req_ready deasserted during reset", req_ready === 1'b0);
        check("resp_valid deasserted during reset", resp_valid === 1'b0);

        @(negedge clk);
        rst = 0;
        @(posedge clk);
        #1;
        check("req_ready asserted in IDLE after reset", req_ready === 1'b1);
        check("resp_valid remains 0 in IDLE", resp_valid === 1'b0);

        // ----------------------------------------------------------------------
        // Test 2: Standard 5-Request Benchmark Demo Trace
        // ----------------------------------------------------------------------
        $display("\n--- Test 2: Standard 5-Request Benchmark Demo Trace ---");
        // Access 1: 0x00000000 -> Compulsory Miss in Set 0 (Way 0 allocated)
        execute_transaction(32'h00000000, 1'b0, 32'h00000000, 1'b0, 32'h0, "Demo Req 1 (0x00000000)");

        // Access 2: 0x00000080 -> Compulsory Miss in Set 0 (Way 1 allocated)
        execute_transaction(32'h00000080, 1'b0, 32'h00000080, 1'b0, 32'h0, "Demo Req 2 (0x00000080)");

        // Access 3: 0x00000000 -> HIT in Set 0 Way 0 (Updates LRU: Way 1 becomes victim!)
        execute_transaction(32'h00000000, 1'b1, 32'h00000000, 1'b0, 32'h0, "Demo Req 3 (0x00000000)");

        // Access 4: 0x00000100 -> Conflict Miss in Set 0 (Evicts Way 1 (0x80), Way 0 (0x00) preserved!)
        execute_transaction(32'h00000100, 1'b0, 32'h00000100, 1'b0, 32'h0, "Demo Req 4 (0x00000100)");

        // Access 5: 0x00000000 -> HIT in Set 0 Way 0 (Proven preserved due to LRU recency update!)
        execute_transaction(32'h00000000, 1'b1, 32'h00000000, 1'b0, 32'h0, "Demo Req 5 (0x00000000)");

        // ----------------------------------------------------------------------
        // Test 3: Nonzero Word Offsets (Words 0, 1, 2, 3) & Spatial Locality
        // ----------------------------------------------------------------------
        $display("\n--- Test 3: Nonzero Word Offsets & Spatial Locality ---");
        // Refill a new block at 0x00000040 (Set 0, Word 0)
        execute_transaction(32'h00000040, 1'b0, 32'h00000040, 1'b0, 32'h0, "Set 0 Block 0x40 Word 0 (Miss)");

        // Subsequent accesses to other words in block 0x40 must all HIT (spatial locality)
        execute_transaction(32'h00000044, 1'b1, 32'h00000044, 1'b0, 32'h0, "Set 0 Block 0x40 Word 1 (Hit)");
        execute_transaction(32'h00000048, 1'b1, 32'h00000048, 1'b0, 32'h0, "Set 0 Block 0x40 Word 2 (Hit)");
        execute_transaction(32'h0000004C, 1'b1, 32'h0000004C, 1'b0, 32'h0, "Set 0 Block 0x40 Word 3 (Hit)");

        // Cold access directly targeting nonzero word offsets in other sets
        // Set 1 (addr[5:4] == 2'b01), Word 2 (addr[3:2] == 2'b10) -> 0x00000018
        execute_transaction(32'h00000018, 1'b0, 32'h00000018, 1'b0, 32'h0, "Set 1 Word 2 Cold Miss (0x18)");
        execute_transaction(32'h00000018, 1'b1, 32'h00000018, 1'b0, 32'h0, "Set 1 Word 2 Subsequent Hit (0x18)");

        // Set 2 (addr[5:4] == 2'b10), Word 3 (addr[3:2] == 2'b11) -> 0x0000002C
        execute_transaction(32'h0000002C, 1'b0, 32'h0000002C, 1'b0, 32'h0, "Set 2 Word 3 Cold Miss (0x2C)");
        // Word 1 in same Set 2 block -> 0x00000024
        execute_transaction(32'h00000024, 1'b1, 32'h00000024, 1'b0, 32'h0, "Set 2 Word 1 Spatial Hit (0x24)");

        // Set 3 (addr[5:4] == 2'b11), Word 1 (addr[3:2] == 2'b01) -> 0x00000034
        execute_transaction(32'h00000034, 1'b0, 32'h00000034, 1'b0, 32'h0, "Set 3 Word 1 Cold Miss (0x34)");
        execute_transaction(32'h00000034, 1'b1, 32'h00000034, 1'b0, 32'h0, "Set 3 Word 1 Subsequent Hit (0x34)");

        // ----------------------------------------------------------------------
        // Test 4: Request-Address Mutation After Acceptance
        // ----------------------------------------------------------------------
        $display("\n--- Test 4: Request-Address Mutation After Acceptance ---");
        // Verify that changing req_addr immediately after acceptance does NOT affect the transaction
        execute_transaction(32'h00000204, 1'b0, 32'h00000204, 1'b1, 32'hFFFFFFFF, "Miss with req_addr changed to 0xFFFFFFFF");
        execute_transaction(32'h00000204, 1'b1, 32'h00000204, 1'b1, 32'h12345678, "Hit with req_addr changed to 0x12345678");

        // ----------------------------------------------------------------------
        // Test 5: Response Protocol & Idle Stability
        // ----------------------------------------------------------------------
        $display("\n--- Test 5: Response Protocol & Idle Stability ---");
        // Let simulation run idle for 10 clock cycles; verify zero phantom responses
        repeat (10) begin
            @(posedge clk);
            #1;
            check("No spurious resp_valid during idle cycles", resp_valid === 1'b0);
            check("req_ready remains high during idle cycles", req_ready === 1'b1);
        end

        // ----------------------------------------------------------------------
        // Test 6: Reset Clears Cache and Restores Cold Behavior
        // ----------------------------------------------------------------------
        $display("\n--- Test 6: Reset Clears Cache ---");
        @(negedge clk);
        rst = 1;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;
        @(posedge clk);
        #1;

        // Block 0x00000040 should now be cold MISS again
        execute_transaction(32'h00000040, 1'b0, 32'h00000040, 1'b0, 32'h0, "Post-reset 0x40 is cold Miss");

        // ----------------------------------------------------------------------
        // Test 7: In-Flight Reset During LOOKUP
        // ----------------------------------------------------------------------
        $display("\n--- Test 7: In-Flight Reset During LOOKUP ---");
        // Issue request to address 0x00000500
        while (!req_ready) @(posedge clk);
        @(negedge clk);
        req_valid = 1'b1;
        req_addr  = 32'h00000500;
        @(posedge clk); // Acceptance edge: DUT transitions from IDLE to LOOKUP
        #1;
        check("LOOKUP abort: req_ready drops to 0 after acceptance", req_ready === 1'b0);

        // Assert reset during LOOKUP state
        @(negedge clk);
        req_valid = 1'b0;
        rst = 1'b1;

        // Sample on next clock edge: reset takes effect
        @(posedge clk);
        #1;
        check("LOOKUP abort: req_ready remains 0 while rst is high", req_ready === 1'b0);
        check("LOOKUP abort: resp_valid remains 0 during reset", resp_valid === 1'b0);

        // Hold reset for 2 additional clock cycles to verify stability
        repeat (2) begin
            @(posedge clk);
            #1;
            check("Hold rst: req_ready remains 0", req_ready === 1'b0);
            check("Hold rst: resp_valid remains 0", resp_valid === 1'b0);
        end

        // Release reset
        @(negedge clk);
        rst = 1'b0;
        @(posedge clk);
        #1;
        check("Post-reset: req_ready returns to 1 in IDLE", req_ready === 1'b1);
        check("Post-reset: resp_valid remains 0 in IDLE", resp_valid === 1'b0);

        // Confirm normal operation resumes by executing clean transaction
        execute_transaction(32'h00000500, 1'b0, 32'h00000500, 1'b0, 32'h0, "Clean miss after LOOKUP reset (0x500)");

        // ----------------------------------------------------------------------
        // Test 8: In-Flight Reset During REFILL
        // ----------------------------------------------------------------------
        $display("\n--- Test 8: In-Flight Reset During REFILL ---");
        // Issue cold miss request to 0x00000600
        while (!req_ready) @(posedge clk);
        @(negedge clk);
        req_valid = 1'b1;
        req_addr  = 32'h00000600;
        @(posedge clk); // Edge 1: Accepted -> moves to LOOKUP
        #1;
        check("REFILL abort: req accepted into LOOKUP", req_ready === 1'b0);

        @(negedge clk);
        req_valid = 1'b0;
        @(posedge clk); // Edge 2: In LOOKUP, evaluates miss -> moves to REFILL
        #1;
        check("REFILL abort: DUT transitioned to REFILL, req_ready still 0", req_ready === 1'b0);
        check("REFILL abort: resp_valid still 0 before refill finishes", resp_valid === 1'b0);

        // Assert reset during REFILL state before Edge 3
        @(negedge clk);
        rst = 1'b1;

        @(posedge clk); // Edge 3: rst active on clock edge during REFILL
        #1;
        check("REFILL abort: req_ready deasserted during reset", req_ready === 1'b0);
        check("REFILL abort: resp_valid remains 0 (no partial response)", resp_valid === 1'b0);

        // Release reset
        @(negedge clk);
        rst = 1'b0;
        @(posedge clk);
        #1;
        check("Post-REFILL reset: req_ready asserted in IDLE", req_ready === 1'b1);
        check("Post-REFILL reset: resp_valid is 0", resp_valid === 1'b0);

        // Address 0x600 was aborted during refill; verifying that re-issuing 0x600 is a fresh cold miss
        execute_transaction(32'h00000600, 1'b0, 32'h00000600, 1'b0, 32'h0, "Fresh cold miss for 0x600 after REFILL abort");

        // ----------------------------------------------------------------------
        // Test 9: Busy Handshake — Follow-Up Request Held While Busy (Miss -> Hit)
        // ----------------------------------------------------------------------
        $display("\n--- Test 9: Busy Handshake (Follow-Up Held During Miss) ---");
        // Request 1: 0x00000700 (Cold miss)
        while (!req_ready) @(posedge clk);
        @(negedge clk);
        req_valid = 1'b1;
        req_addr  = 32'h00000700;
        @(posedge clk); // Request 1 accepted
        #1;
        check("Req 1 accepted: req_ready dropped to 0", req_ready === 1'b0);

        // While controller is busy with Req 1, master drives Request 2 and holds it
        @(negedge clk);
        req_valid = 1'b1;
        req_addr  = 32'h00000704; // Request 2: word 1 in same block

        // Cycle in LOOKUP
        @(posedge clk);
        #1;
        check("Req 2 held: req_ready remains 0 in LOOKUP", req_ready === 1'b0);
        check("Req 2 held: resp_valid is 0 in LOOKUP", resp_valid === 1'b0);

        // Cycle in REFILL
        @(posedge clk);
        #1;
        check("Req 2 held: req_ready remains 0 in REFILL", req_ready === 1'b0);
        check("Req 1 resp: resp_valid asserted for Req 1", resp_valid === 1'b1);
        check("Req 1 resp: hit outcome is miss (0)", resp_hit === 1'b0);
        check("Req 1 resp: returned data matches 0x700", resp_data === 32'h00000700);

        // In STATE_RESP: resp_valid is active for Req 1, req_ready is STILL 0
        check("Req 2 held during RESP: req_ready is 0", req_ready === 1'b0);

        // At next clock edge, Req 1 finishes, DUT enters STATE_IDLE
        @(posedge clk);
        #1;
        check("Req 1 completed: resp_valid pulse ended after 1 cycle", resp_valid === 1'b0);
        check("Handshake transition: req_ready is now 1 in IDLE", req_ready === 1'b1);

        // Edge where Req 2 is accepted (DUT in IDLE, req_valid & req_ready high)
        @(posedge clk);
        #1;
        check("Req 2 accepted: req_ready dropped to 0", req_ready === 1'b0);
        @(negedge clk);
        req_valid = 1'b0;

        // Req 2 is spatial hit, advances to STATE_RESP
        @(posedge clk);
        #1;
        check("Req 2 response: resp_valid asserted", resp_valid === 1'b1);
        check("Req 2 response: hit outcome is HIT (1)", resp_hit === 1'b1);
        check("Req 2 response: returned data matches 0x704", resp_data === 32'h00000704);

        @(posedge clk);
        #1;
        check("Req 2 completed: resp_valid deasserted", resp_valid === 1'b0);
        check("Req 2 post-completion: req_ready returns to 1", req_ready === 1'b1);

        // ----------------------------------------------------------------------
        // Test 10: Busy Handshake — Follow-Up Request Held During Hit
        // ----------------------------------------------------------------------
        $display("\n--- Test 10: Busy Handshake (Follow-Up Held During Hit) ---");
        // Request 3: 0x00000700 (Warm hit)
        while (!req_ready) @(posedge clk);
        @(negedge clk);
        req_valid = 1'b1;
        req_addr  = 32'h00000700;
        @(posedge clk); // Request 3 accepted
        #1;
        check("Req 3 accepted: req_ready dropped to 0", req_ready === 1'b0);

        // Immediately present and hold Request 4 while Req 3 processes in LOOKUP
        @(negedge clk);
        req_valid = 1'b1;
        req_addr  = 32'h00000708; // Request 4: word 2

        // Clock edge: Req 3 hit finishes LOOKUP -> moves to RESP
        @(posedge clk);
        #1;
        check("Req 3 resp: resp_valid asserted", resp_valid === 1'b1);
        check("Req 3 resp: hit outcome is HIT (1)", resp_hit === 1'b1);
        check("Req 3 resp: data is 0x700", resp_data === 32'h00000700);
        check("Req 4 held during RESP: req_ready is 0", req_ready === 1'b0);

        // Clock edge: Req 3 completes -> IDLE
        @(posedge clk);
        #1;
        check("Req 3 finished: resp_valid deasserted", resp_valid === 1'b0);
        check("Handshake transition: req_ready is 1 in IDLE", req_ready === 1'b1);

        // Edge where Req 4 is accepted
        @(posedge clk);
        #1;
        check("Req 4 accepted: req_ready dropped to 0", req_ready === 1'b0);
        @(negedge clk);
        req_valid = 1'b0;

        // Req 4 completes in LOOKUP -> RESP
        @(posedge clk);
        #1;
        check("Req 4 resp: resp_valid asserted", resp_valid === 1'b1);
        check("Req 4 resp: hit outcome is HIT (1)", resp_hit === 1'b1);
        check("Req 4 resp: data is 0x708", resp_data === 32'h00000708);

        @(posedge clk);
        #1;
        check("Req 4 finished: resp_valid deasserted", resp_valid === 1'b0);
        check("Req 4 post-completion: req_ready is 1", req_ready === 1'b1);

        // ----------------------------------------------------------------------
        // Verification Summary
        // ----------------------------------------------------------------------
        $display("\n==================================================================");
        $display("Integration Verification Complete: %0d Passed, %0d Failed", pass_count, fail_count);
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
