import Foundation

/// Anonymous usage events, sent to the PostHog project the website uses unless the user turns them off in Settings.
/// Events say which features are used and how; they never carry recordings, file names, paths or error messages.
enum Telemetry {
  private static let endpoint = URL(string: "https://a.emmmm.dev/i/v0/e/")!
  private static let projectToken = "phc_9biiBNdgbqZlxcJdISohgz7VWJnC83jCexzXhrMKnd"
  private static let installIDKey = "telemetryInstallID"
  private static let screenRecordingDeniedKey = "telemetryScreenRecordingDenied"
  private static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

  static func capture(_ event: String, _ properties: [String: Any] = [:]) {
    guard Preferences.shared.sendsUsageData, !isRunningTests,
          let body = try? JSONSerialization.data(withJSONObject: payload(event: event, properties: properties, distinctID: installID))
    else { return }
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    Task.detached(priority: .utility) { _ = try? await URLSession.shared.data(for: request) }
  }

  /// Sends `app_launched`. Granting Screen Recording usually makes macOS quit and reopen the app before it can
  /// notice, so a launch that finds access granted after one that didn't reports the grant.
  static func captureLaunch(screenRecordingAllowed: Bool) {
    capture("app_launched", ["screen_recording_allowed": screenRecordingAllowed])
    if screenRecordingAllowed, UserDefaults.standard.bool(forKey: screenRecordingDeniedKey) {
      capture("screen_recording_granted", ["from": "relaunch"])
    }
    UserDefaults.standard.set(!screenRecordingAllowed, forKey: screenRecordingDeniedKey)
  }

  /// Reports a grant noticed while running; the next launch then doesn't report it again.
  static func captureScreenRecordingGranted(from: String) {
    capture("screen_recording_granted", ["from": from])
    UserDefaults.standard.set(false, forKey: screenRecordingDeniedKey)
  }

  /// An error's domain and code, which name the kind of failure without the message, which can contain paths.
  static func errorKind(_ error: any Error) -> String {
    let error = error as NSError
    return "\(error.domain)#\(error.code)"
  }

  static func payload(event: String, properties: [String: Any], distinctID: String) -> [String: Any] {
    let system = ProcessInfo.processInfo.operatingSystemVersion
    let common: [String: Any] = [
      "product": "easy-kap-app",
      "environment": isDebug ? "development" : "production",
      "app_version": AppInfo.version,
      "os_version": "\(system.majorVersion).\(system.minorVersion).\(system.patchVersion)",
      // Groups dashboards by release (15, 26, 27) instead of every point update.
      "os_major_version": system.majorVersion,
      "language": Locale.preferredLanguages.first ?? "",
      // No PostHog person profile: events stay tied to a random install ID only.
      "$process_person_profile": false,
      "$lib": "easy-kap-macos"
    ]
    return [
      "api_key": projectToken,
      "event": event,
      "distinct_id": distinctID,
      "timestamp": Date.now.ISO8601Format(),
      "properties": common.merging(properties) { _, new in new }
    ]
  }

  /// A random ID made on first use, so events from one install can be counted together without identifying anyone.
  private static var installID: String {
    if let id = UserDefaults.standard.string(forKey: installIDKey) { return id }
    let id = UUID().uuidString
    UserDefaults.standard.set(id, forKey: installIDKey)
    return id
  }

  private static var isDebug: Bool {
    #if DEBUG
    true
    #else
    false
    #endif
  }
}

/// Times one recording for usage data, telling the time spent paused apart from the time recorded.
struct RecordingClock {
  private let start: Date
  private var pauseStart: Date?
  private var pausedSeconds: TimeInterval = 0
  private var pauseCount = 0

  init(start: Date = .now) {
    self.start = start
  }

  mutating func pause(at date: Date = .now) {
    guard pauseStart == nil else { return }
    pauseStart = date
    pauseCount += 1
  }

  mutating func resume(at date: Date = .now) {
    guard let pauseStart else { return }
    pausedSeconds += date.timeIntervalSince(pauseStart)
    self.pauseStart = nil
  }

  /// `elapsed_seconds` spans start to stop, pauses included; `recorded_seconds` leaves them out.
  func summary(at date: Date = .now) -> [String: Any] {
    let elapsed = date.timeIntervalSince(start)
    let paused = pausedSeconds + (pauseStart.map { date.timeIntervalSince($0) } ?? 0)
    return [
      "elapsed_seconds": elapsed.rounded(),
      "recorded_seconds": max(0, elapsed - paused).rounded(),
      "pause_count": pauseCount
    ]
  }
}
