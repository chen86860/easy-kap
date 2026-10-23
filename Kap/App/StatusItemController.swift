import AppKit

/// Left click runs the primary action (open the cropper or stop recording); right click shows the menu.
final class StatusItemController: NSObject {
  enum State {
    case idle, recording, paused
  }

  private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let makeMenu: () -> NSMenu
  private let onPrimaryAction: () -> Void
  private var timer: Timer?
  private var recordedBeforeResume: TimeInterval = 0
  private var resumedAt: Date?

  init(makeMenu: @escaping () -> NSMenu, onPrimaryAction: @escaping () -> Void) {
    self.makeMenu = makeMenu
    self.onPrimaryAction = onPrimaryAction
    super.init()
    guard let button = item.button else { return }
    button.target = self
    button.action = #selector(clicked)
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    button.imagePosition = .imageLeading
    // Digits keep the same width, so the item doesn't shift as the timer counts.
    button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    setState(.idle)
  }

  /// The title shows recorded time only, so it stands still while paused.
  func setState(_ state: State) {
    timer?.invalidate()
    timer = nil
    guard let button = item.button else { return }

    switch state {
    case .idle:
      recordedBeforeResume = 0
      resumedAt = nil
      item.length = NSStatusItem.squareLength
      button.image = NSImage(named: "menubarDefaultTemplate")
      button.title = ""
      button.toolTip = "Easy Kap"
    case .recording:
      resumedAt = .now
      // The system adds its own stop button to the menu bar while recording, so Kap's ring stays recognizable here.
      item.length = Self.recordingLength
      button.image = Self.ring(color: .systemRed)
      button.toolTip = "Click to stop, right-click to pause"
      updateTitle()
      timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
        MainActor.assumeIsolated { self?.updateTitle() }
      }
    case .paused:
      if let resumedAt { recordedBeforeResume += Date.now.timeIntervalSince(resumedAt) }
      resumedAt = nil
      item.length = Self.recordingLength
      button.image = Self.ring(color: .secondaryLabelColor)
      button.toolTip = "Paused — click to stop, right-click to resume"
      updateTitle()
    }
  }

  /// Wide enough for the ring and "99:59", so the item keeps one size for the whole recording.
  private static let recordingLength: CGFloat = 70

  /// Kap's ring at the menu bar icon's 16pt size, filled while recording.
  private static func ring(color: NSColor) -> NSImage {
    NSImage(size: CGSize(width: 16, height: 16), flipped: false) { rect in
      let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 1.75, dy: 1.75))
      ring.lineWidth = 2
      color.setStroke()
      ring.stroke()
      color.setFill()
      NSBezierPath(ovalIn: rect.insetBy(dx: 5, dy: 5)).fill()
      return true
    }
  }

  private func updateTitle() {
    let elapsed = Int(recordedBeforeResume + (resumedAt.map { Date.now.timeIntervalSince($0) } ?? 0))
    item.button?.title = String(format: " %d:%02d", elapsed / 60, elapsed % 60)
  }

  @objc private func clicked(_ sender: NSStatusBarButton) {
    let event = NSApp.currentEvent
    if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
      // Attaching the menu for one click lets macOS place it below the icon, fully on screen. Placing it by
      // hand put its top above the screen edge, so it opened collapsed behind a scroll arrow.
      item.menu = makeMenu()
      sender.performClick(nil)
      item.menu = nil
    } else {
      onPrimaryAction()
    }
  }
}
