import Foundation

/// Anonymous usage events, sent to the PostHog project the website uses unless the user turns them off in Settings.
/// Events say which features are used and how; they never carry recordings, file names, paths or error messages.
enum Telemetry {
  private static let endpoint = URL(string: "https://a.emmmm.dev/i/v0/e/")!
  private static let projectToken = "phc_9biiBNdgbqZlxcJdISohgz7VWJnC83jCexzXhrMKnd"
  private static let installIDKey = "telemetryInstallID"
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
