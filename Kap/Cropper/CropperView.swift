import SwiftUI

struct CropperView: View {
  let model: CropperModel
  let displayID: CGDirectDisplayID

  @State private var rectAtDragStart: CGRect?

  private var bounds: CGRect { model.bounds(of: displayID) }
  private var selection: CGRect? { model.displayID == displayID ? model.selection : nil }

  /// One action bar: on the display with the selection, or the main display before anything is selected.
  private var showsActionBar: Bool {
    if let selectedDisplay = model.displayID, model.selection != nil { return selectedDisplay == displayID }
    return NSScreen.main?.displayID == displayID
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      DimmingShape(hole: selection)
        .fill(.black.opacity(model.isRecording ? 0 : 0.4), style: FillStyle(eoFill: true))
        .contentShape(Rectangle())
        .gesture(createGesture)
        .simultaneousGesture(TapGesture().onEnded { model.openMenu = nil })
        .pointerStyle(.rectSelection)
        .allowsHitTesting(!model.isRecording)

      if let selection {
        selectionView(selection)
      }

      if !model.isRecording, showsActionBar {
        ActionBar(model: model, displayID: displayID)
          .fixedSize()
          .position(actionBarPosition)
      }
    }
    .frame(width: bounds.width, height: bounds.height)
    .overlayPreferenceValue(ActionBarControlAnchorKey.self) { anchors in
      GeometryReader { proxy in
        if !model.isRecording, showsActionBar {
          popover(anchors: anchors, in: proxy)
        }
      }
    }
    .coordinateSpace(.named(Self.space))
    .ignoresSafeArea()
  }

  private static let space = "cropper"

  /// The open dropdown, or else the hovered control's tip, placed just above that control.
  @ViewBuilder
  private func popover(anchors: [ActionBarControl: Anchor<CGRect>], in proxy: GeometryProxy) -> some View {
    if let menu = model.openMenu, let anchor = anchors[menu] {
      let control = proxy[anchor]
      ActionBarMenuPanel(model: model, menu: menu, displayID: displayID)
        .fixedSize()
        .padding(.leading, max(8, control.minX - 12))
        .frame(width: proxy.size.width, height: control.minY - 14, alignment: .bottomLeading)
    } else if let hovered = model.hoveredControl, let anchor = anchors[hovered] {
      let control = proxy[anchor]
      ActionBarTip(text: hovered.tip)
        // Centering in a frame twice as wide as the control's midpoint puts the tip's center over the control.
        .frame(width: control.midX * 2, height: control.minY - 10, alignment: .bottom)
        .allowsHitTesting(false)
    }
  }

  private var createGesture: some Gesture {
    DragGesture(minimumDistance: 2, coordinateSpace: .named(Self.space))
      .onChanged { value in
        model.openMenu = nil
        let rect = CropperGeometry.selection(from: value.startLocation, to: value.location, ratio: model.ratio, bounds: bounds)
        model.select(rect, on: displayID)
      }
      .onEnded { _ in
        if let selection, selection.width < CropperGeometry.minimumSize || selection.height < CropperGeometry.minimumSize {
          model.select(nil, on: displayID)
        }
      }
  }

  @ViewBuilder
  private func selectionView(_ rect: CGRect) -> some View {
    Rectangle()
      .strokeBorder(.white.opacity(0.9), style: StrokeStyle(lineWidth: 1, dash: model.isRecording ? [6, 4] : []))
      .background(Color.white.opacity(0.001))
      .frame(width: rect.width, height: rect.height)
      .position(x: rect.midX, y: rect.midY)
      .gesture(moveGesture)
      .pointerStyle(.grabIdle)
      .allowsHitTesting(!model.isRecording)

    if !model.isRecording {
      ForEach(Handle.allCases, id: \.self) { handle in
        Circle()
          .fill(.white)
          .stroke(.black.opacity(0.25), lineWidth: 1)
          .frame(width: 9, height: 9)
          .padding(6)
          .contentShape(Rectangle())
          .position(handle.point(in: rect))
          .gesture(resizeGesture(handle))
          .pointerStyle(.frameResize(position: handle.resizePosition))
      }
    }
  }

  private var moveGesture: some Gesture {
    DragGesture(coordinateSpace: .named(Self.space))
      .onChanged { value in
        guard let start = rectAtDragStart ?? selection else { return }
        rectAtDragStart = start
        model.selection = CropperGeometry.moved(start, by: value.translation, within: bounds)
      }
      .onEnded { _ in rectAtDragStart = nil }
  }

  private func resizeGesture(_ handle: Handle) -> some Gesture {
    DragGesture(coordinateSpace: .named(Self.space))
      .onChanged { value in
        guard let start = rectAtDragStart ?? selection else { return }
        rectAtDragStart = start
        if let rect = CropperGeometry.resized(start, handle: handle, by: value.translation, ratio: model.ratio, within: bounds) {
          model.selection = rect
        }
      }
      .onEnded { _ in rectAtDragStart = nil }
  }

  /// Fixed at the bottom center of the display, above the Dock, so it never jumps around with the selection.
  private var actionBarPosition: CGPoint {
    let screen = NSScreen.screens.first { $0.displayID == displayID }
    let bottomInset = screen.map { $0.visibleFrame.minY - $0.frame.minY } ?? 0
    return CGPoint(x: bounds.midX, y: bounds.maxY - bottomInset - 28 - ActionBar.height / 2)
  }
}

nonisolated private struct DimmingShape: Shape {
  var hole: CGRect?

  func path(in rect: CGRect) -> Path {
    var path = Path(rect)
    if let hole { path.addRect(hole) }
    return path
  }
}
