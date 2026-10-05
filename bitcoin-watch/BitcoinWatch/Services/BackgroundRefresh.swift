import BackgroundTasks

// Register and handle BGAppRefreshTask.
// iOS schedules these roughly every 10-15 min in practice, which is the
// fastest possible background fetch rate on iOS without a persistent connection.
enum BackgroundRefresh {
    static let taskIdentifier = "com.rjlcevans.bitcoinwatch.refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            handle(task: task as! BGAppRefreshTask)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 10 * 60)  // no sooner than 10 min
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(task: BGAppRefreshTask) {
        schedule()  // Re-schedule immediately so chain continues

        // Guard against calling setTaskCompleted twice (once from the fetch
        // finishing normally, once from expirationHandler firing around the
        // same time) — iOS throttles future background budget for apps that
        // double-complete a task.
        let lock = NSLock()
        var completed = false
        let complete: (Bool) -> Void = { success in
            lock.lock(); defer { lock.unlock() }
            guard !completed else { return }
            completed = true
            task.setTaskCompleted(success: success)
        }

        let fetchTask = Task { @MainActor in
            // Pull the server's fired-state first — same reason as the
            // foreground path in BitcoinWatchApp.swift: without this, an alert
            // the server already pushed while the app was closed can fire a
            // second, local notification here.
            await PushService.shared.sync()
            await PriceService.shared.fetchPrice()
            complete(true)
        }

        task.expirationHandler = {
            fetchTask.cancel()
            complete(false)
        }
    }
}
