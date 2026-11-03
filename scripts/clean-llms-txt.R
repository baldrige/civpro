# Post-render: Quarto copies chapter titles into llms.txt with their Pandoc
# markup, e.g. "[[2]{.chapter-number}  [Pleadings]{.chapter-title}]{#sec-x}".
# Strip the spans so each entry reads "2 Pleadings".
out <- Sys.getenv("QUARTO_PROJECT_OUTPUT_DIR", "_book")
f <- file.path(out, "llms.txt")
if (file.exists(f)) {
  x <- readLines(f, encoding = "UTF-8", warn = FALSE)
  repeat {
    y <- gsub(r"(\[([^][]*)\]\{[^}]*\})", r"(\1)", x, perl = TRUE)
    if (identical(y, x)) break
    x <- y
  }
  x <- gsub(r"((?<=\S)[ \x{00A0}]{2,})", " ", x, perl = TRUE)
  writeLines(x, f, useBytes = TRUE)
}
