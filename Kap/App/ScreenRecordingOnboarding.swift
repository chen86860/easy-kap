import AppKit
import SwiftUI

/// Explains why Easy Kap needs Screen Recording access before sending the user to System Settings, waits for the
/// grant, then offers to start recording.
final class ScreenRecordingOnboarding {
  private let guide: PermissionGuide
  private let onStartRecording: () -> Void
  private var window: NSWindow?

  init(guide: PermissionGuide, onStartRecording: @escaping () -> Void) {
    self.guide = guide
    self.onStartRecording = onStartRecording
  }

  func show() {
    let window = window ?? makeWindow()
    self.window = window
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }

  private func close() {
    guide.close()
    window?.close()
    window = nil
  }

  private func makeWindow() -> NSWindow {
    let view = ScreenRecordingOnboardingView(
      onOpenSettings: { [weak self] in self?.guide.show() },
      onLater: { [weak self] in self?.close() },
      onGranted: { [weak self] in
        // The user is in System Settings; bring the next step forward.
        NSApp.activate()
        self?.window?.makeKeyAndOrderFront(nil)
      },
      onStartRecording: { [weak self] in
        self?.close()
        self?.onStartRecording()
      }
    )
    let controller = NSHostingController(rootView: view)
    controller.sizingOptions = .preferredContentSize
    let window = NSWindow(contentViewController: controller)
    window.styleMask = [.titled, .closable, .fullSizeContentView]
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.title = String(localized: "Screen Recording")
    window.isMovableByWindowBackground = true
    window.isReleasedWhenClosed = false
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    window.center()
    return window
  }
}

private struct ScreenRecordingOnboardingView: View {
  let onOpenSettings: () -> Void
  let onLater: () -> Void
  let onGranted: () -> Void
  let onStartRecording: () -> Void

  @State private var isGranted = ScreenRecordingPermission.isGranted
  @State private var didOpenSettings = false

  var body: some View {
    VStack(spacing: 20) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 72, height: 72)
        .overlay(alignment: .bottomTrailing) {
          if isGranted {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 26))
              .foregroundStyle(.white, .green)
              .offset(x: 4, y: 4)
              .transition(.scale.combined(with: .opacity))
          }
        }

      if isGranted { granted } else { request }
    }
    .padding(.horizontal, 32)
    .padding(.top, 36)
    .padding(.bottom, 24)
    .frame(width: 420)
    .animation(.spring(duration: 0.35), value: isGranted)
    .task {
      while !Task.isCancelled, !isGranted {
        try? await Task.sleep(for: .seconds(1))
        if ScreenRecordingPermission.isGranted {
          isGranted = true
          onGranted()
        }
      }
    }
  }

  private var request: some View {
    VStack(spacing: 20) {
      VStack(spacing: 8) {
        Text("Allow Easy Kap to Record Your Screen")
          .font(.title2.weight(.semibold))
        Text("macOS asks you to allow this once. Easy Kap only records the area you choose.")
          .foregroundStyle(.secondary)
      }
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)

      VStack(alignment: .leading, spacing: 12) {
        OnboardingStep(number: 1, text: "Open Screen & System Audio Recording in System Settings.")
        OnboardingStep(number: 2, text: "Drag Easy Kap into the list, or switch it on if it's already there.")
        OnboardingStep(number: 3, text: "Come back here and start recording.")
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))

      if didOpenSettings {
        HStack(spacing: 8) {
          ProgressView().controlSize(.small)
          Text("If System Settings offers to quit and reopen Easy Kap, choose Quit & Reopen.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      HStack {
        Button("Later", action: onLater)
          .keyboardShortcut(.cancelAction)
        Spacer()
        Button(didOpenSettings ? "Open System Settings Again" : "Open System Settings") {
          didOpenSettings = true
          onOpenSettings()
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
      }
      .controlSize(.large)
    }
  }

  private var granted: some View {
    VStack(spacing: 20) {
      VStack(spacing: 8) {
        Text("Easy Kap Can Record Your Screen")
          .font(.title2.weight(.semibold))
        Text("You're all set. Choose an area and start recording.")
          .foregroundStyle(.secondary)
      }
      .multilineTextAlignment(.center)

      Button("Start Recording", action: onStartRecording)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
    }
  }
}

private struct OnboardingStep: View {
  let number: Int
  let text: LocalizedStringKey

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Text(verbatim: "\(number)")
        .font(.callout.weight(.semibold).monospacedDigit())
        .foregroundStyle(.white)
        .frame(width: 22, height: 22)
        .background(Color.accentColor, in: .circle)
        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
      Text(text)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
