import Foundation

enum ReminderDisplayMode: String, CaseIterable, Identifiable {
    case notification = "Notification"
    case alert = "Alert"

    var id: String { rawValue }
}
