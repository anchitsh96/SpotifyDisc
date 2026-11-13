# SpotifyDisc

A floating Spotify mini-player for macOS: a small spinning vinyl disc with the current album art that expands on hover into a card with title, artist, art, prev / play-pause / next, shuffle, repeat, and a seekable progress bar. The card is tinted with the album's colour.

- Shows only while the Spotify desktop app is running. It talks to Spotify via AppleScript: no login and no Spotify API key. It doesn't need Screen Recording or Accessibility permission.
- macOS asks once: **"SpotifyDisc wants to control Spotify"**. Click Allow. (If you denied it: System Settings › Privacy & Security › Automation › SpotifyDisc › Spotify.)
- Drag the disc anywhere; it remembers the spot. It floats on every Space and over full-screen apps.
- Menu bar disc icon: Hide/Show Widget, Reset Position, Quit. There's no Dock icon.
- Click the album art or title to bring Spotify forward.

## Build & run

Needs the Xcode Command Line Tools (`swiftc`).

```bash
./build.sh run
```

The app is built to `build/SpotifyDisc.app`. Copy it to `/Applications` if you want to keep it. Because it's ad-hoc signed, macOS may ask for the Spotify permission again after a rebuild.

## Files

- `Sources/SpotifyController.swift` — AppleScript bridge, polling + Spotify's playback notification, artwork & tint colour
- `Sources/WidgetController.swift` — floating panel, hover expand/collapse, drag, position memory
- `Sources/Views.swift` — vinyl disc, expanded card, controls, progress bar
- `Sources/main.swift` — app delegate + menu bar item (`--snapshot <dir>` renders PNGs for testing)
