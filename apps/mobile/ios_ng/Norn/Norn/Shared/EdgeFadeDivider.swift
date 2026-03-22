import SwiftUI

struct EdgeFadeDivider: View {
  var inset: CGFloat = 20
  var opacity: Double = 0.16

  var body: some View {
    Rectangle()
      .fill(
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0),
            .init(color: Color.primary.opacity(opacity), location: 0.16),
            .init(color: Color.primary.opacity(opacity), location: 0.84),
            .init(color: .clear, location: 1)
          ],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .frame(height: 1)
      .padding(.horizontal, inset)
  }
}

#Preview {
  EdgeFadeDivider()
}
