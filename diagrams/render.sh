#!/usr/bin/env bash
# Render each diagrams/*.mmd to a PNG beside it, using Quarto's Mermaid support
# on this machine (it needs a local Chrome or Edge). Run from the repo root:
#   bash diagrams/render.sh
# Commit the updated .png files; the GitHub build uses them and never runs Mermaid.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
for mmd in "$here"/*.mmd; do
  name="$(basename "$mmd" .mmd)"
  cp "$mmd" "$work/$name.mmd"
  printf -- '---\nformat:\n  html:\n    mermaid-format: png\n---\n\n```{mermaid}\n%%%%| file: %s.mmd\n```\n' "$name" > "$work/$name.qmd"
  (cd "$work" && quarto render "$name.qmd" --quiet)
  cp "$work/${name}_files/figure-html/mermaid-figure-1.png" "$here/$name.png"
  echo "rendered $name.png"
done
