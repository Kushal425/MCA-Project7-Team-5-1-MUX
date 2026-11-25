# Testbench & Verification Environment (`tb/`)

This directory is designated for simulation testbenches and verification harnesses.

## Verification Scope

- **Owner**: Kushal (with unit testbenches authored by module owners as needed)
- **Toolchain**: Icarus Verilog (`iverilog -g2012`) and `vvp`.
- **Testbenches & Verification Models**:
  1. `tb_cache_2way_store.sv` (Krishna): Race-free, self-checking unit verification for `cache_2way_store` (51 passing assertions covering cold misses, empty-way priority, both hit ways, 4 word offsets, hit recency updates, LRU eviction, set independence, and synchronous reset).
  2. `tb_cache_2way.sv` (Apoorva): Self-checking integration testbench for top-level `cache_2way` integrated with `cache_2way_store` and `mem_block_model` (276 passing assertions covering reset and handshake timing, 5-request demo trace, non-zero word offset handling, post-acceptance bus mutation isolation, exact single-cycle response pulses, in-flight reset in LOOKUP/REFILL, busy-handshake follow-up holding, measured response timing, and zero response leakage).
  3. `mem_block_model.v` (Apoorva): Reusable combinational block memory model providing deterministic 128-bit block data (`Memory[word_addr] = word_addr`) adhering to the contract defined in [docs/interface.md](../docs/interface.md#3-testbench-memory-verification-model).
  4. `tb_cache_direct.sv` (Prachee): Self-checking integration testbench for `cache_direct` baseline (30 passing assertions verifying synchronous reset, single-outstanding handshake, conflict misses in Set 0, word multiplexing across all 4 offsets, address mutation isolation, and cache invalidation on reset).
  5. `tb_cache_compare.sv` (Prachee): Shared dual-cache comparative testbench driving identical access sequences into both `cache_2way` and `cache_direct` concurrently, validating returned data words, checking individual hit/miss outcomes, and measuring per-trace hit rates (376 passing checks across the five trace files).
  6. `traces/` (Prachee): Five checked-in workloads covering short conflict, extended conflict, spatial locality, sequential reads and a three-block cycle.
  7. `tb_system_regression.sv` (Kushal): Targeted self-checking system regression testbench (344 passing assertions covering full-capacity population across all 8 slots, reset while populated, request suppression during reset, post-reset cold access invalidation, back-to-back request acceptance on the first available ready cycle without idle bubbles, and cross-set LRU independence under interleaved traffic).
  8. `tb_cache_2way_store_stress.sv` (Krishna): Independent LRU reference model and directed stress cases (19,116 passing checks).
  9. `tb_demo_waveform.sv` (Kushal): High-resolution waveform generation harness capturing the exact 5-request demo sequence and decisive eviction timing into `phase1/evidence/cache-2way-demo.vcd`.
