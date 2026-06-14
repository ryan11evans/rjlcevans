import Foundation

class ReviewManager {
    static let shared = ReviewManager()
    private let countKey = "appOpenCount"

    var openCount: Int {
        get { UserDefaults.standard.integer(forKey: countKey) }
        set { UserDefaults.standard.set(newValue, forKey: countKey) }
    }

    func recordOpen() { openCount += 1 }

    // Prompt at 5th open and again at 25th — Apple allows up to 3x per year
    var shouldRequestReview: Bool { openCount == 5 || openCount == 25 }
}
