import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
  case gif
  case mp4
  case hevc
  case apng

  var id: Self { self }

  var title: String {
    switch self {
    case .gif: "GIF"
    case .mp4: "MP4 (H.264)"
    case .hevc: "MP4 (HEVC)"
    case .apng: "APNG"
    }
  }

  var fileExtension: String {
    switch self {
    case .gif: "gif"
    case .mp4, .hevc: "mp4"
    case .apng: "png"
    }
  }

  var contentType: UTType {
    switch self {
    case .gif: .gif
    case .mp4, .hevc: .mpeg4Movie
    case .apng: .png
    }
  }

  var isVideo: Bool { self == .mp4 || self == .hevc }

  var supportsAudio: Bool { isVideo }

  /// GIF frame delays are stored in hundredths of a second and browsers clamp delays below 0.02s to 0.1s.
  var maximumFPS: Int { self == .gif ? 50 : 60 }

  func fileProperties(loops: Bool) -> [CFString: Any] {
    switch self {
    case .gif:
      loops ? [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] : [:]
    case .apng:
      [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: loops ? 0 : 1]]
    case .mp4, .hevc:
      [:]
    }
  }

  func frameProperties(delay: Double) -> [CFString: Any] {
    switch self {
    case .gif:
      [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay]]
    case .apng:
      [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGDelayTime: delay, kCGImagePropertyAPNGUnclampedDelayTime: delay]]
    case .mp4, .hevc:
      [:]
    }
  }
}

nonisolated struct ExportOptions: Equatable, Sendable {
  var format: ExportFormat
  var start: Double
  var end: Double
  var width: Int
  var height: Int
  var fps: Int
  var isMuted: Bool
  var loops: Bool

  /// Video encoders require even dimensions.
  var outputSize: CGSize {
    format.isVideo
      ? CGSize(width: width.roundedDownToEven, height: height.roundedDownToEven)
      : CGSize(width: width, height: height)
  }

  /// Source timestamps of each frame of an animated image export.
  var frameTimes: [Double] {
    let count = max(1, Int(((end - start) * Double(fps)).rounded(.down)))
    return (0..<count).map { start + Double($0) / Double(fps) }
  }
}

nonisolated extension Int {
  var roundedDownToEven: Int { Swift.max(2, self - self % 2) }
}

nonisolated enum FileNaming {
  static func defaultName(for date: Date = .now, fileExtension: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
    return "Kapture \(formatter.string(from: date)).\(fileExtension)"
  }
}
