# LaTeX Compilation Instructions

## Local Compilation

### Using Tectonic (Recommended, Self-Contained)
```bash
cd report/
tectonic main.tex -o .
cp main.pdf phase1-report.pdf
```

### Using Standard TeX Live (pdflatex + bibtex)
If `pdflatex` and `bibtex` are installed:
```bash
cd report/
pdflatex main.tex
bibtex main
pdflatex main.tex
pdflatex main.tex
cp main.pdf phase1-report.pdf
```

## Overleaf Compilation

1. Create a new Overleaf project.
2. Upload `main.tex` and `refs.bib` from this directory.
3. Ensure the compiler is set to **pdfLaTeX**.
4. The IEEEtran class is pre-installed on Overleaf.
5. Compile and download the resulting PDF as `phase1-report.pdf`.
