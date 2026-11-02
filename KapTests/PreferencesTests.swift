import Foundation
import Testing
@testable import Kap

struct PreferencesTests {
  @Test func languageSetsAppleLanguagesForTheNextLaunch() throws {
    let suite = "kap-tests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let appleLanguages = { defaults.persistentDomain(forName: suite)?["AppleLanguages"] as? [String] }

    let preferences = Preferences(defaults: defaults)
    #expect(preferences.language == .system)

    preferences.language = .simplifiedChinese
    #expect(appleLanguages() == ["zh-Hans"])
    // The running app keeps its language until it relaunches.
    #expect(preferences.launchLanguage == .system)

    let relaunched = Preferences(defaults: defaults)
    #expect(relaunched.language == .simplifiedChinese)
    #expect(relaunched.launchLanguage == .simplifiedChinese)

    relaunched.language = .system
    #expect(appleLanguages() == nil)
  }

  @Test func exportsMP4ByDefault() throws {
    let suite = "kap-tests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    #expect(Preferences(defaults: defaults).lastExportFormat == .mp4)
    #expect(ExportFormat.allCases == [.mp4, .hevc, .gif, .apng])
  }
}
