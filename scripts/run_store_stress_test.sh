#!/usr/bin/env bash
# ==============================================================================
# Script: run_store_stress_test.sh
# Description: Portable self-checking stress test runner for cache_2way_store.
# Author: KrishnaDubale
# ==============================================================================

set -euo pipefail

# Determine repository root relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

echo "=================================================================="
echo "MCA Project 7: Running cache_2way_store Stress Verification"
echo "Repository Root: ${REPO_ROOT}"
echo "=================================================================="

if ! command -v iverilog &> /dev/null; then
    echo "ERROR: 'iverilog' (Icarus Verilog) not found in PATH."
    echo "Prerequisite: Install icarus-verilog via Homebrew ('brew install icarus-verilog') or apt-get."
    exit 1
fi

if ! command -v vvp &> /dev/null; then
    echo "ERROR: 'vvp' (Icarus Verilog runtime engine) not found in PATH."
    exit 1
fi

SIM_BIN="sim_store_stress.vvp"
trap 'rm -f "${REPO_ROOT}/${SIM_BIN}"' EXIT

echo "[1/2] Compiling RTL and stress testbench with iverilog (-g2012)..."
iverilog -g2012 -Wall \
    -s tb_cache_2way_store_stress \
    -o "${SIM_BIN}" \
    rtl/cache_2way_store.v \
    tb/tb_cache_2way_store_stress.sv

echo "[2/2] Running simulation via vvp..."
if [[ -n "${SEED:-}" ]]; then
    vvp "${SIM_BIN}" "+SEED=${SEED}"
else
    vvp "${SIM_BIN}"
fi

echo "=================================================================="
echo "Stress Test Suite for cache_2way_store Completed Successfully!"
echo "=================================================================="
