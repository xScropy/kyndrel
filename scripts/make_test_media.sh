#!/usr/bin/env bash
# Generates short, licence-free test clips into test_media/generated/
# (PLAN.md §4). Needs ffmpeg, python3 and Pillow.
#   scripts/make_test_media.sh
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=test_media/generated
mkdir -p "$OUT"
cd "$OUT"

FF=(ffmpeg -nostdin -loglevel error -y)
SRC=(-f lavfi -i testsrc2=size=1280x720:rate=24 -f lavfi -i sine=frequency=440)

"${FF[@]}" "${SRC[@]}" -t 8 -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac clip.mp4
"${FF[@]}" "${SRC[@]}" -t 8 -c:v mpeg4 -q:v 5 -c:a mp3 clip.avi 2>/dev/null \
  || "${FF[@]}" "${SRC[@]}" -t 8 -c:v mpeg4 -q:v 5 -c:a pcm_s16le clip.avi
"${FF[@]}" "${SRC[@]}" -t 8 -c:v libvpx -b:v 1M -deadline realtime -c:a libvorbis clip.webm
"${FF[@]}" "${SRC[@]}" -t 8 -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac \
  -f hls -hls_time 2 -hls_playlist_type vod hls.m3u8

# HEVC (exit criteria; 720p here, real 4K checks are manual).
"${FF[@]}" "${SRC[@]}" -t 4 -c:v libx265 -preset ultrafast -pix_fmt yuv420p -c:a aac \
  -tag:v hvc1 clip_hevc.mp4 2>/dev/null || echo "libx265 missing: skipping HEVC clip"

# Multi-track MKV: 2 audio, SRT + PGS subtitles, scope aspect.
cat > en.srt <<'SRT'
1
00:00:00,500 --> 00:00:30,000
Hello from the embedded English track
SRT
cat > "The.Test.Film.2019.1080p.ar.srt" <<'SRT'
1
00:00:00,500 --> 00:00:30,000
External Arabic file loaded automatically
SRT
cat > extra.srt <<'SRT'
1
00:00:00,500 --> 00:00:30,000
Added with sub-add
SRT
python3 -I ../../scripts/make_pgs.py pgs.sup 1920 800
"${FF[@]}" -f lavfi -i testsrc2=size=1920x800:rate=24 -f lavfi -i sine=frequency=440 \
  -f lavfi -i sine=frequency=660 -i en.srt -i pgs.sup -t 30 \
  -map 0:v -map 1:a -map 2:a -map 3:s -map 4:s \
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac -c:s:0 srt -c:s:1 copy \
  -metadata:s:a:0 language=eng -metadata:s:a:0 title=Stereo -metadata:s:a:1 language=ara \
  -metadata:s:s:0 language=eng -metadata:s:s:1 language=fre \
  "The.Test.Film.2019.1080p.mkv"

# Not a video at all.
echo "this is not a video" > broken.mkv
echo "Generated in $OUT:"; ls -1
