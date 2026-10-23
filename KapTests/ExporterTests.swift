import AVFoundation
import ImageIO
import Testing
@testable import Kap

struct ExporterTests {
  private static let fixture = TestVideo.shared

  private func export(_ options: ExportOptions) async throws -> URL {
    let source = try await Self.fixture.url()
    let destination = FileManager.default.temporaryDirectory
      .appending(path: "kap-export-\(UUID().uuidString).\(options.format.fileExtension)")
    try await Exporter.export(source: source, destination: destination, options: options) { _ in }
    return destination
  }

  private func options(_ format: ExportFormat, loops: Bool = true) -> ExportOptions {
    ExportOptions(format: format, start: 0.5, end: 1.5, width: 160, height: 120, fps: 10, isMuted: true, loops: loops)
  }

  @Test(arguments: [ExportFormat.mp4, .hevc])
  func exportsScaledVideo(format: ExportFormat) async throws {
    let url = try await export(options(format))
    defer { try? FileManager.default.removeItem(at: url) }

    let asset = AVURLAsset(url: url)
    let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
    let (size, descriptions) = try await track.load(.naturalSize, .formatDescriptions)
    #expect(size == CGSize(width: 160, height: 120))
    let duration = try await asset.load(.duration).seconds
    #expect(abs(duration - 1) < 0.15)
    let codec = descriptions.first.map(CMFormatDescriptionGetMediaSubType)
    #expect(codec == (format == .hevc ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264))
    #expect(try await asset.loadTracks(withMediaType: .audio).isEmpty)
  }

  @Test(arguments: [ExportFormat.gif, .apng])
  func exportsAnimatedImage(format: ExportFormat) async throws {
    let url = try await export(options(format))
    defer { try? FileManager.default.removeItem(at: url) }

    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    #expect(CGImageSourceGetCount(source) == 10)
    let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    #expect(properties[kCGImagePropertyPixelWidth] as? Int == 160)
    #expect(properties[kCGImagePropertyPixelHeight] as? Int == 120)
  }

  @Test func gifLoopsForever() async throws {
    let url = try await export(options(.gif, loops: true))
    defer { try? FileManager.default.removeItem(at: url) }
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    let properties = CGImageSourceCopyProperties(source, nil) as? [CFString: Any]
    let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
    #expect(gif?[kCGImagePropertyGIFLoopCount] as? Int == 0)
  }

  @Test func mixesSystemAudioAndMicrophoneIntoOneTrack() async throws {
    let source = try await Self.fixture.urlWithTwoAudioTracks()
    let destination = FileManager.default.temporaryDirectory.appending(path: "kap-mix-\(UUID().uuidString).mp4")
    defer { try? FileManager.default.removeItem(at: destination) }
    var mp4 = options(.mp4)
    mp4.isMuted = false
    try await Exporter.export(source: source, destination: destination, options: mp4) { _ in }
    #expect(try await AVURLAsset(url: destination).loadTracks(withMediaType: .audio).count == 1)
  }

  @Test func cancellationRemovesPartialFile() async throws {
    let source = try await Self.fixture.url()
    let destination = FileManager.default.temporaryDirectory.appending(path: "kap-cancel-\(UUID().uuidString).gif")
    let task = Task {
      try await Exporter.export(source: source, destination: destination, options: options(.gif)) { _ in }
    }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(!FileManager.default.fileExists(atPath: destination.path))
  }
}
