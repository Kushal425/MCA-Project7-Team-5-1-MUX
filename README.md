# 2-Way Set-Associative Cache with LRU Replacement

Modern Computer Architecture — Project 7, Phases I and II

A Verilog implementation of a two-way set-associative cache with least-recently-used replacement, compared with a direct-mapped cache of the same capacity.

## Repository layout

| Location | Contents |
| --- | --- |
| [phase1/](phase1/README.md) | Prototype report, video, submission checklist and simulation evidence |
| [phase2/](phase2/README.md) | Comparative report, verification results, FPGA method and interview guide |
| [docs/](docs/architecture.md) | Shared architecture, interfaces and LRU explanation |
| [rtl/](rtl/README.md) · [tb/](tb/README.md) | Cache implementations, testbenches and benchmark traces |
| [scripts/](scripts/README.md) · [synth/](phase2/docs/fpga-results.md) | Simulation runners and FPGA build flow |

## Architecture

Both caches hold 128 data bytes in eight 16-byte blocks. The two-way cache has four sets with two blocks per set. The direct-mapped cache has eight sets with one block per set. Each block contains four 32-bit words.

The prototype supports aligned 32-bit word reads, synchronous active-high reset and one outstanding request. A deterministic simulation memory returns each word's byte address as its data. See the [architecture](docs/architecture.md) and [interface specification](docs/interface.md).

## Team

| Member | Phase I | Phase II |
| --- | --- | --- |
| Krishna Pramod Dubale | Storage arrays, tag lookup, LRU logic and unit tests | [LRU reference model and stress tests](phase2/docs/lru-verification.md) ([PR #1](https://github.com/Kushal425/MCA-Project7-Team-5-1-MUX/pull/1)) |
| Apoorva Choudhary | Cache controller, memory model and integration tests | [In-flight reset, handshake and timing verification](phase2/docs/controller-verification.md) ([PR #2](https://github.com/Kushal425/MCA-Project7-Team-5-1-MUX/pull/2)) |
| Prachee Dhar | Direct-mapped baseline and comparison tests | [File-driven benchmarks and measured response latency](phase2/docs/cache-benchmarks.md) ([PR #3](https://github.com/Kushal425/MCA-Project7-Team-5-1-MUX/pull/3)) |
| Vani Rudra | IEEE report and demonstration materials | [Phase II IEEE report](phase2/report/phase2-report.pdf) and [interview handout](phase2/docs/interview.md) ([PR #4](https://github.com/Kushal425/MCA-Project7-Team-5-1-MUX/pull/4)) |
| Kushal Sarkar | Design specification, system regressions and waveform evidence | [FPGA comparison flow](phase2/docs/fpga-results.md), integrated six-suite verification and corrected system-regression exit behavior |

## Run the tests

Install Icarus Verilog so that `iverilog` and `vvp` are on your PATH. From the repository root, run:

```bash
./scripts/run_all.sh
```

The six Phase II suites pass 20,193 checks with Icarus Verilog 13.0, including 19,116 LRU reference-model checks. See the [verification breakdown](phase2/docs/evaluation-methodology.md).

To regenerate the demonstration waveform:

```bash
./scripts/generate_demo_waveform.sh
```

Open `phase1/evidence/cache-2way-demo.vcd` in GTKWave or another VCD viewer. The [waveform guide](phase1/evidence/demo-waveform.md) identifies signals and events. Individual runners are listed in [scripts/README.md](scripts/README.md).

## Comparison results

Both caches start empty and receive identical requests.

| Trace | Two-way hits | Direct-mapped hits |
| --- | ---: | ---: |
| Conflict | 2/5 (40.0%) | 0/5 (0.0%) |
| Spatial locality | 4/6 (66.7%) | 4/6 (66.7%) |
| Extended two-block conflict | 14/16 (87.5%) | 0/16 (0.0%) |
| Sequential | 24/32 (75.0%) | 24/32 (75.0%) |
| Mapping-sensitive three-block cycle | 0/30 (0.0%) | 9/30 (30.0%) |
| **Total** | **44/89 (49.44%)** | **37/89 (41.57%)** |

In the five-request demo, the third request refreshes way 0. The fourth replaces block `0x80` in way 1, preserving `0x00` for the final hit. See the [Phase II benchmark evidence](phase2/docs/cache-benchmarks.md) and [LRU explanation](docs/lru_explanation.md).

## FPGA comparison

Both cores met the 100 MHz target after routing on ECP5. The estimated maximum frequencies were 102.64 MHz for two-way and 137.55 MHz for direct-mapped. [Resource counts and raw evidence](phase2/docs/fpga-results.md)

## Project presentation

[Download the PowerPoint](phase2/presentation/MCA-Project7-Presentation.pptx) for the project walkthrough, benchmark results, FPGA comparison and demo. Speaker notes include the team handoffs.

## IEEE reports

- [Phase I PDF](phase1/report/phase1-report.pdf) · [LaTeX source](phase1/report/phase1-report.tex) · [Build instructions](phase1/report/README.md)
- [Phase II report PDF](phase2/report/phase2-report.pdf) · [Updated LaTeX source](phase2/report/phase2-report.tex) · [Build instructions](phase2/report/README.md)

## Prototype Demonstration Video

[Watch the prototype demonstration video on Google Drive](https://drive.google.com/drive/folders/1mvhw6SxGwut4hR3gHfqjN-LHExD14j1P?usp=sharing)

## Submission requirements

The [Phase I checklist](phase1/docs/submission-checklist.md) maps the course requirements to the report, demonstration and implementation.
