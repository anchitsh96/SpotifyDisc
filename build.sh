#!/bin/bash
# ./build.sh          build build/SpotifyDisc.app
# ./build.sh run      build, then (re)launch it from build/
# ./build.sh install  build, copy to ~/Applications, then (re)launch it from there
set -euo pipefail
cd "$(dirname "$0")"

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "error: swiftc not found. Install the Xcode Command Line Tools with: xcode-select --install" >&2
  exit 1
fi

APP=build/SpotifyDisc.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos14" \
  -framework AppKit -framework SwiftUI \
  Sources/*.swift -o "$APP/Contents/MacOS/SpotifyDisc"

cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"

case "${1:-}" in
  run)
    pkill -x SpotifyDisc 2>/dev/null || true
    sleep 0.3
    open "$APP"
    ;;
  install)
    DEST="$HOME/Applications/SpotifyDisc.app"
    pkill -x SpotifyDisc 2>/dev/null || true
    sleep 0.3
    mkdir -p "$HOME/Applications"
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    open "$DEST"
    echo "Installed $DEST and launched it."
    ;;
esac
