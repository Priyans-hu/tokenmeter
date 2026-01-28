import SwiftUI

struct RateLimitView: View {
    let title: String
    let info: WindowInfo
    let limit: UInt64

    private var percentage: Double {
        guard limit > 0 else { return 0 }
        return min(Double(info.tokensUsed) / Double(limit) * 100, 100)
    }

    private var progressColor: Color {
        if percentage >= 80 { return .red }
        if percentage >= 50 { return .orange }
        return .green
    }

    private var resetTimeText: String {
        guard let minutes = info.minutesUntilReset else { return "" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours < 24 { return "\(hours)h \(mins)m" }
        let days = hours / 24
        let remainingHours = hours % 24
        return "\(days)d \(remainingHours)h"
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
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geo.size.width * CGFloat(percentage / 100))
                }
            }
            .frame(height: 8)

            HStack {
                Text(formatTokens(info.tokensUsed))
                    .font(.caption2)
                    .fontWeight(.medium)

                Text("(\(Int(percentage))%)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                if let _ = info.minutesUntilReset {
                    Text("Resets in \(resetTimeText)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    private func formatTokens(_ tokens: UInt64) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM tokens", Double(tokens) / 1_000_000)
        }
        if tokens >= 1_000 {
            return String(format: "%.1fK tokens", Double(tokens) / 1_000)
        }
        return "\(tokens) tokens"
    }
}
