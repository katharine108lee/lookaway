import SwiftUI

@main
struct LookAwayApp: App {
    
    @StateObject private var reminderManager = ReminderManager()

    var body: some Scene {
        MenuBarExtra {
            ReminderMenuView()
                .environmentObject(reminderManager)
                .frame(width: 300)
        } label: {
            Label("LookAway", systemImage: "eye")

        }
        .menuBarExtraStyle(.window)
    }
}
