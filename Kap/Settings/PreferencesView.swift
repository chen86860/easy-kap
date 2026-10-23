import AVFoundation
import SwiftUI

struct PreferencesView: View {
  @Bindable var preferences: Preferences
  @State private var microphones: [AVCaptureDevice] = []

  var body: some View {
    Form {
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
      }

      Section("Recording") {
        Toggle("Show cursor", isOn: $preferences.showCursor)
        Toggle("Highlight clicks", isOn: $preferences.highlightClicks)
          .disabled(!preferences.showCursor)
        Toggle("Record at 60 FPS", isOn: $preferences.record60fps)
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

      Section("Export") {
        Toggle("Loop GIF and APNG exports", isOn: $preferences.loopExports)
      }
    }
    .formStyle(.grouped)
    .frame(width: 480)
    .fixedSize(horizontal: false, vertical: true)
    .task { microphones = Microphones.all }
  }

  private func chooseDirectory() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.directoryURL = preferences.kapturesDirectory
    panel.prompt = "Choose"
    if panel.runModal() == .OK, let url = panel.url {
      preferences.kapturesDirectory = url
    }
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
    if isRecording { return "Type shortcut…" }
    return shortcut?.displayString ?? "Record Shortcut"
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
