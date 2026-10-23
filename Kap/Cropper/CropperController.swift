import AppKit
import SwiftUI

/// Shows one transparent overlay panel per display for picking the recording area.
final class CropperController {
  let model = CropperModel(saved: Preferences.shared.lastSelection)
  private var panels: [CGDirectDisplayID: CropperPanel] = [:]
  private var keyMonitor: Any?

  var isOpen: Bool { !panels.isEmpty }

  func open() {
    guard !isOpen else { return }
    model.isRecording = false
    model.openMenu = nil
    model.validateSelection()
    if model.selection == nil, let mainDisplay = NSScreen.main?.displayID {
      model.select(CropperGeometry.defaultSelection(in: model.bounds(of: mainDisplay)), on: mainDisplay)
    }

    for screen in NSScreen.screens {
      guard let displayID = screen.displayID else { continue }
      let panel = CropperPanel(frame: screen.frame)
      let hostingView = NSHostingView(rootView: CropperView(model: model, displayID: displayID))
      hostingView.sizingOptions = []
      panel.contentView = hostingView
      panel.orderFrontRegardless()
      panels[displayID] = panel
    }

    NSApp.activate()
    let activeDisplay = model.displayID.flatMap { panels[$0] } ?? NSScreen.main?.displayID.flatMap { panels[$0] }
    activeDisplay?.makeKey()

    model.onOtherAppActivated = { [weak self] in
      Task { @MainActor in
        // Give the other app a moment to raise its window, then take keyboard focus back for Esc and Return.
        try? await Task.sleep(for: .milliseconds(250))
        guard let self, self.isOpen, let displayID = self.model.displayID else { return }
        NSApp.activate()
        self.panels[displayID]?.makeKey()
      }
    }

    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      self?.handleKeyDown(event) ?? event
    }
    model.loadWindows()
  }

  /// Keeps only a non-interactive outline around the recorded area. Kap's windows are excluded from the capture.
  func enterRecordingMode() {
    model.isRecording = true
    removeKeyMonitor()
    for (displayID, panel) in panels {
      if displayID == model.displayID {
        panel.ignoresMouseEvents = true
      } else {
        panel.orderOut(nil)
      }
    }
  }

  func close() {
    removeKeyMonitor()
    panels.values.forEach { $0.orderOut(nil) }
    panels = [:]
    model.isRecording = false
  }

  private func removeKeyMonitor() {
    if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    keyMonitor = nil
  }

  private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
    let isEditingText = (NSApp.keyWindow?.firstResponder as? NSTextView)?.isFieldEditor == true
    switch event.keyCode {
    case 53: // Escape
      if model.openMenu != nil {
        model.openMenu = nil
      } else if isEditingText {
        NSApp.keyWindow?.makeFirstResponder(nil)
      } else {
        model.onCancel?()
      }
      return nil
    case 36, 76: // Return, Enter
      guard !isEditingText, model.selection != nil else { return event }
      model.onRecord?()
      return nil
    default:
      return event
    }
  }
}

private final class CropperPanel: NSPanel {
  init(frame: CGRect) {
    super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    level = .screenSaver
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    isReleasedWhenClosed = false
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    setFrame(frame, display: false)
  }

  override var canBecomeKey: Bool { true }
}
