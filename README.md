# 2-Way Set-Associative Cache with LRU Replacement

**Course**: Modern Computer Architecture (MCA)  
**Project**: Project 7 (Level: Intermediate+)  
**Current Phase**: Phase I (Prototype & Core Interface Verification)

---

## 1. Project Overview

This repository contains the hardware implementation and verification environment for a synthesizable **2-Way Set-Associative Cache with Least-Recently-Used (LRU) replacement policy**, compared against a **Direct-Mapped Cache baseline**.

Both cache models are written in synthesizable Verilog-2001, targeting an FPGA-friendly configuration of 128 data bytes (four 16-byte blocks per set or 8 blocks total). The system supports aligned 32-bit word reads with a synchronous active-high reset, deterministic memory model, and standardized request/response handshaking.

---

## 2. Team Members & Work Pipeline

| Order | Team Member | Primary Responsibility | Status |
| :---: | :--- | :--- | :---: |
| 1 | **Kushal** | Initial scaffold, architecture specs, directory layout, interface contract | **COMPLETED** |
| 2 | **Krishna** | Storage submodule (`rtl/cache_2way_store.v`), tag comparators, LRU logic | **NEXT UP** |
| 3 | **Apoorva** | 2-Way Cache Controller FSM & top-level integration (`rtl/cache_2way.v`) | Pending |
| 4 | **Prachee** | Direct-Mapped Cache Baseline (`rtl/cache_direct.v`) | Pending |
| 5 | **Kushal** | Verification testbenches (`tb/`), trace simulation scripts (`scripts/`) | Pending |
| 6 | **Vani** | IEEE project report (`report/`), prototype demo video (`demo/`), submission packaging | Pending |

> [!IMPORTANT]
> **Who Works Next**: **Krishna** takes over to implement `rtl/cache_2way_store.v` following the contract in [docs/interface.md](docs/interface.md).

---

## 3. Key Documentation & Specifications

- **[PROJECT_BRIEF.md](PROJECT_BRIEF.md)**: The permanent single source of truth containing team scope, course evaluation criteria, original project specification, hardware requirements, and submission rules.
- **[AGENTS.md](AGENTS.md)**: Mandatory rules and protocol for AI coding assistants working in this repository.
- **[HANDOFF.md](HANDOFF.md)**: Chronological project log tracking work completed, checks run, real simulation results, and handoffs.
- **[docs/interface.md](docs/interface.md)**: Complete hardware interface contracts, port lists, bit slicings, and timing diagrams.
- **[docs/demo-trace.md](docs/demo-trace.md)**: Worked step-by-step example and predicted outcomes for the 5-access benchmark trace (`0x00`, `0x80`, `0x00`, `0x100`, `0x00`).

---

## 4. Repository Structure

```
├── AGENTS.md             # Guidelines and rules for AI coding assistants
├── HANDOFF.md            # Chronological handoff log and verification records
├── PROJECT_BRIEF.md      # Permanent project brief and evaluation criteria
├── README.md             # Project overview, team workflow, and run guide
├── demo/                 # Video script, slides, demo links, and recording materials
├── docs/                 # Hardware specs, interface contracts, and trace proofs
│   ├── demo-trace.md     # Worked example analysis and predicted hit/miss trace
│   ├── evidence/         # Saved waveform plots, simulation logs, and screenshots
│   └── interface.md      # Hardware interface specification and timing diagrams
├── report/               # IEEE format project report (LaTeX sources and final PDF)
├── rtl/                  # Synthesizable Verilog-2001 source code
├── scripts/              # Automated build, lint, and simulation runner scripts
└── tb/                   # SystemVerilog / Verilog testbenches and trace stimulus
```

---

## 5. Toolchain & Simulation Guide

### Prerequisites
- **Icarus Verilog** (`iverilog` v10+ or v12+)
- **vvp** (Icarus simulation runtime engine)
- **GTKWave** (optional, for viewing `.vcd` waveform dumps)

### Running Simulation (once RTL and testbenches are committed)
To compile and execute the testbench using Icarus Verilog:

```bash
# Compile the testbench with SystemVerilog-2012 support
iverilog -g2012 -o sim_build/tb_cache_trace.vvp rtl/*.v tb/tb_cache_trace.sv

# Run the simulation runtime
vvp sim_build/tb_cache_trace.vvp

# (Optional) Open waveform in GTKWave
gtkwave docs/evidence/cache_trace.vcd
```

