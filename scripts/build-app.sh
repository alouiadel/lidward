#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Lidward"
CONFIGURATION="${CONFIGURATION:-release}"
DIST_DIR="$ROOT/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

if [[ ! -f "$ROOT/assets/AppIcon.icns" ]]; then
    echo "Missing app icon; generating it..."
    "$ROOT/scripts/make-icon.sh"
fi

echo "Building $APP_NAME ($CONFIGURATION)..."

# The Command Line Tools on this machine advertise two developer search paths
# that do not exist. They are harmless, but ld warns about them on every link.
# Suppress linker warnings only when those known paths are missing.
LINKER_FLAGS=()
if [[ ! -d /Library/Developer/CommandLineTools/Developer/usr/lib ]] || \
   [[ ! -d /Library/Developer/CommandLineTools/Developer/Library/Frameworks ]]; then
    LINKER_FLAGS+=(-Xlinker -w)
fi

swift build -c "$CONFIGURATION" ${LINKER_FLAGS[@]+"${LINKER_FLAGS[@]}"}

BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
BIN_PATH="$BIN_DIR/$APP_NAME"
HELPER_PATH="$BIN_DIR/LidwardHelper"

if [[ ! -x "$BIN_PATH" ]]; then
    echo "Build failed: $BIN_PATH not found" >&2
    exit 1
fi

if [[ ! -x "$HELPER_PATH" ]]; then
    echo "Build failed: $HELPER_PATH not found" >&2
    exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$HELPER_PATH" "$APP_BUNDLE/Contents/MacOS/LidwardHelper"
cp "$ROOT/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$ROOT/assets/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/LidwardHelper"

codesign --force --sign - --timestamp=none "$APP_BUNDLE/Contents/MacOS/LidwardHelper" >/dev/null
codesign --force --sign - --timestamp=none "$APP_BUNDLE" >/dev/null

echo "Built $APP_BUNDLE"

if [[ "${1:-}" != "--no-open" ]]; then
    open "$APP_BUNDLE"
fi
