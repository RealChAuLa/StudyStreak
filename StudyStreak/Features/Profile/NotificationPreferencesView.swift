import SwiftUI
import UIKit
import UserNotifications

struct NotificationPreferencesView: View {
    @Bindable var preferences: RoutinePreferences
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var authorization = NotificationAuthorizationService()
    @State private var isRequesting = false
    @State private var showsError = false

    private var systemAllowsNotifications: Bool {
        switch authorization.authorizationStatus {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }
    
    private var enabled: Bool { preferences.settings.notificationsEnabled && systemAllowsNotifications }

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Allow notifications",
                    isOn: Binding(
                        get: { enabled },
                        set: setEnabled
                    )
                )
                .disabled(
                    isRequesting || !authorization.hasLoadedSettings
                )

                Toggle(
                    "Streak alerts",
                    isOn: $preferences.settings.streakAlerts
                )
                .disabled(!enabled)

                Toggle(
                    "Break reminders",
                    isOn: $preferences.settings.breakReminders
                )
                .disabled(!enabled)
            } header: {
                VStack(alignment: .leading, spacing: 16) {
                    Text("A little encouragement.")
                        .font(AppTypography.title2)
                        .foregroundStyle(AppColors.text)

                    Text("Gentle reminders, at the right moment.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondary)
                }
                .textCase(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)
            }
            .listRowInsets(
                EdgeInsets(
                    top: 16,
                    leading: 16,
                    bottom: 16,
                    trailing: 16
                )
            )
            .listRowBackground(AppColors.surface)
            .listRowSeparatorTint(AppColors.border)

            if authorization.authorizationStatus == .denied {
                Section {
                    Text("Notifications are off in iOS Settings.")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColors.secondary)

                    Button("Open Settings", action: openSettings)
                        .foregroundStyle(AppColors.primary)
                }
                .listRowBackground(AppColors.surface)
            }

            reminderTime
            breakFrequency
        }
        .font(AppTypography.body)
        .foregroundStyle(AppColors.text)
        .tint(AppColors.success)
        .listSectionSpacing(16)
        .contentMargins(.horizontal, 24, for: .scrollContent)
        .contentMargins(.top, 16, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await authorization.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await authorization.refresh()
                }
            }
        }
        .alert(
            "Couldn’t request notifications",
            isPresented: $showsError
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(
                "Please try again, or enable notifications in Settings."
            )
        }
    }
    
    private var switches: some View {
        Section {
            Toggle("Allow notifications", isOn: Binding(get: { enabled }, set: setEnabled))
                .disabled(isRequesting || !authorization.hasLoadedSettings)
            Toggle("Streak alerts", isOn: $preferences.settings.streakAlerts).disabled(!enabled)
            Toggle("Break reminders", isOn: $preferences.settings.breakReminders).disabled(!enabled)
        }
        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        .listRowBackground(AppColors.surface).listRowSeparatorTint(AppColors.border)
    }

    private var reminderTime: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    icon("PreferencesClock")
                    DatePicker("Remind me at", selection: timeBinding, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact).tint(AppColors.primary)
                }
                Text("Only if you haven’t reached your daily goal.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
            }
            .padding(.vertical, 12)
            .disabled(!enabled || !preferences.settings.streakAlerts)
            .listRowBackground(AppColors.surface)
        } header: { heading("Streak reminder") }
    }

    private var breakFrequency: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    icon("PreferencesBook")
                    Picker("After focusing", selection: $preferences.settings.breakMinutes) {
                        ForEach([25, 30, 45, 60, 90, 120], id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }.tint(AppColors.secondary)
                }
                Text("A short pause helps your focus last.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
            }
            .padding(.vertical, 12)
            .disabled(!enabled || !preferences.settings.breakReminders)
            .listRowBackground(AppColors.surface)
        } header: { heading("Break reminders") }
    }

    private var timeBinding: Binding<Date> {
        Binding(get: {
            let minutes = preferences.settings.reminderMinuteOfDay
            return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        }, set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            preferences.settings.reminderMinuteOfDay = (components.hour ?? 20) * 60 + (components.minute ?? 0)
        })
    }

    private func setEnabled(_ value: Bool) {
        if !value { preferences.settings.notificationsEnabled = false; return }
        switch authorization.authorizationStatus {
        case .denied:
            preferences.settings.notificationsEnabled = true
            openSettings()
        case .notDetermined:
            preferences.settings.notificationsEnabled = true
            isRequesting = true
            Task {
                defer { isRequesting = false }
                do {
                    try await authorization.requestAccess()
                } catch { showsError = true }
            }
        default: preferences.settings.notificationsEnabled = true
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
    }

    private func heading(_ text: String) -> some View {
        Text(text.uppercased()).font(AppTypography.caption.weight(.semibold)).foregroundStyle(AppColors.secondary)
    }

    private func icon(_ name: String) -> some View {
        Image(name).resizable().scaledToFit().frame(width: 22, height: 22)
            .foregroundStyle(AppColors.primary).accessibilityHidden(true)
    }
}
