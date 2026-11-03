#!/usr/bin/env bash
# Cut each clip listed in audio/clips.csv from the Supreme Court's own
# recording (public domain) and save it as audio/<file>.mp3. Needs ffmpeg.
# Run from the repo root:  bash audio/cut.sh
# Times come from the line-by-line alignment at supremecourt.report/arguments/.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
tail -n +2 "$here/clips.csv" | tr -d '\r' | while IFS=, read -r file docket term start end; do
  src="$work/$docket.mp3"
  [ -f "$src" ] || curl -sfL -A "Mozilla/5.0" -o "$src" \
    "https://www.supremecourt.gov/media/audio/mp3files/$docket.mp3"
  dur=$(awk "BEGIN {print $end - $start}")
  fade=$(awk "BEGIN {print $dur - 0.6}")
  ffmpeg -nostdin -loglevel error -y -ss "$start" -t "$dur" -i "$src" \
    -af "afade=t=in:d=0.3,afade=t=out:st=$fade:d=0.6" -ac 1 -b:a 64k \
    "$here/$file.mp3"
  echo "cut $file.mp3 (${dur}s)"
done
