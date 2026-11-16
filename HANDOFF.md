# Project Development Log & Handoff History

This log tracks all architectural work, implementation milestones, code modifications, and verification records across team members in chronological sequence.

---

## Entry 1: Initial Repository Scaffold & Architecture Specification

- **Date**: 2026-11-10
- **Member**: **Kushal (scaffold)**
- **Work Completed**:
  - Initialized Git repository at the root directory (`/Users/kushalsarkar/Desktop/MCA`) on branch `main`.
  - Configured remote tracking `origin` to `PASTE_GITHUB_REPO_URL_HERE`.
  - Established canonical directory structure: `rtl/`, `tb/`, `scripts/`, `docs/`, `docs/evidence/`, `report/`, and `demo/` with purpose-specific README files.
  - Configured `.gitignore` targeting OS metadata, editor artifacts, Icarus Verilog outputs (`*.vvp`, `*.vcd`, `*.log`), LaTeX build intermediates, while explicitly whitelisting the final report PDF (`report/*.pdf`) and curated demo evidence (`docs/evidence/**`, `demo/**`).
  - Authored comprehensive `PROJECT_BRIEF.md` incorporating team work order, Phase I & Phase II evaluation criteria, course specifications, design contracts, and handoff protocols.
  - Authored `AGENTS.md` establishing the 5-step standing workflow, work boundaries, interface preservation, honest verification reporting, and handoff discipline for all coding assistants.
  - Authored `docs/interface.md` specifying exact port lists for `cache_2way`, `cache_direct`, and `cache_2way_store`, 32-bit address bitfield decompositions, synchronous active-high reset semantics, request/response handshaking protocol, and the deterministic testbench memory model.
  - Authored `docs/demo-trace.md` breaking down the 5-access benchmark trace (`0x00`, `0x80`, `0x00`, `0x100`, `0x00`) with cycle-by-cycle predictions clearly marked as analytical predictions awaiting simulation verification, including a detailed architectural rationale for why Request 3 updates LRU recency to alter the eviction target on Request 4.
  - Authored root `README.md` providing project overview, documentation roadmap, and simulation command guide.
  - Executed staged review and created three substantive commits:
    1. Commit 1: "Document Project 7 requirements and Phase I scope" (`PROJECT_BRIEF.md`)
    2. Commit 2: "Define cache interfaces, memory layout and reference traces" (`docs/interface.md`, `docs/demo-trace.md`)
    3. Commit 3: "Set up repository workflow and team handoffs" (`README.md`, `AGENTS.md`, `HANDOFF.md`, `.gitignore`, `rtl/README.md`, `tb/README.md`, `scripts/README.md`, `docs/evidence/README.md`, `report/README.md`, `demo/README.md`)
- **Changed Files**:
  - `PROJECT_BRIEF.md`
  - `docs/interface.md`
  - `docs/demo-trace.md`
  - `README.md`
  - `AGENTS.md`
  - `HANDOFF.md`
  - `.gitignore`
  - `rtl/README.md`
  - `tb/README.md`
  - `scripts/README.md`
  - `docs/evidence/README.md`
  - `report/README.md`
  - `demo/README.md`
- **Checks Actually Run**:
  - `git status`, `git config user.name`, `git config user.email`, `git remote -v`: verified Kushal author identity, branch `main`, and origin configuration.
  - `git check-ignore -v`: verified that `.gitignore` correctly ignores simulation binaries, build artifacts, LaTeX intermediates, while whitelisting `report/*.pdf`, `docs/evidence/**`, and `demo/**`.
  - Directory and file integrity checks: verified that all 13 scaffold files are present, properly formatted, and free of placeholder cheating or dummy RTL.
  - Staged diff inspections (`git diff --staged`) prior to each of the three commits.
  - Attempted `git push -u origin main` and `git ls-remote origin refs/heads/main` to verify remote status.
- **Observed Results**:
  - Clean repository with complete Phase I specification and architectural contracts.
  - All 3 commits authored under Kushal (`Kushal425`).
  - Zero placeholder RTL or premature Phase II files committed.
- **Unresolved Items**:
  - Remote URL configuration: The supplied remote URL was the placeholder `PASTE_GITHUB_REPO_URL_HERE`. Push to remote was attempted, but blocked because the placeholder URL is not an accessible git host endpoint. When the user sets the real GitHub repository URL (`git remote set-url origin <URL>`), pushing will succeed immediately.
  - RTL implementation of `cache_2way_store.v` to be implemented by Krishna.
- **Next Member**: **Krishna** (Storage & Datapath submodule: `rtl/cache_2way_store.v` following `docs/interface.md#5`).

---

## Entry 2: Two-Way Cache Storage, Parallel Lookup, and LRU Replacement Implementation

- **Date**: 2026-11-10
- **Member**: **Krishna (storage/LRU)**
- **Module Location**: `rtl/cache_2way_store.v`
- **Work Completed**:
  - Implemented synthesizable Verilog-2001 submodule `rtl/cache_2way_store.v` strictly fulfilling the hardware contract defined in `docs/interface.md#5`.
  - Implemented dual-way data RAMs (`data_way0`, `data_way1`), 26-bit tag arrays (`tag_way0`, `tag_way1`), valid tracking registers (`valid_way0`, `valid_way1`), and per-set 1-bit LRU registers (`lru_bit`).
  - Implemented combinational parallel tag comparisons (`way0_match`, `way1_match`, `hit`, `hit_way`) and 4-word multiplexer with defined miss defaults (`hit_way = 1'b0`, `read_word = 32'h00000000`).
  - Built deterministic invalid-slot preference logic (`victim_way = 0` if Way 0 empty; `victim_way = 1` if Way 1 empty; else `lru_bit[set]`).
  - Verified combinational lookup invariance (changing address without `touch_en` or `fill_en` does not mutate register state).
  - Built synchronous active-high reset (`rst`) clearing all 4 sets' valid and LRU bits to zero.
  - Authored race-free, self-checking SystemVerilog unit testbench `tb/tb_cache_2way_store.sv` verifying 51 assertions across 8 functional categories:
    1. Cold initial state and miss defaults across all 4 sets.
    2. Lookup invariance over clock cycles without mutations.
    3. Deterministic empty-way priority (Way 0 followed by Way 1).
    4. Word multiplexing across all four word offsets for both Way 0 and Way 1.
    5. Hit recency update via `touch_en` dynamically flipping candidate victim way.
    6. LRU victim eviction upon refill and preservation of non-victim way.
    7. Full independence between sets (Set 0 preserved while Set 2 modified).
    8. Synchronous reset clearing all sets.
  - Created portable unit test runner `scripts/run_store_unit_test.sh` that checks prerequisites, compiles via `iverilog -g2012`, executes via `vvp`, and traps cleanup.
  - Authored worked LRU walkthrough documentation `docs/lru_explanation.md` tied directly to the unit test suite and `docs/demo-trace.md`.
  - Updated `scripts/README.md` and `tb/README.md`.
  - Executed staged review and created three substantive commits:
    1. Commit 1 (`d76542e`): "Implement two-way cache storage and per-set LRU" (`rtl/cache_2way_store.v`)
    2. Commit 2 (`0c1a380`): "Verify cache lookup, replacement and word selection" (`rtl/cache_2way_store.v`, `tb/tb_cache_2way_store.sv`)
    3. Commit 3: "Add reproducible storage tests and controller handoff" (`scripts/run_store_unit_test.sh`, `docs/lru_explanation.md`, `scripts/README.md`, `tb/README.md`, `HANDOFF.md`)
- **Changed Files**:
  - `rtl/cache_2way_store.v`
  - `tb/tb_cache_2way_store.sv`
  - `scripts/run_store_unit_test.sh`
  - `docs/lru_explanation.md`
  - `scripts/README.md`
  - `tb/README.md`
  - `HANDOFF.md`
- **Reproduction Steps for Apoorva**:
  ```bash
  # Ensure in repository root
  cd MCA-Project7-Team-5-1-MUX

  # Run automated unit test runner
  ./scripts/run_store_unit_test.sh

  # Alternatively, manual iverilog invocation:
  iverilog -g2012 -Wall -s tb_cache_2way_store -o sim_store.vvp rtl/cache_2way_store.v tb/tb_cache_2way_store.sv
  vvp sim_store.vvp
  rm -f sim_store.vvp
  ```
- **Checks Actually Run**:
  - `iverilog -g2001 -s cache_2way_store -Wall rtl/cache_2way_store.v`: Verilog-2001 syntax and synthesizability check clean with 0 warnings.
  - `./scripts/run_store_unit_test.sh`: Full execution of 51 assertions.
- **Observed Results**:
  ```
  ==================================================================
  Starting Unit Verification: cache_2way_store
  ==================================================================
  --- Test 1: Cold Initial State & Miss Defaults ---
    [PASS] Set 0 cold hit==0
    [PASS] Set 0 default hit_way==0
    [PASS] Set 0 default read_word==0
    [PASS] Set 0 empty victim_way==0 (empty Way 0 priority)
    [PASS] Set 1 cold hit==0
    [PASS] Set 1 default hit_way==0
    [PASS] Set 1 default read_word==0
    [PASS] Set 1 empty victim_way==0 (empty Way 0 priority)
    [PASS] Set 2 cold hit==0
    [PASS] Set 2 default hit_way==0
    [PASS] Set 2 default read_word==0
    [PASS] Set 2 empty victim_way==0 (empty Way 0 priority)
    [PASS] Set 3 cold hit==0
    [PASS] Set 3 default hit_way==0
    [PASS] Set 3 default read_word==0
    [PASS] Set 3 empty victim_way==0 (empty Way 0 priority)

  --- Test 2: Lookup Invariance (No State Mutation) ---
    [PASS] Lookup alone does not assert hit
    [PASS] Lookup alone preserves victim_way=0

  --- Test 3: Deterministic Empty-Way Priority ---
    [PASS] Empty set chooses Way 0 as victim
    [PASS] Set 0 after Way 0 fill chooses empty Way 1 as victim
    [PASS] Block A hits on Way 0
    [PASS] Unallocated Block B misses
    [PASS] Victim remains empty Way 1 during miss
    [PASS] Both ways full: miss selects LRU Way 0 as victim

  --- Test 4: Word Selection Multiplexing across All 4 Offsets ---
    [PASS] Way 0 Word 0 select
    [PASS] Way 0 Word 1 select
    [PASS] Way 0 Word 2 select
    [PASS] Way 0 Word 3 select
    [PASS] Way 1 Word 0 select
    [PASS] Way 1 Word 1 select
    [PASS] Way 1 Word 2 select
    [PASS] Way 1 Word 3 select

  --- Test 5: Hit Changing Next Victim via touch_en ---
    [PASS] Pre-touch: victim_way is Way 0
    [PASS] Target address hits in Way 0 during touch
    [PASS] Post-touch Way 0: victim_way flipped to Way 1
    [PASS] Post-touch Way 1: victim_way flipped back to Way 0

  --- Test 6: LRU Eviction of Victim Way ---
    [PASS] Victim before fill cycle is Way 1
    [PASS] Block A in Way 0 survived eviction
    [PASS] Block B was evicted from Way 1
    [PASS] Block C is present in Way 1

  --- Test 7: Independence Between Sets ---
    [PASS] Set 1 remains uncorrupted cold miss
    [PASS] Set 2 remains uncorrupted cold miss
    [PASS] Set 3 remains uncorrupted cold miss
    [PASS] Set 2 victim is Way 0
    [PASS] Set 2 victim updated to Way 1 after touch
    [PASS] Set 0 Block A unaffected by Set 2 operations
    [PASS] Set 0 Block C unaffected by Set 2 operations
    [PASS] Set 1 still cold
    [PASS] Set 3 still cold

  --- Test 8: Synchronous Reset Clears All Sets ---
    [PASS] Reset cleared Set 0 Block A
    [PASS] Reset cleared Set 2 Block D

  ==================================================================
  Verification Complete: 51 Passed, 0 Failed
  ==================================================================
  TEST RESULT: ALL 51 CHECKS PASSED SUCCESSFULLY
  ```
- **Known Limitations**:
  - Control invariant: The top-level cache controller must never assert `touch_en` and `fill_en` concurrently in the same clock cycle.
- **Next Member**: **Apoorva** (Top-level cache controller FSM & memory refill integration: `rtl/cache_2way.v` following `docs/interface.md#4`).


---

## Entry 3: Top-Level Two-Way Cache Controller, Refill Integration, and Memory Verification Model

- **Date**: 2026-11-15
- **Member**: **Apoorva (controller)**
- **Module Location**: `rtl/cache_2way.v`
- **Work Completed**:
  - Implemented top-level synthesizable Verilog-2001 module `rtl/cache_2way.v` strictly conforming to the public interface defined in `docs/interface.md#4` and `PROJECT_BRIEF.md#4.4`.
  - Instantiated Krishna's `cache_2way_store` submodule, wiring up address lookup, parallel tag matching, LRU updates, and refill datapath.
  - Implemented 4-state controller FSM (`STATE_IDLE`, `STATE_LOOKUP`, `STATE_REFILL`, `STATE_RESP`):
    - Handshake logic: Latches `req_addr` into `saved_addr` upon `req_valid && req_ready` at clock rising edge.
    - Busy isolation: Deasserts `req_ready` to `0` throughout the transaction to enforce the single outstanding request protocol. Changing `req_addr` while busy has zero impact on in-flight operations.
    - Hit path (`STATE_LOOKUP`): Asserts `touch_en = 1` for exactly 1 cycle on hit to update LRU recency, selects `store_read_word`, and registers response (`resp_valid = 1`, `resp_hit = 1`, `resp_data = store_read_word`).
    - Miss path (`STATE_REFILL`): Drives 16-byte aligned refill address `mem_block_addr = {saved_addr[31:4], 4'b0000}`, asserts `fill_en = 1` for exactly 1 cycle to write the incoming 128-bit `mem_block_data` into the victim way and update LRU, and registers response (`resp_valid = 1`, `resp_hit = 0`, `resp_data = refill_word`).
    - True classification preservation: Preserves the original `resp_hit = 0` classification for misses, even though the cache is refilled before response delivery.
    - Response timing (`STATE_RESP`): Generates an exact 1-cycle pulse of `resp_valid = 1`, returning to `STATE_IDLE` where `req_ready` re-asserts to accept the next request.
    - Synchronous reset: Active-high `rst` forces FSM to `STATE_IDLE`, resets `saved_addr`, and deasserts both `req_ready` and `resp_valid` to `0`.
  - Authored reusable combinational block-memory model `tb/mem_block_model.v` implementing the deterministic memory contract $\text{Memory}[\text{word\_addr}] = \text{word\_addr}$, ready for direct reuse by Prachee for `cache_direct`.
  - Authored self-checking integration testbench `tb/tb_cache_2way.sv` (141 assertions) verifying:
    1. Synchronous reset and handshake protocol.
    2. The standard 5-request demo sequence (`0x00`, `0x80`, `0x00`, `0x100`, `0x00`) reproducing the predicted 40% hit rate (2 hits, 3 misses).
    3. Returned data integrity across all word offsets (Word 0, 1, 2, 3) and sets (Set 0, 1, 2, 3) on both cold misses and spatial hits.
    4. Request-address mutation resilience (changing `req_addr` to `0xFFFFFFFF` or arbitrary values after acceptance does not affect transactions).
    5. Exact single-cycle `resp_valid` pulse delivery and zero phantom responses during idle cycles.
    6. Post-reset cold cache behavior and watchdog timeout protection.
  - Authored portable test runner script `scripts/run_cache_2way_integration_test.sh`.
  - Authored comprehensive architectural block diagrams, Mermaid flowcharts, and FSM documentation in `docs/architecture.md`.
  - Updated `scripts/README.md` and `tb/README.md`.
  - Executed staged review and created three substantive commits:
    1. Commit 1 (`7c777f7`): "Integrate request controller and two-way cache refill" (`rtl/cache_2way.v`)
    2. Commit 2 (`ba299cf`): "Verify cache transactions against deterministic block memory" (`tb/mem_block_model.v`, `tb/tb_cache_2way.sv`)
    3. Commit 3: "Document cache datapath and integration demo" (`docs/architecture.md`, `scripts/run_cache_2way_integration_test.sh`, `scripts/README.md`, `tb/README.md`, `HANDOFF.md`)
- **Changed Files**:
  - `rtl/cache_2way.v`
  - `tb/mem_block_model.v`
  - `tb/tb_cache_2way.sv`
  - `scripts/run_cache_2way_integration_test.sh`
  - `docs/architecture.md`
  - `scripts/README.md`
  - `tb/README.md`
  - `HANDOFF.md`
- **Location of Reusable Memory Model for Prachee**:
  - Path: `tb/mem_block_model.v`
  - Interface:
    ```verilog
    module mem_block_model (
        input  wire [31:0]  mem_block_addr,
        output wire [127:0] mem_block_data
    );
    ```
  - Behavior: Purely combinational. Given 16-byte aligned base address `mem_block_addr`, reflects 128-bit data packed with each 32-bit word equal to its own byte address. Prachee can instantiate this directly in `tb_cache_direct.sv` without re-implementing memory logic.
- **Reproduction Steps for Prachee / Team**:
  ```bash
  # Ensure in repository root
  cd MCA-Project7-Team-5-1-MUX

  # 1. Run Krishna's unit tests:
  ./scripts/run_store_unit_test.sh

  # 2. Run Apoorva's integration tests:
  ./scripts/run_cache_2way_integration_test.sh

  # Alternatively, manual iverilog invocation:
  iverilog -g2012 -Wall -s tb_cache_2way -o sim_cache_2way.vvp \
      rtl/cache_2way.v rtl/cache_2way_store.v tb/mem_block_model.v tb/tb_cache_2way.sv
  vvp sim_cache_2way.vvp
  rm -f sim_cache_2way.vvp
  ```
- **Checks Actually Run**:
  - `iverilog -Wall -g2001 -s cache_2way rtl/cache_2way.v rtl/cache_2way_store.v`: Verilog-2001 synthesizability check clean with 0 warnings.
  - `./scripts/run_store_unit_test.sh`: Full execution of 51 store assertions (51 passed, 0 failed).
  - `./scripts/run_cache_2way_integration_test.sh`: Full execution of 141 integration assertions (141 passed, 0 failed).
  - Combined suite total: 192 passed, 0 failed.
- **Observed Results (Integration Test Summary)**:
  ```
  ==================================================================
  Starting Integration Verification: cache_2way & mem_block_model
  ==================================================================

  --- Test 1: Reset & Protocol Invariants ---
    [PASS] req_ready deasserted during reset
    [PASS] resp_valid deasserted during reset
    [PASS] req_ready asserted in IDLE after reset
    [PASS] resp_valid remains 0 in IDLE

  --- Test 2: Standard 5-Request Benchmark Demo Trace ---
    [PASS] Demo Req 1 (0x00000000): req_ready must be low while busy
    [PASS] Demo Req 1 (0x00000000): hit outcome (exp=0, got=0)
    [PASS] Demo Req 1 (0x00000000): returned data (exp=0x00000000, got=0x00000000)
    [PASS] Demo Req 2 (0x00000080): hit outcome (exp=0, got=0)
    [PASS] Demo Req 2 (0x00000080): returned data (exp=0x00000080, got=0x00000080)
    [PASS] Demo Req 3 (0x00000000): hit outcome (exp=1, got=1)
    [PASS] Demo Req 3 (0x00000000): returned data (exp=0x00000000, got=0x00000000)
    [PASS] Demo Req 4 (0x00000100): hit outcome (exp=0, got=0)
    [PASS] Demo Req 4 (0x00000100): returned data (exp=0x00000100, got=0x00000100)
    [PASS] Demo Req 5 (0x00000000): hit outcome (exp=1, got=1)
    [PASS] Demo Req 5 (0x00000000): returned data (exp=0x00000000, got=0x00000000)

  --- Test 3: Nonzero Word Offsets & Spatial Locality ---
    [PASS] Set 0 Block 0x40 Word 0 (Miss)
    [PASS] Set 0 Block 0x40 Word 1 (Hit)
    [PASS] Set 0 Block 0x40 Word 2 (Hit)
    [PASS] Set 0 Block 0x40 Word 3 (Hit)
    [PASS] Set 1 Word 2 Cold Miss (0x18)
    [PASS] Set 1 Word 2 Subsequent Hit (0x18)
    [PASS] Set 2 Word 3 Cold Miss (0x2C)
    [PASS] Set 2 Word 1 Spatial Hit (0x24)
    [PASS] Set 3 Word 1 Cold Miss (0x34)
    [PASS] Set 3 Word 1 Subsequent Hit (0x34)

  --- Test 4: Request-Address Mutation After Acceptance ---
    [PASS] Miss with req_addr changed to 0xFFFFFFFF (returned uncorrupted 0x00000204)
    [PASS] Hit with req_addr changed to 0x12345678 (returned uncorrupted 0x00000204)

  --- Test 5: Response Protocol & Idle Stability ---
    [PASS] 10 idle cycles with 0 spurious responses and continuous req_ready

  --- Test 6: Reset Clears Cache ---
    [PASS] Post-reset 0x40 is cold Miss

  ==================================================================
  Integration Verification Complete: 141 Passed, 0 Failed
  ==================================================================
  TEST RESULT: ALL 141 CHECKS PASSED SUCCESSFULLY
  ```
- **Known Limitations**:
  - Single outstanding request: The controller processes one request at a time (`req_ready = 0` while busy).
  - Combinational lower memory model in Phase I (no memory wait states).
- **Next Member**: **Prachee** (Direct-Mapped Cache Baseline: `rtl/cache_direct.v` following `docs/interface.md#4` and reusing `tb/mem_block_model.v`).


---

## Entry 4: Direct-Mapped Cache Baseline, Comparative Testbench, and Verified Conflict/Locality Evidence

- **Date**: 2026-11-15
- **Member**: **Prachee (comparison)**
- **Module Locations**:
  - `rtl/cache_direct.v`
  - `tb/tb_cache_direct.sv`
  - `tb/tb_cache_compare.sv`
  - `tb/traces/conflict_trace.hex`
  - `tb/traces/locality_trace.hex`
  - `scripts/run_cache_direct_test.sh`
  - `scripts/run_cache_compare.sh`
  - `docs/evidence/cache_comparison_evidence.md`
  - `docs/evidence/cache_comparison_sim.log`
- **Work Completed**:
  - Implemented synthesizable Verilog-2001 direct-mapped baseline module `rtl/cache_direct.v` strictly conforming to the public interface in `docs/interface.md#4` and `PROJECT_BRIEF.md#4.4`:
    - Geometry: 128 bytes total capacity, 8 sets x 1 way x 16 bytes/block.
    - 32-bit address decomposition: `addr[31:7]` (25-bit tag), `addr[6:4]` (3-bit set index -> 8 sets), `addr[3:2]` (2-bit word select -> 4 words), `addr[1:0]` (2-bit byte offset).
    - Valid bit array (`valid[7:0]`), tag memory array (`tag[0:7]`), and block data memory array (`data[0:7]`).
    - Combinational tag comparison, dual-path word selection (cached hit word mux vs incoming refill word mux).
    - 4-state controller FSM (`STATE_IDLE`, `STATE_LOOKUP`, `STATE_REFILL`, `STATE_RESP`) enforcing single outstanding request protocol, bus isolation on latched address, and exact 1-cycle `resp_valid` pulse.
  - Implemented self-checking integration testbench `tb/tb_cache_direct.sv` (30 passing assertions):
    - Synchronous reset and handshake protocol.
    - Standard 5-request conflict trace (all accesses mapping to Set 0 yielding 0% hit rate due to compulsory and conflict thrashing).
    - Multi-word selection across all 4 offsets and spatial hit validation.
    - Post-acceptance address bus mutation immunity.
    - Zero spurious responses during idle cycles.
    - Synchronous reset cache invalidation.
  - Implemented shared self-checking dual-cache comparison testbench `tb/tb_cache_compare.sv` (52 passing assertions):
    - Concurrent instantiation of `cache_2way` and `cache_direct`, each connected to an independent instance of `mem_block_model`.
    - Feeds both designs the exact same ordered request stream, accommodating independent ready and response timings.
    - Accepts each request exactly once per design and counts each response exactly once.
    - Verified Trace A (5-access Set 0 conflict trace): `cache_2way` achieves **2 hits / 5 accesses (40% hit rate)**; `cache_direct` achieves **0 hits / 5 accesses (0% hit rate)**.
    - Verified Trace B (6-access within-block spatial locality trace): both designs achieve **4 hits / 6 accesses (66.7% hit rate)** through multi-word block reuse.
    - Fully asserts returned 32-bit data words match `mem_block_model` on both hits and misses.
    - Includes per-trace hit/miss counters, timeout enforcement, and non-zero exit code on mismatch.
  - Created checked-in trace definitions `tb/traces/conflict_trace.hex` and `tb/traces/locality_trace.hex`.
  - Authored portable runners `scripts/run_cache_direct_test.sh` and `scripts/run_cache_compare.sh`.
  - Authored comprehensive empirical evidence report in `docs/evidence/cache_comparison_evidence.md`:
    - Tabulated actual simulation results for Trace A and Trace B.
    - Bitfield address mapping analysis across both architectures.
    - Architectural explanation detailing why Request 3 (`0x00`) asserts `touch_en` to flip Set 0's LRU victim pointer from Way 0 to Way 1, preserving `0x00` during Request 4's refill and enabling Request 5's cache hit.
    - Explanation of why the conflict trace hit rate applies to this trace.
    - Curated list of useful waveform signals for inspection in GTKWave.
  - Updated documentation in `tb/README.md` and `scripts/README.md`.
  - Executed staged review and created three substantive commits:
    1. Commit 1 (`fd3d8d7`): "Implement equal-capacity direct-mapped cache baseline" (`rtl/cache_direct.v`, `scripts/run_cache_direct_test.sh`, `tb/tb_cache_direct.sv`)
    2. Commit 2 (`7188fc6`): "Compare both cache designs on identical access traces" (`scripts/run_cache_compare.sh`, `tb/tb_cache_compare.sv`, `tb/traces/conflict_trace.hex`, `tb/traces/locality_trace.hex`)
    3. Commit 3: "Record verified conflict and locality comparison evidence" (`docs/evidence/cache_comparison_evidence.md`, `docs/evidence/cache_comparison_sim.log`, `tb/README.md`, `scripts/README.md`, `HANDOFF.md`)
- **Changed Files**:
  - `rtl/cache_direct.v`
  - `tb/tb_cache_direct.sv`
  - `tb/tb_cache_compare.sv`
  - `tb/traces/conflict_trace.hex`
  - `tb/traces/locality_trace.hex`
  - `scripts/run_cache_direct_test.sh`
  - `scripts/run_cache_compare.sh`
  - `docs/evidence/cache_comparison_evidence.md`
  - `docs/evidence/cache_comparison_sim.log`
  - `tb/README.md`
  - `scripts/README.md`
  - `HANDOFF.md`
- **Reproduction Steps for Kushal (Round 2) / Team**:
  ```bash
  # Ensure in repository root
  cd MCA-Project7-Team-5-1-MUX

  # 1. Run direct-mapped cache unit & integration test:
  ./scripts/run_cache_direct_test.sh

  # 2. Run shared comparison trace testbench:
  ./scripts/run_cache_compare.sh

  # 3. Full project regression suite:
  ./scripts/run_store_unit_test.sh
  ./scripts/run_cache_2way_integration_test.sh
  ./scripts/run_cache_direct_test.sh
  ./scripts/run_cache_compare.sh
  ```
- **Checks Actually Run**:
  - `iverilog -g2001 -Wall -s cache_direct rtl/cache_direct.v`: Verilog-2001 syntax check clean (0 errors).
  - `./scripts/run_store_unit_test.sh`: 51 passed, 0 failed.
  - `./scripts/run_cache_2way_integration_test.sh`: 141 passed, 0 failed.
  - `./scripts/run_cache_direct_test.sh`: 30 passed, 0 failed.
  - `./scripts/run_cache_compare.sh`: 52 passed, 0 failed.
  - Total assertions verified passing: **274 passed, 0 failed**.
- **Observed Results (Comparative Benchmark Summary)**:
  ```
  ==================================================================
  Starting Comparative Verification: cache_2way vs cache_direct
  ==================================================================

  --- TRACE A: Conflict Trace ---
      Addresses: 0x000, 0x080, 0x000, 0x100, 0x000
      All map to Set 0 in both designs.

    TRACE A Summary:
      2-Way  : 2 hits / 5 accesses = 40% hit rate
      Direct : 0 hits / 5 accesses = 0% hit rate

  --- TRACE B: Within-Block Locality Trace ---
      Addresses: 0x040, 0x044, 0x048, 0x04C, 0x0C0, 0x0C4
      0x040: 2way set=0, direct set=2
      0x0C0: 2way set=0, direct set=4 (different set in direct)
      Expected both: Miss Hit Hit Hit Miss Hit => 4/6 = 67%

    TRACE B Summary:
      2-Way  : 4 hits / 6 accesses = 66% hit rate
      Direct : 4 hits / 6 accesses = 66% hit rate

  ==================================================================
  Comparative Verification Complete: 52 Passed, 0 Failed
  ==================================================================
  TEST RESULT: ALL 52 CHECKS PASSED SUCCESSFULLY
  ```
- **Useful Waveform Signals for Debug & Inspection**:
  - Handshake: `tw_req_valid`, `tw_req_ready`, `tw_req_addr`, `tw_resp_valid`, `tw_resp_hit`, `tw_resp_data`
  - 2-Way Storage: `u_2way.u_store.way0_match`, `way1_match`, `hit`, `victim_way`, `lru_bit[0]`, `touch_en`, `fill_en`
  - Direct Array: `u_direct.tag_match`, `u_direct.valid[7:0]`, `u_direct.tag[0]`, `u_direct.set_idx`
  - Memory: `tw_mem_block_addr`, `tw_mem_block_data`
- **Known Limitations**:
  - Single outstanding transaction handshake (no pipelining).
  - Combinational block-memory model without variable DRAM access latency.
- **Next Member**: **Kushal (verification)** (Round 2: `tb/` testbenches, comparative simulation scripts in `scripts/`).


---

## Entry 5: System Regressions, Master Full-Prototype Workflow, and Demo Waveform Evidence

- **Date**: 2026-11-16
- **Member**: **Kushal (verification)** (Round 2, Phase I Handoff 4)
- **Module & Script Locations**:
  - `tb/tb_system_regression.sv`
  - `scripts/run_system_regression.sh`
  - `scripts/run_all.sh`
  - `tb/tb_demo_waveform.sv`
  - `scripts/generate_demo_waveform.sh`
  - `docs/evidence/cache_2way_demo.vcd`
  - `docs/evidence/demo_waveform_evidence.md`
  - `README.md`
  - `tb/README.md`
  - `scripts/README.md`
  - `docs/evidence/README.md`
- **Work Completed**:
  1. **Targeted Self-Checking System Regressions (`tb/tb_system_regression.sv`)**:
     - Implemented 344 passing assertions covering uncovered system-level behaviors across both caches:
       - **Reset After Population**: Fully populated all 8 blocks in `cache_2way` (Sets 0..3, Ways 0..1) and all 8 sets in `cache_direct`; verified all 8 blocks were active hits; asserted synchronous reset; verified `req_ready == 0`, `resp_valid == 0`, and verified requests asserted during reset were safely suppressed.
       - **Post-Reset Cold Accesses**: Re-queried the exact populated addresses post-reset; verified 100% of accesses were cold misses (`resp_hit == 0`), proving complete invalidation; verified memory refills restored valid data.
       - **First-Ready-Cycle Back-to-Back Acceptance**: Verified streaming requests without idle bubble cycles; verified master presenting `req_valid = 1` on the exact cycle `req_ready` asserts is accepted immediately with zero latency penalty.
       - **Cross-Set LRU Independence**: Verified that recency updates on Set 0 (flipping Set 0 LRU victim pointer from Way 0 to Way 1) do not leak into Set 2; verified heavy interleaved traffic on Sets 1, 2, and 3 leaves Set 2's Way 0 victim pointer untouched; verified Set 2 miss evicts Way 0 and preserves Way 1.
       - **Direct-Mapped Regressions**: Full-population reset, cold access invalidation, and back-to-back streaming verification for `cache_direct`.
  2. **Master Verification Workflow (`scripts/run_all.sh`)**:
     - Built single unified runner executing all 5 project verification suites in sequence:
       1. `run_store_unit_test.sh` (51 assertions)
       2. `run_cache_2way_integration_test.sh` (141 assertions)
       3. `run_cache_direct_test.sh` (30 assertions)
       4. `run_cache_compare.sh` (52 assertions)
       5. `run_system_regression.sh` (344 assertions)
     - Added actionable dependency diagnostics checking for `iverilog` and `vvp` with OS-specific installation instructions (`brew install icarus-verilog` / `apt-get install iverilog`).
     - Preflight validation ensuring all required source, test, and script files are present.
     - Safe pipe handling under `set -euo pipefail` without SIGPIPE issues.
     - Clean exit traps maintaining all simulation outputs in ignored `sim_build/` directory.
     - Clean temporary checkout verification: Successfully verified `./scripts/run_all.sh` inside an isolated temporary directory created via `git archive`, confirming zero missing dependencies or untracked inputs.
  3. **Reproducible 5-Request Demo Waveform & Eviction Analysis**:
     - Authored `tb/tb_demo_waveform.sv` and automation runner `scripts/generate_demo_waveform.sh`.
     - Generated reproducible VCD waveform file `docs/evidence/cache_2way_demo.vcd` (7.1 KB).
     - Authored camera-ready documentation in `docs/evidence/demo_waveform_evidence.md`:
       - Real signal paths and hierarchical signal dictionary.
       - Exact nanosecond cycle timeline for all 5 demo accesses (`0x00`, `0x80`, `0x00`, `0x100`, `0x00`).
       - Decisive eviction proof: Pinpointed Request 3's `touch_en` strobe at $t = 125\text{ ns}$ flipping Set 0's LRU victim bit to 1, causing Request 4's miss at $t = 145\text{ ns}$ to evict Way 1 (`0x80`) at cycle 15.5 ($t = 156\text{ ns}$), preserving Way 0 (`0x00`) to deliver Request 5's hit at $t = 196\text{ ns}$.
       - Camera-ready presentation script with timing cues for Vani's demo video.
  4. **Documentation & Navigation Refresh**:
     - Updated `README.md` with toolchain prerequisites, the master verification command `./scripts/run_all.sh`, and direct links to all verification evidence.
     - Updated `scripts/README.md`, `tb/README.md`, and `docs/evidence/README.md`.
- **Verified Figures for IEEE Report & Demo Video**:
  - `cache_2way_store` Unit Tests: **51 / 51 passed (100%)**
  - `cache_2way` Integration Tests: **141 / 141 passed (100%)**
  - `cache_direct` Baseline Tests: **30 / 30 passed (100%)**
  - Comparative Trace Harness (`tb_cache_compare.sv`): **52 / 52 passed (100%)**
    - Trace A (5-Access Conflict): `cache_2way` **40% hit rate** (2/5) vs `cache_direct` **0% hit rate** (0/5, 100% thrashing).
    - Trace B (6-Access Locality): `cache_2way` **66.7% hit rate** (4/6) vs `cache_direct` **66.7% hit rate** (4/6).
  - Targeted System Regressions (`tb_system_regression.sv`): **344 / 344 passed (100%)**
  - **Grand Total Verified Across All 5 Suites**: **618 / 618 passed, 0 failed (100% pass rate)**.
- **Action Items & Guidance for Vani (report/demo package)**:
  1. **IEEE Progress Report (`report/`)**:
     - Draft standard two-column conference paper in LaTeX.
     - Section Outline: Abstract, Literature Review, Proposed Solution (architecture block diagrams, FSM states, and LRU datapath), Results & Individual Contributions, References.
     - Cite verified figures: 618 total passing assertions across 5 suites, 40% vs 0% conflict benchmark comparison, cycle 15.5 decisive eviction timestamp.
  2. **Prototype Demo Video (`demo/`)**:
     - Maximum 5 minutes duration.
     - Introduce all 5 members by name: Krishna, Apoorva, Prachee, Kushal, Vani.
     - Demonstrate working prototype: RTL walkthrough (`rtl/cache_2way.v`, `rtl/cache_2way_store.v`, `rtl/cache_direct.v`), block diagrams from `docs/architecture.md`, and GTKWave simulation of `docs/evidence/cache_2way_demo.vcd` using the narration script in `docs/evidence/demo_waveform_evidence.md`.
  3. **Submission Package**:
     - Verify report PDF compiles cleanly (`report/report.pdf`).
     - Submit GitHub repository URL (`https://github.com/Kushal425/MCA-Project7-Team-5-1-MUX.git`) through the official course form prior to November 16, 2026, 11:59 PM IST.
- **Next Member**: **Vani (report/demo package)**.
