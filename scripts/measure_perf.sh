#!/usr/bin/env bash
# Measures Kyndrel against its resource budget (task 8.12, perf/budget.env).
#
#   scripts/measure_perf.sh linux <kyndrel-binary> [media] [--record]
#   scripts/measure_perf.sh android <package> [--record]
#
# linux: runs the app under xvfb-run, idle (the library) and then playing
#   [media] (default: the generated 1080p test film), sampling /proc.
# android: reads `dumpsys meminfo` and `dumpsys gfxinfo` from the device
#   adb sees, idle and then while playing (start a video by hand when asked,
#   or let the emulator smoke test do it).
# --record writes the numbers as the new baseline (perf/baseline-*.env).
# Exits 1 when a number is over budget or >TOLERANCE_PCT over baseline.
set -euo pipefail
cd "$(dirname "$0")/.."
source perf/budget.env
MODE=${1:?linux or android}; shift
RECORD=0
ARGS=()
for a in "$@"; do [ "$a" = --record ] && RECORD=1 || ARGS+=("$a"); done

FAIL=0
RESULTS=()
check() { # name value budget (lower is better)
  local name=$1 value=$2 budget=$3 base_var="BASE_$1"
  local base=${!base_var:-}
  local status=ok
  if awk -v v="$value" -v b="$budget" 'BEGIN { exit !(v > b) }'; then
    status="OVER BUDGET ($budget)"; FAIL=1
  elif [ -n "$base" ] && awk -v v="$value" -v b="$base" -v t="$TOLERANCE_PCT" \
      'BEGIN { exit !(v > b * (1 + t / 100) + 0.5) }'; then
    status="REGRESSION (baseline $base)"; FAIL=1
  fi
  printf '%-22s %8s   %s\n' "$name" "$value" "$status"
  RESULTS+=("BASE_$name=$value")
}

# Samples [pid] for [seconds]; prints "cpu_mean_after_warmup rss_max_mb".
sample() {
  local pid=$1 secs=$2 ticks prev_cpu="" prev_t="" cpu now rss
  ticks=$(getconf CLK_TCK)
  local out; out=$(mktemp)
  for ((i = 0; i < secs; i += 2)); do
    sleep 2
    kill -0 "$pid" 2>/dev/null || break
    read -r -a stat < "/proc/$pid/stat"
    cpu=$(( stat[13] + stat[14] ))
    rss=$(awk '/VmRSS/ {print int($2 / 1024)}' "/proc/$pid/status")
    now=$(date +%s%3N)
    if [ -n "$prev_cpu" ]; then
      awk -v c=$((cpu - prev_cpu)) -v t=$((now - prev_t)) -v k="$ticks" -v r="$rss" \
        'BEGIN { printf "%.2f %d\n", 100 * (c / k) / (t / 1000), r }' >> "$out"
    fi
    prev_cpu=$cpu; prev_t=$now
  done
  awk 'NR > 3 {c += $1; n++} {if ($2 > m) m = $2} END {printf "%.1f %d\n", (n ? c / n : 0), m}' "$out"
  rm -f "$out"
}

case "$MODE" in
linux)
  BIN=${ARGS[0]:?binary}
  MEDIA=${ARGS[1]:-test_media/generated/The.Test.Film.2019.1080p.mkv}
  BASELINE=perf/baseline-linux.env
  [ -f "$BASELINE" ] && source "$BASELINE"
  log=$(mktemp)
  start=$(date +%s%3N)
  xvfb-run -a "$BIN" --perf-log 2>"$log" >/dev/null &
  sleep 1
  pid=$(pgrep -n -f "$(basename "$BIN") --perf-log")
  read -r cpu rss <<<"$(sample "$pid" 30)"
  first=$(awk '$1 == "kyndrel-perf" && $2 == "first-frame" {print $3; exit}' "$log")
  kill "$pid" 2>/dev/null || true; wait 2>/dev/null || true
  echo "== Linux, idle library (30 s)"
  [ -n "$first" ] && check LINUX_START_MS $((first - start)) 3000
  check LINUX_IDLE_RSS_MB "$rss" "$LINUX_IDLE_RSS_MB"
  check LINUX_IDLE_CPU_PCT "$cpu" "$LINUX_IDLE_CPU_PCT"
  if [ -f "$MEDIA" ]; then
    xvfb-run -a "$BIN" --perf-log "$MEDIA" 2>"$log" >/dev/null &
    sleep 1
    pid=$(pgrep -n -f "$(basename "$BIN") --perf-log")
    read -r cpu rss <<<"$(sample "$pid" 30)"
    kill "$pid" 2>/dev/null || true; wait 2>/dev/null || true
    echo "== Linux, playing $(basename "$MEDIA") (30 s)"
    # No absolute budget on desktop playback: only the baseline.
    check LINUX_PLAY_RSS_MB "$rss" 100000
    check LINUX_PLAY_CPU_PCT "$cpu" 100000
  fi
  rm -f "$log"
  ;;
android)
  PKG=${ARGS[0]:-dev.kyndrel.kyndrel}
  BASELINE=perf/baseline-android.env
  [ -f "$BASELINE" ] && source "$BASELINE"
  pss() { adb shell dumpsys meminfo "$PKG" | awk '/TOTAL PSS:/ {print int($3 / 1024); exit} /TOTAL:/ {print int($2 / 1024); exit}'; }
  janky() { adb shell dumpsys gfxinfo "$PKG" | awk -F'[()%]' '/Janky frames:/ {print $2; exit}'; }
  adb shell dumpsys gfxinfo "$PKG" reset >/dev/null
  sleep 10
  echo "== Android, idle"
  check ANDROID_IDLE_PSS_MB "$(pss)" "$ANDROID_IDLE_PSS_MB"
  echo "Start a 1080p video in Kyndrel now; measuring in 30 s…"
  sleep 30
  echo "== Android, playing"
  check ANDROID_PLAY_PSS_MB "$(pss)" "$ANDROID_PLAY_PSS_MB"
  check ANDROID_JANKY_PCT "$(janky)" "$ANDROID_JANKY_PCT"
  ;;
*) echo "linux or android" >&2; exit 2 ;;
esac

if [ "$RECORD" = 1 ]; then
  printf '%s\n' "# Recorded by scripts/measure_perf.sh on $(date -u +%F)." "${RESULTS[@]}" > "$BASELINE"
  echo "Baseline written to $BASELINE"
fi
exit "$FAIL"
