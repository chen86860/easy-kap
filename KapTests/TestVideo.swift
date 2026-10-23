import AVFoundation
import Testing

/// Writes a 2 second, 320×240, 30 FPS H.264 movie once per test run.
actor TestVideo {
  static let shared = TestVideo()
  private var cached: URL?
  private var cachedWithAudio: URL?

  func url() async throws -> URL {
    if let cached { return cached }
    let url = FileManager.default.temporaryDirectory.appending(path: "kap-fixture-\(UUID().uuidString).mov")
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: 320,
      AVVideoHeightKey: 240
    ])
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: 320,
      kCVPixelBufferHeightKey as String: 240
    ])
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    for frame in 0..<60 {
      while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
      var buffer: CVPixelBuffer?
      CVPixelBufferPoolCreatePixelBuffer(nil, try #require(adaptor.pixelBufferPool), &buffer)
      let pixelBuffer = try #require(buffer)
      CVPixelBufferLockBaseAddress(pixelBuffer, [])
      let base = try #require(CVPixelBufferGetBaseAddress(pixelBuffer))
      memset(base, Int32(frame * 4 % 256), CVPixelBufferGetDataSize(pixelBuffer))
      CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
      adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
    }
    input.markAsFinished()
    await writer.finishWriting()
    try #require(writer.status == .completed)
    cached = url
    return url
  }

  /// The video plus two audio tracks, like a recording with system audio and microphone.
  func urlWithTwoAudioTracks() async throws -> URL {
    if let cachedWithAudio { return cachedWithAudio }
    let audioURL = FileManager.default.temporaryDirectory.appending(path: "kap-fixture-\(UUID().uuidString).caf")
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 96_000))
    buffer.frameLength = 96_000
    let samples = try #require(buffer.floatChannelData?[0])
    for index in 0..<96_000 { samples[index] = sin(Float(index) * 2 * .pi * 440 / 48_000) * 0.2 }
    do {
      let file = try AVAudioFile(forWriting: audioURL, settings: format.settings)
      try file.write(from: buffer)
    }

    let video = AVURLAsset(url: try await url())
    let audio = AVURLAsset(url: audioURL)
    let composition = AVMutableComposition()
    let range = CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600))
    let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    try videoTrack?.insertTimeRange(range, of: try #require(try await video.loadTracks(withMediaType: .video).first), at: .zero)
    let sourceAudio = try #require(try await audio.loadTracks(withMediaType: .audio).first)
    for _ in 0..<2 {
      let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
      try track?.insertTimeRange(range, of: sourceAudio, at: .zero)
    }

    let destination = FileManager.default.temporaryDirectory.appending(path: "kap-fixture-audio-\(UUID().uuidString).mov")
    let joined = try #require(composition.copy() as? AVComposition)
    let session = try #require(AVAssetExportSession(asset: joined, presetName: AVAssetExportPresetPassthrough))
    try await session.export(to: destination, as: .mov)
    cachedWithAudio = destination
    return destination
  }
}
