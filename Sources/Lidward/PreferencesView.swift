import AppKit
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var loginItem: LoginItemController
    @ObservedObject var updateChecker: UpdateChecker
    let uninstaller: UninstallController

    var body: some View {
        Form {
            Section("Menu Bar") {
                Toggle("Show session elapsed time", isOn: $settings.showSessionTimeInMenuBar)
            }

            Section("Appearance") {
                Toggle("Hide Lidward in the Dock", isOn: $settings.hideInDock)
            }

            Section("Startup") {
                Toggle(
                    "Launch Lidward at login",
                    isOn: Binding(
                        get: { loginItem.isEnabled },
                        set: { loginItem.setEnabled($0) }
                    )
                )

                if loginItem.requiresApproval {
                    Text("Approve Lidward in System Settings → General → Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Open Login Items Settings") {
                        loginItem.openLoginItemsSettings()
                    }
                }

                if let error = loginItem.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Updates") {
                Toggle(
                    "Check for updates automatically (once a day)",
                    isOn: $settings.automaticallyCheckForUpdates
                )

                HStack {
                    Button("Check Now") {
                        updateChecker.check(force: true)
                    }
                    .disabled(updateChecker.isChecking)

                    if updateChecker.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let update = updateChecker.availableUpdate {
                    HStack {
                        Text("Lidward \(update.version) is available.")
                        Spacer()
                        Button("Download") {
                            NSWorkspace.shared.open(update.releaseURL)
                        }
                    }
                } else if let lastCheck = settings.lastUpdateCheck {
                    Text("Last checked \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = updateChecker.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Uninstall") {
                Text("Removes Lidward, its preferences, login item, and closed-display helper.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Uninstall Lidward…", role: .destructive) {
                    uninstaller.requestUninstall()
                }
            }

            Section {
                HStack {
                    Text("Lidward \(appVersion)")
                    Spacer()
                    Text("MIT licensed")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 520)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
