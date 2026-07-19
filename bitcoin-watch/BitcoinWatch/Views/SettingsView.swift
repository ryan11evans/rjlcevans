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
                    VStack(alignment: .leading, spacing: 28) {
                        ProSection()
                        NotificationsSection()
                        IconPickerSection()
                        SiriShortcutsSection()
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Pro

private struct ProSection: View {
    @ObservedObject private var pro = ProService.shared
    @State private var showPaywall = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TapBTC Pro")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .padding(.horizontal, 24)

            Group {
                if pro.isPro {
                    HStack(spacing: 14) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.orange)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pro Unlocked")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Unlimited alerts — thanks for the support!")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                } else {
                    Button { showPaywall = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.orange)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Unlock Pro")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("Unlimited price alerts · one-time \(pro.priceText)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
            .padding(.horizontal, 24)
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
            Text("Notifications")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .padding(.horizontal, 24)

            VStack(spacing: 0) {
                toggleRow(icon: "rocket.fill", tint: .orange,
                          title: "All-Time High Alerts",
                          subtitle: "Get a push when BTC sets a new record",
                          isOn: $athAlert)
                Divider().padding(.leading, 60)
                toggleRow(icon: "hourglass", tint: .purple,
                          title: "Halving Milestones",
                          subtitle: "Countdown alerts as the halving approaches",
                          isOn: $milestoneAlert)
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
            .padding(.horizontal, 24)
        }
        .onChange(of: athAlert) { _, _ in Task { await PushService.shared.sync() } }
        .onChange(of: milestoneAlert) { _, _ in Task { await PushService.shared.sync() } }
    }

    private func toggleRow(icon: String, tint: Color, title: String,
                           subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(.orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
            Text("App Icon")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(AppIcon.allCases, id: \.rawValue) { icon in
                        IconTile(icon: icon, isSelected: selected == icon) {
                            applyIcon(icon)
                        }
                    }
                }
                .padding(.horizontal, 24)
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
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .orange : .secondary)
        }
        .onTapGesture(perform: onTap)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Siri Shortcuts promo row

private struct SiriShortcutsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Siri")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .padding(.horizontal, 24)

            VStack(spacing: 0) {
                SiriRow(phrase: "\"What's Bitcoin at?\"",
                        subtitle: "Get the current price",
                        icon: "waveform")
                Divider().padding(.leading, 60)
                SiriRow(phrase: "\"Convert $100 to sats\"",
                        subtitle: "Satoshi calculator",
                        icon: "plusminus")
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))
            )
            .padding(.horizontal, 24)

            Text("These phrases work in Siri, Spotlight, and the Shortcuts app.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 24)
        }
    }
}

private struct SiriRow: View {
    let phrase: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(phrase)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#if DEBUG
#Preview {
    SettingsView()
}
#endif
