import AVFoundation

nonisolated enum SegmentMergerError: LocalizedError {
  case emptyRecording
  case cannotCreateExportSession

  var errorDescription: String? {
    switch self {
    case .emptyRecording: "Nothing was recorded."
    case .cannotCreateExportSession: "The recording could not be saved."
    }
  }
}

/// Joins the segments of a paused recording back to back without re-encoding.
nonisolated enum SegmentMerger {
  @concurrent
  static func merge(_ segments: [URL], into destination: URL) async throws {
    try? FileManager.default.removeItem(at: destination)

    var playable: [(url: URL, duration: CMTime)] = []
    for url in segments {
      // A segment can be missing or empty when the screen didn't change between resume and pause.
      if let duration = try? await AVURLAsset(url: url).load(.duration), duration.seconds > 0 {
        playable.append((url, duration))
      }
    }
    guard !playable.isEmpty else { throw SegmentMergerError.emptyRecording }

    if playable.count == 1 {
      try FileManager.default.moveItem(at: playable[0].url, to: destination)
      return
    }

    let composition = AVMutableComposition()
    var compositionTracks: [AVMediaType: [AVMutableCompositionTrack]] = [:]
    var cursor = CMTime.zero
    for (url, duration) in playable {
      let asset = AVURLAsset(url: url)
      for mediaType in [AVMediaType.video, .audio] {
        // Segments share one stream configuration, so their tracks line up by index.
        for (index, track) in try await asset.loadTracks(withMediaType: mediaType).enumerated() {
          if compositionTracks[mediaType, default: []].count <= index,
             let newTrack = composition.addMutableTrack(withMediaType: mediaType, preferredTrackID: kCMPersistentTrackID_Invalid) {
            if mediaType == .video { newTrack.preferredTransform = try await track.load(.preferredTransform) }
            compositionTracks[mediaType, default: []].append(newTrack)
          }
          let timeRange = try await track.load(.timeRange)
          try compositionTracks[mediaType]?[index].insertTimeRange(timeRange, of: track, at: cursor + timeRange.start)
        }
      }
      cursor = CMTimeAdd(cursor, duration)
    }

    guard let joined = composition.copy() as? AVComposition,
          let session = AVAssetExportSession(asset: joined, presetName: AVAssetExportPresetPassthrough) else {
      throw SegmentMergerError.cannotCreateExportSession
    }
    try await session.export(to: destination, as: .mov)
  }
}
