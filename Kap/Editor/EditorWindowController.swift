import AppKit
import SwiftUI

final class EditorWindowController: NSWindowController, NSWindowDelegate {
  private let model: EditorModel
  private let onClose: (EditorWindowController) -> Void
  private var isDiscardConfirmed = false

  init(url: URL, onClose: @escaping (EditorWindowController) -> Void) {
    model = EditorModel(url: url)
    self.onClose = onClose
    let window = NSWindow(
      contentRect: CGRect(x: 0, y: 0, width: 1080, height: 660),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = url.deletingPathExtension().lastPathComponent
    window.representedURL = url
    window.minSize = CGSize(width: 780, height: 400)
    // The title is drawn over the video on hover, like the original Kap.
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
    window.isReleasedWhenClosed = false
    super.init(window: window)

    let editorView = EditorView(
      model: model,
      onConvert: { [weak self] in self?.convert() },
      onHoverChange: { [weak self] in self?.setTitlebarButtonsVisible($0) }
    )
    window.contentViewController = NSHostingController(rootView: editorView)
    window.setContentSize(CGSize(width: 960, height: 540 + EditorView.barHeight))
    window.delegate = self
    window.center()
    setTitlebarButtonsVisible(false)
    fitWindowWhenLoaded()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setTitlebarButtonsVisible(_ isVisible: Bool) {
    let buttons = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap { window?.standardWindowButton($0) }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.2
      buttons.forEach { $0.animator().alphaValue = isVisible ? 1 : 0 }
    }
  }

  private func fitWindowWhenLoaded() {
    guard model.isLoaded else {
      withObservationTracking { _ = model.isLoaded } onChange: { [weak self] in
        Task { @MainActor in self?.fitWindowWhenLoaded() }
      }
      return
    }
    fitWindowToVideo()
  }

  /// Sizes the window to the video's aspect ratio at up to 1 point per pixel, within the screen.
  private func fitWindowToVideo() {
    guard let window, let screen = window.screen ?? NSScreen.main else { return }
    let scale = screen.backingScaleFactor
    let visible = screen.visibleFrame
    let maxVideo = CGSize(width: visible.width * 0.8, height: visible.height * 0.8 - EditorView.barHeight)
    var video = CGSize(width: model.naturalSize.width / scale, height: model.naturalSize.height / scale)
    let fit = min(1, maxVideo.width / video.width, maxVideo.height / video.height)
    video = CGSize(width: video.width * fit, height: video.height * fit)
    if video.width < window.minSize.width {
      video = CGSize(width: window.minSize.width, height: window.minSize.width / model.aspectRatio)
    }
    let content = CGSize(width: video.width.rounded(), height: (video.height + EditorView.barHeight).rounded())
    var frame = window.frameRect(forContentRect: CGRect(origin: .zero, size: content))
    frame.origin = CGPoint(x: visible.midX - frame.width / 2, y: visible.midY - frame.height / 2)
    window.setFrame(frame, display: true, animate: false)
  }

  private func convert() {
    switch model.destination {
    case .saveToDisk:
      showSavePanel()
    case .copyToClipboard, .openWith:
      let directory = URL.temporaryDirectory.appending(path: "Exports")
      try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      model.export(to: directory.appending(path: exportFileName))
    }
  }

  /// Keeps the recording's name, which carries the time it was recorded, e.g. "Kapture 2026-10-23 at 17.17.02.gif".
  private var exportFileName: String {
    "\(model.url.deletingPathExtension().lastPathComponent).\(model.format.fileExtension)"
  }

  private func showSavePanel() {
    guard let window else { return }
    let directory = Preferences.shared.kapturesDirectory
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let panel = NSSavePanel()
    panel.directoryURL = directory
    panel.nameFieldStringValue = exportFileName
    panel.allowedContentTypes = [model.format.contentType]
    panel.canCreateDirectories = true
    panel.beginSheetModal(for: window) { [weak self] response in
      guard response == .OK, let url = panel.url else { return }
      self?.model.export(to: url)
    }
  }

  /// A fresh recording only exists in Kap's cache, so closing it without exporting asks first, like the original Kap.
  private var needsDiscardConfirmation: Bool {
    let recordings = Recorder.recordingsDirectory.standardizedFileURL.path
    return !isDiscardConfirmed && !model.hasExported && model.url.standardizedFileURL.path.hasPrefix(recordings)
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    guard needsDiscardConfirmation else { return true }
    let alert = NSAlert()
    alert.messageText = "Are you sure that you want to discard this recording?"
    alert.informativeText = "You will no longer be able to edit and export the original recording."
    alert.addButton(withTitle: "Discard")
    alert.addButton(withTitle: "Cancel")
    alert.beginSheetModal(for: sender) { [weak self] response in
      guard let self, response == .alertFirstButtonReturn else { return }
      self.isDiscardConfirmed = true
      try? FileManager.default.removeItem(at: self.model.url)
      sender.close()
    }
    return false
  }

  func windowWillClose(_ notification: Notification) {
    model.tearDown()
    onClose(self)
  }
}
