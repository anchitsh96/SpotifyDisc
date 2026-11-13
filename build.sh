#!/bin/bash
# Builds build/SpotifyDisc.app. `./build.sh run` also (re)launches it.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/SpotifyDisc.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos14" \
  -framework AppKit -framework SwiftUI \
  Sources/*.swift -o "$APP/Contents/MacOS/SpotifyDisc"

cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"

if [[ "${1:-}" == "run" ]]; then
  pkill -x SpotifyDisc 2>/dev/null || true
  sleep 0.3
  open "$APP"
fi
