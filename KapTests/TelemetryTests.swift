import Foundation
import Testing
@testable import Kap

struct TelemetryTests {
  @Test func usageDataIsOnByDefaultAndCanBeTurnedOff() throws {
    let suite = "kap-tests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let preferences = Preferences(defaults: defaults)
    #expect(preferences.sendsUsageData)
    preferences.sendsUsageData = false
    #expect(!Preferences(defaults: defaults).sendsUsageData)
  }

  @Test func payloadIsAnonymousPostHogEvent() throws {
    let payload = Telemetry.payload(event: "export_finished", properties: ["format": "gif"], distinctID: "install-id")
    #expect(payload["event"] as? String == "export_finished")
    #expect(payload["distinct_id"] as? String == "install-id")
    #expect((payload["api_key"] as? String)?.hasPrefix("phc_") == true)
    let properties = try #require(payload["properties"] as? [String: Any])
    #expect(properties["format"] as? String == "gif")
    #expect(properties["product"] as? String == "easy-kap-app")
    #expect(properties["$process_person_profile"] as? Bool == false)
    #expect(JSONSerialization.isValidJSONObject(payload))
  }

  @Test func errorKindLeavesOutTheMessage() {
    let error = NSError(domain: "NSCocoaErrorDomain", code: 4, userInfo: [NSLocalizedDescriptionKey: "/Users/someone/secret.mov"])
    #expect(Telemetry.errorKind(error) == "NSCocoaErrorDomain#4")
  }
}
