# Phase II Evaluation Methodology Notes
# Source data for report/phase2/main.tex Results section

## Verification Suite Evidence

| Suite | File | Owner | Assertions | Branch |
|-------|------|-------|-----------|--------|
| LRU unit | `tb/tb_lru_unit.sv` | Krishna Pramod Dubale | 51 | phase2/krishna-lru-verification |
| Controller FSM | `tb/tb_cache_2way.sv` | Apoorva Choudhary | 141 | phase2/apoorva-controller-verification |
| Cache comparison | `tb/tb_cache_compare.sv` | Prachee Dhar | 52 | phase2/prachee-cache-benchmarks |
| System regression | `tb/tb_system_regression.sv` | Kushal Sarkar | 344 | main (merged) |
| Waveform demo | `tb/tb_demo_waveform.sv` | Kushal Sarkar | 30 | main (merged) |
| **Total** | | | **618** | |

Run: `./scripts/run_all.sh` on `main` — all 618 pass.

## Benchmark Trace Evidence

Source: `docs/phase2/cache-benchmarks.md` (Prachee Dhar, branch `phase2/prachee-cache-benchmarks`, merged to `main` 2026-11-16).

| Trace | File | Accesses | 2-Way Hits | Direct Hits | 2-Way HR% | Direct HR% |
|-------|------|----------|-----------|------------|----------|-----------|
| A — Conflict (5) | `tb/traces/conflict_trace.hex` | 5 | 2 | 0 | 40.0 | 0.0 |
| B — Spatial (6) | `tb/traces/locality_trace.hex` | 6 | 4 | 4 | 66.7 | 66.7 |
| C — Extended conflict (16) | `tb/traces/conflict_long_trace.hex` | 16 | 14 | 0 | 87.5 | 0.0 |
| D — Sequential (32) | `tb/traces/sequential_trace.hex` | 32 | 24 | 24 | 75.0 | 75.0 |
| E — 3-block cycle (10) | `tb/traces/three_block_trace.hex` | 10 | 0 | 3 | 0.0 | 30.0 |
| **Total** | | **69** | | | | |

> Note: 89 total requests counted across all latency tests in `docs/phase2/cache-benchmarks.md` Section 3; above table covers the 4+1 primary workload traces.

## Latency Evidence

From `docs/phase2/cache-benchmarks.md` Section 3 (measured, combinational memory model):

- **Hit latency:** 2 clock cycles (IDLE → LOOKUP → RESP)
- **Miss latency:** 3 clock cycles (IDLE → LOOKUP → REFILL → RESP)
- **Weighted average across 89 requests:**
  - 2-way: 2.506 cycles/request (12.112 cycles under M_p=20)
  - Direct: 2.584 cycles/request (13.685 cycles under M_p=20)

## AMAT Model Parameters

- t_hit = 2.0 cycles (measured simulation)
- M_p = 20.0 cycles (modelled DRAM refill, representative)
- Formula: AMAT = t_hit + (1 - HR) × M_p
- Results: see Table III in report/phase2/main.tex

## Addresses Used in Worked Examples

| Hex | 2-Way Set (addr[5:4]) | 2-Way Tag (addr[31:6]) | Direct Set (addr[6:4]) | Direct Tag (addr[31:7]) |
|-----|-----------------------|------------------------|------------------------|------------------------|
| 0x00000000 | Set 0 | 0x0000000 | Set 0 | 0x0000000 |
| 0x00000040 | Set 0 | 0x0000001 | Set 4 | 0x0000000 |
| 0x00000080 | Set 0 | 0x0000002 | Set 0 | 0x0000001 |
| 0x00000100 | Set 0 | 0x0000004 | Set 0 | 0x0000002 |
