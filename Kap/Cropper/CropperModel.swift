import AppKit
import Observation

struct SnapWindow: Identifiable {
  let id: CGWindowID
  let title: String
  let appName: String
  let processID: pid_t
  /// Global display coordinates, top-left origin.
  let frame: CGRect
}

struct SnapApp: Identifiable {
  let id: pid_t
  let name: String
  let icon: NSImage?
  let windows: [SnapWindow]
}

/// A control on the action bar. Its tip and dropdown are drawn by the cropper above the bar, positioned from
/// the control's reported bounds, so they never overlap the bar or fall off screen.
enum ActionBarControl: Hashable {
  case cancel, ratio, screen, window, fullScreen, record

  var tip: String {
    switch self {
    case .cancel: "Cancel (Esc)"
    case .ratio: "Aspect ratio"
    case .screen: "Record a screen"
    case .window: "Record an app's window"
    case .fullScreen: "Select this entire screen"
    case .record: "Start recording (Return)"
    }
  }

  var hasMenu: Bool { [.ratio, .screen, .window].contains(self) }
}

/// The last recorded area, restored the next time the cropper opens.
nonisolated struct SavedSelection: Codable, Equatable, Sendable {
  var displayID: CGDirectDisplayID
  var rect: CGRect
  var ratio: AspectRatio?
}

@Observable
final class CropperModel {
  var displayID: CGDirectDisplayID?
  /// Display-local points, top-left origin.
  var selection: CGRect?
  var ratio: AspectRatio?
  var isRecording = false
  var windows: [SnapWindow] = []
  var openMenu: ActionBarControl?
  var hoveredControl: ActionBarControl?

  @ObservationIgnored var onRecord: (() -> Void)?
  @ObservationIgnored var onCancel: (() -> Void)?
  /// Called after another app was brought forward, so the cropper can take keyboard focus back.
  @ObservationIgnored var onOtherAppActivated: (() -> Void)?

  init(saved: SavedSelection?) {
    displayID = saved?.displayID
    selection = saved?.rect
    ratio = saved?.ratio
  }

  var savedSelection: SavedSelection? {
    guard let displayID, let selection else { return nil }
    return SavedSelection(displayID: displayID, rect: selection, ratio: ratio)
  }

  /// Windows grouped by app, in the order the apps first appear (front to back).
  var apps: [SnapApp] {
    var order: [pid_t] = []
    var grouped: [pid_t: [SnapWindow]] = [:]
    for window in windows {
      if grouped[window.processID] == nil { order.append(window.processID) }
      grouped[window.processID, default: []].append(window)
    }
    return order.compactMap { pid in
      guard let windows = grouped[pid], let first = windows.first else { return nil }
      let icon = NSRunningApplication(processIdentifier: pid)?.icon.map(Self.menuIcon)
      return SnapApp(id: pid, name: first.appName, icon: icon, windows: windows)
    }
  }

  private static func menuIcon(_ image: NSImage) -> NSImage {
    let icon = image.copy() as? NSImage ?? image
    icon.size = CGSize(width: 16, height: 16)
    return icon
  }

  func bounds(of displayID: CGDirectDisplayID) -> CGRect {
    CGRect(origin: .zero, size: CGDisplayBounds(displayID).size)
  }

  func select(_ rect: CGRect?, on displayID: CGDirectDisplayID) {
    self.displayID = displayID
    selection = rect
  }

  func setRatio(_ ratio: AspectRatio?) {
    self.ratio = ratio
    if let ratio, let selection, let displayID {
      self.selection = CropperGeometry.applying(ratio, to: selection, within: bounds(of: displayID))
    }
  }

  func setSize(width: CGFloat? = nil, height: CGFloat? = nil) {
    guard let selection, let displayID else { return }
    var newWidth = width ?? selection.width
    var newHeight = height ?? selection.height
    if let ratio {
      if width != nil { newHeight = newWidth / ratio.value } else { newWidth = newHeight * ratio.value }
    }
    self.selection = CropperGeometry.resized(selection, width: newWidth, height: newHeight, within: bounds(of: displayID))
  }

  func selectFullScreen(_ displayID: CGDirectDisplayID) {
    ratio = nil
    select(bounds(of: displayID), on: displayID)
  }

  /// Selects the window on whichever display holds most of it and brings its app forward, like the original Kap.
  func select(_ window: SnapWindow) {
    let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
    let displays = NSScreen.screens.compactMap(\.displayID)
    guard let displayID = displays.first(where: { CGDisplayBounds($0).contains(center) }) ?? displays.first,
          let frame = CropperGeometry.localFrame(of: window.frame, displayBounds: CGDisplayBounds(displayID)) else { return }
    ratio = nil
    select(frame, on: displayID)
    if window.processID != ProcessInfo.processInfo.processIdentifier {
      NSRunningApplication(processIdentifier: window.processID)?.activate()
      onOtherAppActivated?()
    }
  }

  /// Drops a remembered selection that no longer fits, e.g. after a display was disconnected or changed resolution.
  func validateSelection() {
    guard let displayID, let selection else { return }
    let isOnline = NSScreen.screens.contains { $0.displayID == displayID }
    if !isOnline || !bounds(of: displayID).contains(selection) {
      self.selection = nil
    }
  }

  /// Reads on-screen windows with the window server API, which, unlike ScreenCaptureKit, works before the user
  /// has granted Screen Recording permission. Titles stay empty until then.
  func loadWindows() {
    let ownPID = ProcessInfo.processInfo.processIdentifier
    let displays = NSScreen.screens.compactMap(\.displayID).map(CGDisplayBounds)
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[CFString: Any]] ?? []
    windows = info.compactMap { window in
      guard (window[kCGWindowLayer] as? Int) == 0,
            let id = window[kCGWindowNumber] as? CGWindowID,
            let pid = window[kCGWindowOwnerPID] as? pid_t, pid != ownPID,
            let appName = window[kCGWindowOwnerName] as? String, !appName.isEmpty,
            let boundsDictionary = window[kCGWindowBounds] as? NSDictionary,
            let frame = CGRect(dictionaryRepresentation: boundsDictionary),
            frame.width > 50, frame.height > 50,
            // Skips helper windows parked off screen, such as browsers' hidden tab strips.
            displays.contains(where: { CropperGeometry.localFrame(of: frame, displayBounds: $0) != nil }),
            (window[kCGWindowAlpha] as? Double ?? 1) > 0 else { return nil }
      return SnapWindow(id: id, title: window[kCGWindowName] as? String ?? "", appName: appName, processID: pid, frame: frame)
    }
  }
}

extension NSScreen {
  var displayID: CGDirectDisplayID? {
    deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
  }
}
