import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// "Save to Disk", "Copy to Clipboard", and an "Open With…" submenu listing the apps that open the export format.
struct DestinationMenu: View {
  @Binding var destination: EditorModel.Destination
  let contentType: UTType

  var body: some View {
    Menu(destination.title) {
      Picker("Destination", selection: $destination) {
        Text("Save to Disk").tag(EditorModel.Destination.saveToDisk)
        Text("Copy to Clipboard").tag(EditorModel.Destination.copyToClipboard)
      }
      .pickerStyle(.inline)
      .labelsHidden()

      Menu("Open With…") {
        let applications = OpenWithApplications.list(for: contentType)
        if let defaultApplication = applications.defaultApplication {
          item(defaultApplication, title: "\(OpenWithApplications.name(of: defaultApplication)) (default)")
          Divider()
        }
        ForEach(applications.others, id: \.self) { application in
          item(application, title: OpenWithApplications.name(of: application))
        }
      }
    }
    .fixedSize()
  }

  private func item(_ application: URL, title: String) -> some View {
    Toggle(isOn: Binding(
      get: { destination == .openWith(application) },
      set: { if $0 { destination = .openWith(application) } }
    )) {
      Label {
        Text(title)
      } icon: {
        Image(nsImage: OpenWithApplications.icon(of: application))
      }
    }
  }
}

enum OpenWithApplications {
  static func list(for contentType: UTType) -> (defaultApplication: URL?, others: [URL]) {
    let workspace = NSWorkspace.shared
    let defaultApplication = workspace.urlForApplication(toOpen: contentType)
    let others = workspace.urlsForApplications(toOpen: contentType)
      .filter { $0 != defaultApplication && Bundle(url: $0)?.bundleIdentifier != Bundle.main.bundleIdentifier }
      .sorted { name(of: $0).localizedStandardCompare(name(of: $1)) == .orderedAscending }
    return (defaultApplication, others)
  }

  static func name(of application: URL) -> String {
    FileManager.default.displayName(atPath: application.path).replacing(/\.app$/, with: "")
  }

  static func icon(of application: URL) -> NSImage {
    let icon = NSWorkspace.shared.icon(forFile: application.path)
    icon.size = CGSize(width: 16, height: 16)
    return icon
  }
}
