import XCTest
@testable import LookAway

final class FakeNotificationSender: NotificationSending {
    var didRequestPermission = false
    var sentNotifications: [(title: String, body: String)] = []

    func requestPermission() {
        didRequestPermission = true
    }

    func sendNotification(title: String, body: String) {
        sentNotifications.append((title: title, body: body))
    }
}

@MainActor
final class ReminderManagerTests: XCTestCase {
    var fakeNotificationSender: FakeNotificationSender!
    var manager: ReminderManager!

    override func setUp() async throws {
        fakeNotificationSender = FakeNotificationSender()

        manager = ReminderManager(
            notificationSender: fakeNotificationSender,
            shouldStartTimersAutomatically: false
        )
    }

    override func tearDown() async throws {
        manager = nil
        fakeNotificationSender = nil
    }

    func testInitialStateRequestsNotificationPermission() {
        XCTAssertTrue(fakeNotificationSender.didRequestPermission)
    }

    func testReminderTypeDefaultIntervals() {
        XCTAssertEqual(ReminderType.eyes.defaultIntervalMinutes, 20)
        XCTAssertEqual(ReminderType.stretch.defaultIntervalMinutes, 45)
        XCTAssertEqual(ReminderType.stand.defaultIntervalMinutes, 60)
    }

    func testEyesReminderSendsCorrectNotification() {
        manager.triggerReminderForTesting(.eyes)

        XCTAssertEqual(fakeNotificationSender.sentNotifications.count, 1)
        XCTAssertEqual(
            fakeNotificationSender.sentNotifications.first?.title,
            "Look away from your screen"
        )
        XCTAssertEqual(
            fakeNotificationSender.sentNotifications.first?.body,
            "Look at something far away for about 20 seconds."
        )
    }

    func testStretchReminderSendsCorrectNotification() {
        manager.triggerReminderForTesting(.stretch)

        XCTAssertEqual(fakeNotificationSender.sentNotifications.count, 1)
        XCTAssertEqual(
            fakeNotificationSender.sentNotifications.first?.title,
            "Time to stretch"
        )
    }

    func testStandReminderSendsCorrectNotification() {
        manager.triggerReminderForTesting(.stand)

        XCTAssertEqual(fakeNotificationSender.sentNotifications.count, 1)
        XCTAssertEqual(
            fakeNotificationSender.sentNotifications.first?.title,
            "Time to stand"
        )
    }

    func testPauseSuppressesNotifications() {
        manager.pause(minutes: 30)

        manager.triggerReminderForTesting(.eyes)

        XCTAssertTrue(manager.isPaused)
        XCTAssertEqual(fakeNotificationSender.sentNotifications.count, 0)
    }

    func testResumeAllowsNotificationsAgain() {
        manager.pause(minutes: 30)
        manager.resume()

        manager.triggerReminderForTesting(.eyes)

        XCTAssertFalse(manager.isPaused)
        XCTAssertEqual(fakeNotificationSender.sentNotifications.count, 1)
    }

    func testNextReminderTextShowsNoRemindersWhenAllDisabled() {
        manager.eyesEnabled = false
        manager.stretchEnabled = false
        manager.standEnabled = false

        manager.restartTimersAfterSettingsChange()

        XCTAssertEqual(manager.nextReminderText, "No reminders active")
    }

    func testNextReminderTextShowsEnabledReminders() {
        manager.eyesEnabled = true
        manager.stretchEnabled = true
        manager.standEnabled = false

        manager.eyesInterval = 20
        manager.stretchInterval = 45

        manager.restartTimersAfterSettingsChange()

        XCTAssertTrue(manager.nextReminderText.contains("Eyes: 20 min"))
        XCTAssertTrue(manager.nextReminderText.contains("Stretch: 45 min"))
        XCTAssertFalse(manager.nextReminderText.contains("Stand"))
    }

    func testCustomIntervalAppearsInReminderText() {
        manager.eyesEnabled = true
        manager.eyesInterval = 10

        manager.restartTimersAfterSettingsChange()

        XCTAssertTrue(manager.nextReminderText.contains("Eyes: 10 min"))
    }
}
