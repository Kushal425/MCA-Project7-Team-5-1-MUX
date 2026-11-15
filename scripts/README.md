# Automation & Simulation Scripts (`scripts/`)

This directory is designated for build, linting, and simulation automation scripts.

## Available Scripts

1. `run_store_unit_test.sh`:
   - Portable unit test runner for `cache_2way_store.v` using `iverilog` (-g2012) and `vvp`.
   - Verified: 51/51 checks passing.
   - Usage from repository root: `./scripts/run_store_unit_test.sh`

2. `run_cache_2way_integration_test.sh`:
   - Portable integration test runner for top-level `cache_2way.v` integrated with `cache_2way_store.v` and `mem_block_model.v`.
   - Verified: 141/141 checks passing.
   - Usage from repository root: `./scripts/run_cache_2way_integration_test.sh`

3. `run_trace_sim.sh`:
   - (Round 2 Kushal): Shell script to compile and execute the comparative trace benchmark via `iverilog` and `vvp`.

All scripts must run from the repository root using relative paths and adhere to standard POSIX shell conventions.
