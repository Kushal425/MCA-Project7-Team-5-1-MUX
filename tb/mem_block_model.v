// ==============================================================================
// Module: mem_block_model
// Description: Reusable combinational block-memory verification model.
//              Provides deterministic memory blocks where each 32-bit word
//              contains its own aligned byte address:
//                mem_block_data[31:0]   = {mem_block_addr[31:4], 4'b0000} (Word 0)
//                mem_block_data[63:32]  = {mem_block_addr[31:4], 4'b0100} (Word 1)
//                mem_block_data[95:64]  = {mem_block_addr[31:4], 4'b1000} (Word 2)
//                mem_block_data[127:96] = {mem_block_addr[31:4], 4'b1100} (Word 3)
// Standard: Verilog-2001
// ==============================================================================

`timescale 1ns / 1ps

module mem_block_model (
    input  wire [31:0]  mem_block_addr,
    output wire [127:0] mem_block_data
);

    assign mem_block_data[31:0]   = {mem_block_addr[31:4], 4'b0000};
    assign mem_block_data[63:32]  = {mem_block_addr[31:4], 4'b0100};
    assign mem_block_data[95:64]  = {mem_block_addr[31:4], 4'b1000};
    assign mem_block_data[127:96] = {mem_block_addr[31:4], 4'b1100};

endmodule
