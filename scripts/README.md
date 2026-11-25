# Automation & Simulation Scripts (`scripts/`)

This directory is designated for build, linting, and simulation automation scripts.

## Available Scripts

0. `run_all.sh`:
   - Master full-prototype verification workflow.
   - Executes all six suites (unit, stress, integration, direct-mapped, comparison and system regressions).
   - Provides toolchain dependency diagnostics and halts on any failure.
   - Usage from repository root: `./scripts/run_all.sh`

1. `run_store_unit_test.sh`:
   - Portable unit test runner for `cache_2way_store.v` using `iverilog` (-g2012) and `vvp`.
   - Verified: 51/51 checks passing.
   - Usage from repository root: `./scripts/run_store_unit_test.sh`

2. `run_cache_2way_integration_test.sh`:
   - Portable integration test runner for top-level `cache_2way.v` integrated with `cache_2way_store.v` and `mem_block_model.v`.
   - Verified: 276/276 checks passing.
   - Usage from repository root: `./scripts/run_cache_2way_integration_test.sh`

3. `run_cache_direct_test.sh`:
   - Portable unit & integration test runner for `cache_direct.v` baseline using `iverilog` (-g2012) and `vvp`.
   - Verified: 30/30 checks passing.
   - Usage from repository root: `./scripts/run_cache_direct_test.sh`

4. `run_cache_compare.sh`:
   - Portable comparative trace benchmark runner evaluating `cache_2way` vs `cache_direct` under identical access traces (`tb_cache_compare.sv`).
   - Verified: 376/376 checks passing across five file-driven traces.
   - Usage from repository root: `./scripts/run_cache_compare.sh`

5. `run_system_regression.sh`:
   - Targeted system regression test runner (`tb_system_regression.sv`) covering full-population reset, cold access invalidation, back-to-back first-ready-cycle acceptance, and cross-set LRU independence.
   - Verified: 344/344 checks passing.
   - Usage from repository root: `./scripts/run_system_regression.sh`

6. `generate_demo_waveform.sh`:
   - Compiles and runs `tb_demo_waveform.sv` to regenerate the reproducible VCD waveform file at `docs/evidence/cache_2way_demo.vcd`.
   - Usage from repository root: `./scripts/generate_demo_waveform.sh`

7. `run_store_stress_test.sh`:
   - Runs the independent LRU reference model and directed coverage cases.
   - Verified: 19,116/19,116 checks passing.
   - Usage from repository root: `./scripts/run_store_stress_test.sh`

All scripts must run from the repository root using relative paths and adhere to standard POSIX shell conventions.
