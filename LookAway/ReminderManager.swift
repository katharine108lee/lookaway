import Foundation
import UserNotifications
import SwiftUI

enum ReminderType: String, CaseIterable, Identifiable {
    case eyes = "Look away"
    case stretch = "Stretch"
    case stand = "Stand"
    case posture = "Sit up straight"

    var id: String { rawValue }

    var defaultIntervalMinutes: Int {
        switch self {
        case .eyes:
            return 20
        case .stretch:
            return 45
        case .stand:
            return 60
        case .posture:
            return 30
        }
    }

    var notificationTitle: String {
        switch self {
        case .eyes:
            return "Eye Break"
        case .stretch:
            return "Time to stretch"
        case .stand:
            return "Time to stand"
        case .posture:
            return "Sit up straight"
        }
    }

    var notificationBody: String {
        switch self {
        case .eyes:
            return "Look 20 feet away for 20 seconds while blinking slowly."
        case .stretch:
            return "Roll your shoulders, stretch your neck, and reset."
        case .stand:
            return "Stand up and give your body a break."
        case .posture:
            return "Relax your shoulders, lengthen your spine, and reset your posture."
        }
    }
}

protocol NotificationSending {
    func requestPermission()
    func sendNotification(title: String, body: String)
}

final class SystemNotificationSender: NSObject, NotificationSending, UNUserNotificationCenterDelegate {
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }

            print("Notification permission granted: \(granted)")
        }
    }

    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Do not set .timeSensitive or .critical here.
        // This lets macOS Focus / Do Not Disturb suppress the notification normally.

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error.localizedDescription)")
            }
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Normal notification presentation.
        // Focus / Do Not Disturb can still suppress this at the system level.
        return [.banner, .list, .sound]
    }
}
@MainActor
final class ReminderManager: ObservableObject {
    
    // MARK: - Saved settings
    
    @AppStorage("eyesEnabled") var eyesEnabled: Bool = true
    
    // Deactivated for now.
    @AppStorage("stretchEnabled") var stretchEnabled: Bool = false
    @AppStorage("standEnabled") var standEnabled: Bool = false
    @AppStorage("postureEnabled") var postureEnabled: Bool = false

    @AppStorage("eyesInterval") var eyesInterval: Int = ReminderType.eyes.defaultIntervalMinutes
    
    // Deactivated for now.
    @AppStorage("stretchInterval") var stretchInterval: Int = ReminderType.stretch.defaultIntervalMinutes
    @AppStorage("standInterval") var standInterval: Int = ReminderType.stand.defaultIntervalMinutes
    @AppStorage("postureInterval") var postureInterval: Int = ReminderType.posture.defaultIntervalMinutes

    @AppStorage("reminderDisplayMode") private var reminderDisplayModeRawValue: String = ReminderDisplayMode.notification.rawValue
    
    @AppStorage("breakDurationSeconds") var breakDurationSeconds: Int = 20

    var reminderDisplayMode: ReminderDisplayMode {
        get {
            ReminderDisplayMode(rawValue: reminderDisplayModeRawValue) ?? .notification
        }
        set {
            reminderDisplayModeRawValue = newValue.rawValue
        }
    }

    // MARK: - Published UI state
    
    @Published var nextReminderText: String = "Starting..."
    @Published var timeRemainingText: String = ""
    @Published var isPaused: Bool = false

    // MARK: - Private state
    
    private let notificationSender: NotificationSending
    private let popupController: ReminderPopupController
    
    private var timers: [ReminderType: Timer] = [:]
    private var statusTimer: Timer?
    
    private var pauseUntil: Date?
    private var nextEyesReminderDate: Date?
    
    private let shouldStartTimersAutomatically: Bool

    init(
        notificationSender: NotificationSending = SystemNotificationSender(),
        popupController: ReminderPopupController? = nil,
        shouldStartTimersAutomatically: Bool = true
    ) {
        self.notificationSender = notificationSender
        self.popupController = popupController ?? ReminderPopupController()
        self.shouldStartTimersAutomatically = shouldStartTimersAutomatically

        notificationSender.requestPermission()

        startStatusTimer()

        if shouldStartTimersAutomatically {
            startAllTimers()
        }

        updateStatusText()
    }

    // MARK: - Timer control

    func startAllTimers() {
        stopAllReminderTimers()

        if eyesEnabled {
            startTimer(for: .eyes, intervalMinutes: eyesInterval)
            nextEyesReminderDate = Date().addingTimeInterval(TimeInterval(eyesInterval * 60))
        } else {
            nextEyesReminderDate = nil
        }

        // DEACTIVATED FOR NOW:
        //
        // if stretchEnabled {
        //     startTimer(for: .stretch, intervalMinutes: stretchInterval)
        // }
        //
        // if standEnabled {
        //     startTimer(for: .stand, intervalMinutes: standInterval)
        // }
        //
        // if postureEnabled {
        //     startTimer(for: .posture, intervalMinutes: postureInterval)
        // }

        updateStatusText()
    }

    func stopAllTimers() {
        stopAllReminderTimers()
        statusTimer?.invalidate()
        statusTimer = nil
    }

    private func stopAllReminderTimers() {
        for timer in timers.values {
            timer.invalidate()
        }

        timers.removeAll()
    }

    func restartTimersAfterSettingsChange() {
        startAllTimers()
    }

    private func startTimer(for type: ReminderType, intervalMinutes: Int) {
        let intervalSeconds = TimeInterval(intervalMinutes * 60)

        let timer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleReminder(type)
            }
        }

        timers[type] = timer
    }

    private func startStatusTimer() {
        statusTimer?.invalidate()

        statusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusText()
            }
        }
    }

    private func handleReminder(_ type: ReminderType) {
        if let pauseUntil, Date() < pauseUntil {
            return
        }

        if isPaused {
            isPaused = false
            pauseUntil = nil
        }

        showReminder(for: type)

        if type == .eyes {
            nextEyesReminderDate = Date().addingTimeInterval(TimeInterval(eyesInterval * 60))
        }

        updateStatusText()
    }

    private func showReminder(for type: ReminderType) {
        switch reminderDisplayMode {
        case .notification:
            notificationSender.sendNotification(
                title: type.notificationTitle,
                body: type.notificationBody
            )
            
        case .alert:
            popupController.show(
                title: type.notificationTitle,
                body: type.notificationBody
            )
        }
    }

    // MARK: - Pause and resume

    func pause(minutes: Int) {
        pauseUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        isPaused = true
        updateStatusText()
    }

    func pauseForThreeHours() {
        pause(minutes: 180)
    }

    func pauseUntilTomorrow() {
        let calendar = Calendar.current
        let now = Date()

        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else {
            pause(minutes: 180)
            return
        }

        // I am interpreting "until tomorrow" as tomorrow at 9 AM.
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 9
        components.minute = 0
        components.second = 0

        if let tomorrowAtNine = calendar.date(from: components) {
            pauseUntil = tomorrowAtNine
            isPaused = true
            updateStatusText()
        } else {
            pause(minutes: 180)
        }
    }

    func resume() {
        pauseUntil = nil
        isPaused = false

        if shouldStartTimersAutomatically {
            startAllTimers()
        } else {
            updateStatusText()
        }
    }

    // MARK: - Reset and test buttons

    func resetIntervalToDefault(for type: ReminderType) {
        switch type {
        case .eyes:
            eyesInterval = ReminderType.eyes.defaultIntervalMinutes
        case .stretch:
            stretchInterval = ReminderType.stretch.defaultIntervalMinutes
        case .stand:
            standInterval = ReminderType.stand.defaultIntervalMinutes
        case .posture:
            postureInterval = ReminderType.posture.defaultIntervalMinutes
        }

        restartTimersAfterSettingsChange()
    }

    func testNotification(for type: ReminderType) {
        showReminder(for: type)
    }

    func triggerReminderForTesting(_ type: ReminderType) {
        handleReminder(type)
    }

    // MARK: - Status text

    private func updateStatusText() {
        if let pauseUntil, Date() < pauseUntil {
            let remainingSeconds = pauseUntil.timeIntervalSinceNow
            let remainingMinutes = Int(ceil(remainingSeconds / 60))

            nextReminderText = "Paused"
            timeRemainingText = "Resumes in \(formatMinutes(remainingMinutes))"
            return
        }

        if !eyesEnabled {
            nextReminderText = "No reminders active"
            timeRemainingText = ""
            return
        }

        nextReminderText = "Look away: every \(eyesInterval) min"

        if let nextEyesReminderDate {
            let remainingSeconds = nextEyesReminderDate.timeIntervalSinceNow
            let remainingMinutes = max(Int(ceil(remainingSeconds / 60)), 0)
            timeRemainingText = "Next reminder in \(formatMinutes(remainingMinutes))"
        } else {
            timeRemainingText = "Next reminder not scheduled"
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        }

        let hours = minutes / 60
        let leftoverMinutes = minutes % 60

        if leftoverMinutes == 0 {
            return "\(hours) hr"
        }

        return "\(hours) hr \(leftoverMinutes) min"
    }
}
