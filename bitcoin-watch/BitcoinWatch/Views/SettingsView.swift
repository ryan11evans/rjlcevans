import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.11, blue: 0.10),
                             Color(red: 0.05, green: 0.04, blue: 0.04)],
                    startPoint: .topLeading, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        ProCard()
                        NotificationsSection()
                        IconPickerSection()
                        VersionFooter()
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Shared styling

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .tracking(1.2)
            .padding(.horizontal, 24)
    }
}

// Colored icon chip, like iOS Settings rows
private struct IconChip: View {
    let systemName: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.18))
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 30, height: 30)
    }
}

private struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
    }
}

// MARK: - Pro

private struct ProCard: View {
    @ObservedObject private var pro = ProService.shared
    @State private var showPaywall = false

    var body: some View {
        Group {
            if pro.isPro {
                // Unlocked state: gold "thank you" card
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("TapBTC Pro")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("UNLOCKED")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(.white))
                        }
                        Text("Unlimited alerts — thanks for the support 🧡")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(colors: [
                                Color(red: 0.98, green: 0.62, blue: 0.15),
                                Color(red: 0.85, green: 0.42, blue: 0.04)
                            ], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
                .padding(.horizontal, 20)
            } else {
                // Locked state: hero upsell card
                Button { showPaywall = true } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 44, height: 44)
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Unlock TapBTC Pro")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Unlimited price alerts · one-time \(pro.priceText)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(colors: [
                                    Color(red: 0.98, green: 0.62, blue: 0.15),
                                    Color(red: 0.85, green: 0.42, blue: 0.04)
                                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}

// MARK: - Notifications

private struct NotificationsSection: View {
    @AppStorage("athAlertEnabled", store: .shared) private var athAlert = true
    @AppStorage("milestoneAlertEnabled", store: .shared) private var milestoneAlert = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Notifications")

            VStack(spacing: 0) {
                toggleRow(icon: "rocket.fill", tint: .orange,
                          title: "All-Time High Alerts",
                          subtitle: "When BTC sets a new record",
                          isOn: $athAlert)
                Divider()
                    .overlay(Color.white.opacity(0.06))
                    .padding(.leading, 62)
                toggleRow(icon: "hourglass", tint: Color(red: 0.75, green: 0.52, blue: 0.98),
                          title: "Halving Milestones",
                          subtitle: "Countdown alerts as the halving nears",
                          isOn: $milestoneAlert)
            }
            .modifier(CardBackground())
        }
        .onChange(of: athAlert) { _, _ in Task { await PushService.shared.sync() } }
        .onChange(of: milestoneAlert) { _, _ in Task { await PushService.shared.sync() } }
    }

    private func toggleRow(icon: String, tint: Color, title: String,
                           subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            IconChip(systemName: icon, color: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(.orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - App Icon Picker

enum AppIcon: String, CaseIterable {
    case `default` = "AppIcon"
    case gold      = "AppIcon-Gold"
    case midnight  = "AppIcon-Midnight"
    case silver    = "AppIcon-Silver"

    var displayName: String {
        switch self {
        case .default:  return "Default"
        case .gold:     return "Gold"
        case .midnight: return "Midnight"
        case .silver:   return "Silver"
        }
    }

    // nil = primary icon (system requirement)
    var alternateIconName: String? { self == .default ? nil : rawValue }

    // Accent color for the rendered preview tile
    var accentColor: Color {
        switch self {
        case .default:  return .orange
        case .gold:     return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .midnight: return Color(red: 0.4, green: 0.3, blue: 0.9)
        case .silver:   return Color(red: 0.8, green: 0.8, blue: 0.85)
        }
    }

    var backgroundColors: [Color] {
        switch self {
        case .default:  return [Color(red: 0.18, green: 0.16, blue: 0.14), Color(red: 0.07, green: 0.06, blue: 0.05)]
        case .gold:     return [Color(red: 0.20, green: 0.17, blue: 0.05), Color(red: 0.10, green: 0.08, blue: 0.02)]
        case .midnight: return [Color(red: 0.06, green: 0.05, blue: 0.15), Color(red: 0.02, green: 0.02, blue: 0.08)]
        case .silver:   return [Color(red: 0.18, green: 0.18, blue: 0.20), Color(red: 0.08, green: 0.08, blue: 0.10)]
        }
    }
}

private struct IconPickerSection: View {
    @State private var selected: AppIcon = {
        let name = UIApplication.shared.alternateIconName
        return AppIcon.allCases.first { $0.rawValue == name } ?? .default
    }()
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "App Icon")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(AppIcon.allCases, id: \.rawValue) { icon in
                        IconTile(icon: icon, isSelected: selected == icon) {
                            applyIcon(icon)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 4)
            }

            if let msg = errorMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
            }
        }
    }

    private func applyIcon(_ icon: AppIcon) {
        UIApplication.shared.setAlternateIconName(icon.alternateIconName) { error in
            if let error {
                errorMessage = error.localizedDescription
            } else {
                selected = icon
                errorMessage = nil
            }
        }
    }
}

private func loadIconImage(_ name: String) -> UIImage? {
    // Default icon lives in the asset catalog
    if let img = UIImage(named: name) { return img }
    // Alternate icons are in the AlternateIcons bundle subfolder
    let suffix = UIScreen.main.scale >= 3 ? "@3x" : "@2x"
    for candidate in ["\(name)\(suffix)", name] {
        if let path = Bundle.main.path(forResource: candidate, ofType: "png", inDirectory: "AlternateIcons"),
           let img = UIImage(contentsOfFile: path) { return img }
    }
    return nil
}

private struct IconTile: View {
    let icon: AppIcon
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if let img = loadIconImage(icon.rawValue) {
                    Image(uiImage: img)
                        .resizable()
                        .interpolation(.high)
                } else {
                    // Fallback if image not found
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.08))
                        Text("₿").font(.system(size: 28, weight: .bold))
                            .foregroundStyle(icon.accentColor)
                    }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.orange : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)

            Text(icon.displayName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundStyle(isSelected ? .orange : .secondary)
        }
        .onTapGesture(perform: onTap)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Footer

private struct VersionFooter: View {
    private var versionText: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "TapBTC \(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("₿")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.orange.opacity(0.5))
            Text(versionText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
            Text("No accounts. No ads. Just Bitcoin.")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

#if DEBUG
#Preview {
    SettingsView()
}
#endif
