import SwiftUI

// Pro-exclusive accent color for the Home Screen widgets, mirroring the
// AppIcon color families so a Pro user's widget can match their icon.
enum WidgetTheme: String, CaseIterable {
    case `default`
    case gold
    case midnight
    case silver
    case emerald
    case rose

    private static let key = "widgetTheme"

    static var current: WidgetTheme {
        get { WidgetTheme(rawValue: UserDefaults.shared.string(forKey: key) ?? "") ?? .default }
        set { UserDefaults.shared.set(newValue.rawValue, forKey: key) }
    }

    var displayName: String {
        switch self {
        case .default:  return "Default"
        case .gold:     return "Gold"
        case .midnight: return "Midnight"
        case .silver:   return "Silver"
        case .emerald:  return "Emerald"
        case .rose:     return "Rose"
        }
    }

    // Default & Silver are free; Gold, Midnight, Emerald & Rose are Pro-exclusive.
    var isPro: Bool { self != .default && self != .silver }

    var accentColor: Color {
        switch self {
        case .default:  return .orange
        case .gold:     return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .midnight: return Color(red: 0.4, green: 0.3, blue: 0.9)
        case .silver:   return Color(red: 0.8, green: 0.8, blue: 0.85)
        case .emerald:  return Color(red: 0.29, green: 0.85, blue: 0.5)
        case .rose:     return Color(red: 1.0, green: 0.42, blue: 0.71)
        }
    }
}
