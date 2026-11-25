#!/usr/bin/env bash
set -euo pipefail

if (( $# > 1 )); then
    printf 'Usage: %s [new output directory]\n' "$0" >&2
    exit 2
fi

root=$(cd "$(dirname "$0")/.." && pwd)
for tool in yosys nextpnr-ecp5; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Missing %s. Load the OSS CAD Suite environment first.\n' "$tool" >&2
        exit 127
    fi
done

if (( $# == 1 )); then
    output=$1
    mkdir "$output"
else
    mkdir -p "$root/sim_build/fpga"
    output=$(mktemp -d "$root/sim_build/fpga/ecp5.XXXXXX")
fi
output=$(cd "$output" && pwd)

yosys -V > "$output/versions.txt"
nextpnr-ecp5 --version >> "$output/versions.txt" 2>&1
printf 'Device: LFE5U-25F CABGA381 speed grade 6\nClock target: 100 MHz\nSeed: 1\nMode: Out of context, post-route\n' >> "$output/versions.txt"

cd "$root"
for top in cache_2way cache_direct; do
    if [[ "$top" == cache_2way ]]; then
        sources='rtl/cache_2way.v rtl/cache_2way_store.v'
    else
        sources='rtl/cache_direct.v'
    fi
    work="$output/$top"
    mkdir "$work"
    if ! yosys -p "read_verilog $sources; synth_ecp5 -top $top -json \"$work/netlist.json\"" > "$work/yosys.log" 2>&1; then
        cat "$work/yosys.log" >&2
        exit 1
    fi
    if ! nextpnr-ecp5 --25k --package CABGA381 --speed 6 --out-of-context \
        --freq 100 --seed 1 --timing-allow-fail \
        --json "$work/netlist.json" --report "$work/timing.json" > "$work/nextpnr.log" 2>&1; then
        cat "$work/nextpnr.log" >&2
        exit 1
    fi
    test -s "$work/timing.json"
done

printf 'ECP5 utilization and timing reports: %s\n' "$output"
