# Verification Evidence & Artifacts (`docs/evidence/`)

This directory stores authentic verification evidence generated during simulation runs:
## Curated Evidence Artifacts

1. `cache_comparison_evidence.md`:
   - Empirical analysis of Trace A (conflict) and Trace B (locality) comparing `cache_2way` vs `cache_direct`.
   - Verified 40% vs 0% conflict hit rate and 67% vs 67% spatial locality hit rate.

2. `cache_comparison_sim.log`:
   - Complete verbatim simulation transcript of comparative trace evaluation.

3. `demo_waveform_evidence.md`:
   - High-resolution timing analysis of the 5-request demo trace on `cache_2way`.
   - Real internal signal paths, exact nanosecond cycle breakdown, and decisive eviction proof.

4. `cache_2way_demo.vcd`:
   - Fully reproducible VCD waveform dump generated via `./scripts/generate_demo_waveform.sh`.
   - Inspectable in GTKWave: `gtkwave docs/evidence/cache_2way_demo.vcd`.

> [!IMPORTANT]
