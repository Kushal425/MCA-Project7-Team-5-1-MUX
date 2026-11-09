# Testbench & Verification Environment (`tb/`)

This directory is designated for simulation testbenches and verification harnesses.

## Verification Scope (Phase I)

- **Owner**: Kushal (with unit testbenches authored by module owners as needed)
- **Toolchain**: Icarus Verilog (`iverilog -g2012`) and `vvp`.
- **Testbenches**:
  1. `tb_cache_2way_store.sv` (Krishna): Race-free, self-checking unit verification for `cache_2way_store` (51 passing assertions covering cold misses, empty-way priority, both hit ways, 4 word offsets, hit recency updates, LRU eviction, set independence, and synchronous reset).
  2. `tb_cache_trace.sv` (Kushal Round 2): Comparative evaluation harness driving identical access traces through both `cache_2way` and `cache_direct`.
  3. Memory verification model: Providing combinational 128-bit block responses adhering to the address-equals-data contract defined in [docs/interface.md](../docs/interface.md#3-testbench-memory-verification-model).
