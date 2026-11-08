import AppKit
import SwiftUI

final class UpdateCheckFeedback: ObservableObject {
    @Published var message: String?
    @Published var isError = false
}

struct PreferencesView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var loginItem: LoginItemController
    @ObservedObject var updateChecker: UpdateChecker
    @ObservedObject var feedback: UpdateCheckFeedback
    let uninstaller: UninstallController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                sessionPanel
                menuBarPanel
                startupPanel
                updatesPanel
                uninstallPanel
                footer
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
        .background(background.ignoresSafeArea())
        .frame(width: 520, height: 680)
        .tint(.lidwardAccent)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.16), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text("Lidward")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))

                Text("Your Mac stays awake. Even with the lid shut.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text("v\(appVersion)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
        }
    }

    // MARK: - Session

    private var sessionPanel: some View {
        panel {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Session", icon: "timer", tint: .lidwardAccent)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default session length")

                        Text("Used when you start from the menu bar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Picker("Default session length", selection: $settings.sessionDurationMinutes) {
                        ForEach(SessionDuration.allCases) { duration in
                            Text(duration.label).tag(duration.minutes)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .frame(width: 125)
                }
            }
        }
    }

    // MARK: - Settings

    private var menuBarPanel: some View {
        panel {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Menu Bar", icon: "menubar.rectangle", tint: .blue)

                settingToggle(
                    "Show session time",
                    subtitle: "Show elapsed time for indefinite sessions and remaining time for timed sessions.",
                    isOn: $settings.showSessionTimeInMenuBar
                )
            }
        }
    }

    private var startupPanel: some View {
        panel {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Startup", icon: "power", tint: .purple)

                settingToggle(
                    "Launch Lidward at login",
                    subtitle: "Start quietly in the menu bar when you log in.",
                    isOn: Binding(
                        get: { loginItem.isEnabled },
                        set: { loginItem.setEnabled($0) }
                    )
                )

                if loginItem.requiresApproval {
                    callout(
                        icon: "exclamationmark.circle.fill",
                        tint: LidwardTheme.warning,
                        message: "Approve Lidward in System Settings → General → Login Items."
                    ) {
                        Button("Open Login Items Settings") {
                            loginItem.openLoginItemsSettings()
                        }
                        .controlSize(.small)
                    }
                }

                if let error = loginItem.errorMessage {
                    callout(
                        icon: "xmark.octagon.fill",
                        tint: LidwardTheme.danger,
                        message: error
                    )
                }
            }
        }
    }

    private var updatesPanel: some View {
        panel {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Updates", icon: "arrow.triangle.2.circlepath", tint: LidwardTheme.success)

                settingToggle(
                    "Check automatically",
                    subtitle: "Looks for a new version once a day on GitHub Releases.",
                    isOn: $settings.automaticallyCheckForUpdates
                )

                Divider()

                HStack(spacing: 10) {
                    Button {
                        checkForUpdates()
                    } label: {
                        Label("Check Now", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                    .disabled(updateChecker.isChecking)

                    if updateChecker.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Spacer()

                    if let lastCheck = settings.lastUpdateCheck {
                        Text("Last checked \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if let message = feedback.message {
                    Label(
                        message,
                        systemImage: feedback.isError
                            ? "exclamationmark.triangle.fill"
                            : "checkmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(feedback.isError ? .red : .secondary)
                }

                if let update = updateChecker.availableUpdate {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lidward \(update.version) is available")
                                .font(.callout.weight(.medium))

                            Text("Download the latest release from GitHub.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        Button("Download") {
                            NSWorkspace.shared.open(update.releaseURL)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.lidwardAccent.opacity(0.10))
                    )
                } else if let error = updateChecker.errorMessage, feedback.message == nil {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var uninstallPanel: some View {
        panel(background: Color.red.opacity(0.045), border: Color.red.opacity(0.18)) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Uninstall", icon: "trash", tint: LidwardTheme.danger)

                Text("Removes Lidward, its preferences, login item, and closed-display helper.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    uninstaller.requestUninstall()
                } label: {
                    Label("Uninstall Lidward…", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.red)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Lidward \(appVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("MIT licensed")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    // MARK: - Building blocks

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            LinearGradient(
                colors: [Color.lidwardAccent.opacity(0.09), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )
        }
    }

    private func panel<Content: View>(
        background: Color = LidwardTheme.panel,
        border: Color = Color.primary.opacity(0.06),
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
    }

    private func sectionHeader(_ title: String, icon: String, tint: Color) -> some View {
        Label {
            Text(title)
                .font(.subheadline.weight(.semibold))
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(tint)
        }
    }

    private func settingToggle(
        _ title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }

    private func callout<Actions: View>(
        icon: String,
        tint: Color,
        message: String,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.callout)

            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                actions()
            }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private func checkForUpdates() {
        feedback.message = nil
        feedback.isError = false

        updateChecker.check(force: true) { error in
            if let error {
                feedback.message = "Update check failed: \(error.localizedDescription)"
                feedback.isError = true
            } else if updateChecker.availableUpdate != nil {
                feedback.message = "A newer version is available."
                feedback.isError = false
            } else {
                feedback.message = "You're up to date."
                feedback.isError = false
            }
        }
    }
}
