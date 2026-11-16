#!/usr/bin/env bash
# ==============================================================================
# Script: run_system_regression.sh
# Description: Compiles and executes the targeted system regression suite
#              (tb_system_regression) covering reset-after-population, cold
#              accesses post-reset, back-to-back first-ready-cycle handshakes,
#              cross-set LRU independence, and direct-mapped regressions.
# Author: Kushal
# Usage: ./scripts/run_system_regression.sh
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "=================================================================="
echo "MCA Project 7: Running System Regression Suite"
echo "Repository Root: $REPO_ROOT"
echo "=================================================================="

# Check toolchain prerequisites
if ! command -v iverilog >/dev/null 2>&1; then
    echo "ERROR: 'iverilog' (Icarus Verilog) not found in PATH."
    echo "Prerequisite: Install icarus-verilog via Homebrew ('brew install icarus-verilog') or apt-get."
    exit 1
fi

if ! command -v vvp >/dev/null 2>&1; then
    echo "ERROR: 'vvp' runtime engine not found in PATH."
    echo "Prerequisite: Install icarus-verilog via Homebrew ('brew install icarus-verilog') or apt-get."
    exit 1
fi

echo "  iverilog: $(iverilog -V 2>&1 | head -1)"
echo "  vvp:      $(vvp -V 2>&1 | head -1)"

# Check required design and test files
REQUIRED_FILES=(
    "rtl/cache_2way.v"
    "rtl/cache_2way_store.v"
    "rtl/cache_direct.v"
    "tb/mem_block_model.v"
    "tb/tb_system_regression.sv"
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
VVP_OUT="$BUILD_DIR/sim_system_regression.vvp"

trap 'rm -f "$VVP_OUT"' EXIT

echo ""
echo "[1/2] Compiling system regression suite with iverilog (-g2012)..."
iverilog -g2012 -Wall \
    -s tb_system_regression \
    -o "$VVP_OUT" \
    rtl/cache_2way.v \
    rtl/cache_2way_store.v \
    rtl/cache_direct.v \
    tb/mem_block_model.v \
    tb/tb_system_regression.sv

echo "Compilation successful."

echo ""
echo "[2/2] Running system regression simulation via vvp..."
vvp "$VVP_OUT"
SIM_EXIT=$?

if [[ $SIM_EXIT -eq 0 ]]; then
    echo ""
    echo "=================================================================="
    echo "run_system_regression.sh: ALL REGRESSIONS PASSED (exit 0)"
    echo "=================================================================="
else
    echo ""
    echo "=================================================================="
    echo "run_system_regression.sh: FAILURES DETECTED (exit $SIM_EXIT)"
    echo "=================================================================="
    exit $SIM_EXIT
fi
