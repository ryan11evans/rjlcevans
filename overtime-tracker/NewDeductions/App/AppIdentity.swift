import Foundation

enum AppIdentity {
    /// Home-screen name. The only copy of the working title is `CFBundleDisplayName`
    /// in `NewDeductions/App/Info.plist`. Stays "New Deductions".
    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? ""
    }

    /// App Store listing name. Set in App Store Connect. Not the home-screen name.
    static let appStoreName = "New Deductions: OT + Car Loan"
}

enum AppCopy {
    /// Required onboarding acceptance, and repeated in Settings.
    /// The Social Security number question lives in this sentence instead of its own step.
    static let disclaimer = "Estimates only, not tax advice or tax-prep software. The overtime deduction needs a valid Social Security number."
    /// One-line footnote on every estimate screen.
    static let estimateFootnote = "Estimates only, not tax advice"
}
