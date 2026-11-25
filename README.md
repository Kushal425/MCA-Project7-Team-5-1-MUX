# 2-Way Set-Associative Cache with LRU Replacement

Modern Computer Architecture — Project 7, Phases I and II

A Verilog implementation of a two-way set-associative cache with least-recently-used replacement, compared with a direct-mapped cache of the same capacity.

## Architecture

Both caches hold 128 data bytes in eight 16-byte blocks. The two-way cache has four sets with two blocks per set. The direct-mapped cache has eight sets with one block per set. Each block contains four 32-bit words.

The prototype supports aligned 32-bit word reads, synchronous active-high reset and one outstanding request. A deterministic simulation memory returns each word's byte address as its data. See the [architecture](docs/architecture.md) and [interface specification](docs/interface.md).

## Team

| Member | Phase I | Phase II |
| --- | --- | --- |
| Krishna Pramod Dubale | Storage arrays, tag lookup, LRU logic and unit tests | [LRU reference model and stress tests](docs/phase2/lru-verification.md) ([PR #1](https://github.com/Kushal425/MCA-Project7-Team-5-1-MUX/pull/1)) |
| Apoorva Choudhary | Cache controller, memory model and integration tests | [In-flight reset, handshake and timing verification](docs/phase2/controller-verification.md) ([PR #2](https://github.com/Kushal425/MCA-Project7-Team-5-1-MUX/pull/2)) |
| Prachee Dhar | Direct-mapped baseline and comparison tests | [File-driven benchmarks and measured response latency](docs/phase2/cache-benchmarks.md) ([PR #3](https://github.com/Kushal425/MCA-Project7-Team-5-1-MUX/pull/3)) |
| Vani Rudra | IEEE report and demonstration materials | [Phase II IEEE draft](report/phase2/main.pdf) and [interview handout](docs/phase2/interview.md) ([PR #4](https://github.com/Kushal425/MCA-Project7-Team-5-1-MUX/pull/4)) |
| Kushal Sarkar | Design specification, system regressions and waveform evidence | [FPGA comparison flow](docs/phase2/fpga-results.md), integrated six-suite verification and corrected system-regression exit behavior |

## Run the tests

Install Icarus Verilog so that `iverilog` and `vvp` are on your PATH. From the repository root, run:

```bash
./scripts/run_all.sh
```

The six Phase II suites pass 20,193 checks with Icarus Verilog 13.0, including 19,116 LRU reference-model checks. See the [verification breakdown](docs/phase2/evaluation-methodology.md).

To regenerate the demonstration waveform:

```bash
./scripts/generate_demo_waveform.sh
```

Open `docs/evidence/cache_2way_demo.vcd` in GTKWave or another VCD viewer. The [waveform guide](docs/evidence/demo_waveform_evidence.md) identifies signals and events. Individual runners are listed in [scripts/README.md](scripts/README.md).

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

In the five-request demo, the third request refreshes way 0. The fourth replaces block `0x80` in way 1, preserving `0x00` for the final hit. See the [Phase II benchmark evidence](docs/phase2/cache-benchmarks.md) and [LRU explanation](docs/lru_explanation.md).

## FPGA comparison

Run `./synth/run_fpga_comparison.sh` on a machine with Vivado and Artix-7 device support. [Method and evidence status](docs/phase2/fpga-results.md)

## IEEE reports

- [Phase I PDF](report/phase1-report.pdf) · [LaTeX source](report/main.tex) · [Build instructions](report/BUILD.md)
- [Phase II draft PDF](report/phase2/main.pdf) · [Updated LaTeX source](report/phase2/main.tex) · [Build instructions](report/phase2/BUILD.md)

## Prototype Demonstration Video

[Watch the prototype demonstration video on Google Drive](https://drive.google.com/drive/folders/1mvhw6SxGwut4hR3gHfqjN-LHExD14j1P?usp=sharing)

## Submission requirements

The [Phase I checklist](docs/phase1-submission.md) maps the course requirements to the report, demonstration and implementation.
