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
