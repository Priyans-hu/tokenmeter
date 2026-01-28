import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(viewModel: viewModel)

            Divider()

            if viewModel.showSettings {
                SettingsView(viewModel: viewModel)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        // Update Banner
                        if let update = viewModel.updateInfo {
                            UpdateBannerView(update: update, onDismiss: viewModel.dismissUpdate)
                        }

                        // Error Banner
                        if let error = viewModel.errorMessage {
                            ErrorBannerView(message: error)
                        }

                        if let summary = viewModel.summary {
                            // Rate Limits
                            RateLimitView(
                                title: "5-Hour Session",
                                info: summary.rateLimits.session,
                                outputLimit: viewModel.selectedPlan.sessionOutputLimit
                            )

                            RateLimitView(
                                title: "Weekly (7 days)",
                                info: summary.rateLimits.weekly,
                                outputLimit: viewModel.selectedPlan.weeklyOutputLimit
                            )

                            Divider()
                                .padding(.vertical, 4)

                            // Cost Summary
                            CostSummaryView(summary: summary)

                            Divider()
                                .padding(.vertical, 4)

                            // Daily Chart
                            DailyChartView(daily: summary.daily)

                            // Model Breakdown
                            if !summary.todayModelBreakdowns.isEmpty {
                                Divider()
                                    .padding(.vertical, 4)

                                ModelBreakdownView(breakdowns: summary.todayModelBreakdowns)
                            }
                        } else if viewModel.isLoading {
                            ProgressView()
                                .padding(40)
                        } else {
                            Text("No data yet")
                                .foregroundColor(.secondary)
                                .padding(40)
                        }

                        // Quick Links
                        QuickLinksView()
                    }
                    .padding(12)
                }
            }
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Header View

struct HeaderView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        HStack {
            Text("TokenMeter")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            if let summary = viewModel.summary {
                Text(relativeTime(from: summary.lastUpdated))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: viewModel.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)

            Button {
                viewModel.showSettings.toggle()
            } label: {
                Image(systemName: viewModel.showSettings ? "xmark" : "gearshape")
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }

    private func relativeTime(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return "" }

        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

// MARK: - Update Banner

struct UpdateBannerView: View {
    let update: UpdateInfo
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Update Available: v\(update.version)")
                    .font(.caption)
                    .fontWeight(.medium)

                Link("Download", destination: URL(string: update.url)!)
                    .font(.caption2)
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Error Banner

struct ErrorBannerView: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)

            Text(message)
                .font(.caption)
                .foregroundColor(.red)

            Spacer()
        }
        .padding(8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Quick Links

struct QuickLinksView: View {
    var body: some View {
        VStack(spacing: 8) {
            Link(destination: URL(string: "https://console.anthropic.com/settings/usage")!) {
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                    Text("Usage Dashboard")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
                .font(.caption)
            }
            .buttonStyle(.plain)

            Link(destination: URL(string: "https://status.anthropic.com")!) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Status Page")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
                .font(.caption)
            }
            .buttonStyle(.plain)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit TokenMeter")
                    Spacer()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }
}
