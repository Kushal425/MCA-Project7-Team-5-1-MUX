# FPGA utilization and timing

## Routed ECP5 results

Both caches met the 100 MHz internal clock target after routing. Yosys
and nextpnr ran on the same Lattice ECP5 LFE5U-25F, CABGA381, speed grade 6,
with seed 1 and out-of-context settings.

| Metric | Two-way | Direct-mapped |
| --- | ---: | ---: |
| Logic cells (TRELLIS_COMB) | 1,817 | 548 |
| Flip-flops (TRELLIS_FF) | 82 | 79 |
| Distributed RAM write cells (TRELLIS_RAMW) | 78 | 39 |
| Block RAM (DP16KD) | 0 | 0 |
| Critical path (ns) | 9.743 | 7.270 |
| Estimated maximum clock frequency (MHz) | 102.64 | 137.55 |

The two-way cache used more logic and had a longer critical path under
this implementation. Both designs used distributed memory resources.
The RAM write-cell counts are reported separately and should not be
added to the logic-cell counts as a total area measure. The maximum
frequencies are post-route estimates for the cache cores without board
I/O timing or external-memory timing.

Run the **FPGA comparison** GitHub Actions workflow or run
./synth/run_fpga_ecp5_comparison.sh with OSS CAD Suite on PATH.
The execution reports are archived below.

- [GitHub Actions run #1](https://github.com/Kushal425/MCA-Project7-Team-5-1-MUX/actions/runs/45633205741)
- [Tool versions and constraints](../evidence/ecp5/versions.txt)
- [Two-way raw timing and utilization](../evidence/ecp5/cache-2way-post-route.json)
- [Direct-mapped raw timing and utilization](../evidence/ecp5/cache-direct-post-route.json)

## Optional Artix-7 comparison

Use a machine with AMD Vivado and Artix-7 device support. From the repository root:

```bash
./synth/run_fpga_comparison.sh xc7a35tcpg236-1 10.000
```

The default part is an Artix-7 XC7A35T in the CPG236 package, speed grade -1. Use the same part and period for both caches if your lab uses a different board. Vivado reads only the RTL for each cache, then runs out-of-context synthesis, optimization, placement and routing with the same settings for both. No testbench or simulation memory implementation is included.

Each run creates its own directory under `sim_build/fpga/`. Each design directory contains the synthesized and routed utilization reports, route status, timing summary, detailed internal setup paths and a CSV timing row. The top-level `timing-comparison.csv` combines both rows and identifies the part, tool version and analysis stage. Confirm that both designs are fully routed before using their results.

### Artix-7 reporting

For each top, record the routed Slice LUTs, LUTs used as memory, Slice Registers, Block RAM Tile count and worst internal setup slack. Record the endpoints of the worst internal path from `post_route_internal_setup.rpt`. Preserve the relevant tool reports with the published result.

The 10 ns period constrains `clk` to a 100 MHz target. The flow estimates internal maximum frequency as `1000 / (period_ns - worst_internal_setup_slack_ns)` using the fixed routed implementation. Check the setup and hold reports before claiming timing closure. To verify a faster setting, rerun place and route for both designs at a common tighter period and inspect the resulting reports.

The estimate covers internal synchronous paths. This out-of-context comparison has no external I/O timing budgets, board pin assignments or attached lower memory. The simulation's request latency, the modeled AMAT and any routed clock estimate describe different quantities.

References: [Vivado synth_design](https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands/synth_design) · [Out-of-context design constraints](https://docs.amd.com/r/en-US/ug905-vivado-hierarchical-design/Out-of-Context-Design-Constraints)
