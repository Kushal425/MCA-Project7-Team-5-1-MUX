# Phase II Evaluation Methodology

## Verification Suite Evidence

| Suite | Testbench | Owner | Passing checks |
| --- | --- | --- | ---: |
| LRU unit | `tb/tb_cache_2way_store.sv` | Krishna Pramod Dubale | 51 |
| LRU reference-model stress test | `tb/tb_cache_2way_store_stress.sv` | Krishna Pramod Dubale | 19,116 |
| Controller FSM | `tb/tb_cache_2way.sv` | Apoorva Choudhary | 276 |
| Direct-mapped baseline | `tb/tb_cache_direct.sv` | Prachee Dhar | 30 |
| Cache comparison | `tb/tb_cache_compare.sv` | Prachee Dhar | 376 |
| System regression | `tb/tb_system_regression.sv` | Kushal Sarkar | 344 |
| **Total** | | | **20,193** |

Run `./scripts/run_all.sh` with Icarus Verilog. The separate waveform generator records the five-request LRU demo.

## Benchmark Trace Evidence

| Trace | Accesses per design | Two-way hits | Direct hits |
| --- | ---: | ---: | ---: |
| A — Conflict | 5 | 2 | 0 |
| B — Spatial locality | 6 | 4 | 4 |
| C — Extended conflict | 16 | 14 | 0 |
| D — Sequential | 32 | 24 | 24 |
| E — Mapping-sensitive cycle | 30 | 0 | 9 |
| **Total** | **89** | **44** | **37** |

Run `./scripts/run_cache_compare.sh` for the observed metrics. See [the workload definitions and timing methodology](cache-benchmarks.md).

## Latency Evidence

From `docs/phase2/cache-benchmarks.md` Section 3 (measured, combinational memory model):

- **Hit latency:** 2 clock cycles (acceptance edge to response-sampling edge)
- **Miss latency:** 3 clock cycles (acceptance edge to response-sampling edge)
- **Weighted average across 89 requests:**
  - 2-way: 2.506 cycles/request (12.112 cycles under M_p=20)
  - Direct: 2.584 cycles/request (13.685 cycles under M_p=20)

## AMAT Model Parameters

- t_hit = 2.0 cycles (measured simulation)
- M_p = 20.0 cycles (assumed refill penalty)
- Formula: AMAT = t_hit + (1 - HR) × M_p
- Results: see Table III in report/phase2/main.tex

## Addresses Used in Worked Examples

| Hex | 2-Way Set (addr[5:4]) | 2-Way Tag (addr[31:6]) | Direct Set (addr[6:4]) | Direct Tag (addr[31:7]) |
|-----|-----------------------|------------------------|------------------------|------------------------|
| 0x00000000 | Set 0 | 0x0000000 | Set 0 | 0x0000000 |
| 0x00000040 | Set 0 | 0x0000001 | Set 4 | 0x0000000 |
| 0x00000080 | Set 0 | 0x0000002 | Set 0 | 0x0000001 |
| 0x00000100 | Set 0 | 0x0000004 | Set 0 | 0x0000002 |
