import Foundation

enum AppIdentity {
    /// Home-screen name. The only copy of the working title is `CFBundleDisplayName`
    /// in `NewDeductions/App/Info.plist`.
    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? ""
    }
}

enum AppCopy {
    /// Required onboarding acceptance, and repeated in Settings.
    static let disclaimer = "Estimates only, not tax advice or tax-prep software."
}
