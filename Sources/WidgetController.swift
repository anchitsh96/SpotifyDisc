import AppKit
import SwiftUI
import Combine

/// Hosting view that accepts the first click, so buttons work without activating the app first.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Owns the floating panel: position, hover expand/collapse, dragging, visibility.
///
/// The panel is always card-sized; only the disc (or the card, when expanded) is drawn and
/// interactive. Everywhere else the panel ignores the mouse so clicks fall through.
final class WidgetController: ObservableObject {
    static let discD: CGFloat = 64
    static let cardW: CGFloat = 330
    static let cardH: CGFloat = 64 // same height as the disc: expands only in width
    static let pad: CGFloat = 30 // room for the shadow
    static let hoverDelay: TimeInterval = 0.5 // rest on the disc this long before it expands
    static var winSize: CGSize { CGSize(width: cardW + 2 * pad, height: cardH + 2 * pad) }

    @Published private(set) var expanded = false
    @Published private(set) var expandsLeft = false
    @Published private(set) var dragging = false
    @Published var userHidden: Bool {
        didSet { UserDefaults.standard.set(userHidden, forKey: "userHidden"); updateVisibility() }
    }

    let spotify: SpotifyController
    private var panel: NSPanel!
    private var discCenter: CGPoint // screen coordinates
    private var hoverTimer: Timer?
    private var enterTime: Date?
    private var leaveTime: Date?
    private var dragStartMouse: CGPoint?
    private var dragStartCenter: CGPoint = .zero
    private var bag = Set<AnyCancellable>()

    init(spotify: SpotifyController) {
        self.spotify = spotify
        let d = UserDefaults.standard
        userHidden = d.bool(forKey: "userHidden")
        if d.object(forKey: "discX") != nil {
            discCenter = CGPoint(x: d.double(forKey: "discX"), y: d.double(forKey: "discY"))
        } else {
            discCenter = Self.defaultCenter()
        }
        buildPanel()
        discCenter = clamped(discCenter)
        layoutWindow()

        spotify.$isRunning.removeDuplicates().sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateVisibility() }
        }.store(in: &bag)

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.discCenter = self.clamped(self.discCenter)
            self.layoutWindow()
        }

        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        hoverTimer = t
    }

    private static func defaultCenter() -> CGPoint {
        let f = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return CGPoint(x: f.maxX - 70, y: f.maxY - 110)
    }

    private func buildPanel() {
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: Self.winSize),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.isMovable = false
        p.ignoresMouseEvents = true
        p.isReleasedWhenClosed = false
        let host = FirstMouseHostingView(rootView: WidgetView(c: self, s: spotify))
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: Self.winSize)
        p.contentView = host
        panel = p
    }

    // MARK: - Visibility

    func updateVisibility() {
        if spotify.isRunning && !userHidden {
            layoutWindow()
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
            if expanded { expanded = false }
        }
    }

    func resetPosition() {
        discCenter = clamped(Self.defaultCenter())
        layoutWindow()
        save()
    }

    // MARK: - Geometry

    /// Disc centre inside the window (AppKit coords, origin bottom-left).
    private var discCenterLocal: CGPoint {
        let s = Self.winSize
        return CGPoint(x: expandsLeft ? s.width - Self.pad - Self.discD / 2 : Self.pad + Self.discD / 2, y: s.height / 2)
    }

    private func layoutWindow() {
        let l = discCenterLocal
        panel.setFrameOrigin(CGPoint(x: (discCenter.x - l.x).rounded(), y: (discCenter.y - l.y).rounded()))
    }

    private var cardRectScreen: CGRect {
        let o = panel.frame.origin, s = Self.winSize
        let x = expandsLeft ? s.width - Self.pad - Self.cardW : Self.pad
        return CGRect(x: o.x + x, y: o.y + Self.pad, width: Self.cardW, height: Self.cardH)
    }

    private func screen(for p: CGPoint) -> NSScreen {
        NSScreen.screens.first { $0.frame.contains(p) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func clamped(_ p: CGPoint) -> CGPoint {
        let f = screen(for: p).visibleFrame
        let r = Self.discD / 2 + 4
        let vr = Self.cardH / 2 + 4 // keep room for the card vertically
        return CGPoint(x: min(max(p.x, f.minX + r), f.maxX - r),
                       y: min(max(p.y, f.minY + vr), f.maxY - vr))
    }

    // MARK: - Hover

    private func tick() {
        guard panel.isVisible else { return }
        let m = NSEvent.mouseLocation
        let overDisc = hypot(m.x - discCenter.x, m.y - discCenter.y) <= Self.discD / 2 + 2
        let overCard = expanded && cardRectScreen.insetBy(dx: -6, dy: -6).contains(m)
        let interactive = overDisc || overCard || dragging
        if panel.ignoresMouseEvents == interactive { panel.ignoresMouseEvents = !interactive }

        if dragging { enterTime = nil; leaveTime = nil; return }
        let now = Date()
        if !expanded {
            leaveTime = nil
            // Expand only after resting on the disc for 1 s with no button held, so a quick
            // grab-and-drag moves the disc itself without opening the card.
            if overDisc && NSEvent.pressedMouseButtons == 0 {
                if let t = enterTime { if now.timeIntervalSince(t) >= Self.hoverDelay { expand() } } else { enterTime = now }
            } else { enterTime = nil }
        } else {
            enterTime = nil
            if overCard || overDisc { leaveTime = nil }
            else if let t = leaveTime { if now.timeIntervalSince(t) > 0.35 { collapse() } }
            else { leaveTime = now }
        }
    }

    private func expand() {
        let f = screen(for: discCenter).visibleFrame
        let left = discCenter.x - Self.discD / 2 + Self.cardW + 8 > f.maxX
        if left != expandsLeft {
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { expandsLeft = left }
            layoutWindow()
        }
        spotify.refresh()
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) { self.expanded = true }
        }
    }

    private func collapse() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { expanded = false }
    }

    // MARK: - Dragging

    func dragChanged() {
        let m = NSEvent.mouseLocation
        if dragStartMouse == nil {
            dragStartMouse = m
            dragStartCenter = discCenter
            dragging = true
        }
        guard let s = dragStartMouse else { return }
        discCenter = CGPoint(x: dragStartCenter.x + m.x - s.x, y: dragStartCenter.y + m.y - s.y)
        layoutWindow()
    }

    func dragEnded() {
        dragStartMouse = nil
        dragging = false
        discCenter = clamped(discCenter)
        layoutWindow()
        save()
    }

    private func save() {
        UserDefaults.standard.set(Double(discCenter.x), forKey: "discX")
        UserDefaults.standard.set(Double(discCenter.y), forKey: "discY")
    }
}
