import SwiftUI

struct CostSummaryView: View {
    let summary: UsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cost")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                CostCard(
                    label: "Today",
                    cost: summary.todayCost,
                    tokens: summary.todayTokens,
                    isPrimary: true
                )

                CostCard(
                    label: "This Week",
                    cost: summary.weekCost,
                    tokens: nil,
                    isPrimary: false
                )

                CostCard(
                    label: "This Month",
                    cost: summary.monthCost,
                    tokens: nil,
                    isPrimary: false
                )
            }
        }
    }
}

struct CostCard: View {
    let label: String
    let cost: Double
    let tokens: UInt64?
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(formatCost(cost))
                .font(isPrimary ? .title3 : .callout)
                .fontWeight(.semibold)
                .foregroundColor(isPrimary ? .primary : .secondary)

            if let tokens = tokens {
                Text(formatTokens(tokens))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.gray.opacity(isPrimary ? 0.1 : 0.05))
        .cornerRadius(6)
    }

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 && cost > 0 {
            return "<$0.01"
        }
        return String(format: "$%.2f", cost)
    }

    private func formatTokens(_ tokens: UInt64) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM tokens", Double(tokens) / 1_000_000)
        }
        if tokens >= 1_000 {
            return String(format: "%.0fK tokens", Double(tokens) / 1_000)
        }
        return "\(tokens) tokens"
    }
}
