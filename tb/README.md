# Testbench & Verification Environment (`tb/`)

This directory is designated for simulation testbenches and verification harnesses.

## Verification Scope (Phase I)

- **Owner**: Kushal (with unit testbenches authored by module owners as needed)
- **Toolchain**: Icarus Verilog (`iverilog -g2012`) and `vvp`.
- **Testbenches & Verification Models**:
  1. `tb_cache_2way_store.sv` (Krishna): Race-free, self-checking unit verification for `cache_2way_store` (51 passing assertions covering cold misses, empty-way priority, both hit ways, 4 word offsets, hit recency updates, LRU eviction, set independence, and synchronous reset).
  2. `tb_cache_2way.sv` (Apoorva): Self-checking integration testbench for top-level `cache_2way` integrated with `cache_2way_store` and `mem_block_model` (141 passing assertions covering reset and handshake timing, 5-request demo trace, non-zero word offset handling, post-acceptance bus mutation isolation, exact single-cycle response pulses, and multi-set operations).
  3. `mem_block_model.v` (Apoorva): Reusable combinational block memory model providing deterministic 128-bit block data (`Memory[word_addr] = word_addr`) adhering to the contract defined in [docs/interface.md](../docs/interface.md#3-testbench-memory-verification-model).
  4. `tb_cache_direct.sv` (Prachee): Self-checking integration testbench for `cache_direct` baseline (30 passing assertions verifying synchronous reset, single-outstanding handshake, conflict misses in Set 0, word multiplexing across all 4 offsets, address mutation isolation, and cache invalidation on reset).
  5. `tb_cache_compare.sv` (Prachee): Shared dual-cache comparative testbench driving identical access sequences into both `cache_2way` and `cache_direct` concurrently, validating returned data words, checking individual hit/miss outcomes, and measuring per-trace hit rates (52 passing assertions across Trace A and Trace B).
  6. `traces/` (Prachee): Checked-in trace definitions (`conflict_trace.hex` and `locality_trace.hex`) documenting address bit decompositions and expected outcomes.
