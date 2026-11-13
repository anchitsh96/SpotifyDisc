import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var spotify: SpotifyController!
    private var widget: WidgetController!
    private var statusItem: NSStatusItem!
    private let toggleItem = NSMenuItem(title: "Hide Widget", action: #selector(toggleWidget), keyEquivalent: "h")
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        spotify = SpotifyController()
        widget = WidgetController(spotify: spotify)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "opticaldisc", accessibilityDescription: "SpotifyDisc")
            ?? NSImage(systemSymbolName: "music.note", accessibilityDescription: "SpotifyDisc")

        let menu = NSMenu()
        menu.delegate = self
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        toggleItem.target = self
        menu.addItem(toggleItem)
        let reset = NSMenuItem(title: "Reset Position", action: #selector(resetPosition), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SpotifyDisc", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count { snapshot(to: args[i + 1]) }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        toggleItem.title = widget.userHidden ? "Show Widget" : "Hide Widget"
        if !spotify.isRunning {
            statusLine.title = "Spotify isn't running"
        } else if spotify.permissionDenied {
            statusLine.title = "Needs Automation permission for Spotify"
        } else if spotify.hasTrack {
            statusLine.title = "\(spotify.isPlaying ? "▶︎" : "❚❚")  \(spotify.track.title) — \(spotify.track.artist)"
        } else {
            statusLine.title = "Nothing playing"
        }
    }

    /// `SpotifyDisc --snapshot <dir>`: renders the disc and card with live data to PNGs, then quits.
    func snapshot(to dir: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [self] in
            let s = spotify!, w = widget!
            print("running=\(s.isRunning) playing=\(s.isPlaying) hasTrack=\(s.hasTrack) denied=\(s.permissionDenied) title=\(s.track.title) artist=\(s.track.artist) art=\(s.artwork != nil)")
            let disc = VinylDisc(art: s.artwork, playing: false, size: WidgetController.discD)
                .frame(width: 64, height: 64).padding(20).background(Color.gray.opacity(0.3))
            let card = WidgetView(c: w, s: s, forceExpanded: true).background(Color.gray.opacity(0.3))
            let seek = WidgetView(c: w, s: s, forceExpanded: true, forceSeekHover: true).background(Color.gray.opacity(0.3))
            for (name, view) in [("disc", AnyView(disc)), ("card", AnyView(card)), ("seek", AnyView(seek))] {
                let r = ImageRenderer(content: view); r.scale = 2
                if let img = r.nsImage, let tiff = img.tiffRepresentation,
                   let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
                }
            }
            NSApp.terminate(nil)
        }
    }

    @objc private func toggleWidget() { widget.userHidden.toggle() }
    @objc private func resetPosition() { widget.userHidden = false; widget.resetPosition() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
