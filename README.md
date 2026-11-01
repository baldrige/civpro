# Civil Procedure

Source for *Civil Procedure* by Thomas B. Bennett, a free casebook for the first-year law school course in federal civil procedure. The book is published at **<https://civ.pro>**.

The book is written in [Quarto](https://quarto.org). Each chapter is a `.qmd` (Markdown) file; `_quarto.yml` sets the chapter order and the HTML/PDF formats.

## Building locally

Requires Quarto (1.7+) and a TeX distribution (`quarto install tinytex`).

```sh
quarto preview          # live-reloading local preview of the website
quarto render           # full build: website + PDF into _book/
quarto render --to pdf  # PDF only
```

## Publishing

Pushing to `main` triggers the GitHub Actions workflow in `.github/workflows/publish.yml`. It renders the website and PDF and deploys them to GitHub Pages. Pull requests are built but not deployed. There is no need to upload anything by hand.

## Corrections

Spotted a typo or an error? Please [open an issue](../../issues) or email tbbennett@smu.edu.
