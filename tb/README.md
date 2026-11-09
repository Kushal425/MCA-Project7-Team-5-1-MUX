# Testbench & Verification Environment (`tb/`)

This directory is designated for simulation testbenches and verification harnesses.

## Verification Scope (Phase I)

- **Owner**: Kushal (with unit testbenches authored by module owners as needed)
- **Toolchain**: Icarus Verilog (`iverilog -g2012`) and `vvp`.
- **Expected Testbenches**:
  1. `tb_cache_store.v`: Unit verification for `cache_2way_store` (tag match, victim selection, and LRU updates).
  2. `tb_cache_trace.sv`: Comparative evaluation harness driving identical access traces through both `cache_2way` and `cache_direct`.
  3. Memory verification model: Providing combinational 128-bit block responses adhering to the address-equals-data contract defined in [docs/interface.md](../docs/interface.md#3-testbench-memory-verification-model).

> [!NOTE]
> Testbenches will be added during the designated verification handoff step.

