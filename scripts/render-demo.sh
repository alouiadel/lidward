#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ffmpeg is required to build the demo animation." >&2
    exit 1
fi

FRAMES="$(mktemp -d)"
trap 'rm -rf "$FRAMES"' EXIT

echo "Building the demo renderer..."
CONFIGURATION=debug "$ROOT/scripts/build-app.sh" --no-open

echo "Rendering frames..."
"$ROOT/dist/Lidward.app/Contents/MacOS/Lidward" --render-demo "$FRAMES"

echo "Encoding GIF..."
DEMO_GIF="$FRAMES/demo.gif"
ffmpeg -y -loglevel error \
    -framerate 10 \
    -i "$FRAMES/frame_%03d.png" \
    -vf "scale=600:620:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128:stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    -loop 0 \
    -f gif \
    "$DEMO_GIF"

cp "$DEMO_GIF" "$ROOT/assets/demo.png"

# The file is a GIF with a .png extension on purpose: GitHub serves the image
# bytes to the browser, which animates it. This keeps the README asset path
# simple while still autoplaying.
echo "Wrote $ROOT/assets/demo.png ($(du -h "$ROOT/assets/demo.png" | cut -f1))"
