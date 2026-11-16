# Project Report (`report/`)

This directory contains the IEEE-format project report for Phase I of Modern Computer Architecture (MCA) Project 7.

- **Owner**: Vani (with architectural sections contributed by all five team members).
- **Target Conference Format**: Standard two-column IEEE conference paper template (`\documentclass[conference]{IEEEtran}`).
- **Compiled PDF Deliverable**: [`phase1-report.pdf`](phase1-report.pdf) (compiled and tracked directly in Git).
- **Compilation Guide**: See [`BUILD.md`](BUILD.md) for compilation instructions using Tectonic, pdfLaTeX/BibTeX, or Overleaf.

## Phase I Required Sections

1. **Abstract** (`main.tex`, lines 37–55): Problem statement, 2-way set-associative architecture, LRU replacement, direct-mapped baseline, and experimental findings.
2. **Literature Review** (`main.tex`, lines 65–108): Evolution of cache memory, associativity vs. hit latency tradeoffs (Hill, Smith), victim caching (Jouppi), and modern replacement policies.
3. **Proposed Solution** (`main.tex`, lines 110–280): Detailed architectural breakdown, address slicing, parallel tag comparators, 1-bit LRU update matrix, 4-state controller FSM, direct-mapped comparison, and trace analysis.
4. **Individual Contributions** (`main.tex`, lines 283–331): Specific contributions of all five members (Kushal, Krishna, Apoorva, Prachee, Vani) with verified Git commit hashes.
5. **References** (`refs.bib`, 9 citations): IEEE numeric citations covering classic and modern cache literature and Verilog standards.

> [!NOTE]
> The final compiled document `phase1-report.pdf` is tracked in the repository. Intermediate LaTeX build artifacts (`.aux`, `.log`, `.bbl`, `.blg`, `.out`) are excluded by `.gitignore`.

