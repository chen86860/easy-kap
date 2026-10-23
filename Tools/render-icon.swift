import AppKit
import CoreGraphics

let size: CGFloat = 1024
let output = URL(filePath: CommandLine.arguments[1])
let space = CGColorSpace(name: CGColorSpace.displayP3)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: space, components: [r, g, b, a])! }
func gradient(_ colors: [CGColor]) -> CGGradient { CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)! }

let purple = color(0.40, 0.36, 0.96)
let teal = color(0.06, 0.88, 0.78)

// macOS icon grid: an 824pt squircle centered in the 1024pt canvas.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0, 0, 0, 0.28))
ctx.addPath(tilePath); ctx.setFillColor(color(1, 1, 1)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(tilePath); ctx.clip()
ctx.drawLinearGradient(gradient([color(1, 1, 1), color(0.925, 0.937, 0.965)]),
                       start: CGPoint(x: 512, y: tile.maxY), end: CGPoint(x: 512, y: tile.minY), options: [])
ctx.restoreGState()

let center = CGPoint(x: 512, y: 512)
let ring = CGPath(ellipseIn: CGRect(x: center.x - 268, y: center.y - 268, width: 536, height: 536), transform: nil)
let ringStroke = ring.copy(strokingWithWidth: 70, lineCap: .round, lineJoin: .round, miterLimit: 1)

// Soft colored glow under the ring.
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 46, color: color(0.25, 0.55, 0.95, 0.45))
ctx.addPath(ringStroke); ctx.setFillColor(color(0.3, 0.6, 0.95)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(ringStroke); ctx.clip()
ctx.drawLinearGradient(gradient([purple, teal]), start: CGPoint(x: 230, y: 230), end: CGPoint(x: 794, y: 794), options: [])
ctx.restoreGState()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try rep.representation(using: .png, properties: [:])!.write(to: output)
