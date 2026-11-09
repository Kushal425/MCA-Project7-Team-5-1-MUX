# Project Brief: Modern Computer Architecture (MCA) Group Project

## Project 7: 2-Way Set-Associative Cache with LRU

---

## 1. Scope and Team

### Team Members
1. **Krishna**
2. **Apoorva**
3. **Prachee**
4. **Kushal**
5. **Vani**

### Implementation Work Order
The development sequence for Phase I is strictly sequential:
$$\text{Kushal (scaffold)} \longrightarrow \text{Krishna (storage/LRU)} \longrightarrow \text{Apoorva (controller)} \longrightarrow \text{Prachee (comparison)} \longrightarrow \text{Kushal (verification)} \longrightarrow \text{Vani (report/demo package)}$$

1. **Kushal (scaffold)**: Repository setup, directory structure, core documentation, interface contracts, gitignore, and initial handoff logging.
2. **Krishna (storage/LRU)**: Internal two-way storage arrays, tag comparators, combinational read-word muxing, and set-associative LRU state logic (`rtl/cache_2way_store.v`).
3. **Apoorva (controller)**: Top-level two-way cache integration, controller FSM, memory fill interface, request handshaking, and response generation (`rtl/cache_2way.v`).
4. **Prachee (comparison)**: Direct-mapped cache baseline implementation (`rtl/cache_direct.v`) conforming to the identical external interface for comparative evaluation.
5. **Kushal (verification)**: Testbenches (`tb/`), trace simulation harnesses, automated correctness assertions, and comparative hit-rate simulation scripts (`scripts/`).
6. **Vani (report/demo package)**: IEEE progress report (`report/`), demonstration video script/slides (`demo/`), verification evidence curation (`docs/evidence/`), and submission packaging.

> [!IMPORTANT]
> **Current Project Phase: PHASE I ONLY.**
> All ongoing implementation work, verification, and logging must focus strictly on the Phase I deliverables. Phase II criteria are documented below solely to provide architectural context and ensure forward compatibility. Do not claim Phase II completion.

---

## 2. Course Evaluation Criteria

### Phase I (30% of Total Grade)
- **Deadline**: November 16, 2026, 11:59 PM GMT+5:30 (IST).
- **Deliverables & Breakdown**:
  1. **IEEE Project Report (10 Marks)**:
     - Formatted according to the standard IEEE conference template.
     - Required sections:
       - Abstract
       - Literature Review
       - Proposed Solution (Architecture, Controller FSM, and LRU mechanics)
       - Individual Contributions
       - References
  2. **Prototype Video (15 Marks)**:
     - Maximum duration: 5 minutes.
     - Clearly state the project title, motivation, and architecture.
     - Introduce all five members by name.
     - Demonstrate real prototype progress: Verilog RTL walkthrough, block diagrams, and working simulation traces.
  3. **GitHub Repository (5 Marks)**:
     - Repository URL submitted via the official course submission form.
     - Content: Complete IEEE project report, prototype/demo video link, all synthesizable RTL and testbench files, simulation scripts, and verification artifacts.
     - Git history: Rigorously evaluated for authentic, individual version control contributions. All five team members must commit and push their respective portions using their own personal GitHub accounts.

### Phase II (70% of Total Grade) - *For Context*
- **Deliverables**:
  - Comprehensive IEEE Project Report:
    - Abstract
    - Literature Review
    - Proposed Solution
    - Results and Discussion (Extended benchmarking, hit/miss analysis under varied workloads)
    - Individual Contributions
    - Conclusion
    - References
  - Continued GitHub repository maintenance demonstrating continuous, verifiable individual commits.
  - Final Project Interview / Oral Defense:
    - Evaluates in-depth architectural understanding, RTL design choices, verification methodology, individual contributions, and collaborative execution.
    - Every single team member must be fully prepared to explain both their individual contribution and the end-to-end cache system architecture.
    - Specific interview time slots and logistics will be announced by course instructors.

---

## 3. Project 7 Specification (from Project_list_MCA.pdf)

- **Title**: 2-Way Set-Associative Cache with LRU
- **Level**: Intermediate+
- **Objective**: Implement a synthesizable 2-Way Set-Associative Cache with Least-Recently-Used (LRU) replacement policy and compare its performance against a Direct-Mapped Cache baseline under identical memory access traces.
- **Key Architectural Concepts**:
  - Set associativity and conflict miss reduction
  - Parallel tag comparison and hit detection
  - Replacement policies and LRU tracking mechanics
  - Temporal and spatial locality
  - Memory hierarchy and average memory access time (AMAT)
- **Suggested Hardware Building Blocks**:
  - Way-0 and Way-1 Data and Tag RAM / register arrays
  - Valid bit tracking registers per way
  - LRU status register per set (1 bit per set for 2-way)
  - Parallel tag comparators
  - Hit/miss determination logic
  - Cache Controller Finite State Machine (FSM)
  - Lower-level memory refill interface
- **Deliverables & Expectations**:
  - Two-way cache RTL with correct parallel tag matching and LRU state updates.
  - Direct-mapped baseline RTL with identical interface.
  - Common reproducible memory trace verification.
  - Hit-rate comparison analysis.
  - Synthesis / resource utilization and performance assessment.
- **Distinction Between Course Requirements and Team Design Choices**:
  - *Course Requirements*: 2-way set-associative cache with LRU replacement, direct-mapped cache comparison, parallel tag matching, valid bit and LRU state handling, identical trace testing, and IEEE report/video submission.
  - *Team Design Choices*:
    - Fixed capacity of 128 data bytes arranged as 16-byte cache blocks (4 words per block).
    - 2-way cache configured with 4 sets (2 ways × 4 sets × 16 bytes = 128 bytes).
    - Direct-mapped cache configured with 8 sets (1 way × 8 sets × 16 bytes = 128 bytes).
    - **Team Phase I Target**: Working read-access prototype, small verified comparison, IEEE progress report, demonstration video and repository. Reserve broader benchmarking and the final resource/performance analysis for Phase II.
    - Extended workload benchmarking and FPGA hardware synthesis utilization reports belong to Phase II.

---

## 4. Team Design Contract

The design contract defined here is binding across all submodules and testbenches. See [docs/interface.md](file:///Users/kushalsarkar/Desktop/MCA/docs/interface.md) for detailed timing diagrams and pinouts.

### 4.1 Tools and Language Standards
- **RTL Language**: Synthesizable Verilog-2001 (`.v`).
- **Testbench Language**: SystemVerilog / Verilog-2001 (`.v` or `.sv`), compiled using Icarus Verilog (`iverilog -g2012`).
- **Paths**: All simulation scripts and include paths must use portable relative paths.

### 4.2 Cache Geometry and Address Partitioning
- **Address Width**: 32-bit byte address (`addr[31:0]`).
- **Supported Accesses**: Aligned 32-bit word read requests (`addr[1:0] == 2'b00`).
- **Data Capacity**: 128 data bytes total.
- **Block Size**: 16 bytes (128 bits), containing four 32-bit words.
- **Block Layout (Little-Endian Word Packing)**:
  - `mem_block_data[31:0]`   : Word 0 (`addr[3:2] == 2'b00`)
  - `mem_block_data[63:32]`  : Word 1 (`addr[3:2] == 2'b01`)
  - `mem_block_data[95:64]`  : Word 2 (`addr[3:2] == 2'b10`)
  - `mem_block_data[127:96]` : Word 3 (`addr[3:2] == 2'b11`)

#### 2-Way Set-Associative Cache (`cache_2way`)
- Total Capacity: 128 bytes = 8 blocks total = 4 sets × 2 ways.
- Block Offset: bits `[3:0]` (16 bytes).
- Word Select: bits `[3:2]` (4 words per block).
- Set Index: bits `[5:4]` (4 sets $\rightarrow$ 2 index bits).
- Tag: bits `[31:6]` (26 tag bits).

#### Direct-Mapped Cache Baseline (`cache_direct`)
- Total Capacity: 128 bytes = 8 blocks total = 8 sets × 1 way.
- Block Offset: bits `[3:0]` (16 bytes).
- Word Select: bits `[3:2]` (4 words per block).
- Set Index: bits `[6:4]` (8 sets $\rightarrow$ 3 index bits).
- Tag: bits `[31:7]` (25 tag bits).

### 4.3 Memory Verification Model
- `mem_block_addr[31:0]` is the full 32-bit byte address aligned to a 16-byte block boundary (`addr[31:4], 4'b0000`).
- **Deterministic Testbench Memory Rule**: Each memory word contains its own 32-bit aligned byte address as its data value:
  $$\text{Memory}[\text{word\_addr}] = \text{word\_addr}$$
- Example: For block address `0x00000080`:
  - Word 0 (`0x00000080`): `32'h00000080` (placed in `mem_block_data[31:0]`)
  - Word 1 (`0x00000084`): `32'h00000084` (placed in `mem_block_data[63:32]`)
  - Word 2 (`0x00000088`): `32'h00000088` (placed in `mem_block_data[95:64]`)
  - Word 3 (`0x0000008C`): `32'h0000008C` (placed in `mem_block_data[127:96]`)
- **Key Advantage**: Enables testbenches to verify data integrity independently of whether an access was a hit or a miss.

### 4.4 Top-Level Module Interfaces
Both external cache modules (`cache_2way` and `cache_direct`) implement the identical interface:

```verilog
module cache_2way (
    input  wire        clk,
    input  wire        rst,
    input  wire        req_valid,
    input  wire [31:0] req_addr,
    output wire        req_ready,
    output reg         resp_valid,
    output reg         resp_hit,
    output reg  [31:0] resp_data,
    output wire [31:0] mem_block_addr,
    input  wire [127:0] mem_block_data
);
```

```verilog
module cache_direct (
    input  wire        clk,
    input  wire        rst,
    input  wire        req_valid,
    input  wire [31:0] req_addr,
    output wire        req_ready,
    output reg         resp_valid,
    output reg         resp_hit,
    output reg  [31:0] resp_data,
    output wire [31:0] mem_block_addr,
    input  wire [127:0] mem_block_data
);
```

#### Protocol & Handshake Rules
- **Reset**: Synchronous, active-high (`rst`). While `rst` is asserted, `req_ready` and `resp_valid` must be deasserted (`0`).
- **Request Acceptance**: A request is accepted on the rising edge of `clk` when `req_valid && req_ready`.
- **Single Outstanding Request**: The cache processes at most one request at a time. Once a request is accepted, the address is latched, and `req_ready` is deasserted until response delivery.
- **Response Delivery**: Exactly one cycle of `resp_valid = 1` is produced per accepted request. `resp_hit` and `resp_data` are valid simultaneously with `resp_valid`. The master/testbench samples responses on the rising clock edge.
- **Memory Refill Port**: Combinational read port provided by testbench. `mem_block_addr` is driven by the cache; the testbench continuously supplies `mem_block_data` corresponding to `mem_block_addr`. No handshake required in Phase I.
- **Latency**: Implementation-dependent (e.g., 1–2 cycles for hit, 2–3 cycles for miss refill), but strictly adheres to the ready/valid protocol.

### 4.5 Internal Submodule: `cache_2way_store` (Krishna)
The storage, tag match, and LRU tracking logic for `cache_2way` is encapsulated in `cache_2way_store`:

```verilog
module cache_2way_store (
    input  wire         clk,
    input  wire         rst,
    input  wire [31:0]  addr,
    input  wire         touch_en,
    input  wire         fill_en,
    input  wire [127:0] fill_block,
    output wire         hit,
    output wire         hit_way,
    output wire         victim_way,
    output wire [31:0]  read_word
);
```

- **Combinational Tag Comparison & Read**: Based on `addr[31:0]`, checks tag match against valid ways in set `addr[5:4]`. If matched, `hit = 1` and `hit_way` indicates matching way. `read_word` outputs the selected 32-bit word.
- **LRU & Allocation Policy**:
  - Invalid ways take priority during allocation. If way 0 is invalid, `victim_way = 0`. Else if way 1 is invalid, `victim_way = 1`.
  - When both ways are valid, a 1-bit LRU register per set tracks the least recently used way (`lru_bit == 0` $\rightarrow$ way 0 is LRU victim; `lru_bit == 1` $\rightarrow$ way 1 is LRU victim).
  - On a cache hit with `touch_en == 1`, access updates the set's LRU register to point to the *other* way as the next victim.
  - On a cache refill with `fill_en == 1`, `fill_block` is written into `victim_way`, that way is marked valid, tag is written, and the LRU register is updated to point away from the newly written way.
- **Control Invariant**: The controller must **never** assert `touch_en` and `fill_en` simultaneously.

### 4.6 Benchmark Trace & Predicted Results
Standard 5-access trace evaluated from cold (empty/invalid) caches:
1. `0x00000000`
2. `0x00000080`
3. `0x00000000`
4. `0x00000100`
5. `0x00000000`

- **Address Mapping in Set 0**:
  - `0x00000000`: Set index 0 in both caches.
  - `0x00000080`: Set index 0 in both caches (bits `[5:4] == 2'b00` for 2-way; bits `[6:4] == 3'b000` for direct-mapped).
  - `0x00000100`: Set index 0 in both caches (bits `[5:4] == 2'b00` for 2-way; bits `[6:4] == 3'b000` for direct-mapped).
- **Expected Results**:
  - **2-Way Set-Associative**: Miss (`0x00`), Miss (`0x80`), **Hit** (`0x00`), Miss (`0x100`), **Hit** (`0x00`) $\rightarrow$ **2 Hits / 5 Accesses (40% Hit Rate)**.
  - **Direct-Mapped**: Miss (`0x00`), Miss (`0x80`), Miss (`0x00`), Miss (`0x100`), Miss (`0x00`) $\rightarrow$ **0 Hits / 5 Accesses (0% Hit Rate)** due to thrashing.

> [!NOTE]
> These predicted numbers are illustrative architectural predictions derived from set conflicts on Set 0. They must be validated by automated simulation runs before being reported as empirical measurements.

---

## 5. Handoff and Submission Rules

To ensure academic integrity, clear project tracking, and fair evaluation:
1. **Pull Before Work**: Every team member must run `git pull` before beginning edits to ensure they are on the latest commit.
2. **Personal Git Identity**: Each member must commit and push strictly using their own personal GitHub account. Never commit under a teammate's credentials.
3. **Diff Review**: Prior to committing, each member must run `git diff` and `git status` to ensure only intended changes are staged.
4. **Authenticity & Integrity**:
   - Zero tolerance for fabricated simulation results, fake test logs, or placeholder cheating.
   - Do not claim a test passed unless the simulation script was actually executed and returned exit code 0.
   - Do not pre-populate future handoff accomplishments.
5. **Clear Handoff Logging**: After completing their milestone, each member must update [HANDOFF.md](file:///Users/kushalsarkar/Desktop/MCA/HANDOFF.md) detailing work completed, changed files, checks run, observed results, unresolved issues, and the next member in sequence.
6. **Privacy & Security**: Never commit personal passwords, API tokens, or private phone numbers/emails to the repository.

