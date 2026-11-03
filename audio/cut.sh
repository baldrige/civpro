#!/usr/bin/env bash
# Cut each clip listed in audio/clips.csv from its source recording and save it
# as audio/<file>.mp3. Needs ffmpeg. Run from the repo root:  bash audio/cut.sh
# (or  bash audio/cut.sh mallory ford  to cut only those clips).
#
# Sources: the Supreme Court's own recordings (public domain), with times from
# the line-by-line alignment at supremecourt.report/arguments/; and, for
# arguments before October 2017, Oyez's recordings and timed transcripts
# (oyez.org, CC BY-NC 4.0).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
tail -n +2 "$here/clips.csv" | tr -d '\r' | while IFS=, read -r file start end url; do
  if [ $# -gt 0 ] && [[ " $* " != *" $file "* ]]; then continue; fi
  src="$work/$(basename "$url")"
  [ -f "$src" ] || curl -sfL -A "Mozilla/5.0" -o "$src" "$url"
  dur=$(awk "BEGIN {print $end - $start}")
  fade=$(awk "BEGIN {print $dur - 0.6}")
  ffmpeg -nostdin -loglevel error -y -ss "$start" -t "$dur" -i "$src" \
    -af "afade=t=in:d=0.3,afade=t=out:st=$fade:d=0.6" -ac 1 -b:a 64k \
    "$here/$file.mp3"
  echo "cut $file.mp3 (${dur}s)"
done
