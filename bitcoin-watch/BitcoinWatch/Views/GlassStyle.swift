import SwiftUI

extension Color {
    /// Subtle dark row tint standing in for the system's grouped-row background,
    /// since `.scrollContentBackground(.hidden)` drops it in favor of our gradient.
    static let listRowTint = Color.white.opacity(0.05)
}

extension View {
    /// Dark gradient shown behind native List/.insetGrouped screens once
    /// `.scrollContentBackground(.hidden)` removes the system grouped background.
    func nativeListBackground() -> some View {
        background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.11, blue: 0.10),
                         Color(red: 0.05, green: 0.04, blue: 0.04)],
                startPoint: .topLeading, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

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
