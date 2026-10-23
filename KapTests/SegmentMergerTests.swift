import AVFoundation
import Testing
@testable import Kap

struct SegmentMergerTests {
  private func copyOfFixture(withAudio: Bool = false) async throws -> URL {
    let source = withAudio ? try await TestVideo.shared.urlWithTwoAudioTracks() : try await TestVideo.shared.url()
    let copy = FileManager.default.temporaryDirectory.appending(path: "kap-segment-\(UUID().uuidString).mov")
    try FileManager.default.copyItem(at: source, to: copy)
    return copy
  }

  private func destination() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "kap-merged-\(UUID().uuidString).mov")
  }

  @Test func joinsSegmentsBackToBack() async throws {
    let segments = [try await copyOfFixture(withAudio: true), try await copyOfFixture(withAudio: true)]
    let output = destination()
    defer { try? FileManager.default.removeItem(at: output) }

    try await SegmentMerger.merge(segments, into: output)

    let asset = AVURLAsset(url: output)
    #expect(abs(try await asset.load(.duration).seconds - 4) < 0.1)
    #expect(try await asset.loadTracks(withMediaType: .video).count == 1)
    #expect(try await asset.loadTracks(withMediaType: .audio).count == 2)
  }

  @Test func skipsMissingSegmentsAndMovesASingleOne() async throws {
    let segment = try await copyOfFixture()
    let missing = FileManager.default.temporaryDirectory.appending(path: "kap-missing-\(UUID().uuidString).mov")
    let output = destination()
    defer { try? FileManager.default.removeItem(at: output) }

    try await SegmentMerger.merge([missing, segment], into: output)

    #expect(!FileManager.default.fileExists(atPath: segment.path))
    #expect(abs(try await AVURLAsset(url: output).load(.duration).seconds - 2) < 0.1)
  }

  @Test func failsWhenNothingWasRecorded() async {
    let missing = FileManager.default.temporaryDirectory.appending(path: "kap-missing-\(UUID().uuidString).mov")
    await #expect(throws: SegmentMergerError.self) {
      try await SegmentMerger.merge([missing], into: destination())
    }
  }
}
