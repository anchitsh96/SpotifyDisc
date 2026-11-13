import AppKit
import Combine

struct TrackInfo: Equatable {
    var id = ""
    var title = ""
    var artist = ""
    var album = ""
    var artworkURL = ""
    var duration: Double = 0 // seconds
}

/// Talks to the Spotify desktop app over AppleScript (no login, no network API).
final class SpotifyController: ObservableObject {
    static let bundleID = "com.spotify.client"
    static let fallbackTint = NSColor(calibratedRed: 0.10, green: 0.36, blue: 0.20, alpha: 1)

    @Published private(set) var isRunning = false
    @Published private(set) var isPlaying = false
    @Published private(set) var hasTrack = false
    @Published private(set) var track = TrackInfo()
    @Published private(set) var position: Double = 0
    @Published private(set) var positionStamp = Date()
    @Published private(set) var shuffling = false
    @Published private(set) var repeating = false
    @Published private(set) var artwork: NSImage?
    @Published private(set) var tint: NSColor = SpotifyController.fallbackTint
    @Published private(set) var permissionDenied = false

    private let queue = DispatchQueue(label: "spotifydisc.applescript", qos: .userInitiated)
    private var timer: Timer?
    private var inFlight = false
    private var loadedArtURL = ""
    private var artCache: [String: (NSImage, NSColor)] = [:]

    init() {
        isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(appLaunched(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        ws.addObserver(self, selector: #selector(appTerminated(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(playbackChanged(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil)
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        refresh()
    }

    // MARK: - Running state

    @objc private func appLaunched(_ n: Notification) {
        guard (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == Self.bundleID else { return }
        isRunning = true
        // Spotify needs a moment before it answers Apple Events.
        for delay in [1.5, 4.0] { DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.refresh() } }
    }

    @objc private func appTerminated(_ n: Notification) {
        guard (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == Self.bundleID else { return }
        isRunning = false
        isPlaying = false
    }

    @objc private func playbackChanged(_ n: Notification) { refresh() }

    // MARK: - Position

    func currentPosition(at date: Date = Date()) -> Double {
        guard isPlaying else { return position }
        return min(position + date.timeIntervalSince(positionStamp), max(track.duration, 0))
    }

    // MARK: - Polling

    private static let stateScript = """
    if application "Spotify" is running then
        with timeout of 3 seconds
            tell application "Spotify"
                set pstate to player state as string
                if pstate is "stopped" then return "stopped"
                set t to current track
                set sep to character id 31
                return pstate & sep & (name of t) & sep & (artist of t) & sep & (album of t) & sep & (artwork url of t) & sep & ((duration of t) as string) & sep & ((player position) as string) & sep & (shuffling as string) & sep & (repeating as string) & sep & (id of t)
            end tell
        end timeout
    end if
    return "notrunning"
    """

    func refresh() {
        guard isRunning, !inFlight else { return }
        inFlight = true
        queue.async { [weak self] in
            let (out, err) = Self.run(Self.stateScript)
            DispatchQueue.main.async {
                guard let self else { return }
                self.inFlight = false
                self.apply(out, err)
            }
        }
    }

    private func apply(_ out: String?, _ err: Int?) {
        if ProcessInfo.processInfo.environment["SPOTIFYDISC_DEBUG"] != nil || CommandLine.arguments.contains("--snapshot") {
            FileHandle.standardError.write("refresh: out=\(out ?? "nil") err=\(err.map(String.init) ?? "nil")\n".data(using: .utf8)!)
        }
        if let err {
            if err == -1743 { permissionDenied = true }
            return
        }
        permissionDenied = false
        guard let out else { return }
        if out == "notrunning" { return }
        if out == "stopped" {
            hasTrack = false; isPlaying = false
            return
        }
        let f = out.components(separatedBy: "\u{1F}")
        guard f.count >= 10 else { return }
        let num: (String) -> Double = { Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        let newTrack = TrackInfo(id: f[9], title: f[1], artist: f[2], album: f[3], artworkURL: f[4], duration: num(f[5]) / 1000)
        if newTrack != track { track = newTrack }
        hasTrack = true
        isPlaying = f[0] == "playing"
        position = num(f[6])
        positionStamp = Date()
        shuffling = f[7] == "true"
        repeating = f[8] == "true"
        loadArtwork(newTrack.artworkURL)
    }

    // MARK: - Commands

    func playPause() {
        position = currentPosition(); positionStamp = Date()
        isPlaying.toggle()
        command("playpause")
    }
    func next() { command("next track") }
    func previous() { command("previous track") }
    func toggleShuffle() { shuffling.toggle(); command("set shuffling to not shuffling") }
    func toggleRepeat() { repeating.toggle(); command("set repeating to not repeating") }
    func seek(to seconds: Double) {
        position = seconds; positionStamp = Date()
        command("set player position to \(String(format: "%.2f", seconds))")
    }
    func openSpotify() {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).first?.activate()
    }

    private func command(_ cmd: String) {
        guard isRunning else { return }
        let script = "if application \"Spotify\" is running then\nwith timeout of 3 seconds\ntell application \"Spotify\" to \(cmd)\nend timeout\nend if"
        queue.async { [weak self] in
            let (_, err) = Self.run(script)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if err == -1743 { self?.permissionDenied = true }
                self?.refresh()
            }
        }
    }

    /// Runs on `queue` only.
    private static func run(_ source: String) -> (String?, Int?) {
        guard let script = NSAppleScript(source: source) else { return (nil, -1) }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error { return (nil, (error[NSAppleScript.errorNumber] as? Int) ?? -1) }
        return (result.stringValue, nil)
    }

    // MARK: - Artwork + tint

    private func loadArtwork(_ urlString: String) {
        guard urlString != loadedArtURL else { return }
        loadedArtURL = urlString
        if let cached = artCache[urlString] {
            artwork = cached.0; tint = cached.1
            return
        }
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            artwork = nil; tint = Self.fallbackTint
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            let color = Self.dominantColor(image) ?? Self.fallbackTint
            DispatchQueue.main.async {
                guard let self, self.loadedArtURL == urlString else { return }
                self.artCache[urlString] = (image, color)
                self.artwork = image
                self.tint = color
            }
        }.resume()
    }

    /// Saturation-weighted average of a 16×16 downsample, pushed into a range that reads well under white text.
    static func dominantColor(_ image: NSImage) -> NSColor? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let n = 16
        var px = [UInt8](repeating: 0, count: n * n * 4)
        let ok: Bool = px.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
            return true
        }
        guard ok else { return nil }
        var r = 0.0, g = 0.0, b = 0.0, wsum = 0.0
        for i in stride(from: 0, to: px.count, by: 4) {
            let pr = Double(px[i]) / 255, pg = Double(px[i + 1]) / 255, pb = Double(px[i + 2]) / 255
            let mx = max(pr, pg, pb), mn = min(pr, pg, pb)
            let sat = mx == 0 ? 0 : (mx - mn) / mx
            let w = sat * sat * mx + 0.02
            r += pr * w; g += pg * w; b += pb * w; wsum += w
        }
        let avg = NSColor(calibratedRed: r / wsum, green: g / wsum, blue: b / wsum, alpha: 1)
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
        avg.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
        return NSColor(calibratedHue: h, saturation: min(s * 1.15, 0.85), brightness: min(max(v, 0.30), 0.46), alpha: 1)
    }
}
