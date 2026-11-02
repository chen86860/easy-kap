import AVFoundation
import Sparkle
import SwiftUI

/// Permissions, where recordings go, the shortcut, the language, and export options.
struct GeneralSettingsView: View {
  @Bindable var preferences: Preferences
  /// Opens System Settings with the drag guide beside it.
  let onGrantScreenRecording: () -> Void
  @State private var canRecordScreen = ScreenRecordingPermission.isGranted

  var body: some View {
    Form {
      Section {
        LabeledContent {
          if canRecordScreen {
            Label("Allowed", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
          } else {
            Button("Allow…", action: onGrantScreenRecording)
              .buttonStyle(.borderedProminent)
          }
        } label: {
          Text("Screen Recording")
          if !canRecordScreen {
            Text("Easy Kap needs this permission to record your screen.")
          }
        }
      } header: {
        Text("Permissions")
      }

      Section("General") {
        LabeledContent("Save to") {
          HStack {
            Text((preferences.kapturesDirectory.path as NSString).abbreviatingWithTildeInPath)
              .lineLimit(1)
              .truncationMode(.middle)
              .foregroundStyle(.secondary)
            Button("Choose…", action: chooseDirectory)
          }
        }
        LabeledContent("Start recording shortcut") {
          ShortcutRecorder(shortcut: $preferences.shortcut)
        }
        Picker("Language", selection: $preferences.language) {
          Text("Follow System").tag(AppLanguage.system)
          Text(verbatim: "English").tag(AppLanguage.english)
          Text(verbatim: "简体中文").tag(AppLanguage.simplifiedChinese)
        }
        if preferences.language != preferences.launchLanguage {
          LabeledContent("Restart Easy Kap to use the new language.") {
            Button("Restart Now", action: AppInfo.relaunch)
          }
          .foregroundStyle(.secondary)
        }
      }

      Section("Export") {
        Toggle("Loop GIF and APNG exports", isOn: $preferences.loopExports)
      }
    }
    .settingsPane()
    .task {
      // Access granted in System Settings applies right away, so the status follows it while Settings is open.
      while !Task.isCancelled {
        canRecordScreen = ScreenRecordingPermission.isGranted
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  private func chooseDirectory() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.directoryURL = preferences.kapturesDirectory
    panel.prompt = String(localized: "Choose")
    if panel.runModal() == .OK, let url = panel.url {
      preferences.kapturesDirectory = url
    }
  }
}

/// What a recording captures: video and audio.
struct RecordingSettingsView: View {
  @Bindable var preferences: Preferences
  @State private var microphones: [AVCaptureDevice] = []

  var body: some View {
    Form {
      Section("Video") {
        Toggle("Show cursor", isOn: $preferences.showCursor)
        Toggle("Highlight clicks", isOn: $preferences.highlightClicks)
          .disabled(!preferences.showCursor)
        Toggle("Record at 60 FPS", isOn: $preferences.record60fps)
      }

      Section("Audio") {
        Toggle("Record system audio", isOn: $preferences.recordSystemAudio)
        Toggle("Record microphone", isOn: $preferences.recordAudio)
        if preferences.recordAudio {
          Picker("Microphone", selection: $preferences.audioDeviceID) {
            Text("System Default").tag(String?.none)
            ForEach(microphones, id: \.uniqueID) { device in
              Text(device.localizedName).tag(Optional(device.uniqueID))
            }
          }
        }
      }
    }
    .settingsPane()
    .task { microphones = Microphones.all }
  }
}

/// The app's icon, version and links, and update options.
struct AboutSettingsView: View {
  /// `nil` in previews and tests, where no updater runs.
  let updater: SPUUpdater?
  @State private var checksForUpdates = false

  var body: some View {
    Form {
      Section {
        AboutHeader()
      }

      if let updater {
        Section("Updates") {
          Toggle("Check for updates automatically", isOn: $checksForUpdates)
            .onChange(of: checksForUpdates) { updater.automaticallyChecksForUpdates = checksForUpdates }
          LabeledContent("Easy Kap \(AppInfo.version)") {
            Button("Check Now") { updater.checkForUpdates() }
          }
        }
      }
    }
    .settingsPane()
    .task { checksForUpdates = updater?.automaticallyChecksForUpdates ?? false }
  }
}

private extension View {
  /// Every tab has the same width and is as tall as its content, so the window fits each tab without scrolling.
  func settingsPane() -> some View {
    formStyle(.grouped)
      .scrollDisabled(true)
      .frame(width: 500)
      .fixedSize(horizontal: false, vertical: true)
  }
}

enum AppInfo {
  static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
  static let website = URL(string: "https://easy-kap.emmmm.dev")!
  static let repository = URL(string: "https://github.com/chen86860/easy-kap")!
  static let changelog = URL(string: "https://github.com/chen86860/easy-kap/blob/main/CHANGELOG.md")!
  static let issues = URL(string: "https://github.com/chen86860/easy-kap/issues")!
  static let kap = URL(string: "https://github.com/wulkano/Kap")!

  /// Quits and opens Easy Kap again, once this instance has exited, so only one copy ever runs.
  static func relaunch() {
    let process = Process()
    process.executableURL = URL(filePath: "/bin/sh")
    process.arguments = ["-c", "while /bin/kill -0 \"$1\" 2>/dev/null; do sleep 0.1; done; /usr/bin/open \"$2\"", "relaunch",
                         String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundlePath]
    try? process.run()
    NSApp.terminate(nil)
  }
}

/// The app icon, name, version and project links at the top of Settings.
struct AboutHeader: View {
  var body: some View {
    HStack(spacing: 16) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 64, height: 64)
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text("Easy Kap")
            .font(.title2.weight(.semibold))
          Text("Version \(AppInfo.version)")
            .font(.callout)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
        Text("Inspired by [Kap](\(AppInfo.kap.absoluteString)) · MIT License")
          .font(.caption)
          .foregroundStyle(.secondary)
          .tint(.secondary)
        HStack(spacing: 14) {
          Link("Website", destination: AppInfo.website)
          Link("GitHub", destination: AppInfo.repository)
          Link("What's New", destination: AppInfo.changelog)
          Link("Report an Issue", destination: AppInfo.issues)
        }
        .font(.callout)
        .padding(.top, 4)
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, 6)
  }
}

enum Microphones {
  static var all: [AVCaptureDevice] {
    AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified).devices
  }
}

struct ShortcutRecorder: View {
  @Binding var shortcut: Shortcut?
  @State private var isRecording = false
  @State private var monitor: Any?

  var body: some View {
    HStack(spacing: 6) {
      Button(action: toggleRecording) {
        Text(label)
          .frame(minWidth: 110)
          .foregroundStyle(isRecording ? Color.accentColor : .primary)
      }
      if shortcut != nil, !isRecording {
        Button("Clear", systemImage: "xmark.circle.fill") { shortcut = nil }
          .labelStyle(.iconOnly)
          .buttonStyle(.borderless)
          .foregroundStyle(.secondary)
      }
    }
    .onDisappear(perform: stopRecording)
  }

  private var label: String {
    if isRecording { return String(localized: "Type shortcut…") }
    return shortcut?.displayString ?? String(localized: "Record Shortcut")
  }

  private func toggleRecording() {
    if isRecording {
      stopRecording()
    } else {
      startRecording()
    }
  }

  private func startRecording() {
    isRecording = true
    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      if event.keyCode == UInt16(53) { // Escape
        stopRecording()
        return nil
      }
      let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
      guard !flags.subtracting(.shift).isEmpty, let key = event.characters(byApplyingModifiers: []), !key.isEmpty else {
        NSSound.beep()
        return nil
      }
      shortcut = Shortcut(keyCode: event.keyCode, modifiers: flags.rawValue, key: key)
      stopRecording()
      return nil
    }
  }

  private func stopRecording() {
    isRecording = false
    if let monitor { NSEvent.removeMonitor(monitor) }
    monitor = nil
  }
}
