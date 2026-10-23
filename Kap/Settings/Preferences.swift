import AppKit
import Observation

@Observable
final class Preferences {
  static let shared = Preferences(defaults: .standard)

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored var onShortcutChange: ((Shortcut?) -> Void)?

  var kapturesDirectory: URL {
    didSet { defaults.set(kapturesDirectory.path, forKey: Key.kapturesDirectory) }
  }
  var showCursor: Bool {
    didSet { defaults.set(showCursor, forKey: Key.showCursor) }
  }
  var highlightClicks: Bool {
    didSet { defaults.set(highlightClicks, forKey: Key.highlightClicks) }
  }
  var record60fps: Bool {
    didSet { defaults.set(record60fps, forKey: Key.record60fps) }
  }
  var recordAudio: Bool {
    didSet { defaults.set(recordAudio, forKey: Key.recordAudio) }
  }
  var recordSystemAudio: Bool {
    didSet { defaults.set(recordSystemAudio, forKey: Key.recordSystemAudio) }
  }
  /// `nil` means the system default input device.
  var audioDeviceID: String? {
    didSet { defaults.set(audioDeviceID, forKey: Key.audioDeviceID) }
  }
  var loopExports: Bool {
    didSet { defaults.set(loopExports, forKey: Key.loopExports) }
  }
  var lastExportFormat: ExportFormat {
    didSet { defaults.set(lastExportFormat.rawValue, forKey: Key.lastExportFormat) }
  }
  var lastSelection: SavedSelection? {
    didSet { defaults.set(lastSelection.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.lastSelection) }
  }
  var shortcut: Shortcut? {
    didSet {
      defaults.set(shortcut.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.shortcut)
      onShortcutChange?(shortcut)
    }
  }

  init(defaults: UserDefaults) {
    self.defaults = defaults
    let moviesDirectory = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
    defaults.register(defaults: [
      Key.kapturesDirectory: moviesDirectory.appending(path: "Kaptures").path,
      Key.showCursor: true,
      Key.highlightClicks: false,
      Key.record60fps: false,
      Key.recordAudio: false,
      Key.recordSystemAudio: false,
      Key.loopExports: true,
      Key.lastExportFormat: ExportFormat.gif.rawValue
    ])

    kapturesDirectory = URL(filePath: defaults.string(forKey: Key.kapturesDirectory) ?? "", directoryHint: .isDirectory)
    showCursor = defaults.bool(forKey: Key.showCursor)
    highlightClicks = defaults.bool(forKey: Key.highlightClicks)
    record60fps = defaults.bool(forKey: Key.record60fps)
    recordAudio = defaults.bool(forKey: Key.recordAudio)
    recordSystemAudio = defaults.bool(forKey: Key.recordSystemAudio)
    audioDeviceID = defaults.string(forKey: Key.audioDeviceID)
    loopExports = defaults.bool(forKey: Key.loopExports)
    lastExportFormat = defaults.string(forKey: Key.lastExportFormat).flatMap(ExportFormat.init(rawValue:)) ?? .gif
    lastSelection = defaults.data(forKey: Key.lastSelection).flatMap { try? JSONDecoder().decode(SavedSelection.self, from: $0) }
    shortcut = defaults.data(forKey: Key.shortcut).flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
  }

  private enum Key {
    static let kapturesDirectory = "kapturesDirectory"
    static let showCursor = "showCursor"
    static let highlightClicks = "highlightClicks"
    static let record60fps = "record60fps"
    static let recordAudio = "recordAudio"
    static let recordSystemAudio = "recordSystemAudio"
    static let audioDeviceID = "audioDeviceID"
    static let loopExports = "loopExports"
    static let lastExportFormat = "lastExportFormat"
    static let lastSelection = "lastSelection"
    static let shortcut = "shortcut"
  }
}
