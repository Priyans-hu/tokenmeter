import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel

    @AppStorage("refreshInterval") private var refreshInterval: Int = 300

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)

            // Plan Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Claude Plan")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Plan", selection: $viewModel.selectedPlan) {
                    ForEach(ClaudePlan.allCases, id: \.self) { plan in
                        Text(plan.displayName).tag(plan)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                Text("Used when API data is unavailable")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Divider()

            // Notifications
            VStack(alignment: .leading, spacing: 8) {
                Text("Notifications")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Alert at 80% rate limit", isOn: $viewModel.notificationsEnabled)
                    .font(.caption)
            }

            Divider()

            // Refresh Interval
            VStack(alignment: .leading, spacing: 8) {
                Text("Refresh Interval")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Refresh Interval", selection: $refreshInterval) {
                    Text("1 minute").tag(60)
                    Text("5 minutes").tag(300)
                    Text("10 minutes").tag(600)
                    Text("15 minutes").tag(900)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Divider()

            // About
            VStack(alignment: .leading, spacing: 8) {
                Text("About")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.appVersion)
                        .foregroundColor(.secondary)
                }
                .font(.caption)

                Link(destination: URL(string: "https://github.com/Priyans-hu/tokenmeter")!) {
                    HStack {
                        Text("GitHub Repository")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                Task { await viewModel.checkForUpdates() }
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle")
                    Text("Check for Updates")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
    }
}
