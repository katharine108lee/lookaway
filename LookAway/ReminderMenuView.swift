import SwiftUI

struct ReminderMenuView: View {
    
    @EnvironmentObject var reminderManager: ReminderManager

    var body: some View {
        VStack(spacing: 14) {
            headerCard

            reminderStyleCard

            lookAwayCard

            pauseCard

            footerActions
        }
        .padding(14)
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.16))
                        .frame(width: 34, height: 34)

                    Image(systemName: "eye")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("LookAway")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))

                    Text("Screen break assistant")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                statusPill(
                    text: reminderManager.eyesEnabled ? "On" : "Off",
                    isActive: reminderManager.eyesEnabled
                )
            }

            Divider()
                .opacity(0.45)

            VStack(alignment: .leading, spacing: 4) {
                Text(reminderManager.nextReminderText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                if !reminderManager.timeRemainingText.isEmpty {
                    Text(reminderManager.timeRemainingText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .modifier(CardStyle())
    }

    // MARK: - Reminder style

    private var reminderStyleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Reminder style",
                systemImage: "rectangle.on.rectangle"
            )

            Picker(
                "",
                selection: Binding(
                    get: {
                        reminderManager.reminderDisplayMode
                    },
                    set: { newValue in
                        reminderManager.reminderDisplayMode = newValue
                    }
                )
            ) {
                ForEach(ReminderDisplayMode.allCases) { mode in
                    Text(mode.rawValue)
                        .tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Text("Choose a quiet notification or a centre-screen alert.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .modifier(CardStyle())
    }

    // MARK: - Look Away card

    private var lookAwayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(
                    title: "Look away",
                    systemImage: "timer"
                )

                Spacer()

                statusPill(
                    text: lookAwayStatusText,
                    isActive: lookAwayStatusIsActive
                )
            }

            Text("Look 20 feet away for 20 seconds while blinking slowly.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle(isOn: $reminderManager.eyesEnabled) {
                Text("Enable reminder")
                    .font(.system(size: 13, weight: .medium))
            }
            .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("Interval")
                        .font(.system(size: 13, weight: .medium))

                    Spacer()

                    Stepper(
                        value: $reminderManager.eyesInterval,
                        in: 5...180,
                        step: 5
                    ) {
                        Text("\(reminderManager.eyesInterval) min")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 58, alignment: .trailing)
                    }
                    .disabled(!reminderManager.eyesEnabled)
                }
            }

            HStack(spacing: 8) {
                MenuButton(
                    title: "Reset",
                    systemImage: "arrow.counterclockwise",
                    variant: .secondary
                ) {
                    reminderManager.resetIntervalToDefault(for: .eyes)
                }

                MenuButton(
                    title: "Test",
                    systemImage: "bell",
                    variant: .primary
                ) {
                    reminderManager.testNotification(for: .eyes)
                }
            }
        }
        .modifier(CardStyle())
        .onChange(of: reminderManager.eyesEnabled) {
            reminderManager.restartTimersAfterSettingsChange()
        }
        .onChange(of: reminderManager.eyesInterval) {
            reminderManager.restartTimersAfterSettingsChange()
        }
    }

    private var lookAwayStatusText: String {
        if reminderManager.isPaused {
            return "Paused"
        }

        if reminderManager.eyesEnabled {
            return "Active"
        }

        return "Off"
    }

    private var lookAwayStatusIsActive: Bool {
        reminderManager.eyesEnabled && !reminderManager.isPaused
    }
    // MARK: - Pause

    private var pauseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Pause reminders",
                systemImage: "pause.circle"
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 8
            ) {
                TextMenuButton(
                    title: "30 min",
                    variant: .secondary
                ) {
                    reminderManager.pause(minutes: 30)
                }

                TextMenuButton(
                    title: "1 hour",
                    variant: .secondary
                ) {
                    reminderManager.pause(minutes: 60)
                }

                TextMenuButton(
                    title: "3 hours",
                    variant: .secondary
                ) {
                    reminderManager.pauseForThreeHours()
                }

                TextMenuButton(
                    title: "Until tomorrow",
                    variant: .secondary
                ) {
                    reminderManager.pauseUntilTomorrow()
                }
            }

            MenuButton(
                title: "Resume now",
                systemImage: "play.fill",
                variant: reminderManager.isPaused ? .primary : .disabled
            ) {
                reminderManager.resume()
            }
            .disabled(!reminderManager.isPaused)
        }
        .modifier(CardStyle())
    }

    private struct TextMenuButton: View {
        let title: String
        let variant: MenuButton.Variant
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(background)
                    .foregroundStyle(foreground)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
        }

        private var background: some ShapeStyle {
            switch variant {
            case .primary:
                return AnyShapeStyle(.blue.gradient)
            case .secondary:
                return AnyShapeStyle(.secondary.opacity(0.12))
            case .disabled:
                return AnyShapeStyle(.secondary.opacity(0.08))
            }
        }

        private var foreground: some ShapeStyle {
            switch variant {
            case .primary:
                return AnyShapeStyle(.white)
            case .secondary:
                return AnyShapeStyle(.primary)
            case .disabled:
                return AnyShapeStyle(.secondary)
            }
        }
    }
    // MARK: - Footer

    private var footerActions: some View {
        HStack(spacing: 8) {
                MenuButton(
                    title: "Restart",
                    systemImage: "arrow.clockwise",
                    variant: .secondary
                ) {
                    reminderManager.restartTimersAfterSettingsChange()
                }
                .frame(width: 105)

                
                MenuButton(
                    title: "Quit",
                    systemImage: "xmark",
                    variant: .secondary
                ) {
                    NSApplication.shared.terminate(nil)
                }
                .frame(width: 82)
            }
            .padding(.horizontal, 4)
    }

    // MARK: - Small components

    private func sectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.blue)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
    }

    private func statusPill(text: String, isActive: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isActive ? .green.opacity(0.16) : .secondary.opacity(0.12))
            )
            .foregroundStyle(isActive ? .green : .secondary)
    }
}

// MARK: - Card style

private struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Custom menu button

private struct MenuButton: View {
    enum Variant {
        case primary
        case secondary
        case disabled
    }

    let title: String
    let systemImage: String
    let variant: Variant
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(background)
                .foregroundStyle(foreground)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var background: some ShapeStyle {
        switch variant {
        case .primary:
            return AnyShapeStyle(.blue.gradient)
        case .secondary:
            return AnyShapeStyle(.secondary.opacity(0.12))
        case .disabled:
            return AnyShapeStyle(.secondary.opacity(0.08))
        }
    }

    private var foreground: some ShapeStyle {
        switch variant {
        case .primary:
            return AnyShapeStyle(.white)
        case .secondary:
            return AnyShapeStyle(.primary)
        case .disabled:
            return AnyShapeStyle(.secondary)
        }
    }
    
   
}
