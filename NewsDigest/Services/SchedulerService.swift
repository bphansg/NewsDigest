import Foundation
import Combine
import UserNotifications

/// Runs periodic news fetching in the background.
@MainActor
class SchedulerService: ObservableObject {
    static let shared = SchedulerService()

    @Published var lastFetchDate: Date?
    @Published var nextFetchDate: Date?
    @Published var isFetching = false
    @Published var fetchIntervalMinutes: Int = 60 // Default: every hour

    private var timer: Timer?

    /// Start the background scheduler.
    func start() {
        stop()
        scheduleNext()
        print("📡 Scheduler started — fetching every \(fetchIntervalMinutes) minutes")
    }

    /// Stop the background scheduler.
    func stop() {
        timer?.invalidate()
        timer = nil
        nextFetchDate = nil
    }

    private func scheduleNext() {
        let interval = TimeInterval(fetchIntervalMinutes * 60)
        nextFetchDate = Date().addingTimeInterval(interval)

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performFetch()
            }
        }
    }

    /// Perform an immediate fetch.
    func performFetch() async {
        guard !isFetching else { return }
        isFetching = true
        defer {
            isFetching = false
            lastFetchDate = Date()
        }

        print("📡 Starting news fetch...")

        // This will be called from the ViewModel which has access to SwiftData context
        NotificationCenter.default.post(name: .newsFetchRequested, object: nil)
    }

    /// Request notification permission and send a local notification when new articles arrive.
    func sendNotification(articleCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "News Digest Updated"
        content.body = "\(articleCount) new articles curated for you."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notifications enabled")
            }
        }
    }
}

extension Notification.Name {
    static let newsFetchRequested = Notification.Name("newsFetchRequested")
}
