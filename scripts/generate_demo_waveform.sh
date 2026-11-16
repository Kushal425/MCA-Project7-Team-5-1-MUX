#!/usr/bin/env bash
# ==============================================================================
# Script: generate_demo_waveform.sh
# Description: Compiles and executes the 5-request demo simulation to regenerate
#              the reproducible VCD waveform at docs/evidence/cache_2way_demo.vcd.
# Author: Kushal (Phase I, Handoff 4)
# Usage: ./scripts/generate_demo_waveform.sh
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "=================================================================="
echo "MCA Project 7: Generating 5-Request Benchmark Demo Waveform"
echo "Repository Root: $REPO_ROOT"
echo "=================================================================="

# Check toolchain prerequisites
if ! command -v iverilog >/dev/null 2>&1; then
    echo "ERROR: 'iverilog' (Icarus Verilog) not found in PATH."
    echo "Prerequisite: Install icarus-verilog via Homebrew ('brew install icarus-verilog') or apt-get."
    exit 1
fi

if ! command -v vvp >/dev/null 2>&1; then
    echo "ERROR: 'vvp' (Icarus Verilog runtime) not found in PATH."
    exit 1
fi

REQUIRED_FILES=(
    "rtl/cache_2way.v"
    "rtl/cache_2way_store.v"
    "tb/mem_block_model.v"
    "tb/tb_demo_waveform.sv"
)

for f in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        echo "ERROR: Required file missing: $f"
        exit 1
    fi
    echo "  Found: $f"
done

BUILD_DIR="sim_build"
mkdir -p "$BUILD_DIR"
mkdir -p "docs/evidence"

VVP_OUT="$BUILD_DIR/sim_demo_waveform.vvp"
trap 'rm -f "$VVP_OUT"' EXIT

echo ""
echo "[1/2] Compiling demo waveform harness with iverilog (-g2012)..."
iverilog -g2012 -Wall \
    -s tb_demo_waveform \
    -o "$VVP_OUT" \
    rtl/cache_2way.v \
    rtl/cache_2way_store.v \
    tb/mem_block_model.v \
    tb/tb_demo_waveform.sv

echo "Compilation successful."

echo ""
echo "[2/2] Running simulation and generating VCD..."
vvp "$VVP_OUT"

echo ""
echo "=================================================================="
if [[ -f "docs/evidence/cache_2way_demo.vcd" ]]; then
    WAVE_SIZE=$(ls -lh docs/evidence/cache_2way_demo.vcd | awk '{print $5}')
    echo "SUCCESS: Waveform generated at docs/evidence/cache_2way_demo.vcd ($WAVE_SIZE)"
    echo "To inspect in GTKWave: gtkwave docs/evidence/cache_2way_demo.vcd"
else
    echo "ERROR: VCD waveform was not created!"
    exit 1
fi
echo "=================================================================="
