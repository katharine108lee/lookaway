import SwiftUI

@main
struct LookAwayApp: App {
    
    // This object owns the reminder logic for the whole app.
    @StateObject private var reminderManager = ReminderManager()

    var body: some Scene {
        
        // This creates a menu bar app.
        MenuBarExtra {
            ReminderMenuView()
                .environmentObject(reminderManager)
                .frame(width: 300)
        } label: {
            Label("LookAway", systemImage: "eye")
            
            // If the icon is hard to see while testing, use this instead:
            // Text("👀")
        }
        .menuBarExtraStyle(.window)
    }
}
