# Phase II Interview Handout
# MCA Project 7 — 1-MUX Cache Design

**Team 5 — Rishihood University MCA Programme, 2024–25**
**Prepared by:** Vani Rudra (`phase2/vani-final-report`)

---

## Overview

The Phase II interview covers the complete lifecycle of the project:
RTL design, verification methodology, benchmark evaluation, and FPGA
synthesis (pending). Each team member defends their own component and must
be able to answer cross-cutting questions about the architecture.

**Duration:** ~20 minutes total (~4 minutes per speaker).  
**Live Demo:** Run `./scripts/run_all.sh` from the repo root; open
`docs/evidence/cache_2way_demo.vcd` in VS Code with the WaveTrace extension
(or the Zoro waveform viewer shown in the project screenshots).

---

## Five-Speaker Breakdown

| # | Speaker | Section | Key File(s) |
|---|---------|---------|-------------|
| 1 | **Kushal Sarkar** | System Integration & FPGA | `tb/tb_system_regression.sv`, `docs/evidence/` |
| 2 | **Krishna Pramod Dubale** | LRU Storage Design | `rtl/cache_2way_store.v`, `tb/tb_lru_unit.sv` |
| 3 | **Apoorva Choudhary** | FSM Controller Verification | `tb/tb_cache_2way.sv` |
| 4 | **Prachee Dhar** | Comparative Benchmarks | `docs/phase2/cache-benchmarks.md`, `tb/traces/` |
| 5 | **Vani Rudra** | Report, Figures & AMAT Analysis | `report/phase2/main.tex`, `docs/phase2/interview.md` |

---

## Live Demo Cues

1. **Start the demo**
   ```bash
   cd /path/to/MCA-Project7-Team-5-1-MUX
   ./scripts/run_all.sh
   ```
   Expected output: all 5 suites pass (618 assertions total).

2. **Show the waveform** — open `docs/evidence/cache_2way_demo.vcd` in VS Code (WaveTrace extension).
   - Point to `req_valid` going high at t=0.
   - Point to `resp_valid` going high at t=20 ns (hit) or t=30 ns (miss).
   - Highlight the `state[1:0]` transitions: `00→01→10→11→00` (IDLE→LOOKUP→REFILL→RESP→IDLE).

3. **Show the benchmark comparison** — open `docs/phase2/cache-benchmarks.md`.
   - Highlight Table 2 (Trace A: 40% vs 0%) and Table 4 (Trace C: 87.5% vs 0%).
   - Draw attention to the set-index anomaly (Trace E: 0% vs 30%).

---

## Speaker 1 — Kushal Sarkar: System Integration & FPGA

**What you own:** `tb/tb_system_regression.sv` (344 assertions), waveform
evidence (`docs/evidence/cache_2way_demo.vcd`), `HANDOFF.md`, FPGA synthesis.

**Likely questions:**

1. *"Explain your verification methodology. How did you ensure end-to-end correctness?"*
   > Run all five testbench suites via `run_all.sh`. Each suite uses `$display` + `if (!expr) $fatal` to report assertion failures with file/line references. The 344 regression assertions cover all address boundaries, back-to-back requests, and reset behaviour.

2. *"What does the waveform show at t=115 ns and t=196 ns?"*
   > At t=115 ns: `resp_valid` rises with `resp_hit=1` for the third access (0x00 returns to cache). At t=196 ns: `resp_valid` rises with `resp_hit=0` for the miss on 0x100 (LRU evicts Way 1).

3. *"Why does req_ready deassert during STATE_REFILL?"*
   > The FSM can only handle one request at a time. `req_ready` is combinationally `high` only in `STATE_IDLE`, so during LOOKUP/REFILL/RESP the master must hold its request or buffer it externally.

4. *"What FPGA device and tool are you targeting?"*
   > Xilinx/AMD Artix-7, Vivado 2023.2, 100 MHz clock constraint. Synthesis results are pending — the RTL is complete and synthesisable.

---

## Speaker 2 — Krishna Pramod Dubale: LRU Storage Design

**What you own:** `rtl/cache_2way_store.v` (tag, valid, data, LRU arrays),
`tb/tb_lru_unit.sv` (51 assertions).

**Likely questions:**

1. *"How does the LRU bit update differ on a hit versus a refill?"*
   > On a **hit** in Way *w*: `lru_bit <= 1 - w` (point away from the way just used, marking the other way as LRU victim).  
   > On a **miss/refill**: the way selected for eviction is `lru_bit`; after writing, `lru_bit <= 1 - lru_bit` (flip to point away from the freshly filled way).

2. *"What happens if both ways are invalid (cold start)?"*
   > The LRU bit initialises to 0, so Way 0 fills first. After that, Way 1 fills. After both are valid, standard LRU applies.

3. *"Why use 1 bit per set rather than a full recency counter?"*
   > With exactly 2 ways, 1 bit encodes perfect LRU: it tracks which way was used more recently. A counter would require log2(2)=1 bit anyway, so there is no information gain from a larger counter.

4. *"How did you test the double-eviction edge case?"*
   > `tb_lru_unit.sv` sends three addresses all mapping to Set 0 sequentially. Assertions verify that after the third address, the first address's data is gone (evicted) and the LRU bit correctly reflects the two-entry FIFO order.

---

## Speaker 3 — Apoorva Choudhary: FSM Controller Verification

**What you own:** `tb/tb_cache_2way.sv` (141 assertions covering FSM
transitions, hit/miss flags, `resp_data` correctness, `req_ready` behaviour).

**Likely questions:**

1. *"Why does the FSM latch req\_addr into saved\_addr? What happens if it doesn't?"*
   > The request interface only guarantees `req_addr` is stable while `req_valid && req_ready` is true (the acceptance cycle). After that, the master may change `req_addr`. `saved_addr` holds the latched address so LOOKUP and REFILL can operate on the correct address even if the master already changed its outputs.

2. *"Walk me through the FSM for a cache miss."*
   > `STATE_IDLE`: accept request, latch `saved_addr`. → `STATE_LOOKUP`: compare tag; miss detected. → `STATE_REFILL`: write memory block to the LRU way, update tag/valid/LRU. → `STATE_RESP`: assert `resp_valid=1`, `resp_hit=0`, `resp_data` from refilled block. → `STATE_IDLE`.

3. *"How did you verify that resp\_data is correct on a spatial hit (W1, W2, W3 of a refilled block)?"*
   > After a cold miss on W0 of a block, the testbench sends W1, W2, W3 of the same block. Assertions check `resp_hit=1` and `resp_data == mem_block_data[word_select]` for each word offset.

4. *"What is the minimum handshake overhead per request?"*
   > Hit path: 1 cycle acceptance + 1 cycle LOOKUP + 1 cycle RESP = **2 cycles** per request (no REFILL). Miss path: 2 cycles acceptance+LOOKUP + 1 cycle REFILL + 1 cycle RESP = **3 cycles** minimum.

---

## Speaker 4 — Prachee Dhar: Comparative Benchmarks

**What you own:** `tb/tb_cache_compare.sv`, `tb/traces/` (5 trace files),
`scripts/run_cache_compare.sh`, `docs/phase2/cache-benchmarks.md`.

**Likely questions:**

1. *"Why does direct-mapped outperform 2-way on Trace E (3-block cycle)?"*
   > Addresses `0x00`, `0x40`, `0x80` all map to Set 0 in the 2-way cache (bit 6 is a tag bit, not a set-index bit). Three blocks in a 2-way set causes continuous LRU eviction of all three. In direct-mapped, bit 6 IS a set-index bit: `0x40` goes to Set 4 while `0x00` and `0x80` share Set 0. Only the Set-0 pair thrashes; `0x40` hits stably, giving 30% hit rate.

2. *"Why are your traces loaded from disk rather than hardcoded in the testbench?"*
   > On-disk traces (`.hex` files via `$fopen`/`$fgets`) ensure the trace is \emph{independent} of the RTL. Any change to the cache implementation cannot inadvertently alter the workload, making the benchmark reproducible and tamper-evident.

3. *"What does Trace C prove beyond Trace A?"*
   > Trace A (5 accesses) shows the conflict-miss effect but has only 2 hits in 2-way. Trace C (16 alternating accesses) shows that the advantage is \emph{sustained}: after the first 2 cold misses, all 14 subsequent accesses hit in 2-way (87.5%) while direct-mapped continues to thrash (0%).

4. *"Why do Traces B and D give identical hit rates for both designs?"*
   > Spatial locality within a 16-byte block is determined by block size, not associativity. Both caches have identical 16-byte blocks. Consecutive word accesses within a fetched block hit in both caches identically regardless of tag structure or set index.

---

## Speaker 5 — Vani Rudra: Report, Figures & AMAT Analysis

**What you own:** `report/phase2/main.tex` (this IEEE report),
`docs/phase2/interview.md` (this file).

**Likely questions:**

1. *"What are the AMAT implications of the 40% vs. 0% hit rate difference (Trace A)?"*
   > AMAT = t\_hit + (1 − h) × M\_p.  
   > 2-way: 2.0 + (1 − 0.40) × 20 = **14.0 cycles**.  
   > Direct: 2.0 + (1 − 0.00) × 20 = **22.0 cycles**.  
   > The 2-way cache saves 8 cycles per access under a 20-cycle DRAM penalty — a 36% reduction in memory stall time.

2. *"Why is the combinational memory model a limitation?"*
   > The testbench `u_mem` module returns the full 128-byte memory block in the same simulation clock cycle as the REFILL request. Real DRAM has 50–100+ ns latency. This means the measured 3-cycle miss latency understates the real-world penalty. AMAT modelling adds M\_p=20 cycles to compensate, but the exact real-world value depends on the memory subsystem.

3. *"Explain the address decomposition. Why does the 2-way cache have a larger tag?"*
   > Both caches address 128 bytes in 8 blocks of 16 bytes. 2-way uses 4 sets (2 bits: addr[5:4]), leaving 26 bits for the tag (addr[31:6]). Direct-mapped uses 8 sets (3 bits: addr[6:4]), leaving 25 bits for the tag (addr[31:7]). The extra set-index bit in direct-mapped is what causes addr[6] to separate `0x40` from `0x00` in Set geometry.

4. *"What is the significance of the 618-assertion count?"*
   > 618 assertions across 5 suites provide high coverage of the state space: LRU transitions (51), FSM paths including corner cases (141), cross-design comparison under 4 traces (52), system regression across all addresses (344), and waveform correctness (30). A single failing assertion aborts the run with `$fatal`, so a passing run proves the design is correct against all specified scenarios.

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
# File → Open → docs/evidence/cache_2way_demo.vcd

# Compile the Phase II report
tectonic report/phase2/main.tex -o report/phase2/
```

---

*Document version: Phase II draft — FPGA synthesis results PENDING.*
