import SwiftUI

struct GlassSegmentedSelector<Value: Hashable>: View {
  @Binding var selection: Value
  let options: [Value]
  let unavailableOptions: Set<Value>
  let label: (Value) -> String
  @State private var dragOffset: CGFloat = 0

  private var selectedIndex: Int {
    options.firstIndex(of: selection) ?? 0
  }

  var body: some View {
    GlassEffectContainer(spacing: 0) {
      GeometryReader { geometry in
        let segmentWidth = geometry.size.width / CGFloat(max(options.count, 1))
        let indicatorOffset = clampedIndicatorOffset(segmentWidth: segmentWidth)

        ZStack(alignment: .leading) {
          Capsule()
            .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())
            .frame(width: segmentWidth, height: 42)
            .offset(x: indicatorOffset)
            .allowsHitTesting(false)

          HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
              let isAvailable = !unavailableOptions.contains(option)
              let isSelected = isVisuallySelected(option, segmentWidth: segmentWidth)
              Button { select(option) } label: {
                Text(label(option))
                  .font(.caption.weight(.bold))
                  .lineLimit(1)
                  .minimumScaleFactor(0.7)
                  .frame(maxWidth: .infinity, minHeight: 42)
                  .foregroundStyle(isSelected ? .white : (isAvailable ? .primary : .red))
              }
              .buttonStyle(.plain)
              .disabled(!isAvailable)
            }
          }
          .simultaneousGesture(dragGesture(segmentWidth: segmentWidth))
        }
      }
      .frame(height: 42)
      .padding(4)
      .glassEffect(.regular, in: Capsule())
    }
    .disabled(options.count == 1)
  }

  private func clampedIndicatorOffset(segmentWidth: CGFloat) -> CGFloat {
    let availableIndexes = options.indices.filter { !unavailableOptions.contains(options[$0]) }
    let minimum = segmentWidth * CGFloat(availableIndexes.first ?? 0)
    let maximum = segmentWidth * CGFloat(availableIndexes.last ?? 0)
    let proposed = CGFloat(selectedIndex) * segmentWidth + dragOffset
    return min(max(proposed, minimum), maximum)
  }

  private func isVisuallySelected(_ option: Value, segmentWidth: CGFloat) -> Bool {
    let indicatorIndex = min(
      max(Int((clampedIndicatorOffset(segmentWidth: segmentWidth) / segmentWidth).rounded()), 0),
      max(options.count - 1, 0)
    )
    return option == options[indicatorIndex]
  }

  private func dragGesture(segmentWidth: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 6)
      .onChanged { dragOffset = $0.translation.width }
      .onEnded { _ in
        let offset = clampedIndicatorOffset(segmentWidth: segmentWidth)
        let targetIndex = min(max(Int((offset / segmentWidth).rounded()), 0), max(options.count - 1, 0))
        select(options[targetIndex])
      }
  }

  private func select(_ option: Value) {
    guard !unavailableOptions.contains(option) else { return }
    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
      selection = option
      dragOffset = 0
    }
  }
}
