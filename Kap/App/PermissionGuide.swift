import AppKit

/// Screen Recording access, checked without raising macOS's own prompt.
enum ScreenRecordingPermission {
  static var isGranted: Bool { CGPreflightScreenCaptureAccess() }

  static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture")!
}

/// A floating guide beside System Settings' Screen Recording pane, adapted from Easy Complete's Accessibility guide.
/// It opens the pane, offers Easy Kap as a tile to drag into the list, and closes once access is granted or
/// System Settings goes away.
final class PermissionGuide: NSObject {
  private static let settingsBundleID = "com.apple.systempreferences"
  private static let panelSize = CGSize(width: 480, height: 116)

  private var panel: NSPanel?
  private var timer: Timer?
  private var sawSettingsWindow = false
  /// Bumped by every pane request, so an older request's retries stand down.
  private var settingsRequest = 0

  var isShown: Bool { panel != nil }

  func show() {
    close()
    openSettingsPane(ScreenRecordingPermission.settingsURL)
    panel = makePanel()
    timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.updatePosition() }
    }
    updatePosition()
  }

  @objc func close() {
    timer?.invalidate()
    timer = nil
    panel?.orderOut(nil)
    panel = nil
    sawSettingsWindow = false
  }

  // MARK: Panel

  private func makePanel() -> NSPanel {
    let size = Self.panelSize
    let panel = NSPanel(
      contentRect: CGRect(origin: .zero, size: size),
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    panel.isFloatingPanel = true
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false

    let content = NSView(frame: CGRect(origin: .zero, size: size))
    content.wantsLayer = true
    content.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    content.layer?.cornerRadius = 20
    content.layer?.borderWidth = 1
    content.layer?.borderColor = NSColor(white: 0, alpha: 0.1).cgColor

    let bundleURL = Bundle.main.bundleURL.standardizedFileURL
    let name = GuideTileView.appName(bundleURL)
    let instruction = NSTextField(labelWithString: String(localized: "↑  Drag \(name) into the list above"))
    instruction.frame = CGRect(x: 18, y: 73, width: size.width - 36 - 28, height: 24)
    instruction.font = .systemFont(ofSize: 13, weight: .medium)
    instruction.lineBreakMode = .byTruncatingTail
    instruction.textColor = .labelColor
    content.addSubview(instruction)

    let closeTitle = String(localized: "Close")
    let closeButton = NSButton(
      image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: closeTitle) ?? NSImage(),
      target: self,
      action: #selector(close)
    )
    closeButton.isBordered = false
    closeButton.imageScaling = .scaleProportionallyUpOrDown
    closeButton.contentTintColor = .tertiaryLabelColor
    closeButton.toolTip = closeTitle
    closeButton.frame = CGRect(x: size.width - 18 - 20, y: 75, width: 20, height: 20)
    content.addSubview(closeButton)

    content.addSubview(GuideTileView(frame: CGRect(x: 18, y: 17, width: size.width - 36, height: 44), bundleURL: bundleURL))
    panel.contentView = content
    return panel
  }

  /// Keeps the guide in System Settings' bottom-right corner, and shows it only while System Settings is in front,
  /// so it never covers other apps.
  private func updatePosition() {
    guard let panel else { return }
    if ScreenRecordingPermission.isGranted {
      close()
      return
    }
    guard let settingsFrame = Self.settingsWindowFrame() else {
      if sawSettingsWindow { close() }
      return
    }
    sawSettingsWindow = true
    // Dragging from the non-activating panel leaves System Settings frontmost.
    guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.settingsBundleID else {
      panel.orderOut(nil)
      return
    }

    let settings = Self.appKitFrame(settingsFrame)
    let size = panel.frame.size
    let screen = NSScreen.screens.first { $0.frame.intersects(settings) } ?? NSScreen.main
    let visible = screen?.visibleFrame ?? settings
    var x = settings.maxX - size.width - 16
    // Just above the bottom edge, clear of the list's + and − buttons.
    var y = settings.minY + 20
    x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
    y = min(max(y, visible.minY + 8), visible.maxY - size.height - 8)
    panel.setFrameOrigin(CGPoint(x: x, y: y))
    panel.orderFrontRegardless()
  }

  // MARK: System Settings

  private static var settingsProcessIDs: Set<pid_t> {
    Set(NSRunningApplication.runningApplications(withBundleIdentifier: settingsBundleID).map(\.processIdentifier))
  }

  /// System Settings' main window in Quartz coordinates. Matched by process, not window owner name, which is localized.
  private static func settingsWindowFrame() -> CGRect? {
    let pids = settingsProcessIDs
    guard !pids.isEmpty else { return nil }
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[CFString: Any]] ?? []
    return windows
      .compactMap { window -> CGRect? in
        guard let pid = window[kCGWindowOwnerPID] as? pid_t, pids.contains(pid),
              (window[kCGWindowLayer] as? Int) == 0,
              let bounds = window[kCGWindowBounds] as? NSDictionary,
              let frame = CGRect(dictionaryRepresentation: bounds),
              frame.width >= 300, frame.height >= 200 else { return nil }
        return frame
      }
      .max { $0.width * $0.height < $1.width * $1.height }
  }

  private static func appKitFrame(_ frame: CGRect) -> CGRect {
    guard let primary = NSScreen.screens.first else { return frame }
    return CGRect(x: frame.minX, y: primary.frame.height - frame.minY - frame.height, width: frame.width, height: frame.height)
  }

  /// Opens System Settings at `url`. A System Settings that isn't running yet drops the pane in the URL while it
  /// restores the pane it showed last, so after a cold launch the URL goes again once its window is up and settled.
  private func openSettingsPane(_ url: URL) {
    let isCold = Self.settingsProcessIDs.isEmpty
    settingsRequest += 1
    let request = settingsRequest
    NSWorkspace.shared.open(url)
    guard isCold else { return }
    Task { [weak self] in
      for _ in 0..<100 {
        try? await Task.sleep(for: .milliseconds(100))
        guard let self, request == self.settingsRequest else { return }
        guard Self.settingsWindowFrame() != nil else { continue }
        for delay in [350, 850] {
          try? await Task.sleep(for: .milliseconds(delay))
          guard request == self.settingsRequest else { return }
          NSWorkspace.shared.open(url)
        }
        return
      }
    }
  }
}

/// Easy Kap's icon and name as System Settings lists them. Dragging it hands the list the app bundle's file URL,
/// as the list's + button would, which adds the app and switches it on.
private final class GuideTileView: NSView, NSDraggingSource {
  private let bundleURL: URL
  private let icon: NSImage
  private let name: String
  private var mouseDownEvent: NSEvent?

  init(frame: CGRect, bundleURL: URL) {
    self.bundleURL = bundleURL
    icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
    icon.size = CGSize(width: 32, height: 32)
    name = Self.appName(bundleURL)
    super.init(frame: frame)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  static func appName(_ bundleURL: URL) -> String {
    let name = FileManager.default.displayName(atPath: bundleURL.path).replacing(/\.app$/, with: "")
    return name.isEmpty ? "Easy Kap" : name
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: .openHand)
  }

  override func draw(_ dirtyRect: CGRect) {
    let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    let background = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
    NSColor(white: isDark ? 0.18 : 0.89, alpha: 1).setFill()
    background.fill()
    NSColor(white: isDark ? 1 : 0, alpha: 0.1).setStroke()
    background.lineWidth = 1
    background.stroke()

    icon.draw(in: CGRect(x: 10, y: 6, width: 32, height: 32))
    (name as NSString).draw(at: CGPoint(x: 52, y: 14), withAttributes: [
      .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
      .foregroundColor: NSColor(white: isDark ? 0.94 : 0.12, alpha: 1)
    ])
  }

  override func mouseDown(with event: NSEvent) {
    mouseDownEvent = event
  }

  override func mouseDragged(with event: NSEvent) {
    guard let mouseDownEvent else { return }
    let start = mouseDownEvent.locationInWindow
    guard hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) >= 3 else { return }

    let item = NSDraggingItem(pasteboardWriter: bundleURL as NSURL)
    if let representation = bitmapImageRepForCachingDisplay(in: bounds) {
      cacheDisplay(in: bounds, to: representation)
      let snapshot = NSImage(size: bounds.size)
      snapshot.addRepresentation(representation)
      item.setDraggingFrame(bounds, contents: snapshot)
    }
    let session = beginDraggingSession(with: [item], event: mouseDownEvent, source: self)
    session.animatesToStartingPositionsOnCancelOrFail = true
    session.draggingFormation = .none
    self.mouseDownEvent = nil
  }

  func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
    .copy
  }
}
