import SwiftUI
import AppKit

@MainActor
final class ReminderPopupController: ObservableObject {
    
    private var panel: NSPanel?

    func show(title: String, body: String, countdownSeconds: Int = 20) {
        dismiss()

        let popupView = ReminderPopupView(
            title: title,
            message: body,
            countdownSeconds: countdownSeconds,
            dismissAction: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingController = NSHostingController(rootView: popupView)

        let panelWidth: CGFloat = 340
        let panelHeight: CGFloat = 260

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "LookAway Reminder"
        panel.contentViewController = hostingController

        // Floating keeps it above normal windows.
        panel.level = .floating

        // Allows the alert to appear across Spaces and full-screen apps when possible.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Lets the user drag the alert by its background.
        panel.isMovableByWindowBackground = true

        // Keeps the panel alive until we close it manually.
        panel.isReleasedWhenClosed = false

        // Allows transparent/material background.
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        panel.alphaValue = 0.94

        // Match system light/dark appearance automatically.
        panel.appearance = nil

        // Cleaner title bar appearance.
        panel.titlebarAppearsTransparent = true

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame

            let x = screenFrame.midX - panelWidth / 2
            let y = screenFrame.midY - panelHeight / 2

            panel.setFrame(
                NSRect(x: x, y: y, width: panelWidth, height: panelHeight),
                display: true
            )
        } else {
            panel.center()
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.panel = panel
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }
}

struct ReminderPopupView: View {
    let title: String
    let message: String
    let countdownSeconds: Int
    let dismissAction: () -> Void

    @State private var startDate = Date()
    @State private var now = Date()
    @State private var hasDismissed = false

    // This updates frequently, so the progress ring moves smoothly.
    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    private var elapsed: TimeInterval {
        now.timeIntervalSince(startDate)
    }

    private var remaining: TimeInterval {
        max(TimeInterval(countdownSeconds) - elapsed, 0)
    }

    private var secondsRemainingDisplay: Int {
        Int(ceil(remaining))
    }

    private var progress: CGFloat {
        guard countdownSeconds > 0 else {
            return 0
        }

        return CGFloat(remaining / TimeInterval(countdownSeconds))
    }

    var body: some View {
        VStack(spacing: 12) {
            countdownRing

            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Button {
                hasDismissed = true
                dismissAction()
            } label: {
                Label("Dismiss", systemImage: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 120)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.blue.gradient)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(22)
        .frame(width: 340, height: 260)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.regularMaterial)
                .opacity(0.88)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .onAppear {
            startDate = Date()
            now = Date()
            hasDismissed = false
        }
        .onReceive(timer) { date in
            now = date

            // Auto-close when the countdown finishes.
            if remaining <= 0 && !hasDismissed {
                hasDismissed = true
                dismissAction()
            }
        }
    }

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.secondary.opacity(0.20),
                    lineWidth: 8
                )

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(
                        lineWidth: 8,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(max(secondsRemainingDisplay, 0))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(max(secondsRemainingDisplay, 0) == 1 ? "sec" : "secs")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 82, height: 82)
    }
}
