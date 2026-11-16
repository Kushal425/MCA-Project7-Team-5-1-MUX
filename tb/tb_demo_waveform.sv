// ==============================================================================
// Testbench: tb_demo_waveform
// Description: Generates a high-resolution, reproducible VCD waveform of the
//              5-request LRU benchmark demo trace for cache_2way.
//              Dumps all top-level handshake signals, internal FSM state,
//              memory refill signals, and cache_2way_store LRU datapath registers.
//              Outputs execution timeline to stdout for waveform inspection.
// Standard: SystemVerilog (iverilog -g2012)
// Author: Kushal
// ==============================================================================

`timescale 1ns / 1ps

module tb_demo_waveform;

    initial $timeformat(-9, 0, "", 0);

    // Clock and reset
    reg clk;
    reg rst;

    // Request interface
    reg         req_valid;
    reg  [31:0] req_addr;
    wire        req_ready;

    // Response interface
    wire        resp_valid;
    wire        resp_hit;
    wire [31:0] resp_data;

    // Memory refill interface
    wire [31:0]  mem_block_addr;
    wire [127:0] mem_block_data;

    // Instantiate 2-Way Cache DUT
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

    // Instantiate deterministic memory model
    mem_block_model u_mem (
        .mem_block_addr (mem_block_addr),
        .mem_block_data (mem_block_data)
    );

    // 100 MHz clock (10 ns period)
    always #5 clk = ~clk;

    // Transaction execution task with timeline logging
    task automatic send_request(
        input int req_num,
        input [31:0] addr,
        input string purpose
    );
        longint t_start, t_accept, t_resp;

        // Wait until ready
        while (!req_ready) @(posedge clk);

        @(negedge clk);
        t_start = $time;
        req_valid = 1'b1;
        req_addr  = addr;

        @(posedge clk);
        t_accept = $time;
        #1;

        $display("[TIMELINE @ %0t ns] Req %0d ACCEPTED: addr=0x%08h | Purpose: %s",
                 t_accept, req_num, addr, purpose);
        $display("   Internal State: Set=%0d, Tag=0x%07h | Way0_Valid=%0b Tag0=0x%07h | Way1_Valid=%0b Tag1=0x%07h | LRU_Victim_Bit=%0b",
                 dut.u_store.set_idx, dut.u_store.tag_in,
                 dut.u_store.valid_way0[0], dut.u_store.tag_way0[0],
                 dut.u_store.valid_way1[0], dut.u_store.tag_way1[0],
                 dut.u_store.lru_bit[0]);

        @(negedge clk);
        req_valid = 1'b0;
        req_addr  = 32'hDEADBEEF;

        // Monitor while in flight
        while (!resp_valid) begin
            @(posedge clk);
            #1;
            if (dut.state == 2'b10) begin // STATE_REFILL
                $display("   [REFILL @ %0t ns] fill_en=1, mem_block_addr=0x%08h, victim_way=%0b",
                         $time, dut.mem_block_addr, dut.u_store.victim_way);
            end
        end

        t_resp = $time;
        $display("[TIMELINE @ %0t ns] Req %0d RESPONSE: hit=%0b, resp_data=0x%08h",
                 t_resp, req_num, resp_hit, resp_data);
        $display("   Post-Transaction: LRU_Victim_Bit[0]=%0b (Points to next victim Way %0d)\n",
                 dut.u_store.lru_bit[0], dut.u_store.lru_bit[0]);

        @(posedge clk);
        #1;
    endtask

    initial begin
        // Setup VCD dumping
        $dumpfile("docs/evidence/cache_2way_demo.vcd");
        $dumpvars(0, tb_demo_waveform);

        clk       = 0;
        rst       = 1;
        req_valid = 0;
        req_addr  = 32'h0;

        $display("==================================================================");
        $display("Generating 5-Request Demo Waveform (docs/evidence/cache_2way_demo.vcd)");
        $display("==================================================================");

        // Power-on reset
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;
        @(posedge clk);
        #1;
        $display("[TIMELINE @ %0t ns] Reset released. Cache entered IDLE (req_ready=1).\n", $time);

        // ----------------------------------------------------------------------
        // Five-Request Benchmark Demo Trace
        // ----------------------------------------------------------------------
        // Request 1: 0x00000000
        send_request(1, 32'h00000000, "Compulsory Miss in Set 0 -> fills Way 0");

        // Request 2: 0x00000080
        send_request(2, 32'h00000080, "Compulsory Miss in Set 0 -> fills Way 1 (Way 0 becomes candidate victim)");

        // Request 3: 0x00000000
        send_request(3, 32'h00000000, "HIT on Way 0 -> touch_en updates LRU: Way 1 becomes victim!");

        // Request 4: 0x00000100
        send_request(4, 32'h00000100, "DECISIVE EVICTION: Conflict Miss -> evicts Way 1 (0x80), preserves Way 0 (0x00)");

        // Request 5: 0x00000000
        send_request(5, 32'h00000000, "HIT on Way 0 -> Proves Way 0 was protected by LRU!");

        repeat (5) @(posedge clk);

        $display("==================================================================");
        $display("Waveform generation complete. Saved to docs/evidence/cache_2way_demo.vcd");
        $display("==================================================================");
        $finish(0);
    end

endmodule
