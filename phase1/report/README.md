# Phase I IEEE Report

[Archived report PDF](phase1-report.pdf) · [LaTeX source](phase1-report.tex) · [Bibliography](references.bib)

From the repository root, build with Tectonic:

```bash
cd phase1/report
tectonic phase1-report.tex
```

With TeX Live or MacTeX, run these commands in this directory:

```bash
pdflatex phase1-report.tex
bibtex phase1-report
pdflatex phase1-report.tex
pdflatex phase1-report.tex
```

For Overleaf, upload the source and bibliography and set phase1-report.tex as the main document.
