import CoreGraphics
import Foundation
import Testing
@testable import Kap

struct CropperModelTests {
  @Test func restoresSavedSelection() {
    let saved = SavedSelection(displayID: 1, rect: CGRect(x: 10, y: 20, width: 300, height: 200), ratio: AspectRatio(width: 3, height: 2))
    let model = CropperModel(saved: saved)
    #expect(model.displayID == 1)
    #expect(model.selection == saved.rect)
    #expect(model.ratio == saved.ratio)
    #expect(model.savedSelection == saved)
  }

  @Test func persistsLastSelectionAcrossLaunches() throws {
    let suite = "kap-tests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let saved = SavedSelection(displayID: 2, rect: CGRect(x: 0, y: 0, width: 640, height: 480), ratio: nil)
    Preferences(defaults: defaults).lastSelection = saved
    #expect(Preferences(defaults: defaults).lastSelection == saved)
  }

  @Test func groupsWindowsByApp() {
    let model = CropperModel(saved: nil)
    model.windows = [
      SnapWindow(id: 1, title: "A1", appName: "Alpha", processID: 100, frame: .zero),
      SnapWindow(id: 2, title: "B1", appName: "Beta", processID: 200, frame: .zero),
      SnapWindow(id: 3, title: "A2", appName: "Alpha", processID: 100, frame: .zero)
    ]
    let apps = model.apps
    #expect(apps.map(\.name) == ["Alpha", "Beta"])
    #expect(apps.first?.windows.map(\.title) == ["A1", "A2"])
  }
}
