// Draws the app icon. Regenerate Resources/AppIcon.icns with:
//   swift Resources/make-icon.swift /tmp/icon.png && mkdir -p /tmp/AppIcon.iconset
//   for s in 16 32 128 256 512; do sips -z $s $s /tmp/icon.png --out /tmp/AppIcon.iconset/icon_${s}x${s}.png
//     sips -z $((s*2)) $((s*2)) /tmp/icon.png --out /tmp/AppIcon.iconset/icon_${s}x${s}@2x.png; done
//   iconutil -c icns /tmp/AppIcon.iconset -o Resources/AppIcon.icns
import AppKit

let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
// macOS icon grid: 824pt body centered in the 1024pt canvas.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowBlurRadius = 24
shadow.set()
NSColor.black.setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()
let top = NSColor(red: 0.18, green: 0.62, blue: 0.46, alpha: 1)
let bottom = NSColor(red: 0.04, green: 0.28, blue: 0.22, alpha: 1)
NSGradient(starting: top, ending: bottom)!.draw(in: shape, angle: -90)

// Arches shrink toward a vanishing point so they read as a tunnel receding into the distance.
// Lines use opaque tints rather than transparency so overlapping strokes stay crisp.
let vanishing = NSPoint(x: size / 2, y: 480)
let floor: CGFloat = 290, halfWidth: CGFloat = 290, legs: CGFloat = 170
let depths: [(scale: CGFloat, tint: CGFloat)] = [(1, 1), (0.62, 0.8), (0.38, 0.62), (0.22, 0.46)]
let middle = top.blended(withFraction: 0.5, of: bottom)!
func point(_ x: CGFloat, _ y: CGFloat, _ scale: CGFloat) -> NSPoint {
    NSPoint(x: vanishing.x + (x - vanishing.x) * scale, y: vanishing.y + (y - vanishing.y) * scale)
}
func stroke(_ path: NSBezierPath, depth: Int) {
    path.lineWidth = 52 * depths[depth].scale + 10
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    middle.blended(withFraction: depths[depth].tint, of: .white)!.setStroke()
    path.stroke()
}
// Draw the farthest depth first so nearer lines cover the joints.
for depth in depths.indices.reversed() {
    let scale = depths[depth].scale
    let left = point(vanishing.x - halfWidth, floor, scale), right = point(vanishing.x + halfWidth, floor, scale)
    if depth + 1 < depths.count {
        let next = depths[depth + 1].scale
        let road = NSBezierPath()
        road.move(to: left)
        road.line(to: point(vanishing.x - halfWidth, floor, next))
        road.move(to: right)
        road.line(to: point(vanishing.x + halfWidth, floor, next))
        stroke(road, depth: depth + 1)
    }
    let springLine = left.y + legs * scale
    let arch = NSBezierPath()
    arch.move(to: left)
    arch.line(to: NSPoint(x: left.x, y: springLine))
    arch.appendArc(withCenter: NSPoint(x: vanishing.x, y: springLine), radius: halfWidth * scale,
                   startAngle: 180, endAngle: 0, clockwise: true)
    arch.line(to: right)
    stroke(arch, depth: depth)
}
NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
