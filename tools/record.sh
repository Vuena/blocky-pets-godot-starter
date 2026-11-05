#!/usr/bin/env bash
# Re-records docs/demo.gif and docs/screenshot.png with Godot's Movie Maker mode.
# Needs: a Godot 4 binary (set GODOT=...) with a real renderer (not --headless) and ffmpeg.
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
mkdir -p docs
# 11 seconds at 30 fps; `--autopilot` makes scripts/autopilot.gd drive the character and pet the animals.
"$GODOT" --path . --write-movie docs/_demo.avi --fixed-fps 30 --quit-after 330 -- --autopilot
ffmpeg -y -ss 1 -t 9.5 -i docs/_demo.avi \
  -vf "fps=12,scale=560:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=64:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
  docs/demo.gif
ffmpeg -y -ss 8 -i docs/_demo.avi -frames:v 1 docs/screenshot.png
rm docs/_demo.avi
