# Phase I Prototype Demonstration — Recording Script

**Project**: 2-Way Set-Associative Cache with LRU Replacement (MCA Project 7)  
**Target Duration**: 4 minutes 30 seconds (maximum 5:00 allowed)  
**Team**: Krishna Pramod Dubale, Apoorva Choudhary, Prachee Dhar, Kushal Sarkar, Vani Rudra

---

## Pre-Recording Setup Checklist

Complete these steps **before** pressing Record:

1. **Terminal**: Open a terminal at the repository root (`MCA-Project7-Team-5-1-MUX/`).
2. **Verify toolchain**: Run `iverilog -V 2>&1 | head -1` to confirm Icarus Verilog is installed.
3. **Pre-run verification**: Execute `./scripts/run_all.sh` once to confirm all 618 assertions pass. Leave the terminal output visible.
4. **GTKWave**: Open the demo waveform:
   ```bash
   gtkwave docs/evidence/cache_2way_demo.vcd
   ```
   Pre-load the following signals (see `docs/evidence/demo_waveform_evidence.md` for exact hierarchical paths):
   - `clk`, `rst`, `req_valid`, `req_ready`, `req_addr`, `state`
   - `resp_valid`, `resp_hit`, `resp_data`
   - `u_store.way0_match`, `u_store.way1_match`, `u_store.hit`
   - `u_store.touch_en`, `u_store.fill_en`, `u_store.victim_way`
   - `u_store.lru_bit[0]`

   Zoom the time axis to 0–220 ns.
5. **Editor/Browser**: Have `docs/architecture.md` open (for the block diagram), and `docs/evidence/cache_comparison_evidence.md` (for the comparison table).
6. **Screen recording**: Use OBS, QuickTime, or Zoom screen share recording. Set resolution to 1080p minimum.

---

## Recording Script

### Segment 1: Title and Team Introduction (0:00 – 0:45)

**Screen**: Title slide or the repository `README.md` open in a browser/editor showing the team table.

> **Vani** (spoken):
> *"Hello, and welcome to the Phase I prototype demonstration for Project 7: a 2-Way Set-Associative Cache with LRU Replacement, developed for the Modern Computer Architecture course.*
>
> *Our team consists of five members. I'm Vani Rudra, and I'll be narrating this demonstration. Our team members are:*
> - *Krishna Pramod Dubale, who implemented the storage submodule with parallel tag matching and per-set LRU tracking.*
> - *Apoorva Choudhary, who built the top-level cache controller FSM and memory refill integration.*
> - *Prachee Dhar, who implemented the direct-mapped cache baseline and authored the comparative evaluation.*
> - *Kushal Sarkar, who scaffolded the repository architecture and built the full system regression and verification suite.*
> - *And myself, Vani Rudra, responsible for the IEEE report, this demonstration, and submission packaging."*

---

### Segment 2: Project Motivation and Architecture (0:45 – 1:30)

**Screen**: Switch to `docs/architecture.md` showing the address field diagram and the top-level block diagram.

> **Vani** (spoken):
> *"The goal of this project is to implement a synthesizable 2-way set-associative cache and compare it against a direct-mapped cache of equal capacity — both holding 128 bytes of data.*
>
> *Here you can see the address field decomposition. A 32-bit byte address is split into a 26-bit tag, a 2-bit set index selecting one of 4 sets, a 2-bit word select for choosing among 4 words in a 16-byte block, and 2 byte-offset bits.*
>
> *The block diagram shows the top-level datapath. The controller FSM accepts a request, latches the address, and queries the cache_2way_store submodule. This submodule performs parallel tag comparison on both ways simultaneously. On a hit, it returns the cached word. On a miss, the controller fetches a 128-bit block from lower memory and fills the victim way — chosen by LRU replacement or invalid-slot priority.*
>
> *Both the 2-way and direct-mapped caches share an identical external interface: req_valid, req_ready handshake for acceptance, and a one-cycle resp_valid pulse delivering the hit/miss status and data."*

---

### Segment 3: Running the Full Verification Suite (1:30 – 2:15)

**Screen**: Terminal at repository root.

> **Vani** (spoken):
> *"Let's verify that our prototype works. I'll run the master verification command that exercises all five test suites."*

**Action**: Type and execute:
```bash
./scripts/run_all.sh
```

> *"This runs Krishna's 51 storage unit tests, Apoorva's 141 integration tests, Prachee's 30 direct-mapped tests and 52 comparison tests, and Kushal's 344 system regression assertions — a total of 618 automated checks."*

**Wait for output to complete. Point at the summary lines.**

> *"All 618 assertions pass with zero failures. Every test suite reports a clean pass."*

---

### Segment 4: Waveform Walkthrough — Requests 3 and 4 (2:15 – 3:30)

**Screen**: Switch to GTKWave showing `cache_2way_demo.vcd` zoomed to 0–220 ns.

> **Vani** (spoken):
> *"Now let's examine the 5-request benchmark trace in the waveform viewer. This trace sends addresses 0x00, 0x80, 0x00, 0x100, and 0x00 — all mapping to Set 0 — starting from a cold cache."*

**Action**: Point cursor to Request 1 (t = 35 ns).

> *"Requests 1 and 2 are compulsory cold misses. Request 1 fills 0x00 into Way 0, and Request 2 fills 0x80 into Way 1. After Request 2, the LRU bit drops to 0, marking Way 0 as the next eviction target."*

**Action**: Point cursor to t = 115–125 ns (Request 3).

> *"Here at 115 nanoseconds is the critical moment — Request 3. Address 0x00 hits on Way 0. Watch the touch_en signal assert for one cycle, and see lru_bit flip from 0 to 1 at 125 nanoseconds. This recency update is the key: it marks Way 1 as the LRU candidate instead of Way 0, protecting the 0x00 block."*

**Action**: Point cursor to t = 145–156 ns (Request 4).

> *"On Request 4 at 145 nanoseconds, address 0x100 misses. Because lru_bit is now 1, victim_way points to Way 1. At 156 nanoseconds, fill_en pulses, evicting 0x80 from Way 1 and writing 0x100 in its place. Notice that Way 0 — holding 0x00 — is completely undisturbed."*

**Action**: Point cursor to t = 185–196 ns (Request 5).

> *"Finally, Request 5 re-reads 0x00 at 185 nanoseconds. Because Way 0 was spared by LRU replacement, the cache scores a hit at 196 nanoseconds, delivering resp_hit equals 1 with correct data. This is the payoff of LRU set associativity."*

---

### Segment 5: Comparative Results (3:30 – 4:10)

**Screen**: Switch to `docs/evidence/cache_comparison_evidence.md` or show the comparison table on screen.

> **Vani** (spoken):
> *"Let's compare the two architectures. On the same conflict trace, the 2-way cache achieves a 40% hit rate — 2 hits out of 5 accesses — while the direct-mapped cache achieves 0%, suffering complete thrashing because every conflicting address overwrites the sole block in Set 0.*
>
> *On a spatial locality trace accessing consecutive words within a block, both caches achieve an identical 66.7% hit rate, confirming that the performance advantage is purely from associativity and LRU replacement, not from additional capacity.*
>
> *Our automated verification confirms these results with 618 passing assertions across 5 test suites, with zero failures."*

---

### Segment 6: Summary and Closing (4:10 – 4:30)

**Screen**: Return to `README.md` or a closing slide.

> **Vani** (spoken):
> *"To summarize: in Phase I, we have delivered a working, fully verified prototype of a 2-way set-associative cache with LRU replacement, alongside a direct-mapped baseline for comparison. All RTL is synthesizable Verilog-2001, all tests pass, and the verified results demonstrate the conflict-miss reduction that set associativity provides.*
>
> *Thank you for watching. The complete source code, verification evidence, and this report are available in our GitHub repository."*

---

## Timing Budget Summary

| Segment | Content | Duration |
|:---:|:---|:---:|
| 1 | Title and team introduction | 0:45 |
| 2 | Architecture and motivation | 0:45 |
| 3 | Live verification run | 0:45 |
| 4 | Waveform walkthrough (Requests 3 & 4) | 1:15 |
| 5 | Comparative results | 0:40 |
| 6 | Summary and closing | 0:20 |
| **Total** | | **4:30** |
