// ==============================================================================
// Module: cache_2way_store
// Description: Internal storage, parallel tag comparison, word multiplexing,
//              and per-set 1-bit LRU state tracking for 2-Way Set-Associative Cache.
// Capacity: 128 bytes total (4 sets x 2 ways x 16 bytes/block).
// Author: Krishna (Phase I, Handoff 1)
// Standard: Synthesizable Verilog-2001
// ==============================================================================

`timescale 1ns / 1ps

module cache_2way_store (
    input  wire         clk,         // System clock
    input  wire         rst,         // Synchronous active-high reset
    input  wire [31:0]  addr,        // Target address to lookup or update
    input  wire         touch_en,    // Pulse to update LRU on a hit
    input  wire         fill_en,     // Pulse to write new block into victim way and update LRU
    input  wire [127:0] fill_block,  // 128-bit block from lower memory to write
    output wire         hit,         // Combinational hit detection (1 = hit, 0 = miss)
    output wire         hit_way,     // 0 = Way 0 matched, 1 = Way 1 matched
    output wire         victim_way,  // Target way for replacement / fill
    output wire [31:0]  read_word    // Combinational 32-bit word output selected by addr[3:2]
);

    // --------------------------------------------------------------------------
    // Address Bit Decomposition
    // --------------------------------------------------------------------------
    // addr[1:0]  : Byte offset within word (aligned accesses have addr[1:0] == 2'b00)
    // addr[3:2]  : Word select within 16-byte block (4 words)
    // addr[5:4]  : Set index (4 sets)
    // addr[31:6] : Cache tag (26 bits)
    wire [1:0]  set_idx  = addr[5:4];
    wire [1:0]  word_sel = addr[3:2];
    wire [25:0] tag_in   = addr[31:6];

    // --------------------------------------------------------------------------
    // Storage Elements (4 sets x 2 ways)
    // --------------------------------------------------------------------------
    reg         valid_way0 [0:3];
    reg         valid_way1 [0:3];
    reg [25:0]  tag_way0   [0:3];
    reg [25:0]  tag_way1   [0:3];
    reg [127:0] data_way0  [0:3];
    reg [127:0] data_way1  [0:3];

    // Per-set 1-bit LRU register:
    // 1'b0 => Way 0 is Least Recently Used (victim candidate)
    // 1'b1 => Way 1 is Least Recently Used (victim candidate)
    reg         lru_bit    [0:3];

    // --------------------------------------------------------------------------
    // Combinational Parallel Lookup & Tag Comparison
    // --------------------------------------------------------------------------
    wire way0_match = valid_way0[set_idx] && (tag_way0[set_idx] == tag_in);
    wire way1_match = valid_way1[set_idx] && (tag_way1[set_idx] == tag_in);

    assign hit = way0_match || way1_match;

    // Defined miss default for hit_way: 1'b0
    assign hit_way = hit ? (way1_match ? 1'b1 : 1'b0) : 1'b0;

    // --------------------------------------------------------------------------
    // Word Selection Multiplexer
    // --------------------------------------------------------------------------
    wire [127:0] hit_block = way1_match ? data_way1[set_idx] : data_way0[set_idx];
    reg  [31:0]  selected_word;

    always @(*) begin
        if (hit) begin
            case (word_sel)
                2'b00:   selected_word = hit_block[31:0];
                2'b01:   selected_word = hit_block[63:32];
                2'b10:   selected_word = hit_block[95:64];
                2'b11:   selected_word = hit_block[127:96];
                default: selected_word = 32'h00000000;
            endcase
        end else begin
            // Defined miss default for read_word: 32'h00000000
            selected_word = 32'h00000000;
        end
    end

    assign read_word = selected_word;

    // --------------------------------------------------------------------------
    // Deterministic Victim Selection Logic
    // --------------------------------------------------------------------------
    // Priority order:
    // 1. If Way 0 is empty (invalid), choose Way 0.
    // 2. Else if Way 1 is empty (invalid), choose Way 1.
    // 3. If both ways are valid, choose the LRU way indicated by lru_bit[set_idx].
    assign victim_way = (!valid_way0[set_idx]) ? 1'b0 :
                        (!valid_way1[set_idx]) ? 1'b1 :
                        lru_bit[set_idx];

    // --------------------------------------------------------------------------
    // Synchronous State Updates (Reset, Fill, Touch)
    // --------------------------------------------------------------------------
    // Pure lookup (addr change without touch_en or fill_en) does NOT mutate state.
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 4; i = i + 1) begin
                valid_way0[i] <= 1'b0;
                valid_way1[i] <= 1'b0;
                lru_bit[i]    <= 1'b0;
            end
        end else if (fill_en) begin
            // Write refill block into selected victim way and update recency
            if (victim_way == 1'b0) begin
                valid_way0[set_idx] <= 1'b1;
                tag_way0[set_idx]   <= tag_in;
                data_way0[set_idx]  <= fill_block;
                lru_bit[set_idx]    <= 1'b1; // Way 0 now MRU -> Way 1 becomes LRU
            end else begin
                valid_way1[set_idx] <= 1'b1;
                tag_way1[set_idx]   <= tag_in;
                data_way1[set_idx]  <= fill_block;
                lru_bit[set_idx]    <= 1'b0; // Way 1 now MRU -> Way 0 becomes LRU
            end
        end else if (touch_en) begin
            // Hit recency update: flip LRU pointer away from the hitting way
            if (way1_match) begin
                lru_bit[set_idx] <= 1'b0; // Way 1 touched -> Way 0 becomes LRU
            end else if (way0_match) begin
                lru_bit[set_idx] <= 1'b1; // Way 0 touched -> Way 1 becomes LRU
            end
        end
    end

endmodule
