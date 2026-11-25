#!/usr/bin/env bash
# ==============================================================================
# Script: run_cache_compare.sh
# Description: Compiles and runs the shared comparison testbench (tb_cache_compare).
#              Feeds both cache_2way and cache_direct the same access traces,
#              reports per-design hit rates, and exits non-zero on mismatch.
# Author: Prachee
# Usage: ./scripts/run_cache_compare.sh
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "=================================================================="
echo "Checking prerequisites..."
echo "=================================================================="

if ! command -v iverilog >/dev/null 2>&1; then
    echo "ERROR: iverilog not found. Install Icarus Verilog and retry."
    exit 1
fi
if ! command -v vvp >/dev/null 2>&1; then
    echo "ERROR: vvp not found. Install Icarus Verilog and retry."
    exit 1
fi

echo "  iverilog: $(iverilog -V 2>&1 | head -1)"

REQUIRED_FILES=(
    "rtl/cache_2way.v"
    "rtl/cache_2way_store.v"
    "rtl/cache_direct.v"
    "tb/mem_block_model.v"
    "tb/tb_cache_compare.sv"
    "tb/traces/conflict_trace.hex"
    "tb/traces/locality_trace.hex"
)
for f in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        echo "ERROR: Required file not found: $f"
        exit 1
    fi
    echo "  Found: $f"
done

VVP_OUT="sim_cache_compare.vvp"
trap 'rm -f "$VVP_OUT"' EXIT

echo ""
echo "=================================================================="
echo "Compiling tb_cache_compare with iverilog -g2012..."
echo "=================================================================="

iverilog -g2012 -Wall \
    -s tb_cache_compare \
    -o "$VVP_OUT" \
    rtl/cache_2way.v \
    rtl/cache_2way_store.v \
    rtl/cache_direct.v \
    tb/mem_block_model.v \
    tb/tb_cache_compare.sv

echo "Compilation successful."

echo ""
echo "=================================================================="
echo "Running comparative simulation..."
echo "=================================================================="

vvp "$VVP_OUT"
SIM_EXIT=$?

if [[ $SIM_EXIT -eq 0 ]]; then
    echo ""
    echo "=================================================================="
    echo "run_cache_compare.sh: ALL CHECKS PASSED (exit 0)"
    echo "=================================================================="
else
    echo ""
    echo "=================================================================="
    echo "run_cache_compare.sh: SIMULATION REPORTED FAILURES (exit $SIM_EXIT)"
    echo "=================================================================="
    exit $SIM_EXIT
fi
