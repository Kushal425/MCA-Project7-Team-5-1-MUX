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
> **Phase I Status**: Complete and ready for submission. The IEEE report PDF is compiled and tracked, prototype demonstration video link is integrated, and all 618 automated verification assertions pass cleanly. See [Phase I Submission Checklist](docs/phase1-submission.md).

---

## Phase I Deliverables

| Deliverable | Location | Status |
| :--- | :--- | :---: |
| IEEE Report (LaTeX source) | [`report/main.tex`](report/main.tex), [`report/refs.bib`](report/refs.bib) | ✅ Complete & Overleaf-ready |
| Report PDF | [`report/phase1-report.pdf`](report/phase1-report.pdf) | ✅ Compiled & Tracked |
| Prototype Demonstration Video | [Watch the prototype demonstration video on Google Drive](https://drive.google.com/drive/folders/1mvhw6SxGwut4hR3gHfqjN-LHExD14j1P?usp=sharing) | ✅ Link Provided |
| Demo Script & Walkthrough | [`demo/recording-script.md`](demo/recording-script.md), [`demo/presentation.pdf`](demo/presentation.pdf) | ✅ Complete |
| Submission Checklist & Audit | [`docs/phase1-submission.md`](docs/phase1-submission.md) | ✅ Complete |

### Prototype Demonstration Video

The prototype demonstration video covers the project motivation, introduces all five team members by name (Krishna, Apoorva, Prachee, Kushal, Vani), explains the set-associative cache architecture and LRU replacement logic, and demonstrates live testbench execution and waveform inspection:

- **Direct Link**: [Watch the prototype demonstration video on Google Drive](https://drive.google.com/drive/folders/1mvhw6SxGwut4hR3gHfqjN-LHExD14j1P?usp=sharing)
- **Folder URL**: `https://drive.google.com/drive/folders/1mvhw6SxGwut4hR3gHfqjN-LHExD14j1P?usp=sharing`
- **Narration Script & Presentation**: [`demo/recording-script.md`](demo/recording-script.md) and [`demo/presentation.pdf`](demo/presentation.pdf)

---

## 3. Key Documentation & Specifications

- **[docs/phase1-submission.md](docs/phase1-submission.md)**: Comprehensive Phase I submission audit, deliverable checklist, course criteria mapping, and multi-author Git contribution records.
- **[docs/interface.md](docs/interface.md)**: Hardware interface contracts, port lists, bit slicings, and request/response timing diagrams.
- **[docs/architecture.md](docs/architecture.md)**: Datapath architecture, block diagrams, storage array sizing, and 4-state controller FSM transitions.
- **[docs/demo-trace.md](docs/demo-trace.md)**: Worked step-by-step example and analytical predictions for the 5-access benchmark trace (`0x00`, `0x80`, `0x00`, `0x100`, `0x00`).
- **[docs/lru_explanation.md](docs/lru_explanation.md)**: Algorithmic proof of LRU recency tracking and deterministic victim selection.
- **[report/README.md](report/README.md)**: Report documentation, compilation guide ([`report/BUILD.md`](report/BUILD.md)), and tracked PDF ([`report/phase1-report.pdf`](report/phase1-report.pdf)).
- **[demo/README.md](demo/README.md)**: Demonstration video access link, duration guidelines, and recording script.

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
