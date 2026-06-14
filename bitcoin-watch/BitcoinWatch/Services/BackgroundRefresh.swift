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

        let fetchTask = Task {
            await PriceService.shared.fetchPrice()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            fetchTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
