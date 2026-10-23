import AppKit

/// Left click runs the primary action (open the cropper or stop recording); right click shows the menu.
final class StatusItemController: NSObject {
  enum State {
    case idle, recording, paused
  }

  private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
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
      button.image = NSImage(named: "menubarDefaultTemplate")
      button.title = ""
      button.toolTip = "Easy Kap"
    case .recording:
      resumedAt = .now
      button.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: "Stop Recording")
      button.toolTip = "Click to stop, right-click to pause"
      updateTitle()
      timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
        MainActor.assumeIsolated { self?.updateTitle() }
      }
    case .paused:
      if let resumedAt { recordedBeforeResume += Date.now.timeIntervalSince(resumedAt) }
      resumedAt = nil
      button.image = NSImage(systemSymbolName: "pause.circle.fill", accessibilityDescription: "Recording Paused")
      button.toolTip = "Paused — click to stop, right-click to resume"
      updateTitle()
    }
  }

  private func updateTitle() {
    let elapsed = Int(recordedBeforeResume + (resumedAt.map { Date.now.timeIntervalSince($0) } ?? 0))
    item.button?.title = String(format: " %d:%02d", elapsed / 60, elapsed % 60)
  }

  @objc private func clicked(_ sender: NSStatusBarButton) {
    let event = NSApp.currentEvent
    if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
      makeMenu().popUp(positioning: nil, at: CGPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    } else {
      onPrimaryAction()
    }
  }
}
