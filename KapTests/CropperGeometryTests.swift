import CoreGraphics
import Testing
@testable import Kap

struct CropperGeometryTests {
  private let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)

  @Test func selectionNormalizesDragDirection() {
    let rect = CropperGeometry.selection(from: CGPoint(x: 300, y: 300), to: CGPoint(x: 100, y: 200), ratio: nil, bounds: bounds)
    #expect(rect == CGRect(x: 100, y: 200, width: 200, height: 100))
  }

  @Test func selectionClampsToBounds() {
    let rect = CropperGeometry.selection(from: CGPoint(x: 900, y: 700), to: CGPoint(x: 1200, y: 1000), ratio: nil, bounds: bounds)
    #expect(rect == CGRect(x: 900, y: 700, width: 100, height: 100))
  }

  @Test func selectionKeepsAspectRatioWithinBounds() {
    let ratio = AspectRatio(width: 16, height: 9)
    let rect = CropperGeometry.selection(from: CGPoint(x: 0, y: 700), to: CGPoint(x: 800, y: 800), ratio: ratio, bounds: bounds)
    #expect(rect.height == 100)
    #expect(abs(rect.width / rect.height - ratio.value) < 0.02)
  }

  @Test func moveStopsAtEdges() {
    let rect = CGRect(x: 100, y: 100, width: 200, height: 200)
    let moved = CropperGeometry.moved(rect, by: CGSize(width: 2000, height: -500), within: bounds)
    #expect(moved == CGRect(x: 800, y: 0, width: 200, height: 200))
  }

  @Test func resizeFromTopLeftCorner() throws {
    let rect = CGRect(x: 100, y: 100, width: 200, height: 200)
    let resized = try #require(
      CropperGeometry.resized(rect, handle: .topLeft, by: CGSize(width: -50, height: 30), ratio: nil, within: bounds)
    )
    #expect(resized == CGRect(x: 50, y: 130, width: 250, height: 170))
  }

  @Test func resizeEnforcesMinimumSize() throws {
    let rect = CGRect(x: 100, y: 100, width: 200, height: 200)
    let resized = try #require(
      CropperGeometry.resized(rect, handle: .right, by: CGSize(width: -500, height: 0), ratio: nil, within: bounds)
    )
    #expect(resized.width == CropperGeometry.minimumSize)
    #expect(resized.minX == 100)
  }

  @Test func resizeWithRatioRejectsOverflow() {
    let rect = CGRect(x: 0, y: 600, width: 200, height: 200)
    let square = AspectRatio(width: 1, height: 1)
    let resized = CropperGeometry.resized(rect, handle: .right, by: CGSize(width: 400, height: 0), ratio: square, within: bounds)
    #expect(resized == nil)
  }

  @Test func applyingRatioKeepsCenter() {
    let rect = CGRect(x: 100, y: 100, width: 400, height: 400)
    let result = CropperGeometry.applying(AspectRatio(width: 2, height: 1), to: rect, within: bounds)
    #expect(result == CGRect(x: 100, y: 200, width: 400, height: 200))
  }

  @Test func defaultSelectionIsCentered720p() {
    let large = CropperGeometry.defaultSelection(in: CGRect(x: 0, y: 0, width: 2560, height: 1440))
    #expect(large == CGRect(x: 640, y: 360, width: 1280, height: 720))

    let small = CropperGeometry.defaultSelection(in: CGRect(x: 0, y: 0, width: 1512, height: 982))
    #expect(small.width <= 1512 * 0.7 + 1)
    #expect(abs(small.width / small.height - 16.0 / 9.0) < 0.02)
    #expect(abs(small.midX - 756) <= 1)
  }

  @Test func localFrameClipsToDisplay() {
    let display = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
    let window = CGRect(x: 1300, y: 100, width: 600, height: 400)
    #expect(CropperGeometry.localFrame(of: window, displayBounds: display) == CGRect(x: 0, y: 100, width: 460, height: 400))
    #expect(CropperGeometry.localFrame(of: CGRect(x: 0, y: 0, width: 100, height: 100), displayBounds: display) == nil)
  }
}
