// ==============================================================================
// Module: cache_2way
// Description: Top-level 2-Way Set-Associative Cache Controller & Datapath.
//              Integrates request handshaking, address latching, parallel tag
//              matching, LRU tracking, refill datapath, and response generation.
// Capacity: 128 bytes (4 sets x 2 ways x 16 bytes/block).
// Author: Apoorva
// Standard: Synthesizable Verilog-2001
// ==============================================================================

`timescale 1ns / 1ps

module cache_2way (
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
    // req_ready is asserted only in IDLE when not in reset.
    assign req_ready = (state == STATE_IDLE) && (!rst);

    // mem_block_addr is the 16-byte aligned block base address of the saved request.
    assign mem_block_addr = {saved_addr[31:4], 4'b0000};

    // --------------------------------------------------------------------------
    // Submodule Interconnect: cache_2way_store
    // --------------------------------------------------------------------------
    wire        store_hit;
    wire        store_hit_way;
    wire        store_victim_way;
    wire [31:0] store_read_word;

    // Control signals to store module:
    // - touch_en: pulsed for exactly 1 cycle in STATE_LOOKUP upon a cache hit
    // - fill_en:  pulsed for exactly 1 cycle in STATE_REFILL upon a cache miss
    // Invariant: touch_en and fill_en are mutually exclusive by state definition.
    wire touch_en = (state == STATE_LOOKUP) && store_hit;
    wire fill_en  = (state == STATE_REFILL);

    cache_2way_store u_store (
        .clk        (clk),
        .rst        (rst),
        .addr       (saved_addr),
        .touch_en   (touch_en),
        .fill_en    (fill_en),
        .fill_block (mem_block_data),
        .hit        (store_hit),
        .hit_way    (store_hit_way),
        .victim_way (store_victim_way),
        .read_word  (store_read_word)
    );

    // --------------------------------------------------------------------------
    // Refill Word Selection Multiplexer
    // --------------------------------------------------------------------------
    // Extracts the requested 32-bit word directly from the incoming 128-bit block
    // based on saved_addr[3:2] during a miss refill.
    reg [31:0] refill_word;
    always @(*) begin
        case (saved_addr[3:2])
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
        end else begin
            case (state)
                STATE_IDLE: begin
                    resp_valid <= 1'b0;
                    if (req_valid && req_ready) begin
                        saved_addr <= req_addr;
                        state      <= STATE_LOOKUP;
                    end
                end

                STATE_LOOKUP: begin
                    if (store_hit) begin
                        // Cache Hit:
                        // touch_en is asserted combinationally this cycle.
                        // LRU updates at this posedge clk.
                        // Deliver response with hit status and cached word.
                        resp_valid <= 1'b1;
                        resp_hit   <= 1'b1;
                        resp_data  <= store_read_word;
                        state      <= STATE_RESP;
                    end else begin
                        // Cache Miss:
                        // Proceed to REFILL to write incoming block from lower memory.
                        state <= STATE_REFILL;
                    end
                end

                STATE_REFILL: begin
                    // Cache Miss Refill:
                    // fill_en is asserted combinationally this cycle.
                    // New block written to victim way and LRU updated at this posedge clk.
                    // Deliver response preserving original Miss classification (resp_hit = 0).
                    resp_valid <= 1'b1;
                    resp_hit   <= 1'b0;
                    resp_data  <= refill_word;
                    state      <= STATE_RESP;
                end

                STATE_RESP: begin
                    // Deassert resp_valid after exactly 1 cycle pulse.
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
