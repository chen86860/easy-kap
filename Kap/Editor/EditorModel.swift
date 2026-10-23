import AppKit
import AVFoundation
import Observation

@Observable
final class EditorModel {
  enum ExportState {
    case idle
    case exporting(progress: Double)
    /// `note` describes what happened after converting, e.g. "Copied to Clipboard".
    case finished(URL, note: String?)
    case failed(String)
  }

  enum Destination: Hashable {
    case saveToDisk
    case copyToClipboard
    case openWith(URL)

    var title: String {
      switch self {
      case .saveToDisk: "Save to Disk"
      case .copyToClipboard: "Copy to Clipboard"
      case .openWith(let application): OpenWithApplications.name(of: application)
      }
    }
  }

  let url: URL
  let player: AVPlayer

  private(set) var isLoaded = false
  private(set) var loadError: String?
  private(set) var duration: Double = 0
  private(set) var naturalSize = CGSize(width: 1, height: 1)
  private(set) var originalFPS = 30
  private(set) var hasAudio = false
  private(set) var currentTime: Double = 0
  private(set) var isPlaying = false

  var trimStart: Double = 0 {
    didSet { if isLoaded, trimStart != oldValue { seek(to: trimStart) } }
  }
  var trimEnd: Double = 0 {
    didSet { if isLoaded, trimEnd != oldValue { seek(to: trimEnd) } }
  }
  var format: ExportFormat {
    didSet {
      fps = min(fps, maximumFPS)
      Preferences.shared.lastExportFormat = format
    }
  }
  private(set) var width = 0
  private(set) var height = 0
  var fps = 30
  var isMuted = false {
    didSet { player.isMuted = isMuted }
  }
  var destination = Destination.saveToDisk
  private(set) var exportState = ExportState.idle
  /// Whether anything was exported from this window, after which closing it loses nothing.
  private(set) var hasExported = false

  @ObservationIgnored let framePreviewer: FramePreviewer
  @ObservationIgnored private var timeObserver: Any?
  @ObservationIgnored private var endObserver: (any NSObjectProtocol)?
  @ObservationIgnored private var exportTask: Task<Void, Never>?

  var maximumFPS: Int { min(originalFPS, format.maximumFPS) }
  var aspectRatio: Double { naturalSize.width / naturalSize.height }
  var isShowingExportStatus: Bool {
    if case .idle = exportState { return false }
    return true
  }
  var isExporting: Bool {
    if case .exporting = exportState { return true }
    return false
  }

  init(url: URL) {
    self.url = url
    player = AVPlayer(url: url)
    framePreviewer = FramePreviewer(url: url)
    format = Preferences.shared.lastExportFormat
  }

  func load() async {
    let asset = AVURLAsset(url: url)
    do {
      guard let track = try await asset.loadTracks(withMediaType: .video).first else {
        throw ExportError.noVideoTrack
      }
      let (size, transform, frameRate) = try await track.load(.naturalSize, .preferredTransform, .nominalFrameRate)
      let oriented = CGRect(origin: .zero, size: size).applying(transform).size
      naturalSize = CGSize(width: abs(oriented.width), height: abs(oriented.height))
      duration = try await asset.load(.duration).seconds
      hasAudio = try await !asset.loadTracks(withMediaType: .audio).isEmpty
      originalFPS = max(1, Int(frameRate.rounded()))
    } catch {
      loadError = error.localizedDescription
      return
    }

    width = Int(naturalSize.width)
    height = Int(naturalSize.height)
    fps = maximumFPS
    trimEnd = duration
    isLoaded = true
    startObservingTime()
    player.play()
  }

  // MARK: Size

  func setWidth(_ value: Int) {
    width = value.clamped(16, Int(naturalSize.width))
    height = max(1, Int((Double(width) / aspectRatio).rounded()))
  }

  func setHeight(_ value: Int) {
    height = value.clamped(16, Int(naturalSize.height))
    width = max(1, Int((Double(height) * aspectRatio).rounded()))
  }

  static let scalePresets = [100, 75, 50, 33, 25, 20, 10]

  /// The size `setScale(_:)` produces, for labelling the presets.
  func scaledSize(_ percent: Int) -> (width: Int, height: Int) {
    let width = Int((naturalSize.width * Double(percent) / 100).rounded())
    return (width, max(1, Int((Double(width) / aspectRatio).rounded())))
  }

  func setScale(_ percent: Int) {
    setWidth(scaledSize(percent).width)
  }

  var scalePercent: Int {
    Int((Double(width) / naturalSize.width * 100).rounded())
  }

  // MARK: Playback

  /// Tracks the playhead and loops playback inside the trimmed range.
  private func startObservingTime() {
    // Reaching the end of the file pauses the player, so the trim-range check below never sees it; restart here.
    endObserver = NotificationCenter.default.addObserver(
      forName: AVPlayerItem.didPlayToEndTimeNotification,
      object: player.currentItem,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.seek(to: self.trimStart)
        self.player.play()
      }
    }

    let interval = CMTime(value: 1, timescale: 60)
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.currentTime = time.seconds
        self.isPlaying = self.player.timeControlStatus != .paused
        if self.isPlaying, time.seconds >= self.trimEnd || time.seconds < self.trimStart - 0.05 {
          self.seek(to: self.trimStart)
        }
      }
    }
  }

  func togglePlayback() {
    if isPlaying {
      player.pause()
    } else {
      if currentTime >= trimEnd - 0.05 || currentTime < trimStart { seek(to: trimStart) }
      player.play()
    }
    isPlaying.toggle()
  }

  func scrub(to seconds: Double) {
    player.pause()
    isPlaying = false
    currentTime = seconds.clamped(trimStart, trimEnd)
    seek(to: currentTime)
  }

  func setStartToPlayhead() {
    trimStart = min(currentTime, trimEnd - 0.1).clamped(0, duration)
  }

  func setEndToPlayhead() {
    trimEnd = max(currentTime, trimStart + 0.1).clamped(0, duration)
  }

  private func seek(to seconds: Double) {
    player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
  }

  // MARK: Export

  var exportOptions: ExportOptions {
    ExportOptions(
      format: format,
      start: trimStart,
      end: trimEnd,
      width: width,
      height: height,
      fps: fps,
      isMuted: isMuted || !hasAudio,
      loops: Preferences.shared.loopExports
    )
  }

  func export(to destination: URL) {
    let options = exportOptions
    let source = url
    let target = self.destination
    exportState = .exporting(progress: 0)
    exportTask = Task {
      do {
        try await Exporter.export(source: source, destination: destination, options: options) { progress in
          Task { @MainActor in
            if self.isExporting { self.exportState = .exporting(progress: progress) }
          }
        }
        hasExported = true
        exportState = .finished(destination, note: await deliver(destination, to: target))
      } catch is CancellationError {
        exportState = .idle
      } catch {
        exportState = .failed(error.localizedDescription)
      }
    }
  }

  private func deliver(_ file: URL, to target: Destination) async -> String? {
    switch target {
    case .saveToDisk:
      return nil
    case .copyToClipboard:
      NSPasteboard.general.clearContents()
      NSPasteboard.general.writeObjects([file as NSURL])
      return "Copied to Clipboard"
    case .openWith(let application):
      do {
        try await NSWorkspace.shared.open([file], withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration())
        return "Opened in \(OpenWithApplications.name(of: application))"
      } catch {
        return error.localizedDescription
      }
    }
  }

  func cancelExport() {
    exportTask?.cancel()
  }

  func dismissExportResult() {
    exportState = .idle
  }

  func tearDown() {
    exportTask?.cancel()
    player.pause()
    if let timeObserver { player.removeTimeObserver(timeObserver) }
    timeObserver = nil
    if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    endObserver = nil
  }
}
