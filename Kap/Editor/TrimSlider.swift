import SwiftUI

/// Kap's trim bar: a thin track, a gradient showing playback progress through the selection, and two pill handles.
/// Dragging the track scrubs.
struct TrimSlider: View {
  @Binding var start: Double
  @Binding var end: Double
  let duration: Double
  let currentTime: Double
  let aspectRatio: Double
  let framePreviewer: FramePreviewer
  let onScrub: (Double) -> Void

  private let trackHeight: CGFloat = 4
  private let minimumLength = 0.1
  static let progressGradient = LinearGradient(
    colors: [Color(red: 0.49, green: 0.31, blue: 0.95), Color(red: 0.32, green: 0.86, blue: 0.72)],
    startPoint: .leading,
    endPoint: .trailing
  )
  @State private var valueAtDragStart: Double?
  @State private var hoverTime: Double?
  @State private var previewFrame: CGImage?

  private let previewWidth: CGFloat = 160

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      let midY = proxy.size.height / 2
      let startX = x(for: start, width: width)
      let endX = x(for: end, width: width)
      let playheadX = x(for: currentTime.clamped(start, end), width: width)

      ZStack(alignment: .leading) {
        Capsule()
          .fill(.white.opacity(0.25))
          .frame(height: trackHeight)
        Rectangle()
          .fill(.white.opacity(0.45))
          .frame(width: max(0, endX - startX), height: trackHeight)
          .offset(x: startX)
        Rectangle()
          .fill(Self.progressGradient)
          .frame(width: max(0, playheadX - startX), height: trackHeight)
          .offset(x: startX)
      }
      .frame(height: proxy.size.height)
      .contentShape(Rectangle())
      .onContinuousHover { phase in
        switch phase {
        case .active(let location): hoverTime = (Double(location.x / width) * duration).clamped(0, duration)
        case .ended: hoverTime = nil
        }
      }
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { onScrub(Double($0.location.x / width) * duration) }
      )
      .overlay(alignment: .topLeading) {
        handle
          .position(x: startX, y: midY)
          .gesture(handleGesture(width: width, initial: { start }, update: { start = $0.clamped(0, end - minimumLength) }))
        handle
          .position(x: endX, y: midY)
          .gesture(handleGesture(width: width, initial: { end }, update: { end = $0.clamped(start + minimumLength, duration) }))
      }
      .overlay(alignment: .bottomLeading) {
        if let hoverTime {
          preview(for: hoverTime)
            .offset(
              x: (x(for: hoverTime, width: width) - previewWidth / 2).clamped(0, width - previewWidth),
              y: -proxy.size.height - 6
            )
            .allowsHitTesting(false)
        }
      }
    }
    // Rounded to about a frame so tiny pointer movements don't request new images.
    .task(id: hoverTime.map { ($0 * 30).rounded() }) {
      guard let hoverTime else { return }
      let frame = await framePreviewer.frame(at: hoverTime)
      if !Task.isCancelled, let frame { previewFrame = frame }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Trim")
    .accessibilityValue("\(seconds(start)) to \(seconds(end)) seconds")
  }

  private func preview(for time: Double) -> some View {
    ZStack(alignment: .bottom) {
      if let previewFrame {
        Image(decorative: previewFrame, scale: 1)
          .resizable()
          .scaledToFill()
      } else {
        Rectangle().fill(.black)
      }
      Text(verbatim: "\(Timecode.short(time - start)) (\(Timecode.short(time)))")
        .font(.callout.monospacedDigit())
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.black.opacity(0.55), in: .rect(cornerRadius: 5))
        .padding(.bottom, 6)
    }
    .frame(width: previewWidth, height: previewWidth / max(aspectRatio, 0.1))
    .clipShape(.rect(cornerRadius: 6))
    .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.3)) }
    .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
  }

  private var handle: some View {
    Capsule()
      .fill(.white)
      .frame(width: 6, height: 18)
      .shadow(color: .black.opacity(0.35), radius: 1.5)
      .padding(.horizontal, 8)
      .contentShape(Rectangle())
      .pointerStyle(.frameResize(position: .leading, directions: [.inward, .outward]))
  }

  private func seconds(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1)))
  }

  private func x(for value: Double, width: CGFloat) -> CGFloat {
    guard duration > 0 else { return 0 }
    return CGFloat(value / duration) * width
  }

  private func handleGesture(width: CGFloat, initial: @escaping () -> Double, update: @escaping (Double) -> Void) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { gesture in
        let origin = valueAtDragStart ?? initial()
        valueAtDragStart = origin
        update(origin + Double(gesture.translation.width / width) * duration)
      }
      .onEnded { _ in valueAtDragStart = nil }
  }
}
