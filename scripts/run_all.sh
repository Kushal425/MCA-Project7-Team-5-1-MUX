#!/usr/bin/env bash
# ==============================================================================
# Script: run_all.sh
# Description: Run the storage, controller, baseline, benchmark and system tests.
#              Ensures all generated outputs are maintained in ignored locations,
#              fails on any error, and provides actionable dependency diagnostics.
# Author: Kushal
# Usage: ./scripts/run_all.sh
# ==============================================================================

set -euo pipefail

# Determine repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "=================================================================="
echo " Modern Computer Architecture (MCA) - Project 7: Verification Suite"
echo " 2-Way Set-Associative Cache with LRU vs Direct-Mapped Baseline"
echo "=================================================================="
echo " Repository Root: $REPO_ROOT"
echo " Execution Time : $(date)"
echo "=================================================================="

# ------------------------------------------------------------------------------
# 1. Actionable Dependency Diagnostics
# ------------------------------------------------------------------------------
MISSING_DEPS=0

if ! command -v iverilog >/dev/null 2>&1; then
    echo ""
    echo "[ERROR] 'iverilog' (Icarus Verilog compiler) was not found in your PATH."
    echo "  Action Required:"
    echo "    - macOS (Homebrew): brew install icarus-verilog"
    echo "    - Debian/Ubuntu:    sudo apt-get install iverilog"
    echo "    - Arch Linux:       sudo pacman -S iverilog"
    MISSING_DEPS=1
fi

if ! command -v vvp >/dev/null 2>&1; then
    echo ""
    echo "[ERROR] 'vvp' (Icarus Verilog simulation runtime) was not found in your PATH."
    echo "  Action Required:"
    echo "    - Typically installed alongside icarus-verilog. Verify your PATH."
    MISSING_DEPS=1
fi

if [[ $MISSING_DEPS -ne 0 ]]; then
    echo ""
    echo "FATAL: Missing simulation toolchain dependencies. Aborting."
    exit 1
fi

IVERILOG_VERSION="$(iverilog -V 2>&1 | sed -n '1p')"
VVP_VERSION="$(vvp -V 2>&1 | sed -n '1p')"
echo " Toolchain Diagnostics:"
echo "   iverilog: $IVERILOG_VERSION"
echo "   vvp:      $VVP_VERSION"

# Ensure build directory exists
BUILD_DIR="$REPO_ROOT/sim_build"
mkdir -p "$BUILD_DIR"

# ------------------------------------------------------------------------------
# 2. Test Suite Execution Runner
# ------------------------------------------------------------------------------
PASSED_SUITES=0
FAILED_SUITES=0

declare -a SUITE_NAMES=(
    "Unit: 2-Way Storage & LRU Datapath"
    "Stress: 2-Way Storage & LRU Reference Model"
    "Integration: Top-Level 2-Way Cache & Memory"
    "Baseline: Direct-Mapped Cache Baseline"
    "Comparison: Five Shared Benchmark Traces"
    "Regression: Targeted System Regressions (Reset/LRU/B2B)"
)

declare -a SUITE_COMMANDS=(
    "./scripts/run_store_unit_test.sh"
    "./scripts/run_store_stress_test.sh"
    "./scripts/run_cache_2way_integration_test.sh"
    "./scripts/run_cache_direct_test.sh"
    "./scripts/run_cache_compare.sh"
    "./scripts/run_system_regression.sh"
)
TOTAL_SUITES=${#SUITE_COMMANDS[@]}

declare -a SUITE_RESULTS=()

for i in "${!SUITE_COMMANDS[@]}"; do
    SUITE_NAME="${SUITE_NAMES[$i]}"
    SUITE_CMD="${SUITE_COMMANDS[$i]}"

    echo ""
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo " [Suite $((i+1))/$TOTAL_SUITES] Running $SUITE_NAME"
    echo " Command: $SUITE_CMD"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

    if bash "$SUITE_CMD"; then
        echo "--> [RESULT] Suite $((i+1)) PASSED: $SUITE_NAME"
        SUITE_RESULTS+=("[PASS] $SUITE_NAME")
        PASSED_SUITES=$((PASSED_SUITES + 1))
    else
        echo "--> [RESULT] Suite $((i+1)) FAILED: $SUITE_NAME"
        SUITE_RESULTS+=("[FAIL] $SUITE_NAME")
        FAILED_SUITES=$((FAILED_SUITES + 1))
        echo ""
        echo "=================================================================="
        echo "FATAL: Test suite failure detected in $SUITE_NAME."
        echo "Stopping full-suite run immediately."
        echo "=================================================================="
        exit 1
    fi
done

# ------------------------------------------------------------------------------
# 3. Final Comprehensive Summary
# ------------------------------------------------------------------------------
echo ""
echo "=================================================================="
echo "           MCA PROJECT 7: VERIFICATION SUMMARY REPORT"
echo "=================================================================="
for res in "${SUITE_RESULTS[@]}"; do
    echo "  $res"
done
echo "------------------------------------------------------------------"
echo " Total Suites Executed : $TOTAL_SUITES"
echo " Passed Suites         : $PASSED_SUITES"
echo " Failed Suites         : $FAILED_SUITES"
echo "=================================================================="

if [[ $FAILED_SUITES -eq 0 ]]; then
    echo ""
    echo "SUCCESS: ALL $TOTAL_SUITES TEST SUITES PASSED (EXIT 0)"
    echo "=================================================================="
    exit 0
else
    echo ""
    echo "FAILURE: ONE OR MORE SUITES FAILED (EXIT 1)"
    echo "=================================================================="
    exit 1
fi
