import ActivityKit
import Foundation

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<BTCLiveActivityAttributes>?

    func update(price: Double) {
        let state = BTCLiveActivityAttributes.ContentState(
            price: price,
            change24h: UserDefaults.shared.loadChange24h(),
            timestamp: Date()
        )
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(300))
        Task {
            if let activity = currentActivity, activity.activityState == .active {
                await activity.update(content)
            } else {
                start(content: content)
            }
        }
    }

    private func start(content: ActivityContent<BTCLiveActivityAttributes.ContentState>) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        currentActivity = try? Activity<BTCLiveActivityAttributes>.request(
            attributes: BTCLiveActivityAttributes(),
            content: content
        )
    }

    func endAll() {
        Task {
            for activity in Activity<BTCLiveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
