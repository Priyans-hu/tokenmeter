import SwiftUI

struct RateLimitView: View {
    let title: String
    let info: WindowInfo
    let outputLimit: UInt64
    var apiUtilization: APIWindowUtilization?

    private var hasAPI: Bool { apiUtilization != nil }

    private var percentage: Double {
        if let api = apiUtilization {
            return min(api.utilization, 100)
        }
        guard outputLimit > 0 else { return 0 }
        return min(Double(info.outputTokens) / Double(outputLimit) * 100, 100)
    }

    private var progressColor: Color {
        if percentage >= 80 { return .red }
        if percentage >= 50 { return .orange }
        return .green
    }

    private var resetTimeText: String? {
        if let api = apiUtilization, let resetsAt = api.resetsAt {
            return formatAPIResetTime(resetsAt)
        }
        guard let minutes = info.minutesUntilReset else { return nil }
        return formatMinutes(minutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                if info.sessionsActive > 0 {
                    Text("\(info.sessionsActive) session\(info.sessionsActive == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geo.size.width * CGFloat(percentage / 100))
                }
            }
            .frame(height: 8)

            HStack {
                if hasAPI {
                    Text(String(format: "%.1f%%", percentage))
                        .font(.caption2)
                        .fontWeight(.medium)

                    Text("used")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(formatTokens(info.outputTokens)) / \(formatTokens(outputLimit))")
                        .font(.caption2)
                        .fontWeight(.medium)

                    Text("(\(Int(percentage))%)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let reset = resetTimeText {
                    Text("Resets in \(reset)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if hasAPI {
                Text("Output tokens (\(formatTokens(info.outputTokens)) used)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
            } else {
                Text("Output tokens (limits are estimates)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Formatting

    private func formatTokens(_ tokens: UInt64) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        }
        if tokens >= 1_000 {
            return String(format: "%.1fK", Double(tokens) / 1_000)
        }
        return "\(tokens)"
    }

    private func formatMinutes(_ minutes: UInt32) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours < 24 { return "\(hours)h \(mins)m" }
        let days = hours / 24
        let remainingHours = hours % 24
        return "\(days)d \(remainingHours)h"
    }

    private func formatAPIResetTime(_ iso: String) -> String? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var resetDate = formatter.date(from: iso)
        if resetDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            resetDate = formatter.date(from: iso)
        }
        guard let date = resetDate else { return nil }
        let seconds = date.timeIntervalSinceNow
        guard seconds > 0 else { return nil }
        let minutes = UInt32(seconds / 60)
        return formatMinutes(minutes)
    }
}
