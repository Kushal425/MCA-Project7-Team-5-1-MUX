# 2-Way Set-Associative Cache with LRU Replacement

**Course**: Modern Computer Architecture (MCA)  
**Project**: Project 7 (Level: Intermediate+)  
**Current Phase**: Phase I (Prototype, Comparative Verification & Evidence Packaging)

---

## 1. Project Overview

This repository contains the hardware implementation, automated verification environment, and empirical evaluation data for a synthesizable **2-Way Set-Associative Cache with Least-Recently-Used (LRU) replacement policy**, compared against an equal-capacity **Direct-Mapped Cache baseline**.

Both cache models are written in synthesizable Verilog-2001, targeting an FPGA-friendly configuration of 128 data bytes (four 16-byte blocks per set or 8 blocks total). The system supports aligned 32-bit word reads with a synchronous active-high reset, deterministic memory model, and standardized request/response handshaking.

---

## 2. Team Members & Work Pipeline

| Order | Team Member | Primary Responsibility | Status |
| :---: | :--- | :--- | :---: |
| 1 | **Kushal** | Initial scaffold, architecture specs, directory layout, interface contract | **COMPLETED** |
| 2 | **Krishna** | Storage submodule (`rtl/cache_2way_store.v`), tag comparators, LRU logic | **COMPLETED** |
| 3 | **Apoorva** | 2-Way Cache Controller FSM & top-level integration (`rtl/cache_2way.v`) | **COMPLETED** |
| 4 | **Prachee** | Direct-Mapped Cache Baseline (`rtl/cache_direct.v`) & comparison suite | **COMPLETED** |
| 5 | **Kushal** | System regressions, full-suite automation (`scripts/run_all.sh`), waveform evidence | **COMPLETED** |
| 6 | **Vani** | IEEE project report (`report/`), prototype demo video (`demo/`), submission packaging | **COMPLETED** |

> [!IMPORTANT]
> **Phase I Status**: All development and packaging work is complete. See [Phase I Submission Checklist](docs/phase1-submission.md) for remaining human actions (compile PDF, record video, submit course form).

---

## Phase I Deliverables

| Deliverable | Location | Status |
| :--- | :--- | :---: |
| IEEE Report (LaTeX source) | [`report/main.tex`](report/main.tex), [`report/refs.bib`](report/refs.bib) | ✅ Overleaf-ready |
| Report PDF | `report/phase1-report.pdf` | ⏳ Compile pending |
| Demo Recording Script | [`demo/recording-script.md`](demo/recording-script.md) | ✅ |
| Demo Video | [`demo/README.md`](demo/README.md) | ⏳ Recording pending |
| Submission Checklist | [`docs/phase1-submission.md`](docs/phase1-submission.md) | ✅ |

---

## 3. Key Documentation & Specifications

- **[PROJECT_BRIEF.md](PROJECT_BRIEF.md)**: The permanent single source of truth containing team scope, course evaluation criteria, original project specification, hardware requirements, and submission rules.
- **[AGENTS.md](AGENTS.md)**: Mandatory rules and protocol for AI coding assistants working in this repository.
- **[HANDOFF.md](HANDOFF.md)**: Chronological project log tracking work completed, checks run, real simulation results, and handoffs.
- **[docs/interface.md](docs/interface.md)**: Complete hardware interface contracts, port lists, bit slicings, and timing diagrams.
- **[docs/architecture.md](docs/architecture.md)**: Detailed datapath architecture, block diagrams, and controller FSM state transition graphs.
- **[docs/demo-trace.md](docs/demo-trace.md)**: Worked step-by-step example and analytical predictions for the 5-access benchmark trace (`0x00`, `0x80`, `0x00`, `0x100`, `0x00`).
- **[docs/lru_explanation.md](docs/lru_explanation.md)**: Detailed algorithmic proof of LRU recency tracking and replacement mechanics.

---

## 4. Verification Evidence & Artifacts

- **[docs/evidence/demo_waveform_evidence.md](docs/evidence/demo_waveform_evidence.md)**: Comprehensive timing breakdown of the 5-request demo sequence on `cache_2way`, real signal paths, decisive eviction proof at cycle 15.5 ($t = 156\text{ ns}$), and camera-ready video script.
- **[docs/evidence/cache_2way_demo.vcd](docs/evidence/cache_2way_demo.vcd)**: Reproducible VCD waveform dump capturing all internal handshake, FSM, and LRU datapath signals. Inspect via GTKWave.
- **[docs/evidence/cache_comparison_evidence.md](docs/evidence/cache_comparison_evidence.md)**: Comparative evaluation between `cache_2way` and `cache_direct`:
  - **Trace A (Conflict)**: 2-way achieves **40% hit rate** (2/5 hits); direct-mapped achieves **0% hit rate** (0/5 hits, 100% thrashing).
  - **Trace B (Spatial Locality)**: Both designs achieve **66.7% hit rate** (4/6 hits) through multi-word block reuse.
- **[docs/evidence/cache_comparison_sim.log](docs/evidence/cache_comparison_sim.log)**: Verbatim simulation log from the comparative dual-cache execution.

---

## 5. Toolchain Prerequisites & Simulation Guide

### Prerequisites
- **Icarus Verilog** (`iverilog`) & `vvp` simulation runtime:
  - macOS (Homebrew): `brew install icarus-verilog`
  - Ubuntu / Debian: `sudo apt-get install iverilog`
  - Arch Linux: `sudo pacman -S iverilog`
- **GTKWave** (optional, for visual waveform inspection):
  - macOS: `brew install --cask gtkwave`
  - Linux: `sudo apt-get install gtkwave`

---

### Master Full-Prototype Verification Command

To execute every unit, integration, baseline, comparison, and system regression test in a single reproducible run:

```bash
./scripts/run_all.sh
```

*Result: Executes all 5 test suites sequentially. Halts immediately on any failure and prints a comprehensive pass/fail summary report (618 passing assertions, 0 failed).*

---

### Individual Test Suites

Each component of the verification hierarchy can also be executed independently:

```bash
# 1. Unit verification of 2-way storage & LRU replacement logic (51 assertions)
./scripts/run_store_unit_test.sh

# 2. Integration verification of top-level 2-way cache with memory model (141 assertions)
./scripts/run_cache_2way_integration_test.sh

# 3. Baseline verification of equal-capacity direct-mapped cache (30 assertions)
./scripts/run_cache_direct_test.sh

# 4. Comparative benchmark evaluating both caches under identical traces (52 assertions)
./scripts/run_cache_compare.sh

# 5. Targeted system regressions (reset, cold access, ready handshakes, LRU) (344 assertions)
./scripts/run_system_regression.sh

# 6. Regenerate 5-request demo VCD waveform dump
./scripts/generate_demo_waveform.sh

# 7. (Optional) Open waveform in GTKWave
gtkwave docs/evidence/cache_2way_demo.vcd
```
