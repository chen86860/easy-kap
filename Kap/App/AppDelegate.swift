import AppKit
import OSLog
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "EasyKap", category: "app")

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let preferences = Preferences.shared
  private let cropper = CropperController()
  private let recorder = Recorder()
  private let hotKey = GlobalHotKey()
  private var statusItem: StatusItemController?
  private var editors: [EditorWindowController] = []
  private var preferencesWindow: NSWindow?
  private var isStartingRecording = false

  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

    NSApp.mainMenu = makeMainMenu()
    statusItem = StatusItemController(
      makeMenu: { [weak self] in self?.makeStatusMenu() ?? NSMenu() },
      onPrimaryAction: { [weak self] in self?.primaryAction() }
    )

    cropper.model.onRecord = { [weak self] in self?.startRecording() }
    cropper.model.onCancel = { [weak self] in self?.cropper.close() }

    hotKey.action = { [weak self] in self?.primaryAction() }
    hotKey.register(preferences.shortcut)
    preferences.onShortcutChange = { [weak self] in self?.hotKey.register($0) }
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    urls.forEach(openEditor)
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag { primaryAction() }
    return true
  }

  // MARK: Actions

  private func primaryAction() {
    if recorder.isRecording {
      stopRecording()
    } else if cropper.isOpen {
      cropper.close()
    } else if !isStartingRecording {
      cropper.open()
    }
  }

  private func startRecording() {
    guard !isStartingRecording, let displayID = cropper.model.displayID, let rect = cropper.model.selection else { return }
    isStartingRecording = true
    let settings = RecordingSettings(
      fps: preferences.record60fps ? 60 : 30,
      showsCursor: preferences.showCursor,
      showsClicks: preferences.highlightClicks,
      recordsMicrophone: preferences.recordAudio,
      recordsSystemAudio: preferences.recordSystemAudio,
      audioDeviceID: preferences.audioDeviceID
    )
    logger.info("Starting recording \(String(describing: rect), privacy: .public) on display \(displayID)")
    preferences.lastSelection = cropper.model.savedSelection
    cropper.enterRecordingMode()
    Task {
      defer { isStartingRecording = false }
      do {
        try await recorder.start(displayID: displayID, rect: rect, settings: settings)
        statusItem?.setState(.recording)
      } catch {
        cropper.close()
        present(error)
      }
    }
  }

  private func stopRecording() {
    Task {
      cropper.close()
      statusItem?.setState(.idle)
      do {
        openEditor(try await recorder.stop())
      } catch {
        present(error)
      }
    }
  }

  @objc private func togglePause() {
    Task {
      do {
        if recorder.isPaused {
          try recorder.resume()
          statusItem?.setState(.recording)
        } else {
          try await recorder.pause()
          statusItem?.setState(.paused)
        }
      } catch {
        present(error)
      }
    }
  }

  @objc private func stopRecordingFromMenu() {
    stopRecording()
  }

  private func openEditor(_ url: URL) {
    let editor = EditorWindowController(url: url) { [weak self] closed in
      self?.editors.removeAll { $0 === closed }
    }
    editors.append(editor)
    NSApp.activate()
    editor.showWindow(nil)
  }

  @objc private func openVideo() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.movie]
    panel.allowsMultipleSelection = true
    NSApp.activate()
    guard panel.runModal() == .OK else { return }
    panel.urls.forEach(openEditor)
  }

  @objc private func showPreferences() {
    if preferencesWindow == nil {
      let window = NSWindow(contentViewController: NSHostingController(rootView: PreferencesView(preferences: preferences)))
      window.title = "Easy Kap Settings"
      window.styleMask = [.titled, .closable]
      window.isReleasedWhenClosed = false
      window.center()
      preferencesWindow = window
    }
    NSApp.activate()
    preferencesWindow?.makeKeyAndOrderFront(nil)
  }

  @objc private func startRecordingFromMenu() {
    primaryAction()
  }

  private func present(_ error: any Error) {
    logger.error("\(String(describing: error), privacy: .public)")
    // macOS shows its own Screen Recording prompt, so a second alert would only repeat it.
    if case .screenRecordingDenied? = error as? RecorderError { return }
    let alert = NSAlert(error: error)
    let settingsURL = (error as? RecorderError)?.settingsURL
    if settingsURL != nil {
      alert.addButton(withTitle: "Open System Settings")
      alert.addButton(withTitle: "Cancel")
    }
    NSApp.activate()
    if alert.runModal() == .alertFirstButtonReturn, let settingsURL {
      NSWorkspace.shared.open(settingsURL)
    }
  }

  // MARK: Menus

  private func makeStatusMenu() -> NSMenu {
    let menu = NSMenu()
    if recorder.isRecording {
      let pauseTitle = recorder.isPaused ? "Resume Recording" : "Pause Recording"
      menu.addItem(withTitle: pauseTitle, action: #selector(togglePause), keyEquivalent: "").target = self
      menu.addItem(withTitle: "Stop Recording", action: #selector(stopRecordingFromMenu), keyEquivalent: "").target = self
    } else {
      menu.addItem(withTitle: "Start Recording…", action: #selector(startRecordingFromMenu), keyEquivalent: "").target = self
      menu.addItem(withTitle: "Open Video…", action: #selector(openVideo), keyEquivalent: "").target = self
    }
    menu.addItem(.separator())
    menu.addItem(withTitle: "Settings…", action: #selector(showPreferences), keyEquivalent: ",").target = self
    menu.addItem(.separator())
    menu.addItem(withTitle: "Quit Easy Kap", action: #selector(NSApplication.terminate), keyEquivalent: "q")
    return menu
  }

  /// Accessory apps have no visible menu bar, but the key equivalents still drive copy and paste in text fields.
  private func makeMainMenu() -> NSMenu {
    let main = NSMenu()

    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "Settings…", action: #selector(showPreferences), keyEquivalent: ",").target = self
    appMenu.addItem(withTitle: "Quit Easy Kap", action: #selector(NSApplication.terminate), keyEquivalent: "q")
    main.addItem(withTitle: "Easy Kap", action: nil, keyEquivalent: "").submenu = appMenu

    let fileMenu = NSMenu(title: "File")
    fileMenu.addItem(withTitle: "Open Video…", action: #selector(openVideo), keyEquivalent: "o").target = self
    fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose), keyEquivalent: "w")
    main.addItem(withTitle: "File", action: nil, keyEquivalent: "").submenu = fileMenu

    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
    editMenu.addItem(.separator())
    editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut), keyEquivalent: "x")
    editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy), keyEquivalent: "c")
    editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste), keyEquivalent: "v")
    editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll), keyEquivalent: "a")
    main.addItem(withTitle: "Edit", action: nil, keyEquivalent: "").submenu = editMenu

    return main
  }
}
