import SwiftUI
import AppKit

private let spotifyGreen = Color(red: 0.11, green: 0.73, blue: 0.33)

/// Idle: a vinyl disc. Hover: the disc stays put and a pill of the same height grows sideways
/// out of it: [prev ▶︎ next] [marquee title] (disc), with progress as a stroke on the bottom edge.
struct WidgetView: View {
    @ObservedObject var c: WidgetController
    @ObservedObject var s: SpotifyController
    var forceExpanded = false   // snapshots only
    var forceSeekHover = false  // snapshots only

    var body: some View {
        ZStack(alignment: c.expandsLeft ? .trailing : .leading) {
            Color.clear
            pill
        }
        .padding(WidgetController.pad)
        .frame(width: WidgetController.winSize.width, height: WidgetController.winSize.height)
    }

    private var pill: some View {
        let e = c.expanded || forceExpanded
        let d = WidgetController.discD
        let w = WidgetController.cardW
        let align: Alignment = c.expandsLeft ? .trailing : .leading
        let active = s.isPlaying && s.hasTrack
        return ZStack(alignment: align) {
            if e {
                background
                    .frame(width: w, height: d)
                    .transition(.opacity.animation(.easeOut(duration: 0.18)))
                CardContent(c: c, s: s)
                    .frame(width: w, height: d)
                    .transition(.opacity.animation(.easeOut(duration: 0.2).delay(0.08)))
            }
            VinylDisc(art: s.artwork, playing: active, size: d)
                .frame(width: d, height: d)
                .opacity(!e && !active ? 0.72 : 1)
        }
        .frame(width: e ? w : d, height: d, alignment: align)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(e ? 0.14 : 0.08), lineWidth: 0.5))
        .overlay(alignment: .bottom) {
            if e {
                SeekStroke(s: s, expandsLeft: c.expandsLeft, forceHover: forceSeekHover)
                    .transition(.opacity.animation(.easeOut(duration: 0.2).delay(0.1)))
            }
        }
        .shadow(color: .black.opacity(0.38), radius: e ? 14 : 9, y: e ? 6 : 4)
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { _ in c.dragChanged() }
                .onEnded { _ in c.dragEnded() }
        )
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: e)
        .animation(.easeInOut(duration: 0.6), value: s.tint)
    }

    private var background: some View {
        ZStack {
            VisualEffectBlur()
            Color(nsColor: s.tint).opacity(0.85)
            LinearGradient(colors: [.white.opacity(0.10), .clear, .black.opacity(0.15)],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - Idle disc

struct VinylDisc: View {
    let art: NSImage?
    let playing: Bool
    let size: CGFloat

    @State private var base: Double = 0
    @State private var start: Date?
    private let degreesPerSecond = 45.0 // one turn every 8 s

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !playing)) { tl in
            let angle = base + (start.map { tl.date.timeIntervalSince($0) } ?? 0) * degreesPerSecond
            record.rotationEffect(.degrees(angle))
        }
        .overlay(sheen)
        .onAppear { if playing { start = Date() } }
        .onChange(of: playing) { _, now in
            if now { start = Date() }
            else {
                if let st = start { base += Date().timeIntervalSince(st) * degreesPerSecond }
                start = nil
            }
        }
    }

    private var record: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Color(white: 0.17), Color(white: 0.04)],
                                         center: .center, startRadius: 0, endRadius: size / 2))
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.6)
                    .padding(size * 0.05 + CGFloat(i) * size * 0.032)
            }
            label
                .frame(width: size * 0.46, height: size * 0.46)
                .clipShape(Circle())
            Circle().fill(Color.black.opacity(0.85)).frame(width: size * 0.06, height: size * 0.06)
        }
    }

    @ViewBuilder private var label: some View {
        if let art {
            Image(nsImage: art).resizable().interpolation(.high).scaledToFill()
        } else {
            ZStack {
                spotifyGreen
                Image(systemName: "music.note").font(.system(size: size * 0.16, weight: .bold)).foregroundStyle(.black)
            }
        }
    }

    private var sheen: some View {
        Circle()
            .fill(AngularGradient(colors: [.clear, .white.opacity(0.13), .clear, .clear, .white.opacity(0.09), .clear, .clear],
                                  center: .center, angle: .degrees(-30)))
            .blendMode(.screen)
            .allowsHitTesting(false)
    }
}

// MARK: - Expanded content

struct CardContent: View {
    @ObservedObject var c: WidgetController
    @ObservedObject var s: SpotifyController

    var body: some View {
        HStack(spacing: 10) {
            if !c.expandsLeft { Color.clear.frame(width: WidgetController.discD - 4) }
            controls
            MarqueeText(text: titleText, width: 128, font: .systemFont(ofSize: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { s.openSpotify() }
                .help(s.hasTrack ? "\(s.track.title) — \(s.track.artist)" : "Open Spotify")
            if c.expandsLeft { Color.clear.frame(width: WidgetController.discD - 4) }
        }
        .padding(.leading, c.expandsLeft ? 14 : 0)
        .padding(.trailing, c.expandsLeft ? 0 : 16)
        .foregroundStyle(.white)
    }

    private var titleText: String {
        if s.permissionDenied { return "Allow SpotifyDisc to control Spotify" }
        return s.hasTrack ? s.track.title : "Nothing playing"
    }

    private var controls: some View {
        HStack(spacing: 8) {
            IconButton(symbol: "backward.fill", size: 13, action: s.previous)
            Button(action: s.playPause) {
                Image(systemName: s.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .offset(x: s.isPlaying ? 0 : 1)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.white))
                    .contentShape(Circle())
            }
            .buttonStyle(PressStyle())
            IconButton(symbol: "forward.fill", size: 13, action: s.next)
        }
    }
}

/// Up to 15 characters: static and centred. Longer: shows the first 15 + "…" while resting,
/// then scrolls the full title through a fixed-width window and loops.
struct MarqueeText: View {
    let text: String
    let width: CGFloat
    let font: NSFont
    var limit = 15

    @State private var start = Date()
    private let speed: Double = 28   // pt per second
    private let rest: Double = 1.6   // pause before each scroll
    private let gap: CGFloat = 36

    var body: some View {
        Group {
            if text.count <= limit {
                Text(text).font(Font(font)).lineLimit(1).frame(width: width)
            } else {
                let textW = (text as NSString).size(withAttributes: [.font: font]).width.rounded(.up)
                let cycle = Double(textW + gap)
                let period = rest + cycle / speed
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { tl in
                    let t = tl.date.timeIntervalSince(start).truncatingRemainder(dividingBy: period)
                    if t < rest {
                        Text(String(text.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…")
                            .font(Font(font)).lineLimit(1).fixedSize()
                            .frame(width: width, alignment: .leading)
                    } else {
                        HStack(spacing: gap) { Text(text); Text(text) }
                            .font(Font(font)).lineLimit(1).fixedSize()
                            .offset(x: -CGFloat((t - rest) * speed))
                            .frame(width: width, alignment: .leading)
                            .clipped()
                            .mask(
                                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.07),
                                                       .init(color: .black, location: 0.9), .init(color: .clear, location: 1)],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                    }
                }
                .frame(width: width, alignment: .leading)
                .clipped()
            }
        }
        .onChange(of: text) { _, _ in start = Date() }
    }
}

/// Progress as a thin stroke along the pill's bottom edge. Hovering it reveals a round knob you can drag to seek.
struct SeekStroke: View {
    @ObservedObject var s: SpotifyController
    let expandsLeft: Bool
    var forceHover = false

    @State private var hover = false
    @State private var scrub: Double? // 0…1 while dragging

    var body: some View {
        let d = WidgetController.discD
        // Keep to the straight part of the bottom edge: clear of the far rounded end and the disc.
        HStack(spacing: 0) {
            if expandsLeft { track; Color.clear.frame(width: d + 2) } else { Color.clear.frame(width: d + 2); track }
        }
        .padding(expandsLeft ? .leading : .trailing, d / 2 - 4)
        .frame(width: WidgetController.cardW, height: 18)
        .offset(y: 7.5) // line sits ~1.5pt above the bottom edge
    }

    private var track: some View {
        let showKnob = hover || scrub != nil || forceHover
        return TimelineView(.periodic(from: .now, by: 0.25)) { tl in
            let dur = max(s.track.duration, 0)
            let frac: Double = scrub ?? (dur > 0 ? min(max(s.currentPosition(at: tl.date) / dur, 0), 1) : 0)
            GeometryReader { g in
                let x = g.size.width * frac
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.22)).frame(height: showKnob ? 3 : 2)
                    Capsule().fill(Color.white).frame(width: max(2, x), height: showKnob ? 3 : 2)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                        .scaleEffect(scrub != nil ? 1.15 : 1)
                        .offset(x: x - 6)
                        .opacity(showKnob ? 1 : 0)
                        .scaleEffect(showKnob ? 1 : 0.4)
                }
                .frame(height: g.size.height)
                .contentShape(Rectangle())
                .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in scrub = min(max(v.location.x / g.size.width, 0), 1) }
                        .onEnded { v in
                            let f = min(max(v.location.x / g.size.width, 0), 1)
                            scrub = nil
                            if dur > 0 { s.seek(to: f * dur) }
                        }
                )
            }
        }
        .opacity(s.hasTrack ? 1 : 0.4)
        .animation(.easeOut(duration: 0.15), value: showKnob)
    }
}

struct IconButton: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white.opacity(hover ? 1 : 0.85))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .onHover { hover = $0 }
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
