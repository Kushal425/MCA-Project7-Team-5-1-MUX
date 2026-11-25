# Phase II IEEE Report

[LaTeX source](phase2-report.tex) · [Bibliography](references.bib) · [Report PDF](phase2-report.pdf)

The PDF uses the Phase I typography and two-column layout and includes the verified Phase II simulation and [post-route FPGA results](../docs/fpga-results.md). The IEEEtran source below can be compiled with LaTeX.

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
