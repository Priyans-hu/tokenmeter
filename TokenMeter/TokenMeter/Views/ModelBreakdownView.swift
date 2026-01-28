import SwiftUI
import Charts

struct ModelBreakdownView: View {
    let breakdowns: [ModelBreakdown]

    private var totalCost: Double {
        breakdowns.reduce(0) { $0 + $1.cost }
    }

    private var sortedBreakdowns: [ModelBreakdown] {
        breakdowns.sorted { $0.cost > $1.cost }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model Breakdown")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack(alignment: .top, spacing: 16) {
                // Donut Chart
                Chart(sortedBreakdowns) { model in
                    SectorMark(
                        angle: .value("Cost", model.cost),
                        innerRadius: .ratio(0.6),
                        angularInset: 1
                    )
                    .foregroundStyle(colorFor(model))
                    .cornerRadius(3)
                }
                .frame(width: 80, height: 80)

                // Legend
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sortedBreakdowns) { model in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(colorFor(model))
                                .frame(width: 8, height: 8)

                            Text(model.displayName)
                                .font(.caption)

                            Spacer()

                            Text(formatCost(model.cost))
                                .font(.caption)
                                .fontWeight(.medium)

                            Text("(\(percentage(for: model))%)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func colorFor(_ model: ModelBreakdown) -> Color {
        if model.modelName.contains("opus") { return Color(hex: "8B5CF6") }
        if model.modelName.contains("sonnet") { return Color(hex: "3B82F6") }
        if model.modelName.contains("haiku") { return Color(hex: "10B981") }
        return .gray
    }

    private func percentage(for model: ModelBreakdown) -> Int {
        guard totalCost > 0 else { return 0 }
        return Int((model.cost / totalCost) * 100)
    }

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 && cost > 0 {
            return "<$0.01"
        }
        return String(format: "$%.2f", cost)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

#Preview {
    ModelBreakdownView(breakdowns: [
        ModelBreakdown(
            modelName: "claude-opus-4",
            inputTokens: 50000,
            outputTokens: 25000,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            cost: 1.20
        ),
        ModelBreakdown(
            modelName: "claude-sonnet-4",
            inputTokens: 80000,
            outputTokens: 40000,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            cost: 0.80
        ),
        ModelBreakdown(
            modelName: "claude-haiku-3",
            inputTokens: 200000,
            outputTokens: 100000,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            cost: 0.34
        )
    ])
    .padding()
    .frame(width: 340)
}
