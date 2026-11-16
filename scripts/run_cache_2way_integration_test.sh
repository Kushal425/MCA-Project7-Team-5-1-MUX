#!/usr/bin/env bash
# ==============================================================================
# Script: run_cache_2way_integration_test.sh
# Description: Portable integration test runner for top-level cache_2way.
#              Tests cache_2way integrated with cache_2way_store and mem_block_model.
# Author: Apoorva
# ==============================================================================

set -euo pipefail

# Determine repository root relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

echo "=================================================================="
echo "MCA Project 7: Running cache_2way Integration Verification"
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

SIM_BIN="sim_cache_2way.vvp"

# Clean up any stale simulation binary on exit
trap 'rm -f "${REPO_ROOT}/${SIM_BIN}"' EXIT

echo "[1/2] Compiling top-level RTL and integration testbench with iverilog (-g2012)..."
iverilog -g2012 -Wall \
    -s tb_cache_2way \
    -o "${SIM_BIN}" \
    rtl/cache_2way.v \
    rtl/cache_2way_store.v \
    tb/mem_block_model.v \
    tb/tb_cache_2way.sv

echo "[2/2] Running integration simulation via vvp..."
vvp "${SIM_BIN}"

echo "=================================================================="
echo "Integration Test Suite for cache_2way Completed Successfully!"
echo "=================================================================="
