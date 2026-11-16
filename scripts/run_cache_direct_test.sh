#!/usr/bin/env bash
# ==============================================================================
# Script: run_cache_direct_test.sh
# Description: Compiles and runs the cache_direct integration testbench.
# Author: Prachee
# Usage: ./scripts/run_cache_direct_test.sh
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
    "rtl/cache_direct.v"
    "tb/mem_block_model.v"
    "tb/tb_cache_direct.sv"
)
for f in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        echo "ERROR: Required file not found: $f"
        exit 1
    fi
    echo "  Found: $f"
done

VVP_OUT="sim_cache_direct.vvp"
trap 'rm -f "$VVP_OUT"' EXIT

echo ""
echo "=================================================================="
echo "Compiling tb_cache_direct with iverilog -g2012..."
echo "=================================================================="

iverilog -g2012 -Wall \
    -s tb_cache_direct \
    -o "$VVP_OUT" \
    rtl/cache_direct.v \
    tb/mem_block_model.v \
    tb/tb_cache_direct.sv

echo "Compilation successful."

echo ""
echo "=================================================================="
echo "Running simulation..."
echo "=================================================================="

vvp "$VVP_OUT"
SIM_EXIT=$?

if [[ $SIM_EXIT -eq 0 ]]; then
    echo ""
    echo "=================================================================="
    echo "run_cache_direct_test.sh: ALL CHECKS PASSED (exit 0)"
    echo "=================================================================="
else
    echo ""
    echo "=================================================================="
    echo "run_cache_direct_test.sh: SIMULATION REPORTED FAILURES (exit $SIM_EXIT)"
    echo "=================================================================="
    exit $SIM_EXIT
fi
