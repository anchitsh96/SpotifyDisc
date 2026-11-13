# SpotifyDisc

A floating Spotify mini-player for macOS. While the Spotify desktop app is open, a small vinyl disc with the current album art floats on your screen and spins while music plays. Rest your cursor on it for half a second and it opens into a pill the same height:

- previous / play-pause / next
- the track title, which scrolls when it's longer than 15 characters
- a progress line along the bottom edge; hover over it to get a round knob you can drag to seek
- a background tinted with the album art's colour

Drag the disc anywhere and it remembers the spot. It floats on every desktop and over full-screen apps, and has a menu bar icon to hide it or quit.

It talks to the Spotify app through AppleScript, so there's no Spotify login or API key. macOS asks once for permission to control Spotify. It doesn't need Screen Recording or Accessibility.

## Install

Tell Claude Code (or another coding agent on your Mac):

```
Install the SpotifyDisc widget from https://github.com/anchitsh96/SpotifyDisc by following its INSTALL.md
```

Or run it yourself:

```bash
git clone https://github.com/anchitsh96/SpotifyDisc.git ~/SpotifyDisc && cd ~/SpotifyDisc && ./build.sh install
```

Requires macOS 14 or newer and the Xcode Command Line Tools (`xcode-select --install`). See [INSTALL.md](INSTALL.md) for permissions, updating and uninstalling.

## Development

```bash
./build.sh run      # build to build/ and launch
./build.sh install  # build, copy to ~/Applications and launch
```

- `Sources/SpotifyController.swift` — AppleScript bridge, polling + Spotify's playback notification, artwork and tint colour
- `Sources/WidgetController.swift` — floating panel, hover-to-open delay, dragging, position memory
- `Sources/Views.swift` — vinyl disc, expanded pill, marquee title, seek stroke
- `Sources/main.swift` — app delegate and menu bar item (`--snapshot <dir>` renders PNGs for testing)
