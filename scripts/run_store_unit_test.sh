#!/usr/bin/env bash
# ==============================================================================
# Script: run_store_unit_test.sh
# Description: Portable unit test runner for cache_2way_store.
# Author: Krishna (Phase I, Handoff 1)
# ==============================================================================

set -euo pipefail

# Determine repository root relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

echo "=================================================================="
echo "MCA Project 7: Running cache_2way_store Unit Verification"
echo "Repository Root: ${REPO_ROOT}"
echo "=================================================================="

# Check for required simulation prerequisites
if ! command -v iverilog &> /dev/null; then
    echo "ERROR: 'iverilog' (Icarus Verilog) not found in PATH."
    echo "Prerequisite: Install icarus-verilog via Homebrew ('brew install icarus-verilog') or apt-get."
    exit 1
fi

if ! command -v vvp &> /dev/null; then
    echo "ERROR: 'vvp' (Icarus Verilog runtime engine) not found in PATH."
    exit 1
fi

SIM_BIN="sim_store.vvp"

# Clean up any stale simulation binary on exit
trap 'rm -f "${REPO_ROOT}/${SIM_BIN}"' EXIT

echo "[1/2] Compiling RTL and testbench with iverilog (-g2012)..."
iverilog -g2012 -Wall \
    -s tb_cache_2way_store \
    -o "${SIM_BIN}" \
    rtl/cache_2way_store.v \
    tb/tb_cache_2way_store.sv

echo "[2/2] Running simulation via vvp..."
vvp "${SIM_BIN}"

echo "=================================================================="
echo "Unit Test Suite for cache_2way_store Completed Successfully!"
echo "=================================================================="
