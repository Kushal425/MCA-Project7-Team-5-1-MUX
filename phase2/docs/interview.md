# Phase II Interview Handout
MCA Project 7 · Two-Way Set-Associative Cache with LRU · Team 5, Rishihood University
**Prepared by:** Vani Rudra (`phase2/vani-final-report`)

---

## Overview

The Phase II interview covers the complete lifecycle of the project:
RTL design, verification methodology, benchmark evaluation, and FPGA
implementation results. Each team member defends their own component and must
be able to answer cross-cutting questions about the architecture.

**Rehearsal target:** 20 minutes total, about 4 minutes per speaker. Use the instructor’s timing for the actual interview.

**Live Demo:** Run `./scripts/run_all.sh` from the repo root; open
`phase1/evidence/cache-2way-demo.vcd` in VS Code with the WaveTrace extension
(or the Zoro waveform viewer shown in the project screenshots).

---

## Five-Speaker Breakdown

| # | Speaker | Section | Key File(s) |
|---|---------|---------|-------------|
| 1 | **Kushal Sarkar** | System Integration & FPGA | `tb/tb_system_regression.sv`, `phase1/evidence/` |
| 2 | **Krishna Pramod Dubale** | LRU Storage Design | `rtl/cache_2way_store.v`, `tb/tb_cache_2way_store.sv` |
| 3 | **Apoorva Choudhary** | FSM Controller Verification | `tb/tb_cache_2way.sv` |
| 4 | **Prachee Dhar** | Comparative Benchmarks | `phase2/docs/cache-benchmarks.md`, `tb/traces/` |
| 5 | **Vani Rudra** | Report, Figures & AMAT Analysis | `phase2/report/phase2-report.tex`, `phase2/docs/interview.md` |

---

## Live Demo Cues

1. **Start the demo**
   ```bash
   cd /path/to/MCA-Project7-Team-5-1-MUX
   ./scripts/run_all.sh
   ```
   Expected output: all six suites pass (20,193 checks).

2. **Show the waveform** — open `phase1/evidence/cache-2way-demo.vcd` in VS Code (WaveTrace extension).
   - Point to the accepted third request at 115 ns and its registered hit response visible at the 126 ns sample.
   - Show the fourth request replacing Way 1 at 165 ns and the final hit visible at the 196 ns sample.
   - Highlight the `state[1:0]` transitions: `00→01→10→11→00` (IDLE→LOOKUP→REFILL→RESP→IDLE).

3. **Show the benchmark comparison** — open `phase2/docs/cache-benchmarks.md`.
   - Highlight Trace A (40% vs 0%) and Trace C (87.5% vs 0%) in the results table.
   - Draw attention to the set-index anomaly (Trace E: 0% vs 30%).

---

## Speaker 1 — Kushal Sarkar: System Integration & FPGA

**What you own:** `tb/tb_system_regression.sv` (344 assertions), waveform
evidence (`phase1/evidence/cache-2way-demo.vcd`), and the [FPGA comparison flow](fpga-results.md).

**Likely questions:**

1. *"Explain your verification methodology. How did you ensure end-to-end correctness?"*
   > Run all six testbench suites via `run_all.sh`. The system regression checks reset, back-to-back requests and whether traffic in one set changes replacement in another. A failed check causes the runner to exit with an error.

2. *"What does the waveform show at t=115 ns and t=196 ns?"*
   > The third request for `0x00` is accepted at 115 ns and its hit is visible at the 126 ns sample. The fourth request for `0x100` evicts Way 1 at 165 ns. The last request hits on `0x00`, as observed at 196 ns.

3. *"Why does req_ready deassert during STATE_REFILL?"*
   > The FSM can only handle one request at a time. `req_ready` is combinationally `high` only in `STATE_IDLE`, so during LOOKUP/REFILL/RESP the master must hold its request or buffer it externally.

4. *"What FPGA device and tools did you use?"*
   > We ran Yosys and nextpnr out of context on an ECP5 LFE5U-25F. Both designs met the 100 MHz target. The two-way estimate was 102.64 MHz with 1,817 logic cells. The direct-mapped estimate was 137.55 MHz with 548 logic cells.

---

## Speaker 2 — Krishna Pramod Dubale: LRU Storage Design

**What you own:** `rtl/cache_2way_store.v` (tag, valid, data, LRU arrays),
`tb/tb_cache_2way_store.sv` (51 assertions).

**Likely questions:**

1. *"How does the LRU bit update differ on a hit versus a refill?"*
   > On a **hit** in Way *w*: `lru_bit <= 1 - w` (point away from the way just used, marking the other way as LRU victim).  
   > On a **miss/refill**: the selected way is the first invalid slot, or the way indicated by `lru_bit` if both are valid. The bit then points to the other way.

2. *"What happens if both ways are invalid (cold start)?"*
   > The victim logic explicitly prefers invalid Way 0, then invalid Way 1. It uses the LRU bit once both ways are valid.

3. *"Why use 1 bit per set rather than a full recency counter?"*
   > With exactly 2 ways, 1 bit encodes perfect LRU: it tracks which way was used more recently. A counter would require log2(2)=1 bit anyway, so there is no information gain from a larger counter.

4. *"How did you test the double-eviction edge case?"*
   > The unit test checks both victim directions and that a hit refreshes recency. The stress test compares the RTL against an independently ordered pair of resident entries for each set.

---

## Speaker 3 — Apoorva Choudhary: FSM Controller Verification

**What you own:** `tb/tb_cache_2way.sv` (276 checks covering FSM
transitions, hit/miss flags, `resp_data` correctness, `req_ready` behaviour).

**Likely questions:**

1. *"Why does the FSM latch req\_addr into saved\_addr? What happens if it doesn't?"*
   > The request interface only guarantees `req_addr` is stable while `req_valid && req_ready` is true (the acceptance cycle). After that, the master may change `req_addr`. `saved_addr` holds the latched address so LOOKUP and REFILL can operate on the correct address even if the master already changed its outputs.

2. *"Walk me through the FSM for a cache miss."*
   > `STATE_IDLE`: accept request, latch `saved_addr`. → `STATE_LOOKUP`: compare tag; miss detected. → `STATE_REFILL`: write the block into the selected way and update tag, valid and LRU state. → `STATE_RESP`: assert `resp_valid=1`, `resp_hit=0`, `resp_data` from refilled block. → `STATE_IDLE`.

3. *"How did you verify that resp\_data is correct on a spatial hit (W1, W2, W3 of a refilled block)?"*
   > After a cold miss on W0 of a block, the testbench sends W1, W2, W3 of the same block. Assertions check `resp_hit=1` and `resp_data == mem_block_data[word_select]` for each word offset.

4. *"How many cycles elapse before the receiver samples a response?"*
   > Count from the acceptance edge. On a hit the cache raises the response after one edge and the receiver samples it at the second. A miss adds one REFILL cycle, so the receiver samples it at the third edge.

---

## Speaker 4 — Prachee Dhar: Comparative Benchmarks

**What you own:** `tb/tb_cache_compare.sv`, `tb/traces/` (5 trace files),
`scripts/run_cache_compare.sh`, `phase2/docs/cache-benchmarks.md`.

**Likely questions:**

1. *"Why does direct-mapped outperform 2-way on Trace E (3-block cycle)?"*
   > Addresses `0x00`, `0x40`, `0x80` all map to Set 0 in the 2-way cache (bit 6 is a tag bit, not a set-index bit). Three blocks in a 2-way set causes continuous LRU eviction of all three. In direct-mapped, bit 6 IS a set-index bit: `0x40` goes to Set 4 while `0x00` and `0x80` share Set 0. Only the Set-0 pair thrashes; `0x40` hits stably, giving 30% hit rate.

2. *"Why are your traces loaded from disk rather than hardcoded in the testbench?"*
   > On-disk traces (`.hex` files via `$fopen`/`$fgets`) let both designs replay the same checked-in addresses. We can add a workload by changing the trace file.

3. *"What does Trace C prove beyond Trace A?"*
   > Trace A (5 accesses) shows the conflict-miss effect but has only 2 hits in 2-way. Trace C (16 alternating accesses) shows the same pattern over more requests: after the first 2 cold misses, all 14 subsequent accesses hit in 2-way (87.5%) while direct-mapped continues to thrash (0%).

4. *"Why do Traces B and D give identical hit rates for both designs?"*
   > Spatial locality within a 16-byte block is determined by block size, not associativity. Both caches have identical 16-byte blocks. Consecutive word accesses within a fetched block hit in both caches identically regardless of tag structure or set index.

---

## Speaker 5 — Vani Rudra: Report, Figures & AMAT Analysis

**What you own:** `phase2/report/phase2-report.tex` (this IEEE report),
`phase2/docs/interview.md` (this file).

**Likely questions:**

1. *"What are the AMAT implications of the 40% vs. 0% hit rate difference (Trace A)?"*
   > AMAT = t\_hit + (1 − h) × M\_p.  
   > 2-way: 2.0 + (1 − 0.40) × 20 = **14.0 cycles**.  
   > Direct: 2.0 + (1 − 0.00) × 20 = **22.0 cycles**.  
   > Under that assumed penalty, the modeled average drops from 22 to 14 cycles, about 36%.

2. *"Why is the combinational memory model a limitation?"*
   > The testbench memory returns a 128-bit (16-byte) block combinationally. The three-cycle miss therefore measures the controller with that model. The 20-cycle miss penalty is an assumption for AMAT analysis.

3. *"Explain the address decomposition. Why does the 2-way cache have a larger tag?"*
   > Both caches address 128 bytes in 8 blocks of 16 bytes. 2-way uses 4 sets (2 bits: addr[5:4]), leaving 26 bits for the tag (addr[31:6]). Direct-mapped uses 8 sets (3 bits: addr[6:4]), leaving 25 bits for the tag (addr[31:7]). The extra set-index bit in direct-mapped is what causes addr[6] to separate `0x40` from `0x00` in Set geometry.

4. *"What do the 20,193 checks cover?"*
   > The six suites check directed storage behavior, the independent LRU model, controller transactions, direct-mapped behavior, the same five traces on both designs and system regressions. The total is a count of executed simulation checks.

---

## Architecture Quick-Reference Card

| Item | 2-Way (`cache_2way`) | Direct (`cache_direct`) |
|------|----------------------|------------------------|
| Total capacity | 128 bytes | 128 bytes |
| Associativity | 2 ways | 1 way |
| Sets | 4 | 8 |
| Block size | 16 bytes (4 × 32-bit words) | 16 bytes (4 × 32-bit words) |
| Tag bits | addr[31:6] | addr[31:7] |
| Set index | addr[5:4] | addr[6:4] |
| Word select | addr[3:2] | addr[3:2] |
| Replacement | 1-bit LRU per set | Direct overwrite |
| FSM states | IDLE / LOOKUP / REFILL / RESP | IDLE / LOOKUP / REFILL / RESP |
| Hit latency | 2 cycles | 2 cycles |
| Miss latency | 3 cycles (combinational mem) | 3 cycles (combinational mem) |

---

## Run Commands for Demo

```bash
# Run all verification suites
./scripts/run_all.sh

# Run only the benchmark comparison
./scripts/run_cache_compare.sh

# View waveform in VS Code (requires WaveTrace extension)
# File → Open → phase1/evidence/cache-2way-demo.vcd

# Compile the Phase II report
(cd phase2/report && tectonic phase2-report.tex)
```

---
