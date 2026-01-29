import SwiftUI
import Charts

struct DailyChartView: View {
    let daily: [DailyUsage]

    @State private var selectedRange: Int = 7

    private var filteredData: [DailyUsage] {
        let sorted = daily.sorted { $0.date < $1.date }
        return Array(sorted.suffix(selectedRange))
    }

    private var maxCost: Double {
        filteredData.map(\.totalCost).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Daily Cost")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                Picker("Range", selection: $selectedRange) {
                    Text("7d").tag(7)
                    Text("14d").tag(14)
                    Text("30d").tag(30)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 120)
            }

            if filteredData.isEmpty {
                Text("No data")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(filteredData) { day in
                    BarMark(
                        x: .value("Date", formatDateLabel(day.date)),
                        y: .value("Cost", day.totalCost)
                    )
                    .foregroundStyle(barColor(for: day.totalCost))
                    .cornerRadius(2)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        if let cost = value.as(Double.self) {
                            AxisValueLabel {
                                Text(formatAxisCost(cost))
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        if let label = value.as(String.self) {
                            AxisValueLabel {
                                Text(label)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 100)
            }
        }
    }

    private func formatDateLabel(_ dateStr: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "EEE"

        if let date = inputFormatter.date(from: dateStr) {
            return outputFormatter.string(from: date)
        }
        return dateStr.suffix(2).description
    }

    private func formatAxisCost(_ cost: Double) -> String {
        if cost >= 1 {
            return String(format: "$%.0f", cost)
        }
        return String(format: "$%.1f", cost)
    }

    private func barColor(for cost: Double) -> Color {
        let ratio = maxCost > 0 ? cost / maxCost : 0
        if ratio >= 0.8 { return .red }
        if ratio >= 0.5 { return .orange }
        return .blue
    }
}
