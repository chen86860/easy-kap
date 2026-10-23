import SwiftUI

struct ActionBar: View {
  let model: CropperModel
  let displayID: CGDirectDisplayID

  static let height: CGFloat = 60

  private var selection: CGRect? { model.displayID == displayID ? model.selection : nil }

  var body: some View {
    HStack(spacing: 14) {
      Button("Cancel", systemImage: "xmark") { model.onCancel?() }
        .font(.title3.weight(.medium))
        .control(.cancel, model: model)

      divider

      Button {
        toggle(.ratio)
      } label: {
        Label(model.ratio?.title ?? "Free", systemImage: model.ratio == nil ? "lock.open" : "lock")
          .labelStyle(.titleAndIcon)
      }
      .control(.ratio, model: model)

      HStack(spacing: 6) {
        DimensionField(value: selection.map { Int($0.width) }) { model.setSize(width: CGFloat($0)) }
        Text("×").foregroundStyle(.secondary)
        DimensionField(value: selection.map { Int($0.height) }) { model.setSize(height: CGFloat($0)) }
      }
      .disabled(selection == nil)

      divider

      Button("Screen", systemImage: "display") { toggle(.screen) }
        .font(.title3)
        .control(.screen, model: model)

      Button("Window", systemImage: "macwindow") {
        if model.openMenu != .window { model.loadWindows() }
        toggle(.window)
      }
      .font(.title3)
      .control(.window, model: model)

      Button("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right") { model.selectFullScreen(displayID) }
        .font(.title3)
        .control(.fullScreen, model: model)

      divider

      Button("Record", systemImage: "record.circle.fill") { model.onRecord?() }
        .font(.system(size: 34))
        .foregroundStyle(.red)
        .disabled(selection == nil)
        .control(.record, model: model)
    }
    .labelStyle(.iconOnly)
    .buttonStyle(.borderless)
    .font(.body.weight(.medium))
    .padding(.horizontal, 20)
    .frame(height: Self.height)
    .opaquePanel(in: Capsule())
  }

  private var divider: some View {
    Divider().frame(height: 26)
  }

  private func toggle(_ menu: ActionBarControl) {
    model.openMenu = model.openMenu == menu ? nil : menu
  }
}

/// The contents of the dropdown for `menu`, drawn by `CropperView` above the control.
struct ActionBarMenuPanel: View {
  let model: CropperModel
  let menu: ActionBarControl
  let displayID: CGDirectDisplayID

  var body: some View {
    Group {
      switch menu {
      case .ratio: ratioMenu
      case .screen: screenMenu
      case .window: windowMenu
      case .cancel, .fullScreen, .record: EmptyView()
      }
    }
    .padding(5)
    .frame(minWidth: 180, alignment: .leading)
    .opaquePanel(in: RoundedRectangle(cornerRadius: 12))
  }

  private func choose(_ action: () -> Void) {
    action()
    model.openMenu = nil
  }

  private var ratioMenu: some View {
    VStack(alignment: .leading, spacing: 2) {
      DropdownRow(title: "Free", isSelected: model.ratio == nil) { choose { model.setRatio(nil) } }
      Divider().padding(.vertical, 3)
      ForEach(AspectRatio.presets, id: \.self) { ratio in
        DropdownRow(title: ratio.title, isSelected: model.ratio == ratio) { choose { model.setRatio(ratio) } }
      }
    }
  }

  private var screenMenu: some View {
    VStack(alignment: .leading, spacing: 2) {
      ForEach(NSScreen.screens, id: \.self) { screen in
        if let id = screen.displayID {
          DropdownRow(
            title: screen.localizedName,
            systemImage: CGDisplayIsBuiltin(id) != 0 ? "laptopcomputer" : "display",
            isSelected: model.displayID == id && model.selection == model.bounds(of: id)
          ) {
            choose { model.selectFullScreen(id) }
          }
        }
      }
    }
  }

  private var windowMenu: some View {
    let apps = model.apps
    let rowCount = apps.reduce(0) { $0 + 1 + ($1.windows.count > 1 ? $1.windows.count : 0) }
    return ScrollView {
      VStack(alignment: .leading, spacing: 2) {
        if apps.isEmpty {
          Text("No Windows").foregroundStyle(.secondary).padding(8)
        }
        ForEach(apps) { app in
          DropdownRow(title: app.name, image: app.icon) {
            if let window = app.windows.first { choose { model.select(window) } }
          }
          if app.windows.count > 1 {
            ForEach(app.windows) { window in
              DropdownRow(title: window.title.isEmpty ? "Untitled Window" : window.title, indent: true) {
                choose { model.select(window) }
              }
            }
          }
        }
      }
    }
    .frame(width: 260, height: min(CGFloat(max(rowCount, 1)) * 30 + 4, 380))
  }
}

struct ActionBarTip: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.callout)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .opaquePanel(in: Capsule())
      .fixedSize()
  }
}

struct ActionBarControlAnchorKey: PreferenceKey {
  static var defaultValue: [ActionBarControl: Anchor<CGRect>] { [:] }

  static func reduce(value: inout [ActionBarControl: Anchor<CGRect>], nextValue: () -> [ActionBarControl: Anchor<CGRect>]) {
    value.merge(nextValue()) { $1 }
  }
}

/// A row in one of the action bar's dropdowns, highlighted on hover like a menu item.
private struct DropdownRow: View {
  let title: String
  var systemImage: String?
  var image: NSImage?
  var isSelected = false
  var indent = false
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: "checkmark")
          .font(.caption.weight(.bold))
          .opacity(isSelected ? 1 : 0)
          .frame(width: 12)
        if let image {
          Image(nsImage: image).resizable().frame(width: 18, height: 18)
        } else if let systemImage {
          Image(systemName: systemImage).frame(width: 18)
        }
        Text(title).lineLimit(1).truncationMode(.middle)
        Spacer(minLength: 0)
      }
      .padding(.leading, indent ? 34 : 6)
      .padding(.trailing, 10)
      .frame(height: 28)
      .foregroundStyle(isHovered ? Color.white : .primary)
      .background(isHovered ? Color.accentColor : .clear, in: .rect(cornerRadius: 6))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
  }
}

private struct DimensionField: View {
  let value: Int?
  let onCommit: (Int) -> Void

  @State private var text = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    TextField("", text: $text)
      .textFieldStyle(.roundedBorder)
      .multilineTextAlignment(.center)
      .monospacedDigit()
      .controlSize(.large)
      .frame(width: 70)
      .focused($isFocused)
      .onSubmit(commit)
      .onChange(of: isFocused) { if !isFocused { commit() } }
      .onChange(of: value, initial: true) { if !isFocused { text = value.map(String.init) ?? "" } }
  }

  private func commit() {
    if let number = Int(text), number > 0, number != value {
      onCommit(number)
    }
    text = value.map(String.init) ?? ""
  }
}

private extension View {
  /// Reports the control's bounds and hover state so the cropper can draw its tip or dropdown.
  func control(_ control: ActionBarControl, model: CropperModel) -> some View {
    anchorPreference(key: ActionBarControlAnchorKey.self, value: .bounds) { [control: $0] }
      .onHover { hovering in
        if hovering {
          model.hoveredControl = control
        } else if model.hoveredControl == control {
          model.hoveredControl = nil
        }
      }
  }
}

extension View {
  /// Opaque, so controls stay readable over any screen content; follows the system light or dark appearance.
  func opaquePanel(in shape: some InsettableShape) -> some View {
    background(.background, in: shape)
      .overlay { shape.strokeBorder(.separator) }
      .shadow(color: .black.opacity(0.22), radius: 10, y: 3)
  }
}
