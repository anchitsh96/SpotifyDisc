// Draws the SpotifyDisc app icon (a vinyl record on a dark rounded square) and writes
// Resources/AppIcon.icns. Run from the repo root:  swift tools/make_icon.swift
import AppKit

let S: CGFloat = 1024

func draw(_ ctx: CGContext) {
    let rgb = CGColorSpaceCreateDeviceRGB()
    func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }

    // macOS icon grid: 824pt rounded square centred on a 1024 canvas, with a soft drop shadow.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0, 0, 0, 0.35))
    ctx.addPath(tilePath); ctx.setFillColor(color(0.08, 0.08, 0.09)); ctx.fillPath()
    ctx.restoreGState()

    // Tile background: deep charcoal with a faint glow from the top.
    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()
    let bg = CGGradient(colorsSpace: rgb, colors: [color(0.17, 0.18, 0.17), color(0.06, 0.07, 0.07)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    let c = CGPoint(x: 512, y: 512)
    let R: CGFloat = 330

    // Record shadow + body.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0, 0, 0, 0.55))
    ctx.addEllipse(in: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R))
    ctx.setFillColor(color(0.03, 0.03, 0.035)); ctx.fillPath()
    ctx.restoreGState()
    let body = CGGradient(colorsSpace: rgb, colors: [color(0.17, 0.17, 0.18), color(0.035, 0.035, 0.04)] as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R)); ctx.clip()
    ctx.drawRadialGradient(body, startCenter: c, startRadius: 0, endCenter: c, endRadius: R, options: [])

    // Grooves.
    ctx.setLineWidth(2.2)
    var r: CGFloat = R - 18
    var i = 0
    while r > 150 {
        ctx.setStrokeColor(color(1, 1, 1, i % 3 == 0 ? 0.10 : 0.05))
        ctx.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        r -= 11; i += 1
    }

    // Sheen: two soft light wedges, like light catching vinyl.
    for (start, end, alpha) in [(CGFloat.pi * 0.62, CGFloat.pi * 0.86, 0.16), (CGFloat.pi * 1.62, CGFloat.pi * 1.80, 0.10)] {
        let steps = 24
        for k in 0..<steps {
            let t0 = start + (end - start) * CGFloat(k) / CGFloat(steps)
            let t1 = start + (end - start) * CGFloat(k + 1) / CGFloat(steps)
            let mid = 1 - abs(CGFloat(k) / CGFloat(steps - 1) * 2 - 1) // 0→1→0 across the wedge
            ctx.move(to: c)
            ctx.addArc(center: c, radius: R, startAngle: t0, endAngle: t1, clockwise: false)
            ctx.closePath()
            ctx.setFillColor(color(1, 1, 1, CGFloat(alpha) * mid))
            ctx.fillPath()
        }
    }
    ctx.restoreGState()

    // Label: Spotify-green gradient, bright lime-green to deep green.
    let L: CGFloat = 140
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: c.x - L, y: c.y - L, width: 2 * L, height: 2 * L)); ctx.clip()
    let label = CGGradient(colorsSpace: rgb, colors: [color(0.27, 0.92, 0.45), color(0.11, 0.73, 0.33), color(0.04, 0.45, 0.20)] as CFArray, locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(label, start: CGPoint(x: c.x - L, y: c.y + L), end: CGPoint(x: c.x + L, y: c.y - L), options: [])
    ctx.setStrokeColor(color(1, 1, 1, 0.22)); ctx.setLineWidth(3)
    ctx.strokeEllipse(in: CGRect(x: c.x - L * 0.72, y: c.y - L * 0.72, width: L * 1.44, height: L * 1.44))
    ctx.restoreGState()

    // Spindle hole.
    let h: CGFloat = 22
    ctx.addEllipse(in: CGRect(x: c.x - h, y: c.y - h, width: 2 * h, height: 2 * h))
    ctx.setFillColor(color(0.06, 0.05, 0.05)); ctx.fillPath()

    ctx.restoreGState()
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
draw(NSGraphicsContext.current!.cgContext)
NSGraphicsContext.restoreGraphicsState()

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)

let master = rep.representation(using: .png, properties: [:])!
let masterURL = iconset.deletingLastPathComponent().appendingPathComponent("AppIcon-1024.png")
try! master.write(to: masterURL)

func resized(_ px: Int) -> Data {
    let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
    NSGraphicsContext.current!.imageInterpolation = .high
    rep.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    return out.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! resized(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! resized(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

try! fm.createDirectory(atPath: "Resources", withIntermediateDirectories: true)
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! p.run(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns (preview: \(masterURL.path))" : "iconutil failed")
