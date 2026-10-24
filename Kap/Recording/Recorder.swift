import AVFoundation
import ScreenCaptureKit

nonisolated enum RecorderError: LocalizedError {
  case screenRecordingDenied
  case microphoneDenied
  case displayNotFound
  case notRecording

  var errorDescription: String? {
    switch self {
    case .screenRecordingDenied: "Easy Kap needs permission to record your screen."
    case .microphoneDenied: "Easy Kap needs permission to use the microphone."
    case .displayNotFound: "The selected display is no longer available."
    case .notRecording: "No recording is in progress."
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .microphoneDenied: "Allow Easy Kap in System Settings → Privacy & Security → Microphone, or turn off microphone recording."
    case .screenRecordingDenied, .displayNotFound, .notRecording: nil
    }
  }

  var settingsURL: URL? {
    switch self {
    case .microphoneDenied: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    case .screenRecordingDenied, .displayNotFound, .notRecording: nil
    }
  }
}

nonisolated struct RecordingSettings: Sendable {
  var fps: Int
  var showsCursor: Bool
  var showsClicks: Bool
  var recordsMicrophone: Bool
  var recordsSystemAudio: Bool
  var audioDeviceID: String?

  func streamConfiguration(capturing rect: CGRect, pointPixelScale: CGFloat) -> SCStreamConfiguration {
    let configuration = SCStreamConfiguration()
    configuration.sourceRect = rect
    configuration.width = Int(rect.width * pointPixelScale).roundedDownToEven
    configuration.height = Int(rect.height * pointPixelScale).roundedDownToEven
    configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
    configuration.showsCursor = showsCursor
    configuration.showMouseClicks = showsCursor && showsClicks
    configuration.capturesAudio = recordsSystemAudio
    configuration.excludesCurrentProcessAudio = true
    configuration.captureMicrophone = recordsMicrophone
    configuration.microphoneCaptureDeviceID = audioDeviceID
    return configuration
  }
}

/// Records a region of a display with ScreenCaptureKit and writes it with `StreamWriter`.
///
/// Pausing finishes the current segment file while the stream keeps running, resuming starts a new one,
/// and stopping joins the segments into one movie.
final class Recorder {
  private var stream: SCStream?
  private var writer: StreamWriter?
  private var segmentURL: URL?
  private var finishedSegments: [URL] = []
  private var sessionDirectory: URL?
  private var streamDelegate: StreamDelegate?
  /// Set when the stream ended on its own, for example from the system's menu bar stop button.
  private var isStreamStopped = false
  /// Set while `stop()` runs, so a second stop request, from either menu bar button, does nothing.
  private(set) var isStopping = false

  /// Called when the system stops the capture, so the recording can be saved as if the user had stopped it.
  var onStoppedBySystem: (() -> Void)?

  var isRecording: Bool { stream != nil }
  var isPaused: Bool { stream != nil && segmentURL == nil }

  func start(displayID: CGDirectDisplayID, rect: CGRect, settings: RecordingSettings) async throws {
    guard stream == nil else { return }

    if settings.recordsMicrophone, await !AVCaptureDevice.requestAccess(for: .audio) {
      throw RecorderError.microphoneDenied
    }

    // Shows the system prompt the first time; afterwards the user has to allow it in System Settings.
    guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
      throw RecorderError.screenRecordingDenied
    }

    let content: SCShareableContent
    do {
      content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    } catch {
      throw RecorderError.screenRecordingDenied
    }
    guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
      throw RecorderError.displayNotFound
    }

    let ownApplications = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
    let filter = SCContentFilter(display: display, excludingApplications: ownApplications, exceptingWindows: [])
    let configuration = settings.streamConfiguration(capturing: rect, pointPixelScale: CGFloat(filter.pointPixelScale))

    let directory = Self.recordingsDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let streamDelegate = StreamDelegate { [weak self] in
      Task { @MainActor in self?.handleStreamStopped() }
    }
    let stream = SCStream(filter: filter, configuration: configuration, delegate: streamDelegate)
    let writer = StreamWriter(
      width: configuration.width,
      height: configuration.height,
      fps: settings.fps,
      recordsSystemAudio: settings.recordsSystemAudio,
      recordsMicrophone: settings.recordsMicrophone
    )
    self.streamDelegate = streamDelegate
    self.stream = stream
    self.writer = writer
    sessionDirectory = directory
    do {
      try stream.addStreamOutput(writer, type: .screen, sampleHandlerQueue: writer.queue)
      if settings.recordsSystemAudio { try stream.addStreamOutput(writer, type: .audio, sampleHandlerQueue: writer.queue) }
      if settings.recordsMicrophone { try stream.addStreamOutput(writer, type: .microphone, sampleHandlerQueue: writer.queue) }
      try startSegment()
      try await stream.startCapture()
    } catch {
      reset()
      throw error
    }
  }

  func pause() async throws {
    guard isRecording, !isPaused else { return }
    try await finishSegment()
  }

  func resume() throws {
    guard isPaused else { return }
    try startSegment()
  }

  func stop() async throws -> URL {
    guard let stream, let sessionDirectory, !isStopping else { throw RecorderError.notRecording }
    isStopping = true
    defer { reset() }
    try await finishSegment()
    // The segment file is already finished, so a stream that the system stopped meanwhile changes nothing.
    // stopCapture then fails with "invalid parameter", which isn't worth reporting.
    if !isStreamStopped { try? await stream.stopCapture() }

    let destination = Self.recordingsDirectory.appending(path: FileNaming.defaultName(fileExtension: "mov"))
    try await SegmentMerger.merge(finishedSegments, into: destination)
    try? FileManager.default.removeItem(at: sessionDirectory)
    return destination
  }

  private func startSegment() throws {
    guard let writer, let sessionDirectory else { throw RecorderError.notRecording }
    let url = sessionDirectory.appending(path: "segment-\(finishedSegments.count).mov")
    try writer.startSegment(at: url)
    segmentURL = url
  }

  private func finishSegment() async throws {
    guard let writer, let segmentURL else { return }
    // Registered before awaiting so a stop that races a pause still includes this segment.
    self.segmentURL = nil
    finishedSegments.append(segmentURL)
    try await writer.finishSegment()
  }

  private func handleStreamStopped() {
    guard stream != nil, !isStreamStopped else { return }
    isStreamStopped = true
    // Already stopping, from Easy Kap's own button: this is the end of that stop, not a new request.
    if !isStopping { onStoppedBySystem?() }
  }

  private func reset() {
    isStopping = false
    stream = nil
    writer = nil
    streamDelegate = nil
    isStreamStopped = false
    segmentURL = nil
    finishedSegments = []
    sessionDirectory = nil
  }

  static var recordingsDirectory: URL {
    URL.cachesDirectory.appending(path: Bundle.main.bundleIdentifier ?? "EasyKap").appending(path: "Recordings")
  }
}

nonisolated private final class StreamDelegate: NSObject, SCStreamDelegate, Sendable {
  private let onStop: @Sendable () -> Void

  init(onStop: @escaping @Sendable () -> Void) {
    self.onStop = onStop
  }

  func stream(_ stream: SCStream, didStopWithError error: any Error) {
    onStop()
  }
}
