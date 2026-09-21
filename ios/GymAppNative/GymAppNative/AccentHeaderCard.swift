import SwiftUI

struct AccentHeaderCard: View {
  let title: String
  var eyebrow: String? = nil
  var detail: String? = nil
  var emphasizesTitle = false

  var body: some View {
    VStack(spacing: 5) {
      if let eyebrow {
        Text(eyebrow)
          .font(.caption.weight(.semibold))
          .lineLimit(1)
          .opacity(0.82)
      }

      Text(title)
        .font(.system(size: emphasizesTitle ? 28 : 22, weight: .bold))
        .lineLimit(emphasizesTitle ? 2 : 1)
        .minimumScaleFactor(0.78)

      if let detail {
        Text(detail)
          .font(.subheadline.weight(.medium))
          .lineLimit(1)
          .opacity(0.84)
      }
    }
    .multilineTextAlignment(.center)
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 28)
    .padding(.top, 14)
    .padding(.bottom, 22)
    .background(alignment: .top) {
      // `safeAreaInset` positions this view below the status area. Extend only the
      // accent canvas upward so the card begins at the physical edge of the phone.
      Color.gymAccent
        .frame(height: 96)
        .offset(y: -96)
    }
    .background {
      UnevenRoundedRectangle(
        topLeadingRadius: 0,
        bottomLeadingRadius: 48,
        bottomTrailingRadius: 48,
        topTrailingRadius: 0,
        style: .continuous
      )
      .fill(Color.gymAccent)
    }
    .accessibilityElement(children: .combine)
  }
}
