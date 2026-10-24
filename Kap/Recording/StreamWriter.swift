import AVFoundation
import ScreenCaptureKit

/// Writes a stream's video, system audio and microphone samples to movie files, one file per segment.
///
/// Easy Kap writes the file itself rather than using `SCRecordingOutput`, because that output makes macOS add a
/// second stop button to the menu bar next to Easy Kap's own item.
///
/// Every method runs on `queue`, the queue the stream delivers samples on, so the writer needs no other locking.
nonisolated final class StreamWriter: NSObject, SCStreamOutput, @unchecked Sendable {
  let queue = DispatchQueue(label: "EasyKap.StreamWriter")

  private let videoSettings: [String: Any]
  private let recordsSystemAudio: Bool
  private let recordsMicrophone: Bool

  private var segment: Segment?
  /// The last complete frame, kept so a segment can start or end while the screen doesn't change.
  private var lastFrame: CMSampleBuffer?

  init(width: Int, height: Int, fps: Int, recordsSystemAudio: Bool, recordsMicrophone: Bool) {
    videoSettings = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [
        // Screen content is mostly sharp text, which blurs at the encoder's default bit rate.
        AVVideoAverageBitRateKey: max(width * height * fps / 5, 2_000_000),
        AVVideoExpectedSourceFrameRateKey: fps
      ]
    ]
    self.recordsSystemAudio = recordsSystemAudio
    self.recordsMicrophone = recordsMicrophone
  }

  func startSegment(at url: URL) throws {
    try queue.sync {
      let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
      let video = Self.input(.video, settings: videoSettings)
      writer.add(video)
      // Separate tracks, like SCRecordingOutput wrote; the exporter mixes them.
      let systemAudio = recordsSystemAudio ? Self.input(.audio, settings: Self.audioSettings(channels: 2)) : nil
      let microphone = recordsMicrophone ? Self.input(.audio, settings: Self.audioSettings(channels: 1)) : nil
      for input in [systemAudio, microphone].compactMap(\.self) { writer.add(input) }
      guard writer.startWriting() else { throw writer.error ?? StreamWriterError.cannotWrite }
      segment = Segment(writer: writer, video: video, systemAudio: systemAudio, microphone: microphone)
    }
  }

  /// Finishes the current segment's file. A segment that received no samples leaves no file.
  func finishSegment() async throws {
    let finishing = queue.sync { () -> Segment? in
      defer { segment = nil }
      guard let segment, let start = segment.start else {
        segment?.writer.cancelWriting()
        return nil
      }
      // Holds the last frame on screen until the segment's last sample, so a still screen keeps its length.
      if let lastFrame, segment.lastTime > segment.lastVideoTime ?? start {
        segment.appendVideo(lastFrame, at: segment.lastTime)
      }
      segment.writer.endSession(atSourceTime: segment.lastTime)
      return segment
    }
    guard let finishing else { return }
    await withCheckedContinuation { continuation in
      queue.async {
        finishing.writer.finishWriting { continuation.resume() }
      }
    }
    if finishing.writer.status == .failed { throw finishing.writer.error ?? StreamWriterError.cannotWrite }
  }

  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard sampleBuffer.isValid else { return }
    switch type {
    case .screen:
      guard Self.isCompleteFrame(sampleBuffer) else { return }
      lastFrame = sampleBuffer
      segment?.appendVideo(sampleBuffer, at: sampleBuffer.presentationTimeStamp)
    case .audio:
      segment?.appendAudio(sampleBuffer, to: segment?.systemAudio, lastFrame: lastFrame)
    case .microphone:
      segment?.appendAudio(sampleBuffer, to: segment?.microphone, lastFrame: lastFrame)
    @unknown default:
      return
    }
  }

  /// ScreenCaptureKit also delivers idle and blank frames, which carry no image.
  private static func isCompleteFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
    guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
          let rawStatus = attachments.first?[.status] as? Int else { return false }
    return SCFrameStatus(rawValue: rawStatus) == .complete
  }

  private static func input(_ mediaType: AVMediaType, settings: [String: Any]) -> AVAssetWriterInput {
    let input = AVAssetWriterInput(mediaType: mediaType, outputSettings: settings)
    input.expectsMediaDataInRealTime = true
    return input
  }

  private static func audioSettings(channels: Int) -> [String: Any] {
    [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: 48_000,
      AVNumberOfChannelsKey: channels,
      AVEncoderBitRateKey: 128_000 * channels
    ]
  }
}

nonisolated enum StreamWriterError: LocalizedError {
  case cannotWrite

  var errorDescription: String? { "The recording could not be written." }
}

/// Only used on `StreamWriter.queue`.
nonisolated private final class Segment: @unchecked Sendable {
  let writer: AVAssetWriter
  let video: AVAssetWriterInput
  let systemAudio: AVAssetWriterInput?
  let microphone: AVAssetWriterInput?
  /// When the writer's session started: the first sample's time.
  private(set) var start: CMTime?
  /// The latest time any sample reached, where the file ends.
  private(set) var lastTime = CMTime.zero
  private(set) var lastVideoTime: CMTime?

  init(writer: AVAssetWriter, video: AVAssetWriterInput, systemAudio: AVAssetWriterInput?, microphone: AVAssetWriterInput?) {
    self.writer = writer
    self.video = video
    self.systemAudio = systemAudio
    self.microphone = microphone
  }

  func appendVideo(_ frame: CMSampleBuffer, at time: CMTime) {
    begin(at: time)
    // Frames must move forward in time; a late frame from before the session started is dropped.
    guard let start, time >= start, lastVideoTime.map({ time > $0 }) ?? true,
          video.isReadyForMoreMediaData,
          let retimed = try? CMSampleBuffer(copying: frame, withNewTiming: [
            CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: time, decodeTimeStamp: .invalid)
          ]) else { return }
    if video.append(retimed) {
      lastVideoTime = time
      lastTime = max(lastTime, time)
    }
  }

  func appendAudio(_ sampleBuffer: CMSampleBuffer, to input: AVAssetWriterInput?, lastFrame: CMSampleBuffer?) {
    guard let input else { return }
    let time = sampleBuffer.presentationTimeStamp
    if start == nil {
      // A segment that starts with sound on a still screen shows the frame already on screen.
      guard let lastFrame else { return }
      appendVideo(lastFrame, at: time)
    }
    guard let start, time >= start, input.isReadyForMoreMediaData else { return }
    if input.append(sampleBuffer) { lastTime = max(lastTime, time + sampleBuffer.duration) }
  }

  private func begin(at time: CMTime) {
    guard start == nil else { return }
    writer.startSession(atSourceTime: time)
    start = time
    lastTime = time
  }
}
