import CoreGraphics
import SwiftUI

nonisolated struct AspectRatio: Codable, Hashable, Sendable {
  var width: Int
  var height: Int

  var value: CGFloat { CGFloat(width) / CGFloat(height) }
  var title: String { "\(width):\(height)" }

  static let presets = [
    AspectRatio(width: 16, height: 9),
    AspectRatio(width: 5, height: 4),
    AspectRatio(width: 5, height: 3),
    AspectRatio(width: 4, height: 3),
    AspectRatio(width: 3, height: 2),
    AspectRatio(width: 1, height: 1)
  ]
}

nonisolated enum Handle: CaseIterable, Sendable {
  case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

  var movesLeft: Bool { [.topLeft, .left, .bottomLeft].contains(self) }
  var movesRight: Bool { [.topRight, .right, .bottomRight].contains(self) }
  var movesTop: Bool { [.topLeft, .top, .topRight].contains(self) }
  var movesBottom: Bool { [.bottomLeft, .bottom, .bottomRight].contains(self) }

  func point(in rect: CGRect) -> CGPoint {
    let x = movesLeft ? rect.minX : movesRight ? rect.maxX : rect.midX
    let y = movesTop ? rect.minY : movesBottom ? rect.maxY : rect.midY
    return CGPoint(x: x, y: y)
  }

  var resizePosition: FrameResizePosition {
    switch self {
    case .topLeft: .topLeading
    case .top: .top
    case .topRight: .topTrailing
    case .right: .trailing
    case .bottomRight: .bottomTrailing
    case .bottom: .bottom
    case .bottomLeft: .bottomLeading
    case .left: .leading
    }
  }
}

/// Pure selection math. All rects use display-local points with a top-left origin, which is also what ScreenCaptureKit expects.
nonisolated enum CropperGeometry {
  static let minimumSize: CGFloat = 10

  static func selection(from start: CGPoint, to end: CGPoint, ratio: AspectRatio?, bounds: CGRect) -> CGRect {
    let clampedEnd = CGPoint(x: end.x.clamped(bounds.minX, bounds.maxX), y: end.y.clamped(bounds.minY, bounds.maxY))
    var width = abs(clampedEnd.x - start.x)
    var height = abs(clampedEnd.y - start.y)
    if let ratio {
      height = width / ratio.value
      let maxHeight = clampedEnd.y >= start.y ? bounds.maxY - start.y : start.y - bounds.minY
      if height > maxHeight {
        height = maxHeight
        width = height * ratio.value
      }
    }
    let x = clampedEnd.x >= start.x ? start.x : start.x - width
    let y = clampedEnd.y >= start.y ? start.y : start.y - height
    return CGRect(x: x, y: y, width: width, height: height).integral
  }

  static func moved(_ rect: CGRect, by translation: CGSize, within bounds: CGRect) -> CGRect {
    let x = (rect.minX + translation.width).clamped(bounds.minX, bounds.maxX - rect.width)
    let y = (rect.minY + translation.height).clamped(bounds.minY, bounds.maxY - rect.height)
    return CGRect(x: x, y: y, width: rect.width, height: rect.height).integral
  }

  /// Returns `nil` when the requested resize can't be satisfied, so the caller keeps the previous selection.
  static func resized(
    _ rect: CGRect,
    handle: Handle,
    by translation: CGSize,
    ratio: AspectRatio?,
    within bounds: CGRect
  ) -> CGRect? {
    var minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY
    if handle.movesLeft { minX = min(minX + translation.width, maxX - minimumSize).clamped(bounds.minX, bounds.maxX) }
    if handle.movesRight { maxX = max(maxX + translation.width, minX + minimumSize).clamped(bounds.minX, bounds.maxX) }
    if handle.movesTop { minY = min(minY + translation.height, maxY - minimumSize).clamped(bounds.minY, bounds.maxY) }
    if handle.movesBottom { maxY = max(maxY + translation.height, minY + minimumSize).clamped(bounds.minY, bounds.maxY) }
    var result = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

    if let ratio {
      if handle == .top || handle == .bottom {
        result.size.width = result.height * ratio.value
      } else {
        result.size.height = result.width / ratio.value
        if handle.movesTop { result.origin.y = maxY - result.height }
      }
      guard bounds.contains(result.integral) else { return nil }
    }
    return result.integral
  }

  static func resized(_ rect: CGRect, width: CGFloat, height: CGFloat, within bounds: CGRect) -> CGRect {
    let size = CGSize(
      width: width.clamped(minimumSize, bounds.width),
      height: height.clamped(minimumSize, bounds.height)
    )
    let x = rect.minX.clamped(bounds.minX, bounds.maxX - size.width)
    let y = rect.minY.clamped(bounds.minY, bounds.maxY - size.height)
    return CGRect(origin: CGPoint(x: x, y: y), size: size).integral
  }

  /// Fits `rect` to `ratio` around its center, shrinking it if it would leave `bounds`.
  static func applying(_ ratio: AspectRatio, to rect: CGRect, within bounds: CGRect) -> CGRect {
    var size = CGSize(width: rect.width, height: rect.width / ratio.value)
    if size.height > bounds.height {
      size = CGSize(width: bounds.height * ratio.value, height: bounds.height)
    }
    let origin = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
    return moved(CGRect(origin: origin, size: size), by: .zero, within: bounds)
  }

  /// A centered 1280×720 area, scaled down to fit within 70% of the display if needed.
  static func defaultSelection(in bounds: CGRect) -> CGRect {
    let scale = min(1, bounds.width * 0.7 / 1280, bounds.height * 0.7 / 720)
    let width = (1280 * scale).rounded()
    let height = (720 * scale).rounded()
    return CGRect(x: (bounds.midX - width / 2).rounded(), y: (bounds.midY - height / 2).rounded(), width: width, height: height)
  }

  /// Converts a window frame in global display coordinates to coordinates local to the display, clipped to it.
  static func localFrame(of globalFrame: CGRect, displayBounds: CGRect) -> CGRect? {
    let clipped = globalFrame.intersection(displayBounds)
    guard !clipped.isNull, clipped.width >= minimumSize, clipped.height >= minimumSize else { return nil }
    return clipped.offsetBy(dx: -displayBounds.minX, dy: -displayBounds.minY).integral
  }
}

nonisolated extension Comparable {
  func clamped(_ lower: Self, _ upper: Self) -> Self {
    min(max(self, lower), max(lower, upper))
  }
}
