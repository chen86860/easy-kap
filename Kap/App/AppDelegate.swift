import AppKit
import OSLog
import Sparkle
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "EasyKap", category: "app")

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let preferences = Preferences.shared
  private let cropper = CropperController()
  private let recorder = Recorder()
  private let hotKey = GlobalHotKey()
  private let permissionGuide = PermissionGuide()
  private var statusItem: StatusItemController?
  private var editors: [EditorWindowController] = []
  private var settingsWindow: SettingsWindowController?
  private lazy var onboarding = ScreenRecordingOnboarding(guide: permissionGuide) { [weak self] in
    self?.openCropper(source: "onboarding")
  }
  /// Checks the release appcast for updates; created at launch, but not when the app hosts unit tests.
  private var updaterController: SPUStandardUpdaterController?
  private var isStartingRecording = false
  /// Set the moment a stop is requested, before the recorder's async stop begins, so a quick second click is ignored.
  private var isStoppingRecording = false
  private var recordingClock: RecordingClock?

  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

    updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    NSApp.mainMenu = makeMainMenu()
    statusItem = StatusItemController(
      makeMenu: { [weak self] in self?.makeStatusMenu() ?? NSMenu() },
      onPrimaryAction: { [weak self] in self?.primaryAction(source: "menu_bar_icon") }
    )

    cropper.model.onRecord = { [weak self] in self?.startRecording() }
    recorder.onStoppedBySystem = { [weak self] in self?.stopRecording(source: "system") }
    cropper.model.onCancel = { [weak self] in
      Telemetry.capture("cropper_cancelled", ["source": "cancel"])
      self?.cropper.close()
    }

    hotKey.action = { [weak self] in self?.primaryAction(source: "hotkey") }
    hotKey.register(preferences.shortcut)
    preferences.onShortcutChange = { [weak self] in self?.hotKey.register($0) }

    // Without Screen Recording access nothing can be recorded, so the first launch starts in Settings, which shows
    // the permission and a button that guides the user through granting it.
    if !ScreenRecordingPermission.isGranted { showSettings(.general) }
    Telemetry.captureLaunch(screenRecordingAllowed: ScreenRecordingPermission.isGranted)
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    urls.forEach { openEditor($0, source: "open_url") }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag { primaryAction(source: "reopen") }
    return true
  }

  // MARK: Actions

  /// `source` names what triggered the action, for usage data: hotkey, menu_bar_icon, menu or reopen.
  private func primaryAction(source: String) {
    if recorder.isRecording {
      stopRecording(source: source)
    } else if cropper.isOpen {
      Telemetry.capture("cropper_cancelled", ["source": source])
      cropper.close()
    } else if !isStartingRecording {
      if ScreenRecordingPermission.isGranted {
        openCropper(source: source)
      } else {
        onboarding.show(source: source)
      }
    }
  }

  private func openCropper(source: String) {
    cropper.open()
    Telemetry.capture("cropper_opened", ["source": source])
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
    let selectionSource = cropper.model.selectionSource
    let aspectRatio = cropper.model.ratio?.title ?? "free"
    cropper.enterRecordingMode()
    Task {
      defer { isStartingRecording = false }
      do {
        try await recorder.start(displayID: displayID, rect: rect, settings: settings)
        statusItem?.setState(.recording)
        recordingClock = RecordingClock()
        Telemetry.capture("recording_started", [
          "selection_source": selectionSource,
          "aspect_ratio": aspectRatio,
          "width": Int(rect.width),
          "height": Int(rect.height),
          "fps": settings.fps,
          "shows_cursor": settings.showsCursor,
          "highlights_clicks": settings.showsClicks,
          "records_microphone": settings.recordsMicrophone,
          "records_system_audio": settings.recordsSystemAudio
        ])
      } catch {
        Telemetry.capture("recording_failed", ["stage": "start", "error": Telemetry.errorKind(error)])
        cropper.close()
        present(error)
      }
    }
  }

  /// `source` names what stopped it, for usage data: hotkey, menu_bar_icon, menu or system.
  private func stopRecording(source: String) {
    // Both menu bar buttons can stop a recording; only the first click counts.
    guard !isStoppingRecording, !recorder.isStopping else { return }
    isStoppingRecording = true
    Task {
      defer { isStoppingRecording = false }
      cropper.close()
      statusItem?.setState(.idle)
      do {
        let url = try await recorder.stop()
        let timing = recordingClock?.summary() ?? [:]
        Telemetry.capture("recording_finished", timing.merging(["stop_source": source]) { _, new in new })
        openEditor(url, source: "recording")
      } catch {
        Telemetry.capture("recording_failed", ["stage": "stop", "error": Telemetry.errorKind(error)])
        present(error)
      }
    }
  }

  @objc private func togglePause() {
    // Read before the call: a failed pause has already ended its segment, so the recorder reads as paused.
    let stage = recorder.isPaused ? "resume" : "pause"
    Task {
      do {
        if recorder.isPaused {
          try recorder.resume()
          statusItem?.setState(.recording)
          recordingClock?.resume()
          Telemetry.capture("recording_resumed")
        } else {
          try await recorder.pause()
          statusItem?.setState(.paused)
          recordingClock?.pause()
          Telemetry.capture("recording_paused")
        }
      } catch {
        Telemetry.capture("recording_failed", ["stage": stage, "error": Telemetry.errorKind(error)])
        present(error)
      }
    }
  }

  @objc private func stopRecordingFromMenu() {
    stopRecording(source: "menu")
  }

  /// `source` says where the video came from, for usage data: recording, open_video or open_url.
  private func openEditor(_ url: URL, source: String) {
    Telemetry.capture("editor_opened", ["source": source])
    let editor = EditorWindowController(url: url) { [weak self] closed in
      self?.editors.removeAll { $0 === closed }
    }
    editors.append(editor)
    // A recording often ends from the system's stop button while another app is active. macOS refuses the
    // cooperative activate() then, and the editor opened behind that app, so this activation forces it.
    NSApp.activate(ignoringOtherApps: true)
    editor.showWindow(nil)
    editor.window?.orderFrontRegardless()
  }

  @objc private func openVideo() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.movie]
    panel.allowsMultipleSelection = true
    NSApp.activate()
    guard panel.runModal() == .OK else { return }
    panel.urls.forEach { openEditor($0, source: "open_video") }
  }

  @objc private func checkForUpdates() {
    NSApp.activate()
    updaterController?.checkForUpdates(nil)
  }

  @objc private func showPreferences() {
    showSettings()
  }

  private func showSettings(_ tab: SettingsWindowController.Tab? = nil) {
    if settingsWindow == nil {
      settingsWindow = SettingsWindowController(preferences: preferences, updater: updaterController?.updater) { [weak self] in
        Telemetry.capture("screen_recording_settings_opened", ["from": "settings"])
        self?.permissionGuide.show()
      }
    }
    settingsWindow?.show(tab)
  }

  @objc private func startRecordingFromMenu() {
    primaryAction(source: "menu")
  }

  private func present(_ error: any Error) {
    logger.error("\(String(describing: error), privacy: .public)")
    if case .screenRecordingDenied? = error as? RecorderError {
      onboarding.show(source: "recording_denied")
      return
    }
    let alert = NSAlert(error: error)
    let settingsURL = (error as? RecorderError)?.settingsURL
    if settingsURL != nil {
      alert.addButton(withTitle: String(localized: "Open System Settings"))
      alert.addButton(withTitle: String(localized: "Cancel"))
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
      let pauseTitle = recorder.isPaused ? String(localized: "Resume Recording") : String(localized: "Pause Recording")
      menu.addItem(withTitle: pauseTitle, action: #selector(togglePause), keyEquivalent: "").target = self
      let stopTitle = String(localized: "Stop Recording")
      menu.addItem(withTitle: stopTitle, action: #selector(stopRecordingFromMenu), keyEquivalent: "").target = self
    } else {
      let startTitle = String(localized: "Start Recording…")
      menu.addItem(withTitle: startTitle, action: #selector(startRecordingFromMenu), keyEquivalent: "").target = self
      menu.addItem(withTitle: String(localized: "Open Video…"), action: #selector(openVideo), keyEquivalent: "").target = self
    }
    menu.addItem(.separator())
    menu.addItem(withTitle: String(localized: "Check for Updates…"), action: #selector(checkForUpdates), keyEquivalent: "").target = self
    menu.addItem(withTitle: String(localized: "Settings…"), action: #selector(showPreferences), keyEquivalent: ",").target = self
    menu.addItem(.separator())
    menu.addItem(withTitle: String(localized: "Quit Easy Kap"), action: #selector(NSApplication.terminate), keyEquivalent: "q")
    return menu
  }

  /// Accessory apps have no visible menu bar, but the key equivalents still drive copy and paste in text fields.
  private func makeMainMenu() -> NSMenu {
    let main = NSMenu()

    let appMenu = NSMenu()
    appMenu.addItem(withTitle: String(localized: "Check for Updates…"), action: #selector(checkForUpdates), keyEquivalent: "").target = self
    appMenu.addItem(withTitle: String(localized: "Settings…"), action: #selector(showPreferences), keyEquivalent: ",").target = self
    appMenu.addItem(withTitle: String(localized: "Quit Easy Kap"), action: #selector(NSApplication.terminate), keyEquivalent: "q")
    main.addItem(withTitle: "Easy Kap", action: nil, keyEquivalent: "").submenu = appMenu

    let fileMenu = NSMenu(title: String(localized: "File"))
    fileMenu.addItem(withTitle: String(localized: "Open Video…"), action: #selector(openVideo), keyEquivalent: "o").target = self
    fileMenu.addItem(withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose), keyEquivalent: "w")
    main.addItem(withTitle: String(localized: "File"), action: nil, keyEquivalent: "").submenu = fileMenu

    let editMenu = NSMenu(title: String(localized: "Edit"))
    editMenu.addItem(withTitle: String(localized: "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
    editMenu.addItem(withTitle: String(localized: "Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
    editMenu.addItem(.separator())
    editMenu.addItem(withTitle: String(localized: "Cut"), action: #selector(NSText.cut), keyEquivalent: "x")
    editMenu.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy), keyEquivalent: "c")
    editMenu.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste), keyEquivalent: "v")
    editMenu.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll), keyEquivalent: "a")
    main.addItem(withTitle: String(localized: "Edit"), action: nil, keyEquivalent: "").submenu = editMenu

    return main
  }
}
