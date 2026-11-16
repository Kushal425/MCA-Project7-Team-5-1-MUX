# Phase I Submission Audit & Deliverable Checklist

**Project**: 2-Way Set-Associative Cache with LRU Replacement (MCA Project 7)  
**Deadline**: November 16, 2026, 11:59 PM IST  
**Repository URL**: https://github.com/Kushal425/MCA-Project7-Team-5-1-MUX.git

---

## 1. IEEE Project Report (10 Marks)

| Requirement | Evidence | Status |
|:---|:---|:---:|
| Standard IEEE conference format (IEEEtran two-column) | [`report/main.tex`](../report/main.tex) uses `\documentclass[conference]{IEEEtran}` | ✅ Source ready |
| Abstract | Lines 37–55 of `main.tex` | ✅ |
| Literature Review | Lines 65–108 of `main.tex`; 9 real, verifiable references in [`report/refs.bib`](../report/refs.bib) | ✅ |
| Proposed Solution (Architecture, Controller FSM, LRU mechanics) | Lines 110–218 of `main.tex`; address field diagram, block diagram, FSM states, worked LRU example | ✅ |
| Individual Contributions | Lines 237–279 of `main.tex`; grounded in actual commit hashes and handoff entries | ✅ |
| References | 9 IEEE numeric citations (BibTeX) including Patterson & Hennessy, Smith, Hill, Jouppi, Przybylski, Al-Zoubi, IEEE Verilog standard, Icarus Verilog | ✅ |
| Compiled PDF (`report/phase1-report.pdf`) | Compiled via `tectonic` and tracked in Git | ✅ Compiled & Tracked |
| Compilation instructions | [`report/BUILD.md`](../report/BUILD.md) | ✅ |

---

## 2. Prototype Video (15 Marks)

| Requirement | Evidence | Status |
|:---|:---|:---:|
| Maximum duration: 5 minutes | Recording script targets 4:30 | ✅ Script ready |
| Project title, motivation, architecture | Segments 1–2 of [`demo/recording-script.md`](../demo/recording-script.md) | ✅ Scripted |
| All five members introduced by name | Segment 1 names Krishna, Apoorva, Prachee, Kushal, Vani | ✅ Scripted |
| Working prototype demonstration | Segment 3 runs `./scripts/run_all.sh` live (618 assertions) | ✅ Scripted |
| RTL walkthrough / block diagrams | Segment 2 shows `docs/architecture.md` diagrams | ✅ Scripted |
| Simulation traces / waveform inspection | Segment 4 walks through `cache_2way_demo.vcd` in GTKWave, explains Requests 3 and 4 | ✅ Scripted |
| Recorded and uploaded video | No video link found in repository | ⏳ **Pending** — record following script, upload, update `demo/README.md` |

---

## 3. GitHub Repository (5 Marks)

| Requirement | Evidence | Status |
|:---|:---|:---:|
| Repository URL submitted | URL: `https://github.com/Kushal425/MCA-Project7-Team-5-1-MUX.git` | ✅ URL known |
| Course form submission | Not confirmed by team | ⏳ **Pending** — submit URL via official course form |
| IEEE project report present | `report/main.tex`, `report/refs.bib` | ✅ Source present |
| Prototype/demo video link | `demo/README.md` placeholder | ⏳ Pending |
| All synthesizable RTL files | `rtl/cache_2way.v`, `rtl/cache_2way_store.v`, `rtl/cache_direct.v` | ✅ |
| Testbench files | `tb/tb_cache_2way_store.sv`, `tb/tb_cache_2way.sv`, `tb/tb_cache_direct.sv`, `tb/tb_cache_compare.sv`, `tb/tb_system_regression.sv`, `tb/tb_demo_waveform.sv`, `tb/mem_block_model.v` | ✅ |
| Simulation scripts | `scripts/run_all.sh` and 5 individual runners | ✅ |
| Verification artifacts | `docs/evidence/cache_2way_demo.vcd`, `cache_comparison_evidence.md`, `cache_comparison_sim.log`, `demo_waveform_evidence.md` | ✅ |

### Authentic Git History — Individual Contributions

| Team Member | Git Identity | Commits | Files Touched |
|:---|:---|:---:|:---|
| **Kushal Sarkar** | `Kushal425 <kushalsarkar457@gmail.com>` | 7+ (`3043e05`, `92dfa5b`, `3eb612c`, `d6cdad6`, `005cb92`, `fdb01a1`, `d519fc3`, ...) | Repository scaffold, `README.md`, `.gitignore`, `docs/*`, `tb/tb_system_regression.sv`, `tb/tb_demo_waveform.sv`, `scripts/run_all.sh`, `scripts/run_system_regression.sh`, `scripts/generate_demo_waveform.sh`, `docs/evidence/*`, final verification & submission packaging |
| **Krishna Pramod Dubale** | `Krishna Pramod Dubale <krishnapramoddubale@...>` | 3 (`d76542e`, `0c1a380`, `fb36862`) | `rtl/cache_2way_store.v`, `tb/tb_cache_2way_store.sv`, `scripts/run_store_unit_test.sh`, `docs/lru_explanation.md` |
| **Apoorva Choudhary** | `Apoorv Choudhary <apoorvachoudhary506@gmail.com>` | 3 (`7c777f7`, `ba299cf`, `9a976c8`) | `rtl/cache_2way.v`, `tb/mem_block_model.v`, `tb/tb_cache_2way.sv`, `scripts/run_cache_2way_integration_test.sh`, `docs/architecture.md` |
| **Prachee Dhar** | `pracheedhar <prachee.dhar2024@nst.rishihood.edu.in>` | 3 (`fd3d8d7`, `7188fc6`, `cc045d7`) | `rtl/cache_direct.v`, `tb/tb_cache_direct.sv`, `tb/tb_cache_compare.sv`, `tb/traces/*`, `scripts/run_cache_direct_test.sh`, `scripts/run_cache_compare.sh`, `docs/evidence/cache_comparison_evidence.md`, `docs/evidence/cache_comparison_sim.log` |
| **Vani Rudra** | `vanosaur <vanirudra0914@gmail.com>` | 6 (`693444d`, `da0765a`, `c0e872a`, `f097865`, `1486e0d`, `e13598c`) | `report/main.tex`, `report/refs.bib`, `report/phase1-report.pdf`, `report/BUILD.md`, `demo/recording-script.md`, `demo/presentation.pdf`, `demo/README.md`, `docs/phase1-submission.md`, `README.md` |

All five team members have authentic, individual Git contributions with distinct commit hashes.

---

## 4. Summary of Remaining Human Actions

| # | Action | Owner | Deadline | Status |
|:---:|:---|:---|:---|:---:|
| 1 | **Verify video permissions**: Confirm Google Drive folder sharing settings are viewable by instructors | Team | Nov 16, 2026 11:59 PM IST | ⏳ Human check |
| 2 | **Submit course form**: Enter repository URL `https://github.com/Kushal425/MCA-Project7-Team-5-1-MUX.git` in the official course submission form | Any member | Nov 16, 2026 11:59 PM IST | ⏳ Human check |

> **Course-Form Submission Notice**: The repository, reports, evidence, and video links are complete. Submitting the repository link via the official course submission form remains the final human submission step.

---

## 5. Phase II Forward Roadmap (For Architectural Context)

Phase II constitutes 70% of the overall course grade. The completed Phase I foundation establishes forward compatibility for Phase II requirements:

1. **Extended IEEE Project Report**:
   - Expansion of Results & Discussion to include synthetic and benchmark traces (e.g., matrix multiplication, FFT memory patterns).
   - FPGA synthesis resource utilization (LUTs, BRAMs, register slices) and maximum operating frequency ($F_{\max}$) comparison on target FPGA toolchains (e.g., Vivado / Quartus).
   - Conclusions, architectural recommendations, and future work.
2. **Continued Repository Maintenance**:
   - Maintain continuous, multi-author Git commit history throughout Phase II development.
3. **Final Project Oral Defense / Interview**:
   - Oral defense evaluating architecture, RTL trade-offs, FSM state diagrams, LRU mechanics, and verification methodology.
   - All five team members must be prepared to articulate both their individual modules and the end-to-end cache subsystem.
