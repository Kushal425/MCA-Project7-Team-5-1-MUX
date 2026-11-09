# Hardware Design Contract & Interface Specification

This document establishes the binding hardware design contract for the Modern Computer Architecture (MCA) cache project. All implementations (`cache_2way`, `cache_direct`, and `cache_2way_store`) must adhere strictly to the module signatures, address breakdowns, timing behaviors, and memory protocols documented here.

---

## 1. Toolchain & Language Standards

- **Hardware Description Language**: Synthesizable Verilog-2001 (`.v`).
- **Simulation Language**: Verilog-2001 or SystemVerilog (`.v` or `.sv`).
- **Simulator**: Icarus Verilog (`iverilog`) using the `-g2012` flag when compiling SystemVerilog testbenches.
- **Portability**: All file references, include paths, and script arguments must use relative paths originating from the project root.

---

## 2. Memory Organization & Addressing

### 2.1 Capacity & Word/Block Sizing
- **Total Data Capacity**: 128 bytes (1024 bits).
- **Block Size**: 16 bytes (128 bits), containing four 32-bit words.
- **Address Space**: 32-bit byte addresses (`addr[31:0]`).
- **Phase I Support**: Aligned 32-bit word reads (`addr[1:0] == 2'b00`).

### 2.2 128-Bit Block Word Packing
Each 128-bit block is packed with words in little-endian order:
- `block_data[31:0]`   : Word 0 (`addr[3:2] == 2'b00`)
- `block_data[63:32]`  : Word 1 (`addr[3:2] == 2'b01`)
- `block_data[95:64]`  : Word 2 (`addr[3:2] == 2'b10`)
- `block_data[127:96]` : Word 3 (`addr[3:2] == 2'b11`)

### 2.3 Address Decomposition

#### 2-Way Set-Associative Cache (`cache_2way`)
4 sets, 2 ways per set (4 sets × 2 ways × 16 bytes/block = 128 bytes total):

```
 31                          6 5    4 3    2 1    0
+-----------------------------+------+------+------+
|             TAG             | SET  | WORD | BYTE |
|           [31:6]            | [5:4]| [3:2]| [1:0]|
+-----------------------------+------+------+------+
            26 bits            2 bits  2 bits 2 bits
                              (4 sets) (4 wds) (off)
```
- **Byte Offset**: `addr[3:0]` (16 bytes/block)
- **Word Select**: `addr[3:2]` (4 words/block)
- **Set Index**: `addr[5:4]` (4 sets)
- **Tag**: `addr[31:6]` (26 bits)

#### Direct-Mapped Cache Baseline (`cache_direct`)
8 sets, 1 way per set (8 sets × 1 way × 16 bytes/block = 128 bytes total):

```
 31                            7 6    4 3    2 1    0
+-------------------------------+------+------+------+
|              TAG              | SET  | WORD | BYTE |
|            [31:7]             | [6:4]| [3:2]| [1:0]|
+-------------------------------+------+------+------+
             25 bits             3 bits 2 bits 2 bits
                               (8 sets)(4 wds)(off)
```
- **Byte Offset**: `addr[3:0]` (16 bytes/block)
- **Word Select**: `addr[3:2]` (4 words/block)
- **Set Index**: `addr[6:4]` (8 sets)
- **Tag**: `addr[31:7]` (25 bits)

---

## 3. Testbench Memory Verification Model

To decouple data verification from hit/miss mechanics, the simulation testbench implements an algorithmic memory model:
- `mem_block_addr[31:0]` is driven by the cache as the 16-byte aligned base address of the requested block:
  $$\text{mem\_block\_addr} = \{\text{addr}[31:4], 4\text{'b}0000\}$$
- Each 32-bit word in memory contains its own 32-bit aligned byte address as its data value:
  $$\text{Word Data} = \text{Aligned Word Address}$$

### Example: Block Base Address `0x00000080`
- Word 0 Address `0x00000080` $\rightarrow$ Value = `32'h00000080` (`mem_block_data[31:0]`)
- Word 1 Address `0x00000084` $\rightarrow$ Value = `32'h00000084` (`mem_block_data[63:32]`)
- Word 2 Address `0x00000088` $\rightarrow$ Value = `32'h00000088` (`mem_block_data[95:64]`)
- Word 3 Address `0x0000008C` $\rightarrow$ Value = `32'h0000008C` (`mem_block_data[127:96]`)

The testbench memory port is strictly combinational: when the cache presents `mem_block_addr`, the testbench immediately reflects the corresponding 128-bit `mem_block_data`. No handshake signals are required for the memory bus in Phase I.

---

## 4. External Cache Module Interface

Both top-level cache modules (`cache_2way` and `cache_direct`) must strictly match this exact port signature:

```verilog
module <module_name> (
    input  wire        clk,             // System clock (rising-edge active)
    input  wire        rst,             // Synchronous active-high reset
    input  wire        req_valid,       // Master request valid
    input  wire [31:0] req_addr,        // Master requested byte address
    output wire        req_ready,       // Cache ready to accept request
    output reg         resp_valid,      // Cache response valid (1-cycle pulse)
    output reg         resp_hit,        // 1 = Hit, 0 = Miss
    output reg  [31:0] resp_data,       // Requested 32-bit word data
    output wire [31:0] mem_block_addr,  // 16-byte aligned lower memory refill address
    input  wire [127:0] mem_block_data  // 128-bit block data from lower memory
);
```

### Handshake & Timing Protocol

```
Clock:       ___|‾‾‾|___|‾‾‾|___|‾‾‾|___|‾‾‾|___|‾‾‾|___|‾‾‾|___|‾‾‾
rst:         ‾‾‾‾‾‾‾|_______________________________________________
req_valid:   ___________|‾‾‾‾‾‾‾|___________________________________
req_addr:    -----------< ADDR >-----------------------------------
req_ready:   ___________|‾‾‾‾‾‾‾|___________________________________
(accepted)              ^ Handshake Edge
resp_valid:  _______________________|‾‾‾‾‾‾‾|_______________________
resp_hit:    -----------------------< HIT? >------------------------
resp_data:   -----------------------< DATA >------------------------
```

1. **Synchronous Reset (`rst`)**:
   - While `rst` is high, `req_ready` must be `0` and `resp_valid` must be `0`.
   - All valid bits and LRU tracking registers are cleared.
2. **Request Acceptance (`req_valid && req_ready`)**:
   - Sampled on the rising clock edge.
   - When accepted, the cache latches `req_addr`.
   - `req_ready` drops to `0` on subsequent cycles until the request completes. Only **one outstanding request** is allowed at any time.
3. **Response Delivery (`resp_valid`)**:
   - The cache asserts `resp_valid = 1` for **exactly one clock cycle**.
   - Concurrently, `resp_hit` reflects whether the access was a hit (`1`) or miss (`0`), and `resp_data` contains the requested 32-bit word.
   - The master/testbench samples `resp_valid`, `resp_hit`, and `resp_data` on the rising clock edge.
4. **Latency**:
   - Hits may complete in 1 to 2 cycles.
   - Misses may take additional cycles to latch memory refill data and update tags/data before asserting `resp_valid`.

---

## 5. Internal Submodule: `cache_2way_store`

Owner: **Krishna**

The `cache_2way_store` submodule encapsulates the tag RAM, data RAM, valid bit registers, comparator logic, and LRU tracking registers for the 2-Way Set-Associative design.

```verilog
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
```

### Functional Operation & Invariants

1. **Combinational Lookup**:
   - Set index = `addr[5:4]`.
   - Tag = `addr[31:6]`.
   - Way 0 match = `valid[set][0] && (tag[set][0] == tag)`.
   - Way 1 match = `valid[set][1] && (tag[set][1] == tag)`.
   - `hit` = `way0_match || way1_match`.
   - `hit_way` = `way1_match ? 1'b1 : 1'b0`.
   - `read_word` selects the requested 32-bit word from the hitting way based on `addr[3:2]`. If neither way hits, `read_word` value is don't-care.

2. **Victim Selection**:
   - **Invalid Slot Priority**:
     - If Way 0 is invalid (`!valid[set][0]`), `victim_way = 1'b0`.
     - Else if Way 1 is invalid (`!valid[set][1]`), `victim_way = 1'b1`.
   - **LRU Victim**:
     - When both ways are valid (`valid[set][0] && valid[set][1]`), `victim_way = lru_bit[set]`.
     - `lru_bit == 0` signifies Way 0 is LRU (victim).
     - `lru_bit == 1` signifies Way 1 is LRU (victim).

3. **LRU State Updates**:
   - On a hit with `touch_en == 1` on the rising clock edge:
     - If Way 0 hit, `lru_bit[set] <= 1'b1` (Way 1 becomes next victim).
     - If Way 1 hit, `lru_bit[set] <= 1'b0` (Way 0 becomes next victim).
   - On a miss refill with `fill_en == 1` on the rising clock edge:
     - `victim_way` receives `fill_block`, its tag is updated to `addr[31:6]`, and its valid bit is asserted.
     - If `victim_way == 0`, `lru_bit[set] <= 1'b1` (Way 1 becomes next victim).
     - If `victim_way == 1`, `lru_bit[set] <= 1'b0` (Way 0 becomes next victim).
   - **Invariant**: The controller must **never** assert `touch_en` and `fill_en` in the same clock cycle.

4. **Reset Behavior**:
   - On `rst == 1`, all valid bits (`valid[3:0][1:0]`) and all LRU bits (`lru_bit[3:0]`) are reset to `0`. Tag and data arrays may remain uninitialized.

