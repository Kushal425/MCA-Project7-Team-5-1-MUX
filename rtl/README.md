# RTL Source Code (`rtl/`)

This directory is designated for all synthesizable Verilog-2001 hardware description modules.

## Modules

1. `cache_2way_store.v`
   - **Owner**: Krishna
   - **Purpose**: Internal storage arrays (Way 0 and Way 1 data/tag RAM), valid bits, tag comparators, combinational word multiplexer, and LRU replacement logic.
   - **Contract**: See [docs/interface.md](../docs/interface.md#5-internal-submodule-cache_2way_store).

2. `cache_2way.v`
   - **Owner**: Apoorva
   - **Purpose**: Top-level 2-Way Set-Associative Cache incorporating `cache_2way_store`, the cache controller FSM, memory fill logic, and standard handshake interface.
   - **Contract**: See [docs/interface.md](../docs/interface.md#4-external-cache-module-interface).

3. `cache_direct.v`
   - **Owner**: Prachee
   - **Purpose**: Direct-Mapped Cache baseline with identical external interface for comparative performance evaluation.
   - **Contract**: See [docs/interface.md](../docs/interface.md#4-external-cache-module-interface).
