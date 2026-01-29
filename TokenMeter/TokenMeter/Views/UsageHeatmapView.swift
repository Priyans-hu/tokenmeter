import SwiftUI

struct UsageHeatmapView: View {
    let hourly: [HourlyUsage]

    @State private var selectedDays: Int = 7

    private var filteredData: [String: [Int: UInt64]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedDays, to: Date())!
        let cutoffStr = formatter.string(from: cutoff)

        var result: [String: [Int: UInt64]] = [:]
        for entry in hourly {
            guard entry.date >= cutoffStr else { continue }
            var dayData = result[entry.date] ?? [:]
            dayData[entry.hour, default: 0] += entry.outputTokens
            result[entry.date] = dayData
        }
        return result
    }

    private var sortedDates: [String] {
        filteredData.keys.sorted()
    }

    private var maxTokens: UInt64 {
        filteredData.values.flatMap { $0.values }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Usage Heatmap")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                Picker("", selection: $selectedDays) {
                    Text("7d").tag(7)
                    Text("14d").tag(14)
                    Text("30d").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            if sortedDates.isEmpty {
                Text("No usage data")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                // Hour labels
                HStack(spacing: 0) {
                    Text("")
                        .frame(width: 32)

                    ForEach([0, 3, 6, 9, 12, 15, 18, 21], id: \.self) { hour in
                        Text(hourLabel(hour))
                            .font(.system(size: 7))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Grid rows
                ForEach(sortedDates.suffix(selectedDays), id: \.self) { date in
                    HStack(spacing: 1) {
                        Text(shortDateLabel(date))
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .frame(width: 32, alignment: .leading)

                        ForEach(0..<24, id: \.self) { hour in
                            let tokens = filteredData[date]?[hour] ?? 0
                            let intensity = maxTokens > 0 ? Double(tokens) / Double(maxTokens) : 0

                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(cellColor(intensity: intensity))
                                .frame(height: 10)
                                .help(cellTooltip(date: date, hour: hour, tokens: tokens))
                        }
                    }
                }

                // Legend
                HStack(spacing: 4) {
                    Spacer()
                    Text("Less")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(cellColor(intensity: level))
                            .frame(width: 10, height: 10)
                    }
                    Text("More")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Helpers

    private func cellColor(intensity: Double) -> Color {
        if intensity == 0 { return Color.gray.opacity(0.1) }
        return Color.green.opacity(0.2 + intensity * 0.8)
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    private func shortDateLabel(_ date: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let d = formatter.date(from: date) else { return date }
        let display = DateFormatter()
        display.dateFormat = "E d"
        return display.string(from: d)
    }

    private func cellTooltip(date: String, hour: Int, tokens: UInt64) -> String {
        let h = hourLabel(hour)
        if tokens == 0 { return "\(date) \(h): no usage" }
        if tokens >= 1_000_000 {
            return "\(date) \(h): \(String(format: "%.1fM", Double(tokens) / 1_000_000)) output tokens"
        }
        if tokens >= 1_000 {
            return "\(date) \(h): \(String(format: "%.1fK", Double(tokens) / 1_000)) output tokens"
        }
        return "\(date) \(h): \(tokens) output tokens"
    }
}
