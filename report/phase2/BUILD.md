# Phase II Report — Build Instructions

## Quick Build (Recommended)

```bash
tectonic report/phase2/main.tex -o report/phase2/
```

This compiles `main.tex` and writes `main.pdf` into `report/phase2/`. On first run, `tectonic` will download any missing LaTeX packages automatically (requires internet). Subsequent runs use the local cache.

## Alternative: pdflatex (two-pass for bibliography)

```bash
cd report/phase2
pdflatex main.tex
bibtex main
pdflatex main.tex
pdflatex main.tex
```

## Prerequisites

| Tool | Install | Notes |
|------|---------|-------|
| `tectonic` | `brew install tectonic` | Recommended — auto-downloads packages |
| `pdflatex` | MacTeX / TeX Live | Requires `IEEEtran.cls` on `TEXMFHOME` |
| `bibtex` | Included with TeX Live | For bibliography pass |

## Output

| File | Description |
|------|-------------|
| `report/phase2/main.pdf` | Compiled Phase II IEEE report |
| `report/phase2/main.tex` | LaTeX source (edit this) |
| `report/phase2/refs.bib` | Bibliography database |
| `report/phase2/figures/` | ASCII/verbatim figure sources |

## Status

The LaTeX source includes the integrated Phase II results and the FPGA comparison methodology. Routed measurements require a Vivado run. The checked-in PDF is the earlier Phase II draft until the updated source is rebuilt.

## Notes

- Phase I artifacts (`report/main.tex`, `report/phase1-report.pdf`) are **not modified** by this build.
- All `\texttt{}` macros with underscores use `\_` to avoid IEEEtran `Missing $` errors.
- Do not add `enumitem` package — not available in IEEEtran's default class path without tectonic.
