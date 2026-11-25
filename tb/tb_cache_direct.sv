// ==============================================================================
// Testbench: tb_cache_direct
// Description: Self-checking integration testbench for cache_direct.
//              Verifies reset protocol, valid bits, tag comparison, aligned
//              refill, word selection, and the standard 5-request conflict trace.
//              Signals are driven on negedge to guarantee setup time vs posedge
//              sampling; responses are captured by polling resp_valid on posedge.
// Author: Prachee
// Simulator: Icarus Verilog with -g2012
// ==============================================================================

`timescale 1ns / 1ps

module tb_cache_direct;

    // -------------------------------------------------------------------------
    // DUT I/O
    // -------------------------------------------------------------------------
    reg          clk;
    reg          rst;
    reg          req_valid;
    reg  [31:0]  req_addr;
    wire         req_ready;
    wire         resp_valid;
    wire         resp_hit;
    wire [31:0]  resp_data;
    wire [31:0]  mem_block_addr;
    wire [127:0] mem_block_data;

    // -------------------------------------------------------------------------
    // Instantiate DUT
    // -------------------------------------------------------------------------
    cache_direct dut (
        .clk           (clk),
        .rst           (rst),
        .req_valid     (req_valid),
        .req_addr      (req_addr),
        .req_ready     (req_ready),
        .resp_valid    (resp_valid),
        .resp_hit      (resp_hit),
        .resp_data     (resp_data),
        .mem_block_addr(mem_block_addr),
        .mem_block_data(mem_block_data)
    );

    // -------------------------------------------------------------------------
    // Deterministic block memory model (word data = word byte address)
    // -------------------------------------------------------------------------
    mem_block_model u_mem (
        .mem_block_addr(mem_block_addr),
        .mem_block_data(mem_block_data)
    );

    // -------------------------------------------------------------------------
    // Clock Generation: 10 ns period; start low
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Watchdog: kills simulation after 200 us if still running
    // -------------------------------------------------------------------------
    initial begin
        #200000;
        $fatal(1, "[FATAL] Watchdog timeout -- simulation killed.");
    end

    // -------------------------------------------------------------------------
    // Global test counters
    // -------------------------------------------------------------------------
    integer pass_count;
    integer fail_count;

    // -------------------------------------------------------------------------
    // Helper: assertion with label
    // -------------------------------------------------------------------------
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

    // -------------------------------------------------------------------------
    // Helper: send one request and wait for resp_valid.
    //   Drives req_valid/req_addr on negedge, captures on resp_valid posedge.
    //   Saves result to got_hit / got_data.
    // -------------------------------------------------------------------------
    reg        got_hit;
    reg [31:0] got_data;

    task send_req;
        input [31:0] addr;
        integer tout;
        begin
            // Wait until cache is idle (req_ready high), sample on posedge
            tout = 0;
            while (!req_ready) begin
                @(posedge clk);
                #1;
                tout = tout + 1;
                if (tout > 100) begin
                    $fatal(1, "[TIMEOUT] req_ready never high for addr=0x%08h", addr);
                end
            end
            // Drive on negedge to satisfy setup time
            @(negedge clk);
            req_valid = 1'b1;
            req_addr  = addr;
            // Let posedge latch the request
            @(posedge clk);
            #1;
            // Deassert after acceptance (simulate bus mutation)
            @(negedge clk);
            req_valid = 1'b0;
            req_addr  = 32'hXXXXXXXX;
            // Wait for resp_valid to pulse high
            tout = 0;
            @(posedge clk);
            #1;
            while (!resp_valid) begin
                tout = tout + 1;
                if (tout > 100) begin
                    $fatal(1, "[TIMEOUT] resp_valid never arrived for addr=0x%08h", addr);
                end
                @(posedge clk);
                #1;
            end
            got_hit  = resp_hit;
            got_data = resp_data;
        end
    endtask

    // -------------------------------------------------------------------------
    // Helper: synchronous reset DUT
    // -------------------------------------------------------------------------
    task do_reset;
        begin
            @(negedge clk);
            rst       = 1'b1;
            req_valid = 1'b0;
            req_addr  = 32'h00000000;
            @(posedge clk); #1;
            @(posedge clk); #1;
            @(negedge clk);
            rst = 1'b0;
            @(posedge clk); #1;
        end
    endtask

    // =========================================================================
    // TEST EXECUTION
    // =========================================================================
    initial begin
        pass_count = 0;
        fail_count = 0;
        rst       = 1'b1;
        req_valid = 1'b0;
        req_addr  = 32'h00000000;

        $display("==================================================================");
        $display("Starting Integration Verification: cache_direct");
        $display("==================================================================");

        // =====================================================================
        // Test 1: Reset & Protocol Invariants
        // =====================================================================
        $display("\n--- Test 1: Reset & Protocol Invariants ---");
        @(negedge clk);
        rst = 1'b1;
        @(posedge clk); #1;
        check("req_ready deasserted during reset", req_ready === 1'b0);
        check("resp_valid deasserted during reset", resp_valid === 1'b0);
        @(posedge clk); #1;
        @(negedge clk); rst = 1'b0;
        @(posedge clk); #1;
        check("req_ready asserted in IDLE after reset", req_ready === 1'b1);
        check("resp_valid remains 0 in IDLE",           resp_valid === 1'b0);

        // =====================================================================
        // Test 2: Standard 5-Request Conflict Trace (from cold cache)
        // 0x000: set[6:4]=0 tag[31:7]=0  Miss -> fills Set 0
        // 0x080: set[6:4]=0 tag[31:7]=1  Miss -> evicts Set 0 (tag 0 -> tag 1)
        // 0x000: set[6:4]=0 tag[31:7]=0  Miss -> evicts Set 0 (tag 1 -> tag 0)
        // 0x100: set[6:4]=0 tag[31:7]=2  Miss -> evicts Set 0 (tag 0 -> tag 2)
        // 0x000: set[6:4]=0 tag[31:7]=0  Miss -> evicts Set 0 (tag 2 -> tag 0)
        // Expected: 0 hits / 5 accesses = 0% hit rate
        // =====================================================================
        $display("\n--- Test 2: Standard 5-Request Conflict Trace ---");
        do_reset;

        send_req(32'h00000000);
        check("Conflict Req 1 (0x00000000): hit outcome (exp=0)",
              got_hit === 1'b0);
        check("Conflict Req 1 (0x00000000): returned data (exp=0x00000000)",
              got_data === 32'h00000000);

        send_req(32'h00000080);
        check("Conflict Req 2 (0x00000080): hit outcome (exp=0)",
              got_hit === 1'b0);
        check("Conflict Req 2 (0x00000080): returned data (exp=0x00000080)",
              got_data === 32'h00000080);

        send_req(32'h00000000);
        check("Conflict Req 3 (0x00000000): hit outcome (exp=0 conflict miss)",
              got_hit === 1'b0);
        check("Conflict Req 3 (0x00000000): returned data (exp=0x00000000)",
              got_data === 32'h00000000);

        send_req(32'h00000100);
        check("Conflict Req 4 (0x00000100): hit outcome (exp=0)",
              got_hit === 1'b0);
        check("Conflict Req 4 (0x00000100): returned data (exp=0x00000100)",
              got_data === 32'h00000100);

        send_req(32'h00000000);
        check("Conflict Req 5 (0x00000000): hit outcome (exp=0 conflict miss)",
              got_hit === 1'b0);
        check("Conflict Req 5 (0x00000000): returned data (exp=0x00000000)",
              got_data === 32'h00000000);

        // =====================================================================
        // Test 3: Word Selection across All 4 Offsets & Spatial Locality
        // =====================================================================
        $display("\n--- Test 3: Word Selection across All 4 Offsets & Spatial Locality ---");
        do_reset;

        // Cold miss at 0x00000010 -> loads block covering [0x10..0x1F]
        // set[6:4] of 0x10 = 1, tag = 0
        send_req(32'h00000010);
        check("Set 1 Word 0 Cold Miss (0x10)",        got_hit === 1'b0);
        check("Set 1 Word 0 data (exp=0x00000010)",   got_data === 32'h00000010);

        send_req(32'h00000014);
        check("Set 1 Word 1 Spatial Hit (0x14)",       got_hit === 1'b1);
        check("Set 1 Word 1 data (exp=0x00000014)",    got_data === 32'h00000014);

        send_req(32'h00000018);
        check("Set 1 Word 2 Spatial Hit (0x18)",       got_hit === 1'b1);
        check("Set 1 Word 2 data (exp=0x00000018)",    got_data === 32'h00000018);

        send_req(32'h0000001C);
        check("Set 1 Word 3 Spatial Hit (0x1C)",       got_hit === 1'b1);
        check("Set 1 Word 3 data (exp=0x0000001C)",    got_data === 32'h0000001C);

        // Different set: 0x20 -> set[6:4] = 2
        send_req(32'h00000020);
        check("Set 2 Word 0 Cold Miss (0x20)",         got_hit === 1'b0);
        check("Set 2 Word 0 data (exp=0x00000020)",    got_data === 32'h00000020);

        // Spatial hit: 0x28 -> same block as 0x20
        send_req(32'h00000028);
        check("Set 2 Word 2 Spatial Hit (0x28)",       got_hit === 1'b1);
        check("Set 2 Word 2 data (exp=0x00000028)",    got_data === 32'h00000028);

        // =====================================================================
        // Test 4: Request-Address Mutation After Acceptance
        // =====================================================================
        $display("\n--- Test 4: Request-Address Mutation After Acceptance ---");
        do_reset;

        // Cold miss at 0x00000200 (set[6:4] = 0, tag = addr[31:7] = 1)
        // After cold miss, 0x200 is in cache.
        begin : blk_t4a
            integer tout_t4a;
            tout_t4a = 0;
            @(posedge clk); #1;
            while (!req_ready) begin
                @(posedge clk); #1;
                tout_t4a = tout_t4a + 1;
                if (tout_t4a > 100) begin
                    fail_count = fail_count + 1;
                    disable blk_t4a;
                end
            end
            @(negedge clk);
            req_valid = 1'b1;
            req_addr  = 32'h00000200;
            @(posedge clk); #1;
            @(negedge clk);
            req_valid = 1'b0;
            req_addr  = 32'hFFFFFFFF; // mutate after acceptance
            @(posedge clk); #1;
            tout_t4a = 0;
            while (!resp_valid) begin
                @(posedge clk); #1;
                tout_t4a = tout_t4a + 1;
                if (tout_t4a > 100) begin
                    fail_count = fail_count + 1;
                    disable blk_t4a;
                end
            end
            check("Cold miss with req_addr mutated (returned 0x00000200)",
                  resp_data === 32'h00000200 && resp_hit === 1'b0);
        end

        // Hit at same address (now cached)
        begin : blk_t4b
            integer tout_t4b;
            tout_t4b = 0;
            @(posedge clk); #1;
            while (!req_ready) begin
                @(posedge clk); #1;
                tout_t4b = tout_t4b + 1;
                if (tout_t4b > 100) begin
                    fail_count = fail_count + 1;
                    disable blk_t4b;
                end
            end
            @(negedge clk);
            req_valid = 1'b1;
            req_addr  = 32'h00000200;
            @(posedge clk); #1;
            @(negedge clk);
            req_valid = 1'b0;
            req_addr  = 32'h12345678; // mutate after acceptance
            @(posedge clk); #1;
            tout_t4b = 0;
            while (!resp_valid) begin
                @(posedge clk); #1;
                tout_t4b = tout_t4b + 1;
                if (tout_t4b > 100) begin
                    fail_count = fail_count + 1;
                    disable blk_t4b;
                end
            end
            check("Hit with req_addr mutated to 0x12345678 (returned 0x00000200)",
                  resp_data === 32'h00000200 && resp_hit === 1'b1);
        end

        // =====================================================================
        // Test 5: Response Protocol & Idle Stability
        // =====================================================================
        $display("\n--- Test 5: Response Protocol & Idle Stability ---");
        do_reset;
        send_req(32'h00000040);
        // After response, observe 10 idle cycles
        begin : blk_t5
            integer ic;
            integer spurious;
            spurious = 0;
            for (ic = 0; ic < 10; ic = ic + 1) begin
                @(posedge clk); #1;
                if (resp_valid !== 1'b0) spurious = spurious + 1;
            end
            check("10 idle cycles: 0 spurious responses, req_ready high",
                  spurious === 0 && req_ready === 1'b1);
        end

        // =====================================================================
        // Test 6: Reset Clears Cache
        // =====================================================================
        $display("\n--- Test 6: Reset Clears Cache ---");
        do_reset;
        send_req(32'h00000040); // cold miss -- loads block
        do_reset;               // reset again -- clears cache
        send_req(32'h00000040); // must be cold miss again
        check("Post-reset 0x40 is cold Miss", got_hit === 1'b0);

        // =====================================================================
        // Summary
        // =====================================================================
        $display("\n==================================================================");
        $display("Integration Verification Complete: %0d Passed, %0d Failed",
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
