#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Lidward"
CONFIGURATION="${CONFIGURATION:-release}"
DIST_DIR="$ROOT/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT/Info.plist" 2>/dev/null || true)"
TAG="v$VERSION"
ASSET="$DIST_DIR/$APP_NAME-$VERSION.zip"
CHECKSUM="$ASSET.sha256"

DO_INSTALL=0
DO_UNINSTALL=0
DO_PURGE=0
DO_PACKAGE=0
DO_RELEASE=0
OPEN_APP=1

usage() {
    cat <<EOF
Usage: ./scripts/build-app.sh [options]

Options:
  --install     Build and install to $INSTALL_DIR/$APP_NAME.app
  --uninstall   Remove $INSTALL_DIR/$APP_NAME.app (and optionally the helper)
  --purge       Uninstall and remove preferences, login item, and helper
  --package     Build a sanitized ZIP and checksum without publishing
  --release     Build a sanitized ZIP and publish it to GitHub Releases
  --no-open     Do not launch the app after building/installing
  -h, --help    Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install) DO_INSTALL=1 ;;
        --uninstall) DO_UNINSTALL=1 ;;
        --purge) DO_UNINSTALL=1; DO_PURGE=1 ;;
        --package) DO_PACKAGE=1 ;;
        --release) DO_RELEASE=1 ;;
        --no-open) OPEN_APP=0 ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

if [[ -z "$VERSION" ]]; then
    echo "Could not read CFBundleShortVersionString from Info.plist." >&2
    exit 1
fi

if [[ $DO_RELEASE -eq 1 ]]; then
    CONFIGURATION="release"
fi

build_app() {
    if [[ ! -f "$ROOT/assets/AppIcon.icns" ]]; then
        echo "Missing app icon; generating it..."
        "$ROOT/scripts/make-icon.sh"
    fi

    echo "Building $APP_NAME ($CONFIGURATION)..."

    local swift_flags=()
    if [[ "$CONFIGURATION" == "release" ]]; then
        # Do not embed debug info or build paths in release binaries.
        swift_flags+=(-Xswiftc -gnone)
    fi

    # The Command Line Tools on this machine advertise two developer search
    # paths that do not exist. They are harmless, but ld warns about them on
    # every link. Suppress linker warnings only when those known paths are
    # missing.
    local linker_flags=()
    if [[ ! -d /Library/Developer/CommandLineTools/Developer/usr/lib ]] || \
       [[ ! -d /Library/Developer/CommandLineTools/Developer/Library/Frameworks ]]; then
        linker_flags+=(-Xlinker -w)
    fi

    swift build -c "$CONFIGURATION" \
        ${swift_flags[@]+"${swift_flags[@]}"} \
        ${linker_flags[@]+"${linker_flags[@]}"}

    local bin_dir
    bin_dir="$(swift build -c "$CONFIGURATION" --show-bin-path)"

    local bin_path="$bin_dir/$APP_NAME"
    local helper_path="$bin_dir/LidwardHelper"

    if [[ ! -x "$bin_path" ]]; then
        echo "Build failed: $bin_path not found" >&2
        exit 1
    fi

    if [[ ! -x "$helper_path" ]]; then
        echo "Build failed: $helper_path not found" >&2
        exit 1
    fi

    rm -rf "$APP_BUNDLE"
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Resources"

    cp "$bin_path" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    cp "$helper_path" "$APP_BUNDLE/Contents/MacOS/LidwardHelper"
    cp "$ROOT/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
    cp "$ROOT/assets/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    chmod +x "$APP_BUNDLE/Contents/MacOS/LidwardHelper"

    /usr/bin/xattr -cr "$APP_BUNDLE" || true

    # Package builds are signed after stripping, so the signature is not
    # invalidated by strip/install_name_tool in between.
    if [[ $DO_RELEASE -eq 0 && $DO_PACKAGE -eq 0 ]]; then
        codesign --force --sign - --timestamp=none "$APP_BUNDLE/Contents/MacOS/LidwardHelper" >/dev/null
        codesign --force --sign - --timestamp=none "$APP_BUNDLE" >/dev/null
    fi

    echo "Built $APP_BUNDLE"
}

sanitize_app() {
    local bin="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    local helper="$APP_BUNDLE/Contents/MacOS/LidwardHelper"

    echo "Sanitizing release bundle..."

    /usr/bin/strip -S -x "$bin" "$helper"

    # Remove toolchain-only rpaths so the release does not advertise the
    # machine's Command Line Tools installation.
    local binary rpath
    for binary in "$bin" "$helper"; do
        while IFS= read -r rpath; do
            [[ -z "$rpath" ]] && continue
            if [[ "$rpath" == /Library/Developer/CommandLineTools/* ]]; then
                /usr/bin/install_name_tool -delete_rpath "$rpath" "$binary"
            fi
        done < <(/usr/bin/otool -l "$binary" | /usr/bin/awk '/LC_RPATH/{getline; getline; print $2}')
    done

    /usr/bin/xattr -cr "$APP_BUNDLE"
    find "$APP_BUNDLE" -name '.DS_Store' -delete
    find "$APP_BUNDLE" -name '._*' -delete

    codesign --force --sign - --timestamp=none "$helper" >/dev/null
    codesign --force --sign - --timestamp=none "$APP_BUNDLE" >/dev/null
    codesign --verify --deep --strict "$APP_BUNDLE"

    assert_no_personal_metadata
}

assert_no_personal_metadata() {
    local leaks
    leaks="$(find "$APP_BUNDLE" -type f -exec /usr/bin/strings -a {} + \
        | /usr/bin/grep -E '/Users/|/home/|adelaloui|Adel Aloui' || true)"

    if [[ -n "$leaks" ]]; then
        echo "Privacy check failed: personal build metadata found:" >&2
        echo "$leaks" | head -20 >&2
        exit 1
    fi

    if /usr/bin/otool -l "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
        | /usr/bin/grep -q '/Library/Developer/CommandLineTools'; then
        echo "Privacy check failed: toolchain path still embedded." >&2
        exit 1
    fi

    if /usr/bin/otool -l "$APP_BUNDLE/Contents/MacOS/LidwardHelper" \
        | /usr/bin/grep -q '/Library/Developer/CommandLineTools'; then
        echo "Privacy check failed: toolchain path still embedded in helper." >&2
        exit 1
    fi

    echo "Privacy check passed: no personal build paths or toolchain paths."
}

install_app() {
    local target="$INSTALL_DIR/$APP_NAME.app"

    echo "Installing to $target..."

    pkill -x "$APP_NAME" 2>/dev/null || true
    sleep 1

    if [[ -d "$target" ]]; then
        rm -rf "$target" 2>/dev/null || sudo rm -rf "$target"
    fi

    if ! ditto --norsrc --noextattr --noacl "$APP_BUNDLE" "$target" 2>/dev/null; then
        sudo ditto --norsrc --noextattr --noacl "$APP_BUNDLE" "$target"
    fi

    /usr/bin/xattr -cr "$target" 2>/dev/null || sudo /usr/bin/xattr -cr "$target"

    echo "Installed $target"

    if [[ $OPEN_APP -eq 1 ]]; then
        open "$target"
    fi
}

uninstall_app() {
    local target="$INSTALL_DIR/$APP_NAME.app"

    echo "Uninstalling $APP_NAME..."

    if [[ $DO_PURGE -eq 1 && "$INSTALL_DIR" == "/Applications" && -x "$target/Contents/MacOS/$APP_NAME" ]]; then
        "$target/Contents/MacOS/$APP_NAME" --unregister-login-item || true
    fi

    pkill -x "$APP_NAME" 2>/dev/null || true
    sleep 1

    if [[ -d "$target" ]]; then
        rm -rf "$target" 2>/dev/null || sudo rm -rf "$target"
        echo "Removed $target"
    else
        echo "$target is not installed."
    fi

    if [[ $DO_PURGE -eq 1 && "$INSTALL_DIR" == "/Applications" ]]; then
        /usr/bin/defaults delete app.lidward 2>/dev/null || true
        /usr/bin/defaults delete dev.alouiadel.lidward 2>/dev/null || true
        rm -f \
            "$HOME/Library/Preferences/app.lidward.plist" \
            "$HOME/Library/Preferences/dev.alouiadel.lidward.plist"
        rm -rf \
            "$HOME/Library/Saved Application State/app.lidward.savedState" \
            "$HOME/Library/Saved Application State/dev.alouiadel.lidward.savedState"
        echo "Removed preferences."
    fi

    if [[ "$INSTALL_DIR" == "/Applications" ]] && \
       [[ -f /usr/local/libexec/lidward-helper || -f /etc/sudoers.d/lidward ]]; then
        echo
        echo "The closed-display helper is still installed."

        if [[ $DO_PURGE -eq 1 ]]; then
            sudo /usr/bin/pmset -a disablesleep 0 || true
            sudo /bin/rm -f \
                /etc/sudoers.d/lidward \
                /usr/local/libexec/lidward-helper \
                /var/run/lidward-disablesleep.previous
            echo "Closed-display helper removed."
        elif [[ -t 0 ]]; then
            read -r -p "Remove the helper, sudoers rule, and restore sleep? [y/N] " answer

            if [[ "$answer" =~ ^[Yy]$ ]]; then
                sudo /usr/bin/pmset -a disablesleep 0 || true
                sudo /bin/rm -f \
                    /etc/sudoers.d/lidward \
                    /usr/local/libexec/lidward-helper \
                    /var/run/lidward-disablesleep.previous
                echo "Closed-display helper removed."
            else
                echo "Left the helper installed."
            fi
        else
            echo "Run these commands to remove it:"
            echo "  sudo pmset -a disablesleep 0"
            echo "  sudo rm -f /etc/sudoers.d/lidward /usr/local/libexec/lidward-helper /var/run/lidward-disablesleep.previous"
        fi
    fi

    if [[ $DO_PURGE -eq 1 ]]; then
        echo "Purged Lidward."
        echo "If an older Lidward login item remains, remove it in System Settings → General → Login Items."
    else
        echo "If Lidward still appears in Login Items, remove it in System Settings → General → Login Items."
    fi
}

package_app() {
    sanitize_app

    rm -f "$ASSET" "$CHECKSUM"
    ditto -c -k --keepParent --norsrc --noextattr --noacl "$APP_BUNDLE" "$ASSET"

    # Keep the checksum file free of the local build path.
    (
        cd "$DIST_DIR"
        shasum -a 256 "$(basename "$ASSET")" > "$(basename "$CHECKSUM")"
    )

    echo "Created $ASSET"
    cat "$CHECKSUM"
}

release_notes_file() {
    local notes="$DIST_DIR/$APP_NAME-$VERSION-notes.md"

    if [[ -f "$ROOT/CHANGELOG.md" ]]; then
        /usr/bin/awk -v version="$VERSION" '
            index($0, "## [" version "]") == 1 { capture=1; next }
            capture && index($0, "## [") == 1 { exit }
            capture { print }
        ' "$ROOT/CHANGELOG.md" > "$notes"
    fi

    if [[ ! -s "$notes" ]]; then
        echo "$APP_NAME $VERSION" > "$notes"
    fi

    printf '%s' "$notes"
}

publish_release() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "gh is not installed." >&2
        exit 1
    fi

    if ! gh auth status >/dev/null 2>&1; then
        echo "gh is not authenticated." >&2
        exit 1
    fi

    local notes
    notes="$(release_notes_file)"

    if gh release view "$TAG" >/dev/null 2>&1; then
        echo "Release $TAG already exists; updating notes and assets..."
        gh release edit "$TAG" --notes-file "$notes"
        gh release upload "$TAG" "$ASSET" "$CHECKSUM" --clobber
    else
        echo "Creating release $TAG..."
        gh release create "$TAG" "$ASSET" "$CHECKSUM" \
            --title "$APP_NAME $VERSION" \
            --notes-file "$notes"
    fi

    gh release view "$TAG" --json url --jq .url
}

if [[ $DO_UNINSTALL -eq 1 ]]; then
    uninstall_app
    exit 0
fi

if [[ $DO_RELEASE -eq 1 || $DO_PACKAGE -eq 1 ]]; then
    if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
        echo "Warning: working tree has uncommitted changes; the package will include them." >&2
    fi
fi

build_app

if [[ $DO_RELEASE -eq 1 ]]; then
    package_app
    publish_release
elif [[ $DO_PACKAGE -eq 1 ]]; then
    package_app
fi

if [[ $DO_INSTALL -eq 1 ]]; then
    install_app
fi

if [[ $DO_INSTALL -eq 0 && $DO_RELEASE -eq 0 && $DO_PACKAGE -eq 0 && $OPEN_APP -eq 1 ]]; then
    open "$APP_BUNDLE"
fi
