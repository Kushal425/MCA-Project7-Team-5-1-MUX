# Phase I Prototype Demonstration — 5-Member Recording Script

**Project**: Modern Computer Architecture (MCA) — Project 7: 2-Way Set-Associative Cache with LRU  
**Total Target Duration**: 4 minutes 30 seconds (maximum allowed: 5:00)  
**Team Members**:
1. **Kushal Sarkar** (Scaffold, System Verification & Master Regression)
2. **Krishna Pramod Dubale** (Storage Submodule, Parallel Tag Matching & LRU Datapath)
3. **Apoorva Choudhary** (Top-Level Controller FSM & Memory Refill Datapath)
4. **Prachee Dhar** (Direct-Mapped Baseline & Comparative Benchmark Analysis)
5. **Vani Rudra** (Live Simulation, Waveform Evidence, IEEE Report & Wrap-up)

---

## 1. Quick Member Allocation & Timing Summary

| Speaker | Member Name | Role & Topic | Allotted Time | Cumulative Time |
| :---: | :--- | :--- | :---: | :---: |
| **1** | **Kushal Sarkar** | Project Title, Introduces All 5 Names, Motivation & Address Partitioning | ~50 sec | 0:00 – 0:50 |
| **2** | **Krishna Pramod Dubale** | Storage Submodule, Dual-Way Arrays, Parallel Tag Matching & LRU Datapath | ~50 sec | 0:50 – 1:40 |
| **3** | **Apoorva Choudhary** | Cache Controller FSM (4 States), Request Handshake & Memory Refill | ~50 sec | 1:40 – 2:30 |
| **4** | **Prachee Dhar** | Direct-Mapped Baseline & Trace Comparison (40% vs 0% Conflict Hit Rate) | ~55 sec | 2:30 – 3:25 |
| **5** | **Vani Rudra** | Live Regression Run (`run_all.sh`), GTKWave Waveform Walkthrough & Wrap-up | ~65 sec | 3:25 – 4:30 |
| **Total** | | | **4:30** | *(Well under 5:00 max)* |

---

## 2. Pre-Recording Setup: Windows to Open on Screen

Before hitting record, have these 4 windows open and ready to switch between (using `Cmd + Tab`):

1. **Window 1 (Browser or Preview)**:
   - Tab 1: `README.md` showing the **Team Members Table** with all 5 names.
   - Tab 2: `docs/architecture.md` showing the **Address Field Decomposition** and **Datapath Block Diagram**.
2. **Window 2 (Code Editor / VS Code)**:
   - Tab 1: `rtl/cache_2way_store.v` (Storage arrays, comparators, LRU registers).
   - Tab 2: `rtl/cache_2way.v` (Controller FSM states, refill datapath).
   - Tab 3: `rtl/cache_direct.v` (Direct-mapped baseline).
   - Tab 4: `docs/evidence/cache_comparison_evidence.md` (Trace comparison tables).
3. **Window 3 (Clean Terminal)**:
   - Working directory at project root: `MCA-Project7-Team-5-1-MUX/`.
   - Have the command `./scripts/run_all.sh` typed and ready to press Enter.
4. **Window 4 (Waveform Viewer inside VS Code — Recommended)**:
   - **How to set it up (Takes 10 seconds, no GTKWave installation needed)**:
     1. In VS Code, press `Cmd + Shift + X` (Extensions).
     2. Search for **`WaveTrace`** (or **`VCD Viewer`**) and click **Install**.
     3. In the Explorer, click on [`docs/evidence/cache_2way_demo.vcd`](docs/evidence/cache_2way_demo.vcd) to open it.
     4. Press `Cmd + B` to collapse the left sidebar so the waveform fills the entire screen.
     5. Key signals visible in viewer:
        - `dut.req_addr[31:0]` (shows the 5 requests: `0` $\rightarrow$ `80` $\rightarrow$ `0` $\rightarrow$ `100` $\rightarrow$ `0`)
        - `touch_en` (strobe updating recency on hit)
        - `fill_en` (strobe evicting victim line on miss)
        - `way0_match` & `way1_match` (parallel tag match indicators)
        - `resp_hit` (hit output: high on Requests 3 & 5)
        - `req_ready`, `resp_valid`, `clk`, `rst`
     6. Zoom the timescale so 0 ns to 220 ns fits across the screen.

---

## 3. Cue-by-Cue Script for Each Team Member

---

### 🎙️ Speaker 1: Kushal Sarkar (0:00 – 0:50 | ~50 seconds)
**Topic**: Project Title, Names of All 5 Members, Motivation & Address Partitioning

* **What to show on screen:**
  * `0:00 – 0:25`: Show `README.md` on screen highlighting the Team Table with all 5 names.
  * `0:25 – 0:50`: Switch to `docs/architecture.md`, pointing to the **Address Field Partitioning** diagram.

* **Spoken Lines:**
  > *"Hello everyone. Welcome to the Phase I prototype demonstration for Project 7: a Synthesizable 2-Way Set-Associative Cache with LRU Replacement, developed for the Modern Computer Architecture course.*
  >
  > *Our group consists of five members:*
  > 1. *I am **Kushal Sarkar**, responsible for architecture scaffolding and system verification;*
  > 2. ***Krishna Pramod Dubale**, who implemented the storage arrays and LRU replacement datapath;*
  > 3. ***Apoorva Choudhary**, who designed the top-level cache controller FSM;*
  > 4. ***Prachee Dhar**, who implemented our direct-mapped baseline for comparison;*
  > 5. *And **Vani Rudra**, who compiled our IEEE project report and verification evidence.*
  >
  > *Our objective is to design a synthesizable 128-byte cache organized into 4 sets with 2 ways per set and 16-byte blocks. As shown in our address decomposition, a 32-bit address is partitioned into a 26-bit tag, a 2-bit set index, a 2-bit word select, and 2 byte-offset bits. Both designs implement a standardized request-response handshake.*
  >
  > *I will now pass over to Krishna to present the storage and LRU datapath."*

---

### 🎙️ Speaker 2: Krishna Pramod Dubale (0:50 – 1:40 | ~50 seconds)
**Topic**: Storage Submodule, Dual-Way Arrays, Parallel Tag Comparators & LRU State

* **What to show on screen:**
  * `0:50 – 1:15`: Show `rtl/cache_2way_store.v` in VS Code. Point to `tag_way0`, `tag_way1`, data RAMs, and parallel comparators (`way0_match`, `way1_match`, `hit`).
  * `1:15 – 1:40`: Scroll down to the victim selection and `lru_bit` assignment logic.

* **Spoken Lines:**
  > *"Thank you, Kushal. I am **Krishna Pramod Dubale**, and I implemented the internal storage submodule, `cache_2way_store.v`.*
  >
  > *In this module, each of the 4 sets maintains independent Way 0 and Way 1 data RAMs and tag registers. On every cycle, combinational comparators check both ways in parallel against the incoming tag. If either way matches and is valid, `hit` asserts immediately along with `hit_way`.*
  >
  > *For line replacement, we maintain a dedicated 1-bit LRU register per set. Our allocation policy enforces deterministic priority: if Way 0 is empty, it is allocated first; if Way 1 is empty, it is allocated next. When both ways are full, `victim_way` is governed strictly by the set's `lru_bit`.*
  >
  > *When a hit occurs, the controller pulses `touch_en`, updating `lru_bit` to point to the other way as the next candidate for eviction. On a refill, `fill_en` writes the incoming block and flips recency away from the newly written way.*
  >
  > *This datapath passes all 51 storage unit tests cleanly. I'll now hand over to Apoorva for the controller FSM."*

---

### 🎙️ Speaker 3: Apoorva Choudhary (1:40 – 2:30 | ~50 seconds)
**Topic**: Controller FSM (4 States), Request Handshake, Bus Isolation & Memory Refill

* **What to show on screen:**
  * `1:40 – 2:05`: Show the Controller FSM state diagram in `docs/architecture.md` (IDLE $\rightarrow$ LOOKUP $\rightarrow$ REFILL $\rightarrow$ RESP).
  * `2:05 – 2:30`: Switch to `rtl/cache_2way.v` in VS Code. Highlight the `saved_addr` latch register and the handshake logic.

* **Spoken Lines:**
  > *"Thank you, Krishna. I am **Apoorva Choudhary**, and I implemented the top-level cache controller in `cache_2way.v`.*
  >
  > *Our controller coordinates cache transactions using a 4-state Finite State Machine: IDLE, LOOKUP, REFILL, and RESP.*
  >
  > *In STATE_IDLE, `req_ready` is high. When a valid request arrives, the controller latches `req_addr` into `saved_addr` and pulls `req_ready` low. This isolates the bus, ensuring that changing the address during processing has zero impact on the in-flight access.*
  >
  > *In STATE_LOOKUP, if `cache_2way_store` reports a hit, the FSM pulses `touch_en` for one cycle, latches the cached word, and transitions to RESP. On a miss, it transitions to STATE_REFILL, presents the 16-byte aligned base address to lower memory, and asserts `fill_en` to update the victim way.*
  >
  > *Importantly, our FSM preserves authentic miss reporting: `resp_hit` always returns 0 for a miss, even though the cache is refilled before response delivery. Finally, in STATE_RESP, the cache produces an exact 1-cycle pulse of `resp_valid` and returns to IDLE.*
  >
  > *Now, Prachee will discuss our direct-mapped baseline and comparative results."*

---

### 🎙️ Speaker 4: Prachee Dhar (2:30 – 3:25 | ~55 seconds)
**Topic**: Direct-Mapped Baseline, 40% vs 0% Conflict Hit Rate, Spatial Locality Trace

* **What to show on screen:**
  * `2:30 – 2:50`: Show `rtl/cache_direct.v` in VS Code, highlighting the 8 sets $\times$ 1 way organization.
  * `2:50 – 3:25`: Switch to `docs/evidence/cache_comparison_evidence.md`, showing the **Trace A (Conflict)** and **Trace B (Locality)** summary tables.

* **Spoken Lines:**
  > *"Thank you, Apoorva. I am **Prachee Dhar**, and I designed the direct-mapped cache baseline, `cache_direct.v`, and our comparative evaluation suite.*
  >
  > *To provide a completely fair comparison, `cache_direct` has the identical 128-byte data capacity and uses the exact same interface ports as our 2-way design, organized as 8 sets of 1 block each.*
  >
  > *In our comparative testbench, `tb_cache_compare.sv`, we run both caches side-by-side against identical memory access streams.*
  >
  > *In Trace A — an alternating conflict trace on Set 0 — the direct-mapped cache suffers 100% thrashing, achieving **0 hits out of 5 requests (0% hit rate)** because every access overwrites the single resident line.*
  >
  > *In contrast, our 2-way cache achieves **2 hits out of 5 (40% hit rate)** by retaining both active lines in the set using LRU replacement.*
  >
  > *Under Trace B — accessing consecutive words within a block — both caches achieve an identical **66.7% hit rate**, proving that both exploit spatial locality equally, and that the performance gain in Trace A is purely due to associativity and LRU.*
  >
  > *I will now hand over to Vani to demonstrate the live simulation and waveform evidence."*

---

### 🎙️ Speaker 5: Vani Rudra (3:25 – 4:30 | ~65 seconds)
**Topic**: Live Test Execution, VS Code Waveform Walkthrough, IEEE Paper & Wrap-up

* **What to show on screen:**
  * `3:25 – 3:45`: Switch to **Terminal**. Press Enter on `./scripts/run_all.sh`. Show all 5 suites passing with **618 passed, 0 failed**.
  * `3:45 – 4:15`: Switch to **VS Code** with `cache_2way_demo.vcd` open full-width (`Cmd + B` to hide sidebar):
    * Point cursor at **`dut.req_addr[31:0]`**: show the sequence of 5 requests in hex: `0` $\rightarrow$ `80` $\rightarrow$ `0` $\rightarrow$ `100` $\rightarrow$ `0`.
    * Point cursor at **Request 3** (second `0` at ~115–125 ns): point to `way0_match = 1` and `touch_en` pulsing high for 1 cycle.
    * Point cursor at **Request 4** (`100` at ~145–156 ns): point to `fill_en` pulsing high, evicting Way 1 (`0x80`) while keeping Way 0 (`0x00`) intact.
    * Point cursor at **Request 5** (third `0` at ~185–196 ns): point to `resp_hit` pulsing high to **1**, confirming the hit!
  * `4:15 – 4:30`: Briefly switch to `report/phase1-report.pdf` showing the compiled IEEE Conference paper, then return to title slide.

* **Spoken Lines:**
  > *"Thank you, Prachee. I am **Vani Rudra**.*
  >
  > *Let's run our prototype live. In the terminal, I execute our master regression runner: `./scripts/run_all.sh`.*
  >
  > *(Wait 2-3 seconds as test runs)*
  >
  > *As you can see, all five test suites execute sequentially, and all **618 automated assertions pass with zero failures**.*
  >
  > *Now let's examine the decisive waveform proof right here in VS Code.*
  >
  > *On `dut.req_addr`, we see our five requests: 0, 80, 0, 100, and 0.*
  >
  > *At 115 nanoseconds on Request 3, address 0 hits on Way 0. Notice `way0_match` goes high and `touch_en` pulses for one cycle. This critical recency update marks Way 1 as the next victim, shielding address 0 from eviction.*
  >
  > *When Request 4 arrives for 0x100 at 145 nanoseconds, it misses. Because of the recency touch, `fill_en` at 156 nanoseconds evicts Way 1, leaving Way 0 holding address 0 completely undisturbed.*
  >
  > *Therefore, on Request 5, re-reading address 0 scores an immediate hit with `resp_hit` asserting high! This visual trace directly proves that our LRU replacement prevents the thrashing that crippled the direct-mapped cache.*
  >
  > *Finally, our project report is compiled in standard IEEE conference format as `phase1-report.pdf`, and all synthesizable Verilog, testbenches, and verification logs are checked into our GitHub repository.*
  >
  > *Thank you for your time!"*

---

## 4. Key Tips for the Recording

1. **Resolution**: Set recording software (OBS, QuickTime, or Zoom) to **1080p** (1920x1080).
2. **Audio**: Keep microphone levels balanced across all 5 team members.
3. **Pacing**: Speak naturally at conversational speed. Each speaker has 50–60 seconds, which allows comfortable delivery of 5 to 6 sentences without rushing.
4. **Pointer**: Use your mouse cursor to point to the specific signal in GTKWave or line of RTL being discussed.
