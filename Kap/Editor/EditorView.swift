import AVKit
import SwiftUI

/// Kap's editor: the video fills the window and loops; hovering reveals the title and trim controls;
/// export options sit in a bar along the bottom.
struct EditorView: View {
  @Bindable var model: EditorModel
  let onConvert: () -> Void
  let onHoverChange: (Bool) -> Void

  @State private var isHovering = false
  @FocusState private var isFocused: Bool

  static let barHeight: CGFloat = 52

  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        PlayerView(player: model.player)
          .onTapGesture(perform: model.togglePlayback)

        if isHovering, model.isLoaded {
          VStack(spacing: 0) {
            titleBar
            Spacer(minLength: 0)
            trimControls
          }
          .transition(.opacity)
          .environment(\.colorScheme, .dark)
        } else if model.isLoaded {
          // A thin progress line keeps the loop visible while the controls are hidden.
          VStack {
            Spacer()
            progressLine
          }
          .allowsHitTesting(false)
          .transition(.opacity)
        }
      }
      .background(.black)
      .ignoresSafeArea()
      .onHover { hovering in
        withAnimation(.easeInOut(duration: 0.2)) { isHovering = hovering }
        onHoverChange(hovering)
      }
      .overlay {
        if let error = model.loadError {
          ContentUnavailableView("Can't Open Video", systemImage: "exclamationmark.triangle", description: Text(error))
            .background(.background)
        }
      }

      exportBar
    }
    .sheet(isPresented: Binding(
      get: { model.isShowingExportStatus },
      set: { if !$0 { model.dismissExportResult() } }
    )) {
      ExportStatusSheet(model: model)
    }
    .focusable()
    .focusEffectDisabled()
    .focused($isFocused)
    .onAppear { isFocused = true }
    .onKeyPress(.space) {
      model.togglePlayback()
      return .handled
    }
    .onKeyPress("i") {
      model.setStartToPlayhead()
      return .handled
    }
    .onKeyPress("o") {
      model.setEndToPlayhead()
      return .handled
    }
    .task { await model.load() }
  }

  private var progressLine: some View {
    GeometryReader { proxy in
      let length = model.trimEnd - model.trimStart
      let progress = length > 0 ? ((model.currentTime - model.trimStart) / length).clamped(0, 1) : 0
      ZStack(alignment: .leading) {
        Rectangle().fill(.white.opacity(0.3))
        Rectangle()
          .fill(TrimSlider.progressGradient)
          .frame(width: proxy.size.width * progress)
      }
    }
    .frame(height: 3)
  }

  private var titleBar: some View {
    Text(model.url.deletingPathExtension().lastPathComponent)
      .font(.headline)
      .foregroundStyle(.white)
      .lineLimit(1)
      .padding(.horizontal, 80)
      .frame(maxWidth: .infinity)
      .frame(height: 38)
      .background(LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom))
  }

  private var trimControls: some View {
    HStack(spacing: 14) {
      Button(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill") {
        model.togglePlayback()
      }
      .labelStyle(.iconOnly)
      .font(.title2)
      .frame(width: 24)
      .contentTransition(.symbolEffect(.replace, options: .speed(3)))
      .help("Play or pause (Space)")

      Text(Timecode.short(model.currentTime - model.trimStart))
        .frame(width: 40, alignment: .leading)

      TrimSlider(
        start: $model.trimStart,
        end: $model.trimEnd,
        duration: model.duration,
        currentTime: model.currentTime,
        aspectRatio: model.aspectRatio,
        framePreviewer: model.framePreviewer,
        onScrub: model.scrub
      )
      .frame(height: 28)

      Text(Timecode.short(model.trimEnd - model.trimStart))
        .frame(width: 40, alignment: .trailing)

      if model.hasAudio {
        Button(model.isMuted ? "Unmute" : "Mute", systemImage: model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill") {
          model.isMuted.toggle()
        }
        .labelStyle(.iconOnly)
        .font(.title3)
        .frame(width: 24)
        .contentTransition(.symbolEffect(.replace, options: .speed(3)))
        .help(model.isMuted ? "Unmute" : "Mute")
      }
    }
    .buttonStyle(.plain)
    .foregroundStyle(.white)
    .font(.callout.monospacedDigit())
    .padding(.horizontal, 20)
    .frame(height: 56)
    .background(LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom))
  }

  private var exportBar: some View {
    HStack(spacing: 10) {
      Text("Size").foregroundStyle(.secondary).fixedSize()
      HStack(spacing: 2) {
        NumberField(value: model.width, onCommit: model.setWidth)
        NumberField(value: model.height, onCommit: model.setHeight)
      }
      Menu("\(model.scalePercent)%") {
        Picker("Scale", selection: Binding(get: { model.scalePercent }, set: { model.setScale($0) })) {
          ForEach(EditorModel.scalePresets, id: \.self) { percent in
            let size = model.scaledSize(percent)
            Text(verbatim: "\(size.width) x \(size.height) (\(percent == 100 ? "Original" : "\(percent)%"))").tag(percent)
          }
        }
        .pickerStyle(.inline)
        .labelsHidden()
      }
      .fixedSize()
      .help("Scale")

      Text("FPS").foregroundStyle(.secondary).fixedSize().padding(.leading, 6)
      NumberField(value: model.fps) { model.fps = $0.clamped(5, model.maximumFPS) }

      Spacer(minLength: 12)

      Picker("Format", selection: $model.format) {
        ForEach(ExportFormat.allCases) { Text($0.title).tag($0) }
      }
      .labelsHidden()
      .fixedSize()

      DestinationMenu(destination: $model.destination, contentType: model.format.contentType)

      Button("Convert", action: onConvert)
        .buttonStyle(.borderedProminent)
        .fixedSize()
        .keyboardShortcut("e")
        .help("Convert (⌘E)")
    }
    .padding(.horizontal, 14)
    .frame(height: Self.barHeight)
    .lineLimit(1)
    .background(.bar)
    .overlay(alignment: .top) { Divider() }
    .disabled(!model.isLoaded || model.isExporting)
  }

}

private struct ExportStatusSheet: View {
  let model: EditorModel

  var body: some View {
    VStack(spacing: 16) {
      switch model.exportState {
      case .idle:
        EmptyView()
      case .exporting(let progress):
        Text("Converting to \(model.format.title)…").font(.headline)
        ProgressView(value: progress)
        Text(progress.formatted(.percent.precision(.fractionLength(0))))
          .font(.callout.monospacedDigit())
          .foregroundStyle(.secondary)
        Button("Cancel", role: .cancel, action: model.cancelExport)
          .keyboardShortcut(.cancelAction)
      case let .finished(url, note):
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
          .resizable()
          .frame(width: 64, height: 64)
        VStack(spacing: 4) {
          Text(note ?? url.lastPathComponent)
            .font(.headline)
            .lineLimit(2)
            .multilineTextAlignment(.center)
          if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            Text(size.formatted(.byteCount(style: .file))).foregroundStyle(.secondary)
          }
        }
        HStack {
          if note == nil {
            Button("Copy") {
              NSPasteboard.general.clearContents()
              NSPasteboard.general.writeObjects([url as NSURL])
            }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
          }
          Button("Done", action: model.dismissExportResult).keyboardShortcut(.defaultAction)
        }
      case .failed(let message):
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 40))
          .foregroundStyle(.orange)
        Text("Conversion Failed").font(.headline)
        Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
        Button("OK", action: model.dismissExportResult).keyboardShortcut(.defaultAction)
      }
    }
    .padding(24)
    .frame(width: 340)
    .interactiveDismissDisabled(model.isExporting)
  }
}

private struct NumberField: View {
  let value: Int
  let onCommit: (Int) -> Void

  @State private var text = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    TextField("", text: $text)
      .textFieldStyle(.roundedBorder)
      .multilineTextAlignment(.center)
      .monospacedDigit()
      .frame(width: 58)
      .focused($isFocused)
      .onSubmit(commit)
      .onChange(of: isFocused) { if !isFocused { commit() } }
      .onChange(of: value, initial: true) { text = String(value) }
  }

  private func commit() {
    if let number = Int(text), number != value { onCommit(number) }
    text = String(value)
  }
}

enum Timecode {
  /// `m:ss`, as shown next to the trim bar.
  static func short(_ seconds: Double) -> String {
    let value = Int(max(0, seconds).rounded(.down))
    return String(format: "%d:%02d", value / 60, value % 60)
  }
}

struct PlayerView: NSViewRepresentable {
  let player: AVPlayer

  func makeNSView(context: Context) -> AVPlayerView {
    let view = AVPlayerView()
    view.player = player
    view.controlsStyle = .none
    view.videoGravity = .resizeAspect
    view.allowsVideoFrameAnalysis = false
    return view
  }

  func updateNSView(_ nsView: AVPlayerView, context: Context) {}
}
