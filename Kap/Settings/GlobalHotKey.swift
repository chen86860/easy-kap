import AppKit
import Carbon.HIToolbox

nonisolated struct Shortcut: Codable, Equatable, Sendable {
  var keyCode: UInt16
  var modifiers: UInt
  /// The key as typed when the shortcut was recorded, e.g. "5".
  var key: String

  var modifierFlags: NSEvent.ModifierFlags {
    NSEvent.ModifierFlags(rawValue: modifiers).intersection([.command, .option, .control, .shift])
  }

  var displayString: String {
    let flags = modifierFlags
    var result = ""
    if flags.contains(.control) { result += "⌃" }
    if flags.contains(.option) { result += "⌥" }
    if flags.contains(.shift) { result += "⇧" }
    if flags.contains(.command) { result += "⌘" }
    return result + key.uppercased()
  }

  var carbonModifiers: UInt32 {
    let flags = modifierFlags
    var result = 0
    if flags.contains(.command) { result |= cmdKey }
    if flags.contains(.option) { result |= optionKey }
    if flags.contains(.control) { result |= controlKey }
    if flags.contains(.shift) { result |= shiftKey }
    return UInt32(result)
  }
}

/// A system-wide keyboard shortcut backed by the Carbon hot key API, which needs no Accessibility permission.
final class GlobalHotKey {
  var action: (() -> Void)?

  private var hotKeyRef: EventHotKeyRef?
  private var handlerRef: EventHandlerRef?

  func register(_ shortcut: Shortcut?) {
    unregister()
    guard let shortcut else { return }
    installHandlerIfNeeded()
    let id = EventHotKeyID(signature: OSType(0x4B41_5021), id: 1) // "KAP!"
    RegisterEventHotKey(UInt32(shortcut.keyCode), shortcut.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
  }

  func unregister() {
    if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
    hotKeyRef = nil
  }

  private func installHandlerIfNeeded() {
    guard handlerRef == nil else { return }
    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
      guard let userData else { return noErr }
      let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
      MainActor.assumeIsolated { hotKey.action?() }
      return noErr
    }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
  }
}
