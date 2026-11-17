import AppKit

let size = 1024
let out = CommandLine.arguments[1]
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, a])!
}
let s = CGFloat(size)

// Background: diagonal green gradient, light at the top-left.
let gradient = CGGradient(colorsSpace: cs, colors: [color(0x2FD08A), color(0x0E9F6E), color(0x076B52)] as CFArray,
                          locations: [0, 0.55, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

// Ring: faint full track, with a bright arc for the part of the budget left.
let center = CGPoint(x: s / 2, y: s / 2)
let radius: CGFloat = 300
let lineWidth: CGFloat = 76
ctx.setLineWidth(lineWidth)
ctx.setLineCap(.round)
ctx.setStrokeColor(color(0xFFFFFF, 0.24))
ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
ctx.strokePath()

let start = CGFloat.pi / 2                    // 12 o'clock
let end = start - 2 * .pi * 0.72              // 72 % clockwise
ctx.setStrokeColor(color(0xFFFFFF))
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: color(0x03382B, 0.35))
ctx.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
ctx.strokePath()

// "$" in the rounded system font, optically centred in the ring.
var font = NSFont.systemFont(ofSize: 330, weight: .bold)
if let rounded = font.fontDescriptor.withDesign(.rounded) { font = NSFont(descriptor: rounded, size: 330) ?? font }
let text = NSAttributedString(string: "$", attributes: [.font: font, .foregroundColor: NSColor.white])
let line = CTLineCreateWithAttributedString(text)
let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
ctx.textPosition = CGPoint(x: center.x - bounds.midX, y: center.y - bounds.midY)
CTLineDraw(line, ctx)

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
