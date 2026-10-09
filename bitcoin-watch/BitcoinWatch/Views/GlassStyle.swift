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

    /// Frosted "Liquid Glass" panel. On iOS 26+ this is the real system
    /// `.glassEffect()` material (dynamic specular highlights, true
    /// refraction) — the look the new iPhones are designed to show off.
    /// iOS 17–25 fall back to a hand-rolled material approximation.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 20, shadow: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(shadow ? 0.28 : 0), radius: shadow ? 12 : 0, y: shadow ? 5 : 0)
        } else {
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
}

/// Thin frosted seam between two wide-layout panes (e.g. the unfolded Duo's
/// two-pane split) — a soft glass rule with a blurred glow either side,
/// matching the `.glassCard()` material instead of a flat system `Divider`.
struct GlassSeam: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.clear, .white.opacity(0.08), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 14)
            .blur(radius: 6)

            LinearGradient(
                colors: [.white.opacity(0.03), .white.opacity(0.18), .white.opacity(0.03)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 1)
        }
    }
}

/// How a sheet should size itself when there's room for something smaller
/// than full width (iPad, unfolded iPhone Duo, landscape Plus/Max).
enum AdaptiveSheetSize {
    /// Compact, centered form sheet — settings-style and single-column sheets.
    case form
    /// Larger page sheet — content-rich sheets with a two-column wide layout.
    case page
}

extension View {
    /// `.presentationSizing` on iOS 18+ (no-op on 17, where iPad already uses
    /// form sheets). On compact-width iPhones sheets look the same as before.
    @ViewBuilder
    func adaptiveSheetSizing(_ size: AdaptiveSheetSize = .form) -> some View {
        if #available(iOS 18.0, *) {
            switch size {
            case .form: self.presentationSizing(.form)
            case .page: self.presentationSizing(.page)
            }
        } else {
            self
        }
    }

    /// Caps content at a readable width and centers it, so text lines, cards
    /// and buttons don't stretch edge-to-edge on wide screens. No effect on
    /// phone-width screens (narrower than `maxWidth`).
    func readableWidth(_ maxWidth: CGFloat = 580) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}
