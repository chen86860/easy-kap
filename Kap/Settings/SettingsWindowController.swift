import AppKit
import Sparkle
import SwiftUI

/// Settings in a window with a tab for each group in its toolbar, like the system's own apps. The window takes each
/// tab's height, so no tab needs more room than a small screen has.
final class SettingsWindowController {
  enum Tab: Int {
    case general, recording, about
  }

  private let tabs = NSTabViewController()
  private let window: NSWindow

  init(preferences: Preferences, updater: SPUUpdater?, onGrantScreenRecording: @escaping () -> Void) {
    tabs.tabStyle = .toolbar
    tabs.transitionOptions = [.crossfade, .allowUserInteraction]
    tabs.addTabViewItem(Self.item(
      GeneralSettingsView(preferences: preferences, onGrantScreenRecording: onGrantScreenRecording),
      label: String(localized: "General"),
      systemImage: "gearshape"
    ))
    tabs.addTabViewItem(Self.item(
      RecordingSettingsView(preferences: preferences),
      label: String(localized: "Recording"),
      systemImage: "record.circle"
    ))
    tabs.addTabViewItem(Self.item(
      AboutSettingsView(updater: updater),
      label: String(localized: "About"),
      systemImage: "info.circle"
    ))

    window = NSWindow(contentViewController: tabs)
    window.styleMask = [.titled, .closable]
    window.toolbarStyle = .preference
    window.isReleasedWhenClosed = false
    window.center()
  }

  /// Brings Settings forward, on `tab` if given, or else on the tab shown last.
  func show(_ tab: Tab? = nil) {
    if let tab { tabs.selectedTabViewItemIndex = tab.rawValue }
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }

  private static func item(_ view: some View, label: String, systemImage: String) -> NSTabViewItem {
    let controller = NSHostingController(rootView: view)
    controller.sizingOptions = .preferredContentSize
    // The tab controller shows the selected tab's title as the window's title.
    controller.title = label
    let item = NSTabViewItem(viewController: controller)
    item.label = label
    item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: label)
    return item
  }
}
