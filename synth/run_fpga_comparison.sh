#!/usr/bin/env bash
set -euo pipefail

if (( $# > 2 )); then
    printf 'Usage: %s [Vivado part] [clock period in ns]\n' "$0" >&2
    exit 2
fi
if ! command -v vivado >/dev/null 2>&1; then
    printf 'Vivado was not found. Load Vivado with Artix-7 device support and retry.\n' >&2
    exit 127
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
part=${1:-xc7a35tcpg236-1}
period_ns=${2:-10.000}
build_root="$repo_root/sim_build/fpga"
mkdir -p "$build_root"
run_dir="$(mktemp -d "$build_root/comparison.XXXXXX")"

for top in cache_2way cache_direct; do
    design_dir="$run_dir/$top"
    mkdir "$design_dir"
    (
        cd "$design_dir"
        vivado -mode batch -source "$repo_root/synth/compare_cache.tcl" \
            -tclargs "$repo_root" "$top" "$part" "$period_ns" | tee vivado-console.log
        test -s result.csv
    )
done

{
    head -n 1 "$run_dir/cache_2way/result.csv"
    tail -n +2 "$run_dir/cache_2way/result.csv"
    tail -n +2 "$run_dir/cache_direct/result.csv"
} > "$run_dir/timing-comparison.csv"
cat "$run_dir/timing-comparison.csv"
printf 'Synthesis, routed utilization and timing reports: %s\n' "$run_dir"
