import Foundation

// Asks for an App Store review at a *delightful* moment (a fired alert, a new
// ATH, a profitable open) rather than on cold launch — people rate higher when
// they're happy. Stays within Apple's limits (≤3/year, spaced out).
@MainActor
final class ReviewManager: ObservableObject {
    static let shared = ReviewManager()

    @Published var shouldPrompt = false

    /// Set once this launch has decided whether to ask for a review.
    private(set) var didDecideReviewThisSession = false
    /// True for the rest of the process after a review prompt is scheduled.
    private(set) var promptedThisSession = false

    /// The post-holdings sheet stays quiet until this launch's review decision
    /// is in, and stays quiet for the whole session when a review will show.
    var blocksStackPrompt: Bool {
        !didDecideReviewThisSession || promptedThisSession || shouldPrompt
    }

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
        promptedThisSession = true
    }

    /// ContentView calls this after the open-time review decision, including
    /// when no prompt was earned, so other sheets know the session is free.
    func noteReviewDecisionFinished() {
        didDecideReviewThisSession = true
        if shouldPrompt { promptedThisSession = true }
    }
}

// One full-screen "put your stack everywhere" moment after the first holdings
// save, plus a single later chance on a profitable open. Never shares a
// session with ReviewManager's review prompt.
@MainActor
final class StackEverywherePrompt: ObservableObject {
    static let shared = StackEverywherePrompt()

    /// Drives the sheet on the main screen (deferred show, or a later profitable open).
    @Published var isPresented = false
    /// Bumped when the holdings editor is on screen and should present instead.
    @Published var handoffToken = 0
    /// True while the holdings editor sheet is on screen.
    var editorOnScreen = false

    private let countKey = "stackEverywhereShowCount"
    private let deferredKey = "stackEverywhereDeferred"
    private var presentedThisSession = false

    private var showCount: Int {
        get { UserDefaults.standard.integer(forKey: countKey) }
        set { UserDefaults.standard.set(newValue, forKey: countKey) }
    }

    /// A buy just saved and the user still holds Bitcoin.
    func noteSuccessfulSave() {
        guard !ProService.shared.isPro else { return }
        guard HoldingsService.shared.hasHoldings else { return }
        guard showCount == 0, !presentedThisSession else { return }
        guard !ReviewManager.shared.blocksStackPrompt else {
            UserDefaults.standard.set(true, forKey: deferredKey)
            return
        }
        present()
    }

    /// First show was postponed because a review prompt owned the session
    /// (or the review decision hadn't finished yet).
    func considerDeferredFirstShow() {
        guard UserDefaults.standard.bool(forKey: deferredKey) else { return }
        guard showCount == 0, !presentedThisSession else { return }
        if ProService.shared.isPro {
            UserDefaults.standard.set(false, forKey: deferredKey)
            return
        }
        guard HoldingsService.shared.hasHoldings else { return }
        guard !ReviewManager.shared.blocksStackPrompt else { return }
        present()
    }

    /// One extra chance on a later profitable open. Skipped in the session
    /// the sheet already appeared, and whenever a review prompt is due.
    func considerProfitableOpen(isProfitable: Bool) {
        guard isProfitable else { return }
        guard showCount == 1, !presentedThisSession else { return }
        guard !ProService.shared.isPro, HoldingsService.shared.hasHoldings else { return }
        guard !ReviewManager.shared.blocksStackPrompt else { return }
        present()
    }

    private func present() {
        // The first-launch Pro walkthrough owns the screen. A later save or
        // open can still show this; don't cover the walkthrough with it.
        guard !ProWalkthrough.suppressOtherPrompts else { return }
        presentedThisSession = true
        showCount += 1
        UserDefaults.standard.set(false, forKey: deferredKey)
        if editorOnScreen {
            handoffToken += 1
        } else {
            isPresented = true
        }
    }
}
