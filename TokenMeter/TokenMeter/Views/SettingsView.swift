import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel

    @AppStorage("refreshInterval") private var refreshInterval: Int = 300

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)

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

#Preview {
    SettingsView(viewModel: UsageViewModel())
        .frame(width: 340, height: 400)
}
