# LaTeX Compilation Instructions

## Local Compilation

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
6. Place the PDF in this `report/` directory and commit:
   ```bash
   git add report/phase1-report.pdf
   git commit -m "Add compiled Phase I report PDF"
   git push origin main
   ```

## Status

- **LaTeX source**: ✅ Complete (`main.tex`, `refs.bib`)
- **PDF compilation**: ⏳ Pending — `pdflatex` is not installed on the current machine.
  The source is Overleaf-ready and uses only the standard `IEEEtran` class.
