import ActivityKit
import Foundation

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<BTCLiveActivityAttributes>?

    init() {
        // A fresh process (e.g. the app relaunched by a background refresh task)
        // starts with no in-memory reference, but a Live Activity from a prior
        // session may still be running on the system. Reattach to it instead of
        // starting a second one, and clean up any extras left behind by the old
        // behavior so they stop stacking in the Dynamic Island / notification.
        let existing = Activity<BTCLiveActivityAttributes>.activities
        currentActivity = existing.first
        for stale in existing.dropFirst() {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private var isEnabled: Bool {
        (UserDefaults.shared.object(forKey: "liveActivityEnabled") as? Bool) ?? true
    }

    func update(price: Double) {
        guard isEnabled else {
            endAll()
            return
        }
        let state = BTCLiveActivityAttributes.ContentState(
            price: price,
            change24h: UserDefaults.shared.loadChange24h(),
            timestamp: Date()
        )
        // Background refreshes land roughly every 10-15 min (OS-scheduled BGAppRefreshTask,
        // the fastest cadence possible without a push-driven Live Activity update). A 5-min
        // staleDate meant the Island/lock-screen card dimmed to "stale" between almost every
        // background update even though a fresh price was on the way — give it enough room
        // to cover that worst case.
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(20 * 60))
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
