import SwiftUI

extension View {
    /// Frosted "Liquid Glass" panel: a translucent material with a bright
    /// top edge and soft shadow — echoes iOS 26's glass surfaces on iOS 17+.
    func glassCard(cornerRadius: CGFloat = 20, shadow: Bool = true) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.22), .white.opacity(0.05)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(shadow ? 0.28 : 0), radius: shadow ? 12 : 0, y: shadow ? 5 : 0)
    }
}
