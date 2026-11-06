import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var loginItem: LoginItemController

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
        .frame(width: 460, height: 340)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
