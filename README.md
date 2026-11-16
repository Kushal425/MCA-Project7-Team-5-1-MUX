# 2-Way Set-Associative Cache with LRU Replacement

Modern Computer Architecture — Project 7, Phase I

A Verilog implementation of a two-way set-associative cache with least-recently-used replacement, compared with a direct-mapped cache of the same capacity.

## Architecture

Both caches hold 128 data bytes in eight 16-byte blocks. The two-way cache has four sets with two blocks per set. The direct-mapped cache has eight sets with one block per set. Each block contains four 32-bit words.

The prototype supports aligned 32-bit word reads, synchronous active-high reset and one outstanding request. A deterministic simulation memory returns each word's byte address as its data. See the [architecture](docs/architecture.md) and [interface specification](docs/interface.md).

## Team

| Member | Contribution |
| --- | --- |
| Krishna Pramod Dubale | Storage arrays, tag lookup, LRU logic and unit tests |
| Apoorva Choudhary | Cache controller, memory model and integration tests |
| Prachee Dhar | Direct-mapped baseline and comparison tests |
| Kushal Sarkar | Design specification, system regressions and waveform evidence |
| Vani Rudra | IEEE report and demonstration materials |

## Run the tests

Install Icarus Verilog so that `iverilog` and `vvp` are on your PATH. From the repository root, run:

```bash
./scripts/run_all.sh
```

The five suites pass 618 checks covering storage, controller integration, the direct-mapped baseline, comparison traces and system regressions. These results apply to the supplied tests.

To regenerate the demonstration waveform:

```bash
./scripts/generate_demo_waveform.sh
```

Open `docs/evidence/cache_2way_demo.vcd` in GTKWave or another VCD viewer. The [waveform guide](docs/evidence/demo_waveform_evidence.md) identifies signals and events. Individual runners are listed in [scripts/README.md](scripts/README.md).

## Comparison results

Both caches start empty and receive identical requests.

| Trace | Two-way hits | Direct-mapped hits |
| --- | --- | --- |
| Conflict, 5 requests | 2/5 (40%) | 0/5 (0%) |
| Spatial locality, 6 requests | 4/6 (66.7%) | 4/6 (66.7%) |

For `0x00, 0x80, 0x00, 0x100, 0x00`, the third request refreshes way 0. The fourth replaces block `0x80` in way 1, preserving `0x00` for the final hit. See the [comparison evidence](docs/evidence/cache_comparison_evidence.md) and [LRU explanation](docs/lru_explanation.md).

## Project report

[Read the IEEE report](report/phase1-report.pdf). Editable [LaTeX source](report/main.tex), [references](report/refs.bib) and [build instructions](report/BUILD.md) are included.

## Prototype Demonstration Video

[Watch the prototype demonstration video on Google Drive](https://drive.google.com/drive/folders/1mvhw6SxGwut4hR3gHfqjN-LHExD14j1P?usp=sharing)

## Submission requirements

The [Phase I checklist](docs/phase1-submission.md) maps the course requirements to the report, demonstration and implementation.
