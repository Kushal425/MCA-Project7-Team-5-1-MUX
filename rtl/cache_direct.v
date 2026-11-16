// ==============================================================================
// Module: cache_direct
// Description: Direct-Mapped Cache Baseline with identical external interface
//              to cache_2way. Used for comparative hit-rate evaluation.
// Capacity: 128 bytes (8 sets x 1 way x 16 bytes/block).
// Address Decomposition (32-bit byte address):
//   addr[1:0]  : Byte offset within word (aligned: addr[1:0] == 2'b00)
//   addr[3:2]  : Word select within 16-byte block (4 words)
//   addr[6:4]  : Set index (8 sets -> 3 index bits)
//   addr[31:7] : Tag (25 bits)
// Author: Prachee
// Standard: Synthesizable Verilog-2001
// ==============================================================================

`timescale 1ns / 1ps

module cache_direct (
    input  wire         clk,            // System clock (rising-edge active)
    input  wire         rst,            // Synchronous active-high reset
    input  wire         req_valid,      // Master request valid
    input  wire [31:0]  req_addr,       // Master requested byte address
    output wire         req_ready,      // Cache ready to accept request
    output reg          resp_valid,     // Cache response valid (1-cycle pulse)
    output reg          resp_hit,       // 1 = Hit, 0 = Miss
    output reg  [31:0]  resp_data,      // Requested 32-bit word data
    output wire [31:0]  mem_block_addr, // 16-byte aligned lower memory refill address
    input  wire [127:0] mem_block_data  // 128-bit block data from lower memory
);

    // --------------------------------------------------------------------------
    // Controller FSM State Encoding
    // 3-state FSM: IDLE -> LOOKUP -> REFILL (miss) or RESP (hit)
    // --------------------------------------------------------------------------
    localparam [1:0] STATE_IDLE   = 2'b00;
    localparam [1:0] STATE_LOOKUP = 2'b01;
    localparam [1:0] STATE_REFILL = 2'b10;
    localparam [1:0] STATE_RESP   = 2'b11;

    reg [1:0]  state;
    reg [31:0] saved_addr;

    // --------------------------------------------------------------------------
    // Handshake & Memory Address Logic
    // --------------------------------------------------------------------------
    // req_ready is asserted only in IDLE and when not in reset.
    assign req_ready = (state == STATE_IDLE) && (!rst);

    // mem_block_addr is the 16-byte aligned block base address of saved_addr.
    assign mem_block_addr = {saved_addr[31:4], 4'b0000};

    // --------------------------------------------------------------------------
    // Cache Storage: 8 sets x 1 way x 16 bytes = 128 bytes
    // --------------------------------------------------------------------------
    // Address bit decomposition for cache_direct:
    //   set_idx  = saved_addr[6:4]  (3 bits -> 8 sets)
    //   word_sel = saved_addr[3:2]  (2 bits -> 4 words)
    //   tag_in   = saved_addr[31:7] (25 bits)

    reg [7:0]   valid;           // 1 valid bit per set
    reg [24:0]  tag   [0:7];     // 25-bit tag per set
    reg [127:0] data  [0:7];     // 128-bit block per set

    wire [2:0]  set_idx  = saved_addr[6:4];
    wire [1:0]  word_sel = saved_addr[3:2];
    wire [24:0] tag_in   = saved_addr[31:7];

    // --------------------------------------------------------------------------
    // Combinational Tag Comparison & Hit Detection
    // --------------------------------------------------------------------------
    wire tag_match = valid[set_idx] && (tag[set_idx] == tag_in);

    // --------------------------------------------------------------------------
    // Word Selection Multiplexer (hit path -- reads cached block)
    // --------------------------------------------------------------------------
    reg [31:0] cached_word;
    always @(*) begin
        case (word_sel)
            2'b00:   cached_word = data[set_idx][31:0];
            2'b01:   cached_word = data[set_idx][63:32];
            2'b10:   cached_word = data[set_idx][95:64];
            2'b11:   cached_word = data[set_idx][127:96];
            default: cached_word = 32'h00000000;
        endcase
    end

    // --------------------------------------------------------------------------
    // Word Selection Multiplexer (miss/refill path -- reads incoming block)
    // --------------------------------------------------------------------------
    reg [31:0] refill_word;
    always @(*) begin
        case (word_sel)
            2'b00:   refill_word = mem_block_data[31:0];
            2'b01:   refill_word = mem_block_data[63:32];
            2'b10:   refill_word = mem_block_data[95:64];
            2'b11:   refill_word = mem_block_data[127:96];
            default: refill_word = 32'h00000000;
        endcase
    end

    // --------------------------------------------------------------------------
    // Controller FSM & Response Generation
    // --------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state      <= STATE_IDLE;
            saved_addr <= 32'h00000000;
            resp_valid <= 1'b0;
            resp_hit   <= 1'b0;
            resp_data  <= 32'h00000000;
            valid      <= 8'b00000000;
        end else begin
            case (state)
                // ----------------------------------------------------------------
                // IDLE: Accept new request when req_valid && req_ready.
                //       Clear resp_valid between transactions.
                // ----------------------------------------------------------------
                STATE_IDLE: begin
                    resp_valid <= 1'b0;
                    if (req_valid && req_ready) begin
                        saved_addr <= req_addr;
                        state      <= STATE_LOOKUP;
                    end
                end

                // ----------------------------------------------------------------
                // LOOKUP: Combinational tag comparison result is available.
                //         Hit  -> deliver hit response, go to RESP.
                //         Miss -> fetch from lower memory, go to REFILL.
                // ----------------------------------------------------------------
                STATE_LOOKUP: begin
                    if (tag_match) begin
                        // Cache Hit: return cached word.
                        resp_valid <= 1'b1;
                        resp_hit   <= 1'b1;
                        resp_data  <= cached_word;
                        state      <= STATE_RESP;
                    end else begin
                        // Cache Miss: proceed to refill.
                        state <= STATE_REFILL;
                    end
                end

                // ----------------------------------------------------------------
                // REFILL: Lower memory supplies the 128-bit block combinationally
                //         on mem_block_data (driven by mem_block_addr already set).
                //         Write block + tag to the mapped set, mark valid.
                //         Deliver miss response with original miss classification.
                // ----------------------------------------------------------------
                STATE_REFILL: begin
                    // Write new block into the cache set.
                    data[set_idx]  <= mem_block_data;
                    tag[set_idx]   <= tag_in;
                    valid[set_idx] <= 1'b1;
                    // Deliver miss response.
                    resp_valid <= 1'b1;
                    resp_hit   <= 1'b0;
                    resp_data  <= refill_word;
                    state      <= STATE_RESP;
                end

                // ----------------------------------------------------------------
                // RESP: Deassert resp_valid after exactly 1 cycle.
                //       Return to IDLE to accept next request (req_ready re-asserts).
                // ----------------------------------------------------------------
                STATE_RESP: begin
                    resp_valid <= 1'b0;
                    resp_hit   <= 1'b0;
                    resp_data  <= 32'h00000000;
                    state      <= STATE_IDLE;
                end

                default: begin
                    state      <= STATE_IDLE;
                    resp_valid <= 1'b0;
                    resp_hit   <= 1'b0;
                    resp_data  <= 32'h00000000;
                end
            endcase
        end
    end

endmodule
