import AVFoundation
import ScreenCaptureKit
import Synchronization

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

/// Records a region of a display with ScreenCaptureKit's `SCRecordingOutput`.
///
/// `SCRecordingOutput` can't pause, so pausing finishes the current segment while the stream keeps running,
/// resuming attaches a new output, and stopping joins the segments into one movie.
final class Recorder {
  private struct Segment {
    let output: SCRecordingOutput
    let delegate: RecordingDelegate
    let url: URL
  }

  private var stream: SCStream?
  private var segment: Segment?
  private var finishedSegments: [URL] = []
  private var sessionDirectory: URL?

  var isRecording: Bool { stream != nil }
  var isPaused: Bool { stream != nil && segment == nil }

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
    let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
    self.stream = stream
    sessionDirectory = directory
    do {
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
    guard let stream, let sessionDirectory else { throw RecorderError.notRecording }
    defer { reset() }
    try await finishSegment()
    try await stream.stopCapture()

    let destination = Self.recordingsDirectory.appending(path: FileNaming.defaultName(fileExtension: "mov"))
    try await SegmentMerger.merge(finishedSegments, into: destination)
    try? FileManager.default.removeItem(at: sessionDirectory)
    return destination
  }

  private func startSegment() throws {
    guard let stream, let sessionDirectory else { throw RecorderError.notRecording }
    let url = sessionDirectory.appending(path: "segment-\(finishedSegments.count).mov")
    let configuration = SCRecordingOutputConfiguration()
    configuration.outputURL = url
    configuration.outputFileType = .mov
    configuration.videoCodecType = .h264

    let delegate = RecordingDelegate()
    let output = SCRecordingOutput(configuration: configuration, delegate: delegate)
    try stream.addRecordingOutput(output)
    segment = Segment(output: output, delegate: delegate, url: url)
  }

  private func finishSegment() async throws {
    guard let stream, let segment else { return }
    // Registered before awaiting so a stop that races a pause still includes this segment.
    self.segment = nil
    finishedSegments.append(segment.url)
    try stream.removeRecordingOutput(segment.output)
    try await segment.delegate.waitUntilFinished(timeout: .seconds(5))
  }

  private func reset() {
    stream = nil
    segment = nil
    finishedSegments = []
    sessionDirectory = nil
  }

  static var recordingsDirectory: URL {
    URL.cachesDirectory.appending(path: Bundle.main.bundleIdentifier ?? "EasyKap").appending(path: "Recordings")
  }
}

nonisolated private final class RecordingDelegate: NSObject, SCRecordingOutputDelegate, Sendable {
  private struct State {
    var result: Result<Void, any Error>?
    var continuation: CheckedContinuation<Void, any Error>?
  }

  private let state = Mutex(State())

  func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
    complete(.success(()))
  }

  func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: any Error) {
    complete(.failure(error))
  }

  /// Waits for the file to be finalized. Falls back to success after `timeout` because the callback is not guaranteed.
  func waitUntilFinished(timeout: Duration) async throws {
    let timeoutTask = Task { [weak self] in
      try await Task.sleep(for: timeout)
      self?.complete(.success(()))
    }
    defer { timeoutTask.cancel() }
    try await withCheckedThrowingContinuation { continuation in
      let result = state.withLock { state -> Result<Void, any Error>? in
        if let result = state.result { return result }
        state.continuation = continuation
        return nil
      }
      if let result { continuation.resume(with: result) }
    }
  }

  private func complete(_ result: Result<Void, any Error>) {
    let continuation = state.withLock { state -> CheckedContinuation<Void, any Error>? in
      guard state.result == nil else { return nil }
      state.result = result
      defer { state.continuation = nil }
      return state.continuation
    }
    continuation?.resume(with: result)
  }
}
