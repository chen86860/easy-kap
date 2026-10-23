import AVFoundation

/// Generates small frames for the trim bar's hover preview, off the main actor.
actor FramePreviewer {
  private let generator: AVAssetImageGenerator

  init(url: URL) {
    generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 360, height: 360)
    // A frame within 1/30s is close enough for a preview and much faster than an exact one.
    let tolerance = CMTime(value: 1, timescale: 30)
    generator.requestedTimeToleranceBefore = tolerance
    generator.requestedTimeToleranceAfter = tolerance
  }

  /// Cancels any request still in flight, so quick pointer movement doesn't queue up stale frames.
  func frame(at seconds: Double) async -> CGImage? {
    generator.cancelAllCGImageGeneration()
    return await withCheckedContinuation { continuation in
      generator.generateCGImageAsynchronously(for: CMTime(seconds: seconds, preferredTimescale: 600)) { image, _, _ in
        continuation.resume(returning: image)
      }
    }
  }
}
