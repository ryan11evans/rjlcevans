import Foundation

// Asks for an App Store review at a *delightful* moment (a fired alert, a new
// ATH, a profitable open) rather than on cold launch — people rate higher when
// they're happy. Stays within Apple's limits (≤3/year, spaced out).
@MainActor
final class ReviewManager: ObservableObject {
    static let shared = ReviewManager()

    @Published var shouldPrompt = false

    private let d = UserDefaults.standard
    private let countKey = "appOpenCount"
    private let promptsKey = "reviewPromptDates"

    var openCount: Int {
        get { d.integer(forKey: countKey) }
        set { d.set(newValue, forKey: countKey) }
    }

    func recordOpen() { openCount += 1 }

    private var promptDates: [Double] {
        get { d.array(forKey: promptsKey) as? [Double] ?? [] }
        set { d.set(newValue, forKey: promptsKey) }
    }

    private var eligible: Bool {
        guard openCount >= 3 else { return false }  // used the app a little first
        let now = Date().timeIntervalSince1970
        let inYear = promptDates.filter { $0 > now - 365 * 24 * 3600 }
        guard inYear.count < 3 else { return false }                     // Apple's yearly cap
        if let last = inYear.max(), now - last < 45 * 24 * 3600 { return false }  // space them out
        return true
    }

    /// Call at a genuinely good moment. Prompts at most within Apple's limits.
    func markGoodMoment() {
        guard eligible else { return }
        promptDates = promptDates + [Date().timeIntervalSince1970]
        shouldPrompt = true
    }
}
