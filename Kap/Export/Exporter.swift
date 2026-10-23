import AVFoundation
import CoreImage.CIFilterBuiltins
import ImageIO

nonisolated enum ExportError: LocalizedError {
  case noVideoTrack
  case cannotCreateExportSession
  case cannotCreateImageDestination
  case cannotFinalizeImage

  var errorDescription: String? {
    switch self {
    case .noVideoTrack: "The recording has no video track."
    case .cannotCreateExportSession: "The video encoder could not be started."
    case .cannotCreateImageDestination, .cannotFinalizeImage: "The animated image could not be written."
    }
  }
}

/// Converts a recording using only system frameworks: VideoToolbox (through AVFoundation) for video and ImageIO for animated images.
nonisolated enum Exporter {
  @concurrent
  static func export(
    source: URL,
    destination: URL,
    options: ExportOptions,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws {
    try? FileManager.default.removeItem(at: destination)
    let asset = AVURLAsset(url: source)
    do {
      if options.format.isVideo {
        try await exportVideo(asset: asset, destination: destination, options: options, progress: progress)
      } else {
        try await exportAnimatedImage(asset: asset, destination: destination, options: options, progress: progress)
      }
    } catch {
      try? FileManager.default.removeItem(at: destination)
      throw error
    }
  }

  @concurrent
  private static func exportVideo(
    asset: AVURLAsset,
    destination: URL,
    options: ExportOptions,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws {
    guard let sourceVideo = try await asset.loadTracks(withMediaType: .video).first else {
      throw ExportError.noVideoTrack
    }
    let timeRange = CMTimeRange(
      start: CMTime(seconds: options.start, preferredTimescale: 600),
      end: CMTime(seconds: options.end, preferredTimescale: 600)
    )

    let composition = AVMutableComposition()
    let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    try video?.insertTimeRange(timeRange, of: sourceVideo, at: .zero)
    video?.preferredTransform = try await sourceVideo.load(.preferredTransform)
    let audio = options.isMuted ? nil : try await audioSource(of: asset, timeRange: timeRange)
    defer { if let url = audio?.temporaryURL { try? FileManager.default.removeItem(at: url) } }
    if let audio {
      let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
      try track?.insertTimeRange(audio.timeRange, of: audio.track, at: .zero)
    }

    // Each async AVFoundation call takes ownership of the asset it is given, so the session and the
    // video composition each get their own immutable copy.
    guard let trimmed = composition.copy() as? AVComposition, let compositionSource = composition.copy() as? AVComposition else {
      throw ExportError.cannotCreateExportSession
    }
    let renderSize = options.outputSize
    let videoComposition = try await AVMutableVideoComposition.videoComposition(with: compositionSource) { request in
      let source = request.sourceImage
      let scale = CIFilter.lanczosScaleTransform()
      scale.inputImage = source
      scale.scale = Float(renderSize.height / source.extent.height)
      scale.aspectRatio = Float((renderSize.width / source.extent.width) / (renderSize.height / source.extent.height))
      let output = scale.outputImage?.cropped(to: CGRect(origin: .zero, size: renderSize)) ?? source
      request.finish(with: output, context: nil)
    }
    videoComposition.renderSize = renderSize
    videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(options.fps))

    let preset = options.format == .hevc ? AVAssetExportPresetHEVCHighestQuality : AVAssetExportPresetHighestQuality
    guard let session = AVAssetExportSession(asset: trimmed, presetName: preset) else {
      throw ExportError.cannotCreateExportSession
    }
    session.videoComposition = videoComposition
    session.shouldOptimizeForNetworkUse = true

    let states = session.states(updateInterval: 0.1)
    let monitor = Task {
      for await state in states {
        if case .exporting(let exportProgress) = state {
          progress(exportProgress.fractionCompleted)
        }
      }
    }
    defer { monitor.cancel() }
    try await session.export(to: destination, as: .mp4)
    progress(1)
  }

  /// The single audio track to export. System audio and the microphone are recorded as separate tracks, but players
  /// only play the first audio track of an MP4, so several tracks are mixed into a temporary file first.
  @concurrent
  private static func audioSource(of asset: AVURLAsset, timeRange: CMTimeRange) async throws -> AudioSource? {
    let tracks = try await asset.loadTracks(withMediaType: .audio)
    guard tracks.count > 1 else {
      return tracks.first.map { AudioSource(asset: asset, track: $0, timeRange: timeRange, temporaryURL: nil) }
    }
    let url = try await mixDown(tracks, of: asset, timeRange: timeRange)
    let mixedAsset = AVURLAsset(url: url)
    guard let mixed = try await mixedAsset.loadTracks(withMediaType: .audio).first else {
      try? FileManager.default.removeItem(at: url)
      return nil
    }
    return AudioSource(asset: mixedAsset, track: mixed, timeRange: try await mixed.load(.timeRange), temporaryURL: url)
  }

  private struct AudioSource {
    /// Kept alive because a track only holds a weak reference to its asset.
    let asset: AVURLAsset
    let track: AVAssetTrack
    let timeRange: CMTimeRange
    let temporaryURL: URL?
  }

  @concurrent
  private static func mixDown(_ tracks: [AVAssetTrack], of asset: AVURLAsset, timeRange: CMTimeRange) async throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "kap-mixdown-\(UUID().uuidString).m4a")
    let reader = try AVAssetReader(asset: asset)
    reader.timeRange = timeRange
    let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: 48_000,
      AVNumberOfChannelsKey: 2,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false
    ])
    reader.add(output)

    let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
    let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: 48_000,
      AVNumberOfChannelsKey: 2,
      AVEncoderBitRateKey: 192_000
    ])
    input.expectsMediaDataInRealTime = false
    writer.add(input)

    guard reader.startReading(), writer.startWriting() else {
      throw reader.error ?? writer.error ?? ExportError.cannotCreateExportSession
    }
    writer.startSession(atSourceTime: timeRange.start)
    while let buffer = output.copyNextSampleBuffer() {
      while !input.isReadyForMoreMediaData {
        try await Task.sleep(for: .milliseconds(2))
      }
      input.append(buffer)
    }
    input.markAsFinished()
    await writer.finishWriting()
    if let error = reader.error ?? writer.error {
      try? FileManager.default.removeItem(at: url)
      throw error
    }
    return url
  }

  @concurrent
  private static func exportAnimatedImage(
    asset: AVURLAsset,
    destination: URL,
    options: ExportOptions,
    progress: @Sendable (Double) -> Void
  ) async throws {
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    generator.maximumSize = options.outputSize
    defer { generator.cancelAllCGImageGeneration() }

    let times = options.frameTimes.map { CMTime(seconds: $0, preferredTimescale: 600) }
    guard let image = CGImageDestinationCreateWithURL(
      destination as CFURL,
      options.format.contentType.identifier as CFString,
      times.count,
      nil
    ) else {
      throw ExportError.cannotCreateImageDestination
    }
    CGImageDestinationSetProperties(image, options.format.fileProperties(loops: options.loops) as CFDictionary)
    let frameProperties = options.format.frameProperties(delay: 1 / Double(options.fps)) as CFDictionary

    var completed = 0
    for await result in generator.images(for: times) {
      try Task.checkCancellation()
      CGImageDestinationAddImage(image, try result.image, frameProperties)
      completed += 1
      progress(Double(completed) / Double(times.count))
    }
    try Task.checkCancellation()
    guard CGImageDestinationFinalize(image) else {
      throw ExportError.cannotFinalizeImage
    }
  }
}
