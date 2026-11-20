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

# DASH (task 4.5).
mkdir -p dash
"${FF[@]}" "${SRC[@]}" -t 8 -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac \
  -f dash -seg_duration 2 dash/manifest.mpd

# Chapters (task 3.6).
cat > chapters.txt <<'META'
;FFMETADATA1
[CHAPTER]
TIMEBASE=1/1000
START=0
END=3000
title=Opening
[CHAPTER]
TIMEBASE=1/1000
START=3000
END=8000
title=The Heist
META
"${FF[@]}" -i clip.mp4 -i chapters.txt -map_metadata 1 -map_chapters 1 -c copy chapters.mkv

# Test matrix (task 5.5) into matrix/.
mkdir -p matrix
# 4K HEVC Main 10 with HDR10 signalling (PQ, BT.2020, mastering display).
"${FF[@]}" -f lavfi -i testsrc2=size=3840x2160:rate=24 -t 2 \
  -c:v libx265 -preset ultrafast -pix_fmt yuv420p10le -tag:v hvc1 \
  -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc \
  -x265-params "hdr10=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1):max-cll=1000,400" \
  matrix/hdr10_4k_hevc10.mp4 2>/dev/null || echo "libx265 missing: skipping HDR10 clip"
# AV1 (SVT-AV1, or libaom).
"${FF[@]}" "${SRC[@]}" -t 3 -c:v libsvtav1 -preset 12 -pix_fmt yuv420p -c:a libopus \
  matrix/av1.mkv 2>/dev/null \
  || "${FF[@]}" "${SRC[@]}" -t 3 -c:v libaom-av1 -cpu-used 8 -row-mt 1 -c:a libopus \
    matrix/av1.mkv 2>/dev/null || echo "no AV1 encoder: skipping AV1 clip"
# 10-bit H.264 (High 10).
"${FF[@]}" "${SRC[@]}" -t 4 -c:v libx264 -preset ultrafast -pix_fmt yuv420p10le -c:a aac \
  matrix/h264_10bit.mp4
# Variable frame rate: drop two of every three frames in the first half.
"${FF[@]}" "${SRC[@]}" -t 8 \
  -vf "select='gte(t,4)+not(mod(n,3))'" -fps_mode vfr \
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac matrix/vfr.mkv
# A broken MKV: the multi-track film cut off at 40 %.
size=$(stat -c %s "The.Test.Film.2019.1080p.mkv")
head -c $((size * 4 / 10)) "The.Test.Film.2019.1080p.mkv" > matrix/truncated.mkv
# Index (moov) first, so a stream cut mid-way has already started playing.
# 30 s, so a cut at 40 % is clearly before the end.
"${FF[@]}" "${SRC[@]}" -t 30 -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac \
  -movflags +faststart matrix/faststart.mp4
# A huge subtitle file: 100 000 cues (~5 MB).
python3 -I - matrix/huge.srt <<'PY'
import sys
with open(sys.argv[1], "w", encoding="utf-8") as f:
    for i in range(100_000):
        a, b = i * 1000, i * 1000 + 900
        ts = lambda ms: "%02d:%02d:%02d,%03d" % (ms // 3600000, ms // 60000 % 60, ms // 1000 % 60, ms % 1000)
        f.write(f"{i + 1}\n{ts(a)} --> {ts(b)}\nLine {i + 1} of a very long subtitle file\n\n")
PY

# Music with tags and cover art (tasks 7.3, 7.6), and one without a cover.
"${FF[@]}" -f lavfi -i testsrc2=size=300x300 -frames:v 1 cover.png
"${FF[@]}" -f lavfi -i "sine=frequency=330:duration=6" -i cover.png \
  -map 0:a -map 1:v -c:a libmp3lame -q:a 6 -c:v mjpeg -disposition:v attached_pic \
  -id3v2_version 3 -metadata title="Night Drive" -metadata artist="Kyndrel Tests" \
  -metadata album="Test Tones" -metadata track=3 song.mp3
"${FF[@]}" -f lavfi -i "sine=frequency=440:duration=6" -c:a flac \
  -metadata title="Plain Tone" plain.flac

# Not a video at all.
echo "this is not a video" > broken.mkv
echo "Generated in $OUT:"; ls -1
