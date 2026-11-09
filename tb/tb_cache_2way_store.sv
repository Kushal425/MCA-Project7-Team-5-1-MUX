// ==============================================================================
// Testbench: tb_cache_2way_store
// Description: Race-free, self-checking SystemVerilog unit verification for
//              cache_2way_store (internal storage and LRU tracking).
// Author: Krishna (Phase I, Handoff 1)
// Standard: SystemVerilog (compiled with iverilog -g2012)
// ==============================================================================

`timescale 1ns / 1ps

module tb_cache_2way_store;

    // --------------------------------------------------------------------------
    // Test Signals
    // --------------------------------------------------------------------------
    reg         clk;
    reg         rst;
    reg  [31:0] addr;
    reg         touch_en;
    reg         fill_en;
    reg  [127:0] fill_block;

    wire        hit;
    wire        hit_way;
    wire        victim_way;
    wire [31:0] read_word;

    // --------------------------------------------------------------------------
    // DUT Instantiation
    // --------------------------------------------------------------------------
    cache_2way_store u_store (
        .clk(clk),
        .rst(rst),
        .addr(addr),
        .touch_en(touch_en),
        .fill_en(fill_en),
        .fill_block(fill_block),
        .hit(hit),
        .hit_way(hit_way),
        .victim_way(victim_way),
        .read_word(read_word)
    );

    // --------------------------------------------------------------------------
    // Clock Generation (100 MHz, 10ns period)
    // --------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // --------------------------------------------------------------------------
    // Verification Tracking & Assertion Utilities
    // --------------------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    task check(input string test_name, input bit condition, input string err_details);
        begin
            if (condition) begin
                pass_count = pass_count + 1;
                $display("  [PASS] %s", test_name);
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] %s - %s", test_name, err_details);
            end
        end
    endtask

    // Helper function to build 32-bit address from fields:
    // tag (26 bits), set_idx (2 bits), word_sel (2 bits), byte_off (2 bits)
    function [31:0] make_addr(input [25:0] tag, input [1:0] set_idx, input [1:0] word_sel);
        make_addr = {tag, set_idx, word_sel, 2'b00};
    endfunction

    // Helper function to build 128-bit block from 4 words
    function [127:0] make_block(input [31:0] w0, input [31:0] w1, input [31:0] w2, input [31:0] w3);
        make_block = {w3, w2, w1, w0};
    endfunction

    // --------------------------------------------------------------------------
    // Main Test Stimulus
    // --------------------------------------------------------------------------
    integer s;
    reg [127:0] block_a, block_b, block_c, block_d, block_e;

    initial begin
        $display("==================================================================");
        $display("Starting Unit Verification: cache_2way_store");
        $display("==================================================================");

        // Initialize inputs
        rst        = 1'b1;
        addr       = 32'h00000000;
        touch_en   = 1'b0;
        fill_en    = 1'b0;
        fill_block = 128'd0;

        block_a = make_block(32'hA0000000, 32'hA0000001, 32'hA0000002, 32'hA0000003);
        block_b = make_block(32'hB0000000, 32'hB0000001, 32'hB0000002, 32'hB0000003);
        block_c = make_block(32'hC0000000, 32'hC0000001, 32'hC0000002, 32'hC0000003);
        block_d = make_block(32'hD0000000, 32'hD0000001, 32'hD0000002, 32'hD0000003);
        block_e = make_block(32'hE0000000, 32'hE0000001, 32'hE0000002, 32'hE0000003);

        // Reset sequence (2 clock cycles with synchronous deassertion on negedge)
        @(negedge clk);
        rst = 1'b1;
        @(negedge clk);
        rst = 1'b0;
        @(negedge clk);

        // ----------------------------------------------------------------------
        // Test 1: Cold Initial State & Miss Defaults across All Sets
        // ----------------------------------------------------------------------
        $display("\n--- Test 1: Cold Initial State & Miss Defaults ---");
        for (s = 0; s < 4; s = s + 1) begin
            addr = make_addr(26'h1A2B3C, s[1:0], 2'b00);
            #1; // Allow combinational propagation
            check($sformatf("Set %0d cold hit==0", s), (hit == 1'b0),
                  $sformatf("Expected hit=0, got %b", hit));
            check($sformatf("Set %0d default hit_way==0", s), (hit_way == 1'b0),
                  $sformatf("Expected hit_way=0, got %b", hit_way));
            check($sformatf("Set %0d default read_word==0", s), (read_word == 32'h00000000),
                  $sformatf("Expected read_word=0, got 0x%08x", read_word));
            check($sformatf("Set %0d empty victim_way==0 (empty Way 0 priority)", s), (victim_way == 1'b0),
                  $sformatf("Expected victim_way=0, got %b", victim_way));
        end

        // ----------------------------------------------------------------------
        // Test 2: Lookup Invariance (No State Mutation)
        // ----------------------------------------------------------------------
        $display("\n--- Test 2: Lookup Invariance (No State Mutation) ---");
        @(negedge clk);
        addr = make_addr(26'h000001, 2'b00, 2'b00);
        repeat (3) @(negedge clk);
        #1;
        check("Lookup alone does not assert hit", (hit == 1'b0), "hit asserted unexpectedly");
        check("Lookup alone preserves victim_way=0", (victim_way == 1'b0), "victim_way altered");

        // ----------------------------------------------------------------------
        // Test 3: Deterministic Empty-Way Priority
        // ----------------------------------------------------------------------
        $display("\n--- Test 3: Deterministic Empty-Way Priority ---");
        // Set 0 is completely empty. Verify victim_way is Way 0.
        @(negedge clk);
        addr = make_addr(26'h00000A, 2'b00, 2'b00);
        #1;
        check("Empty set chooses Way 0 as victim", (victim_way == 1'b0),
              $sformatf("Expected victim_way=0, got %b", victim_way));

        // Refill Way 0 with Block A
        @(negedge clk);
        fill_block = block_a;
        fill_en    = 1'b1;
        @(negedge clk);
        fill_en    = 1'b0;
        #1;

        // Now Way 0 is valid, Way 1 is empty.
        // Empty Way 1 MUST be chosen as victim.
        check("Set 0 after Way 0 fill chooses empty Way 1 as victim", (victim_way == 1'b1),
              $sformatf("Expected victim_way=1, got %b", victim_way));

        // Lookup Block A on Way 0: should HIT on Way 0
        check("Block A hits on Way 0", (hit == 1'b1 && hit_way == 1'b0),
              $sformatf("Expected hit=1, hit_way=0; got hit=%b, hit_way=%b", hit, hit_way));

        // Lookup an unallocated tag (Block B tag) on Set 0: should MISS, victim_way remains 1
        addr = make_addr(26'h00000B, 2'b00, 2'b00);
        #1;
        check("Unallocated Block B misses", (hit == 1'b0), "Expected hit=0");
        check("Victim remains empty Way 1 during miss", (victim_way == 1'b1),
              $sformatf("Expected victim_way=1, got %b", victim_way));

        // Refill Way 1 with Block B
        @(negedge clk);
        fill_block = block_b;
        fill_en    = 1'b1;
        @(negedge clk);
        fill_en    = 1'b0;
        #1;

        // Now both ways are valid!
        // Because Way 1 was filled last, Way 1 is MRU, and Way 0 is LRU (lru_bit=0).
        // For a new miss, victim_way must now be Way 0!
        addr = make_addr(26'h0000FF, 2'b00, 2'b00); // Unallocated tag
        #1;
        check("Both ways full: miss selects LRU Way 0 as victim", (victim_way == 1'b0),
              $sformatf("Expected victim_way=0, got %b", victim_way));

        // ----------------------------------------------------------------------
        // Test 4: Word Selection Multiplexing across Both Ways (All 4 offsets)
        // ----------------------------------------------------------------------
        $display("\n--- Test 4: Word Selection Multiplexing across All 4 Offsets ---");
        // Way 0 holds Block A: W0=0xA0000000, W1=0xA0000001, W2=0xA0000002, W3=0xA0000003
        addr = make_addr(26'h00000A, 2'b00, 2'b00); #1;
        check("Way 0 Word 0 select", (hit && hit_way == 1'b0 && read_word == 32'hA0000000),
              $sformatf("Got 0x%08x", read_word));

        addr = make_addr(26'h00000A, 2'b00, 2'b01); #1;
        check("Way 0 Word 1 select", (hit && hit_way == 1'b0 && read_word == 32'hA0000001),
              $sformatf("Got 0x%08x", read_word));

        addr = make_addr(26'h00000A, 2'b00, 2'b10); #1;
        check("Way 0 Word 2 select", (hit && hit_way == 1'b0 && read_word == 32'hA0000002),
              $sformatf("Got 0x%08x", read_word));

        addr = make_addr(26'h00000A, 2'b00, 2'b11); #1;
        check("Way 0 Word 3 select", (hit && hit_way == 1'b0 && read_word == 32'hA0000003),
              $sformatf("Got 0x%08x", read_word));

        // Way 1 holds Block B: W0=0xB0000000, W1=0xB0000001, W2=0xB0000002, W3=0xB0000003
        addr = make_addr(26'h00000B, 2'b00, 2'b00); #1;
        check("Way 1 Word 0 select", (hit && hit_way == 1'b1 && read_word == 32'hB0000000),
              $sformatf("Got 0x%08x", read_word));

        addr = make_addr(26'h00000B, 2'b00, 2'b01); #1;
        check("Way 1 Word 1 select", (hit && hit_way == 1'b1 && read_word == 32'hB0000001),
              $sformatf("Got 0x%08x", read_word));

        addr = make_addr(26'h00000B, 2'b00, 2'b10); #1;
        check("Way 1 Word 2 select", (hit && hit_way == 1'b1 && read_word == 32'hB0000002),
              $sformatf("Got 0x%08x", read_word));

        addr = make_addr(26'h00000B, 2'b00, 2'b11); #1;
        check("Way 1 Word 3 select", (hit && hit_way == 1'b1 && read_word == 32'hB0000003),
              $sformatf("Got 0x%08x", read_word));

        // ----------------------------------------------------------------------
        // Test 5: Hit Changing the Next Victim (Recency Update via touch_en)
        // ----------------------------------------------------------------------
        $display("\n--- Test 5: Hit Changing Next Victim via touch_en ---");
        // Current state: Way 0 is LRU victim (victim_way == 0 for misses).
        addr = make_addr(26'h0000FF, 2'b00, 2'b00); #1;
        check("Pre-touch: victim_way is Way 0", (victim_way == 1'b0),
              $sformatf("Expected victim_way=0, got %b", victim_way));

        // Access Block A (in Way 0) and assert touch_en
        @(negedge clk);
        addr     = make_addr(26'h00000A, 2'b00, 2'b00);
        touch_en = 1'b1;
        #1;
        check("Target address hits in Way 0 during touch", (hit == 1'b1 && hit_way == 1'b0),
              "Expected hit in Way 0");

        @(negedge clk);
        touch_en = 1'b0;
        #1;

        // Way 0 was touched -> Way 0 is now MRU, Way 1 becomes LRU!
        // Check victim_way for a miss address:
        addr = make_addr(26'h0000FF, 2'b00, 2'b00); #1;
        check("Post-touch Way 0: victim_way flipped to Way 1", (victim_way == 1'b1),
              $sformatf("Expected victim_way=1, got %b", victim_way));

        // Now touch Way 1 (Block B) and verify victim_way flips back to Way 0
        @(negedge clk);
        addr     = make_addr(26'h00000B, 2'b00, 2'b00);
        touch_en = 1'b1;
        @(negedge clk);
        touch_en = 1'b0;
        #1;

        addr = make_addr(26'h0000FF, 2'b00, 2'b00); #1;
        check("Post-touch Way 1: victim_way flipped back to Way 0", (victim_way == 1'b0),
              $sformatf("Expected victim_way=0, got %b", victim_way));

        // ----------------------------------------------------------------------
        // Test 6: Eviction of the Least-Recently-Used Block
        // ----------------------------------------------------------------------
        $display("\n--- Test 6: LRU Eviction of Victim Way ---");
        // Touch Way 0 so that Way 1 is designated as victim
        @(negedge clk);
        addr     = make_addr(26'h00000A, 2'b00, 2'b00);
        touch_en = 1'b1;
        @(negedge clk);
        touch_en = 1'b0;
        #1;

        // Target new block (Block C, tag 26'h00000C) at Set 0.
        // Since Way 1 is LRU victim, Block C will overwrite Way 1 (evicting Block B).
        @(negedge clk);
        addr       = make_addr(26'h00000C, 2'b00, 2'b00);
        fill_block = block_c;
        fill_en    = 1'b1;
        #1;
        check("Victim before fill cycle is Way 1", (victim_way == 1'b1),
              $sformatf("Expected victim_way=1, got %b", victim_way));

        @(negedge clk);
        fill_en    = 1'b0;
        #1;

        // Verify: Block A (Way 0) is preserved
        addr = make_addr(26'h00000A, 2'b00, 2'b00); #1;
        check("Block A in Way 0 survived eviction", (hit == 1'b1 && hit_way == 1'b0 && read_word == 32'hA0000000),
              "Block A missing or corrupted");

        // Verify: Block B was evicted
        addr = make_addr(26'h00000B, 2'b00, 2'b00); #1;
        check("Block B was evicted from Way 1", (hit == 1'b0 && read_word == 32'h00000000),
              "Block B still hitting after eviction");

        // Verify: Block C is now present in Way 1
        addr = make_addr(26'h00000C, 2'b00, 2'b00); #1;
        check("Block C is present in Way 1", (hit == 1'b1 && hit_way == 1'b1 && read_word == 32'hC0000000),
              "Block C not found in Way 1");

        // ----------------------------------------------------------------------
        // Test 7: Independence Between Sets
        // ----------------------------------------------------------------------
        $display("\n--- Test 7: Independence Between Sets ---");
        // Verify Sets 1, 2, and 3 are still completely cold
        for (s = 1; s < 4; s = s + 1) begin
            addr = make_addr(26'h1A2B3C, s[1:0], 2'b00); #1;
            check($sformatf("Set %0d remains uncorrupted cold miss", s), (hit == 1'b0 && victim_way == 1'b0),
                  $sformatf("Set %0d hit=%b victim_way=%b", s, hit, victim_way));
        end

        // Populate Set 2 with Block D (Way 0) and Block E (Way 1)
        @(negedge clk);
        addr       = make_addr(26'h00000D, 2'b10, 2'b00); // Set 2
        fill_block = block_d;
        fill_en    = 1'b1;
        @(negedge clk);

        addr       = make_addr(26'h00000E, 2'b10, 2'b00); // Set 2
        fill_block = block_e;
        fill_en    = 1'b1;
        @(negedge clk);
        fill_en    = 1'b0;
        #1;

        // In Set 2, Way 1 was filled last, so Set 2's LRU victim is Way 0.
        addr = make_addr(26'h0000FF, 2'b10, 2'b00); #1;
        check("Set 2 victim is Way 0", (victim_way == 1'b0),
              $sformatf("Expected Set 2 victim_way=0, got %b", victim_way));

        // Touch Way 0 in Set 2: Set 2 victim should become Way 1
        @(negedge clk);
        addr     = make_addr(26'h00000D, 2'b10, 2'b00);
        touch_en = 1'b1;
        @(negedge clk);
        touch_en = 1'b0;
        #1;

        addr = make_addr(26'h0000FF, 2'b10, 2'b00); #1;
        check("Set 2 victim updated to Way 1 after touch", (victim_way == 1'b1),
              $sformatf("Expected Set 2 victim_way=1, got %b", victim_way));

        // Verify Set 0 state was completely untouched by Set 2 operations:
        // Set 0 should still hold Block A in Way 0 and Block C in Way 1
        addr = make_addr(26'h00000A, 2'b00, 2'b00); #1;
        check("Set 0 Block A unaffected by Set 2 operations", (hit == 1'b1 && hit_way == 1'b0),
              "Set 0 Block A corrupted");
        addr = make_addr(26'h00000C, 2'b00, 2'b00); #1;
        check("Set 0 Block C unaffected by Set 2 operations", (hit == 1'b1 && hit_way == 1'b1),
              "Set 0 Block C corrupted");

        // Verify Set 1 and Set 3 remain cold
        addr = make_addr(26'h1A2B3C, 2'b01, 2'b00); #1;
        check("Set 1 still cold", (hit == 1'b0 && victim_way == 1'b0), "Set 1 corrupted");
        addr = make_addr(26'h1A2B3C, 2'b11, 2'b00); #1;
        check("Set 3 still cold", (hit == 1'b0 && victim_way == 1'b0), "Set 3 corrupted");

        // ----------------------------------------------------------------------
        // Test 8: Synchronous Reset Clears All Sets
        // ----------------------------------------------------------------------
        $display("\n--- Test 8: Synchronous Reset Clears All Sets ---");
        @(negedge clk);
        rst = 1'b1;
        @(negedge clk);
        rst = 1'b0;
        #1;

        // Check Set 0 (previously had Block A and C)
        addr = make_addr(26'h00000A, 2'b00, 2'b00); #1;
        check("Reset cleared Set 0 Block A", (hit == 1'b0 && victim_way == 1'b0), "Set 0 still hits");

        // Check Set 2 (previously had Block D and E)
        addr = make_addr(26'h00000D, 2'b10, 2'b00); #1;
        check("Reset cleared Set 2 Block D", (hit == 1'b0 && victim_way == 1'b0), "Set 2 still hits");

        // ----------------------------------------------------------------------
        // Verification Summary & Final Status
        // ----------------------------------------------------------------------
        $display("\n==================================================================");
        $display("Verification Complete: %0d Passed, %0d Failed", pass_count, fail_count);
        $display("==================================================================");

        if (fail_count > 0) begin
            $display("TEST RESULT: FAILED with %0d errors", fail_count);
            $fatal(1, "Unit tests failed.");
        end else begin
            $display("TEST RESULT: ALL %0d CHECKS PASSED SUCCESSFULLY", pass_count);
            $finish(0);
        end
    end

endmodule
