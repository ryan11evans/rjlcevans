import SwiftUI
import UIKit

/// Colors sampled from the app icon: emerald field, deep teal shadow, gold wedge.
enum Theme {
    static let emerald = Color.adaptive(light: 0x0A9F5A, dark: 0x1DBF6E)
    static let deepTeal = Color.adaptive(light: 0x004D4D, dark: 0xB7E0D6)
    static let ink = Color.adaptive(light: 0x07302E, dark: 0xF4FBF8)
    static let gold = Color.adaptive(light: 0xE2AE1E, dark: 0xF5C542)
    static let goldBright = Color(hex: 0xF5C542)

    static let background = Color.adaptive(light: 0xF3F7F4, dark: 0x062221)
    static let backgroundElevated = Color.adaptive(light: 0xE5F2EB, dark: 0x0C3330)
    static let card = Color.adaptive(light: 0xFFFFFF, dark: 0x103936)
    static let cardStroke = Color.adaptive(light: 0xD5E6DC, dark: 0x1C4F4A)
    static let textSecondary = Color.adaptive(light: 0x2A5C56, dark: 0xC5E4DC)
    static let track = Color.adaptive(light: 0xD7EBE1, dark: 0x164440)

    static var shadowColor: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor.black.withAlphaComponent(0.45)
            }
            return UIColor(hex: 0x004D4D).withAlphaComponent(0.10)
        })
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: 0x14C472),
                Color(hex: 0x0A9F5A),
                Color(hex: 0x087668),
                Color(hex: 0x004D4D)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }

    static func applyAppearance() {
        let background = UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? 0x062221 : 0xF3F7F4)
        }
        let primary = UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? 0xF4FBF8 : 0x07302E)
        }

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = background
        nav.shadowColor = .clear
        nav.titleTextAttributes = titleAttributes(style: .headline, color: primary, bold: true)
        nav.largeTitleTextAttributes = titleAttributes(style: .largeTitle, color: primary, bold: true)
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = background
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    private static func titleAttributes(style: UIFont.TextStyle, color: UIColor, bold: Bool) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color]
        var descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
        if let rounded = descriptor.withDesign(.rounded) {
            descriptor = rounded
        }
        if bold, let heavy = descriptor.withSymbolicTraits(.traitBold) {
            descriptor = heavy
        }
        attributes[.font] = UIFont(descriptor: descriptor, size: 0)
        return attributes
    }
}

extension Color {
    static func adaptive(light: UInt, dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    init(hex: UInt, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension UIColor {
    convenience init(hex: UInt) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}

extension View {
    func themeScreen() -> some View {
        background(Theme.background.ignoresSafeArea())
    }

    func themeGroupedList() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .tint(Theme.emerald)
    }
}

struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.22, bounce: 0.2), value: configuration.isPressed)
    }
}

struct SoftCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.card)
                    .shadow(color: Theme.shadowColor, radius: 16, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            )
    }
}

struct ChoiceCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Theme.emerald, Theme.gold, Theme.deepTeal)
                    .frame(width: 58, height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isSelected ? Theme.gold.opacity(0.28) : Theme.backgroundElevated)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Theme.rounded(.title3, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(Theme.rounded(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Theme.emerald : Theme.cardStroke)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? Theme.emerald.opacity(0.12) : Theme.card)
                    .shadow(color: Theme.shadowColor, radius: isSelected ? 14 : 10, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? Theme.emerald : Theme.cardStroke, lineWidth: isSelected ? 2.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct KindNote: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.body.weight(.semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Theme.gold, Theme.emerald)
                .accessibilityHidden(true)
                .padding(.top, 2)
            Text(text)
                .font(Theme.rounded(.subheadline))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.gold.opacity(0.18))
        )
        .accessibilityElement(children: .combine)
    }
}

struct ThemeButton: View {
    let title: String
    var enabled: Bool
    var isLoading = false
    let action: () -> Void

    private var showsFill: Bool { enabled || isLoading }

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(Theme.rounded(.headline, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 26)
            .padding(.vertical, 16)
            .foregroundStyle(showsFill ? Color.white : Theme.textSecondary)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(showsFill ? AnyShapeStyle(Theme.heroGradient) : AnyShapeStyle(Theme.track))
            )
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled || isLoading)
    }
}

struct ThemeMoney: View {
    var amount: Decimal
    var style: Font.TextStyle = .title2
    var alignment: TextAlignment = .leading
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(AppFormatting.currency(amount))
            .font(Theme.rounded(style, weight: .bold))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(alignment)
            .contentTransition(.numericText())
            .animation(reduceMotion ? nil : .snappy, value: amount)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    private var frameAlignment: Alignment {
        alignment == .center ? .center : .leading
    }
}

enum Haptics {
    static func select() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

struct EstimateFootnote: View {
    var body: some View {
        Text(AppCopy.estimateFootnote)
            .font(Theme.rounded(.caption))
            .foregroundStyle(Theme.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

struct CardBlock<Content: View>: View {
    var title: String
    var footer: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 12) {
                ThemeSectionHeader(title)
                content()
                if let footer {
                    Text(footer)
                        .font(Theme.rounded(.footnote))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct ThemeSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(Theme.rounded(.subheadline, weight: .semibold))
            .foregroundStyle(Theme.deepTeal)
            .textCase(nil)
    }
}

struct StopwatchHero: View {
    var diameter: CGFloat = 210
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var typeScale: CGFloat = 1
    @State private var lit = false

    private var size: CGFloat { diameter * min(max(typeScale, 0.85), 1.4) }

    var body: some View {
        let crownHeight = size * 0.075
        VStack(spacing: -crownHeight * 0.45) {
            ZStack {
                Capsule(style: .continuous)
                    .fill(Color.white)
                    .frame(width: size * 0.18, height: crownHeight)
                Circle()
                    .fill(Theme.heroGradient)
                    .frame(width: size * 0.045, height: size * 0.045)
            }
            .accessibilityHidden(true)

            ZStack {
                Circle()
                    .fill(Theme.emerald.opacity(0.28))
                    .blur(radius: 22)
                    .padding(size * 0.08)

                Circle()
                    .fill(Theme.heroGradient)

                PieSlice(
                    startAngle: .degrees(-10),
                    endAngle: .degrees(lit ? 66 : 36)
                )
                .fill(Theme.goldBright)
                .padding(size * 0.075)

                Circle()
                    .stroke(Color.white, lineWidth: max(6, size * 0.048))

                ticks

                Image(systemName: "car.fill")
                    .font(.system(size: size * 0.16, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(y: size * 0.16)
                    .accessibilityHidden(true)

                Capsule()
                    .fill(Color.white)
                    .frame(width: max(4, size * 0.028), height: size * 0.28)
                    .offset(y: -size * 0.11)
                    .rotationEffect(.degrees(lit ? 46 : 26))

                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.07, height: size * 0.07)
            }
            .frame(width: size, height: size)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reduceMotion
            ? "Stopwatch with a gold slice and a car"
            : "Animated stopwatch with a gold slice and a car")
        .onAppear(perform: start)
    }

    private var ticks: some View {
        ForEach(0..<12, id: \.self) { tick in
            Capsule()
                .fill(Color.white.opacity(tick % 3 == 0 ? 0.95 : 0.48))
                .frame(
                    width: tick % 3 == 0 ? max(2, size * 0.016) : max(1.5, size * 0.01),
                    height: tick % 3 == 0 ? size * 0.07 : size * 0.042
                )
                .offset(y: -size * 0.36)
                .rotationEffect(.degrees(Double(tick) / 12 * 360))
        }
        .accessibilityHidden(true)
    }

    private func start() {
        guard !reduceMotion else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { lit = true }
            return
        }
        withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
            lit = true
        }
    }
}

struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle.radians, endAngle.radians) }
        set {
            startAngle = .radians(newValue.first)
            endAngle = .radians(newValue.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}
