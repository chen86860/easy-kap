import CoreMedia
import Foundation
import Testing
@testable import Kap

struct ExportOptionsTests {
  private func options(_ format: ExportFormat, width: Int = 641, height: Int = 359, fps: Int = 10) -> ExportOptions {
    ExportOptions(format: format, start: 1, end: 2.55, width: width, height: height, fps: fps, isMuted: false, loops: true)
  }

  @Test func videoOutputSizeIsEven() {
    #expect(options(.mp4).outputSize == CGSize(width: 640, height: 358))
    #expect(options(.hevc).outputSize == CGSize(width: 640, height: 358))
  }

  @Test func imageOutputSizeIsExact() {
    #expect(options(.gif).outputSize == CGSize(width: 641, height: 359))
  }

  @Test func frameTimesCoverTrimmedRange() {
    let times = options(.gif).frameTimes
    #expect(times.count == 15)
    #expect(times.first == 1)
    #expect(times.allSatisfy { $0 < 2.55 })
  }

  @Test func gifCapsFrameRate() {
    #expect(ExportFormat.gif.maximumFPS == 50)
    #expect(ExportFormat.apng.maximumFPS == 60)
  }

  @Test func defaultFileName() {
    var components = DateComponents()
    components.year = 2026
    components.month = 10
    components.day = 23
    components.hour = 9
    components.minute = 5
    components.second = 7
    let date = Calendar.current.date(from: components)!
    #expect(FileNaming.defaultName(for: date, fileExtension: "gif") == "Kapture 2026-10-23 at 09.05.07.gif")
  }

  @Test func recordingConfigurationUsesPixelSize() {
    let settings = RecordingSettings(
      fps: 60, showsCursor: true, showsClicks: true, recordsMicrophone: false, recordsSystemAudio: true, audioDeviceID: nil
    )
    let configuration = settings.streamConfiguration(capturing: CGRect(x: 10, y: 20, width: 301, height: 200), pointPixelScale: 2)
    #expect(configuration.width == 602)
    #expect(configuration.height == 400)
    #expect(configuration.sourceRect == CGRect(x: 10, y: 20, width: 301, height: 200))
    #expect(configuration.minimumFrameInterval == CMTime(value: 1, timescale: 60))
    #expect(configuration.showMouseClicks)
    #expect(configuration.capturesAudio)
    #expect(configuration.excludesCurrentProcessAudio)
    #expect(!configuration.captureMicrophone)
  }
}
