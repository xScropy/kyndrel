#!/usr/bin/env bash
# Performance probe (task 5.4). Launches a built Kyndrel with --perf-log on
# a media file, samples CPU and memory, and prints a summary.
#
#   scripts/perf_probe.sh <kyndrel-binary> <media-file> [seconds]
#
# Needs a display (use xvfb-run on headless Linux). Linux only: it reads
# /proc and uses ps. Example:
#   flutter build linux --release
#   scripts/perf_probe.sh build/linux/x64/release/bundle/kyndrel film.mkv 600
set -euo pipefail

BIN=${1:?binary}; MEDIA=${2:?media}; SECS=${3:-60}
LOG=$(mktemp); SAMPLES=$(mktemp)
trap 'rm -f "$LOG" "$SAMPLES"' EXIT

START=$(date +%s%3N)
"$BIN" --perf-log "$MEDIA" 2>"$LOG" >/dev/null &
PID=$!
TICKS=$(getconf CLK_TCK)

prev_cpu=""; prev_t=""
for ((i = 0; i < SECS; i += 2)); do
  sleep 2
  kill -0 "$PID" 2>/dev/null || { echo "app exited early" >&2; break; }
  # utime + stime of the process (all threads), in clock ticks.
  read -r -a stat < "/proc/$PID/stat"
  cpu=$(( stat[13] + stat[14] ))
  rss_kb=$(awk '/VmRSS/ {print $2}' "/proc/$PID/status")
  now=$(date +%s%3N)
  if [ -n "$prev_cpu" ]; then
    pct=$(awk -v c=$((cpu - prev_cpu)) -v t=$((now - prev_t)) -v k="$TICKS" \
      'BEGIN { printf "%.1f", 100 * (c / k) / (t / 1000) }')
    echo "$(( (now - START) / 1000 )) $pct $(( rss_kb / 1024 ))" >> "$SAMPLES"
  fi
  prev_cpu=$cpu; prev_t=$now
done
kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true

at() { awk -v e="$1" '$1 == "kyndrel-perf" && $2 == e {print $3; exit}' "$LOG"; }
main=$(at main); frame=$(at first-frame); video=$(at first-video-frame)
echo "== Kyndrel perf probe: $(basename "$MEDIA"), ${SECS}s"
[ -n "$main" ] && echo "process start -> Dart main:      $((main - START)) ms"
[ -n "$frame" ] && echo "process start -> first frame:    $((frame - START)) ms"
[ -n "$video" ] && echo "process start -> first video:    $((video - START)) ms"
if [ -s "$SAMPLES" ]; then
  awk 'NR == 1 {first = $3}
       {cpu += $2; n++; if ($3 > max) max = $3; last = $3; if (NR > 3) {c2 += $2; n2++}}
       END {
         printf "CPU mean (all cores, %%):        %.0f\n", cpu / n
         if (n2) printf "CPU mean after warm-up (%%):     %.0f\n", c2 / n2
         printf "RSS first / last / max (MB):    %d / %d / %d\n", first, last, max
       }' "$SAMPLES"
  # Memory trend: least-squares slope of RSS over the second half.
  awk -v n="$(wc -l < "$SAMPLES")" 'NR > n / 2 {x += $1; y += $3; xy += $1 * $3; xx += $1 * $1; k++}
       END { if (k > 2) { s = (k * xy - x * y) / (k * xx - x * x);
             printf "RSS trend, 2nd half (MB/hour):  %.1f\n", s * 3600 } }' "$SAMPLES"
fi
last() { awk -v e="$1" '$1 == "kyndrel-perf" && $2 == e {v = $4} END {print v}' "$LOG"; }
echo "dropped frames (mpv, total):    $(last dropped-frames)"
echo "measured video fps (last):      $(last fps)"
grep -q "kyndrel-perf" "$LOG" || { echo "no perf log; app output:" >&2; head -20 "$LOG" >&2; }
