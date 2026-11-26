#!/usr/bin/env bash
# Storyboard benchmark (task 8.2): makes a long 1080p H.264 clip with ffmpeg,
# then times a full storyboard render with the real libmpv frame engine and
# reports peak memory. Decides whether the Rust/FFmpeg frame helper is worth
# building (PLAN.md Phase 8).
#   scripts/bench_storyboard.sh            # a 20-minute clip
#   BENCH_MINUTES=120 scripts/bench_storyboard.sh
set -euo pipefail
cd "$(dirname "$0")/.."
MINUTES=${BENCH_MINUTES:-20}
OUT=test_media/generated/bench_${MINUTES}min.mp4
if [ ! -f "$OUT" ]; then
  mkdir -p test_media/generated
  echo "Making a ${MINUTES}-minute 1080p clip (one keyframe every 10 s)…"
  ffmpeg -nostdin -loglevel error -y \
    -f lavfi -i "testsrc2=size=1920x1080:rate=24" -t $((MINUTES * 60)) \
    -c:v libx264 -preset ultrafast -g 240 -pix_fmt yuv420p "$OUT"
fi
KYNDREL_BENCH_MEDIA="$PWD/$OUT" KYNDREL_BENCH_SECONDS=$((MINUTES * 60)) \
  flutter test -t engine --run-skipped test/engine/bench_storyboard_test.dart \
  --reporter expanded 2>&1 | grep -E "^bench|passed|failed|Error"
