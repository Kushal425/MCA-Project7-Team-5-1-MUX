# Phase II IEEE Report

[LaTeX source](phase2-report.tex) · [Bibliography](references.bib) · [Earlier draft PDF](phase2-report.pdf)

The PDF is the earlier draft. Rebuild it to include the latest simulation results and the revised report. FPGA resource and timing measurements are [pending a Vivado run](../docs/fpga-results.md).

From the repository root, build with Tectonic:

```bash
cd phase2/report
tectonic phase2-report.tex
```

With TeX Live or MacTeX, run these commands in this directory:

```bash
pdflatex phase2-report.tex
bibtex phase2-report
pdflatex phase2-report.tex
pdflatex phase2-report.tex
```

For Overleaf, upload the source and bibliography and set phase2-report.tex as the main document.
