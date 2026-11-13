# Installing SpotifyDisc

SpotifyDisc is a small floating Spotify mini-player for macOS. It shows a spinning vinyl disc with the current album art. Rest your cursor on it for half a second and it opens into a pill with previous / play-pause / next, the track title, and a progress line you can drag to seek.

## The one-line way (with Claude)

Paste this to Claude Code (or any coding agent that can run terminal commands on your Mac):

```
Install the SpotifyDisc widget from https://github.com/anchitsh96/SpotifyDisc by following its INSTALL.md
```

## The manual way

In Terminal:

```bash
git clone https://github.com/anchitsh96/SpotifyDisc.git ~/SpotifyDisc && cd ~/SpotifyDisc && ./build.sh install
```

Then do the two steps under **After installing** below.

---

## Instructions for an AI agent installing this

Follow these steps in order on the user's Mac. Don't use `sudo`; nothing here needs it.

1. **Check the Mac.** Run `sw_vers -productVersion`. It needs macOS 14 (Sonoma) or newer; if it's older, stop and tell the user.
2. **Check for the Swift compiler.** Run `xcrun --find swiftc`. If that fails, run `xcode-select --install`. This opens a macOS dialog that the user has to click through, and the download takes a few minutes. Ask them to finish it, wait until they say it's done, then check `xcrun --find swiftc` again. (A full Xcode install also works.)
3. **Get the code.** If `~/SpotifyDisc` doesn't exist, run `git clone https://github.com/anchitsh96/SpotifyDisc.git ~/SpotifyDisc`. If it already exists and is this repo, run `git -C ~/SpotifyDisc pull` instead. If `~/SpotifyDisc` exists but is something else, clone to a different folder and use that folder below.
4. **Build and install.** Run `cd ~/SpotifyDisc && ./build.sh install`. It compiles the app (about 30–60 seconds), copies it to `~/Applications/SpotifyDisc.app` and launches it. Success ends with `Installed … and launched it.` If the build fails, show the user the error.
5. **Confirm it's running.** Run `pgrep -x SpotifyDisc`; it should print a process ID.
6. **Tell the user what to do next.** Pass on the **After installing** section below in your own words. In particular, they must click **Allow** on the macOS prompt, and the disc only appears while the Spotify desktop app is open.

## After installing

1. **Open the Spotify desktop app** and play something. The disc only shows while Spotify is running, near the top-right of your screen.
2. **Click "Allow"** when macOS asks *"SpotifyDisc wants to control Spotify"*. That's how it reads the current track and sends play/pause/next. If you clicked Don't Allow, turn it on in System Settings › Privacy & Security › Automation › SpotifyDisc › Spotify.

You won't be asked for Screen Recording, Accessibility or a Spotify login. None of them are used.

## Using it

- **Open the controls:** rest your cursor on the disc for half a second.
- **Move it:** grab the disc and drag it anywhere. It remembers the spot.
- **Seek:** hover over the line along the bottom edge of the open pill, then drag the round knob (or click the line).
- **Bring Spotify forward:** click the track title.
- **Hide, reset or quit:** use the disc icon in the menu bar. There's no Dock icon.
- **Start at login (optional):** System Settings › General › Login Items › **+** › choose `~/Applications/SpotifyDisc.app`.

## Updating

```bash
cd ~/SpotifyDisc && git pull && ./build.sh install
```

After an update macOS may ask for the Spotify permission again, because each build is signed on your own Mac.

## Uninstalling

Quit it from the menu bar icon, then:

```bash
rm -rf ~/Applications/SpotifyDisc.app ~/SpotifyDisc
```
