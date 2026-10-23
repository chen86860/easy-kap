#!/usr/bin/swift
// Draws the disk image window background, at 1x and 2x, into Tools/dmg/.
// Tools/make-dmg.sh combines them into one multi-resolution TIFF for create-dmg.
// Run: swift Tools/make-dmg-background.swift
//
// The layout matches the create-dmg options in Tools/make-dmg.sh: a 640 × 400 pt window with the app icon
// centered at (160, 200) and the Applications shortcut at (480, 200), measured from the top left.
import AppKit

let width: CGFloat = 640
let height: CGFloat = 400
let iconCenterY: CGFloat = 200 // from the top, as create-dmg measures
let violet = NSColor(srgbRed: 0.392, green: 0.345, blue: 0.961, alpha: 1)
let teal = NSColor(srgbRed: 0.071, green: 0.839, blue: 0.745, alpha: 1)
let ink = NSColor(srgbRed: 0.078, green: 0.094, blue: 0.161, alpha: 1)
let muted = NSColor(srgbRed: 0.353, green: 0.388, blue: 0.467, alpha: 1)

func render(scale: CGFloat) -> Data {
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
  )!
  // Sizing the bitmap in points makes AppKit map points to pixels, so drawing below uses points throughout.
  // AppKit's origin is the bottom left.
  rep.size = NSSize(width: width, height: height)
  NSGraphicsContext.saveGraphicsState()
  defer { NSGraphicsContext.restoreGraphicsState() }
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let context = NSGraphicsContext.current!.cgContext

  // A cool white ground with the website's faint pixel grid.
  NSColor(srgbRed: 0.953, green: 0.965, blue: 0.973, alpha: 1).setFill()
  NSRect(x: 0, y: 0, width: width, height: height).fill()
  NSColor(srgbRed: 0.078, green: 0.094, blue: 0.161, alpha: 0.06).setFill()
  for x in stride(from: CGFloat(11), to: width, by: 22) {
    for y in stride(from: CGFloat(11), to: height, by: 22) {
      NSBezierPath(ovalIn: NSRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5)).fill()
    }
  }

  let centered = NSMutableParagraphStyle()
  centered.alignment = .center
  func text(_ string: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, fromTop centerY: CGFloat, kern: CGFloat = 0) {
    let attributed = NSAttributedString(string: string, attributes: [
      .font: NSFont.systemFont(ofSize: size, weight: weight),
      .foregroundColor: color,
      .paragraphStyle: centered,
      .kern: kern,
    ])
    let lineHeight = attributed.size().height
    attributed.draw(in: NSRect(x: 0, y: height - centerY - lineHeight / 2, width: width, height: lineHeight + 2))
  }

  text("Easy Kap", size: 30, weight: .bold, color: ink, fromTop: 64, kern: -0.4)
  text("Drag Easy Kap onto Applications to install", size: 13, weight: .regular, color: muted, fromTop: 330)

  // The arrow between the icons, in Kap's ring gradient.
  let arrowY = height - iconCenterY
  let start = CGPoint(x: 262, y: arrowY)
  let end = CGPoint(x: 378, y: arrowY)
  let arrow = CGMutablePath()
  arrow.move(to: start)
  arrow.addLine(to: end)
  arrow.move(to: CGPoint(x: end.x - 14, y: arrowY + 12))
  arrow.addLine(to: end)
  arrow.addLine(to: CGPoint(x: end.x - 14, y: arrowY - 12))
  context.saveGState()
  context.addPath(arrow.copy(strokingWithWidth: 4, lineCap: .round, lineJoin: .round, miterLimit: 1))
  context.clip()
  let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [violet.cgColor, teal.cgColor] as CFArray, locations: nil)!
  context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
  context.restoreGState()

  return rep.representation(using: .png, properties: [:])!
}

let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("dmg")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
try render(scale: 1).write(to: directory.appendingPathComponent("background.png"))
try render(scale: 2).write(to: directory.appendingPathComponent("background@2x.png"))
print("✓ Tools/dmg/background.png (640×400) and background@2x.png (1280×800)")
