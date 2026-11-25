# FPGA utilization and timing

The FPGA comparison is ready to run. Device utilization and clock frequency are pending a Vivado run.

## Reproduce the comparison

Use a machine with AMD Vivado and Artix-7 device support. From the repository root:

```bash
./synth/run_fpga_comparison.sh xc7a35tcpg236-1 10.000
```

The default part is an Artix-7 XC7A35T in the CPG236 package, speed grade -1. Use the same part and period for both caches if your lab uses a different board. Vivado reads only the RTL for each cache, then runs out-of-context synthesis, optimization, placement and routing with the same settings for both. No testbench or simulation memory implementation is included.

Each run creates its own directory under `sim_build/fpga/`. Each design directory contains the synthesized and routed utilization reports, route status, timing summary, detailed internal setup paths and a CSV timing row. The top-level `timing-comparison.csv` combines both rows and identifies the part, tool version and analysis stage. Confirm that both designs are fully routed before using their results.

## Report the comparison

For each top, record the routed Slice LUTs, LUTs used as memory, Slice Registers, Block RAM Tile count and worst internal setup slack. Record the endpoints of the worst internal path from `post_route_internal_setup.rpt`. Preserve the relevant tool reports with the published result.

The 10 ns period constrains `clk` to a 100 MHz target. The flow estimates internal maximum frequency as `1000 / (period_ns - worst_internal_setup_slack_ns)` using the fixed routed implementation. Check the setup and hold reports before claiming timing closure. To verify a faster setting, rerun place and route for both designs at a common tighter period and inspect the resulting reports.

The estimate covers internal synchronous paths. This out-of-context comparison has no external I/O timing budgets, board pin assignments or attached lower memory. The simulation's request latency, the modeled AMAT and any routed clock estimate describe different quantities.

References: [Vivado synth_design](https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands/synth_design) · [Out-of-context design constraints](https://docs.amd.com/r/en-US/ug905-vivado-hierarchical-design/Out-of-Context-Design-Constraints)

## ECP5 comparison with open-source tools

The GitHub Actions workflow **FPGA comparison** runs both cache cores
with Yosys and nextpnr on a Lattice ECP5 LFE5U-25F, CABGA381, speed grade 6.
Use the workflow's **ecp5-fpga-comparison** artifact for the raw reports,
or run ./synth/run_fpga_ecp5_comparison.sh with OSS CAD Suite on PATH.

Both runs use the same 100 MHz target, seed and out-of-context settings.
Read the utilized logic cells, flip-flops and memory blocks from the
routed utilization report. Use the achieved clock frequency from the
post-route timing report. A run may produce a valid report even if the
estimated frequency falls below the target. Out-of-context clock timing
covers the cache cores without external I/O timing or board-level clock
distribution. ECP5 and Artix-7 measurements describe different devices.
