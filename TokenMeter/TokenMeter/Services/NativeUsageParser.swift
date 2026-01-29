import Foundation

struct ParseResult {
    let daily: [DailyUsage]
    let rateLimits: RateLimitInfo
}

struct NativeUsageParser {
    private let projectsDirs: [URL]

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        projectsDirs = [
            home.appendingPathComponent(".claude/projects"),
            home.appendingPathComponent(".config/claude/projects"),
        ]
    }

    func parse(days: Int = 30) -> ParseResult {
        let now = Date()
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now)!

        var rawEntries: [ParsedEntry] = []
        for dir in projectsDirs {
            rawEntries.append(contentsOf: scanJSONLFiles(in: dir, modifiedAfter: cutoff))
        }

        // Deduplicate by requestId — Claude Code writes multiple JSONL lines
        // per API request (one per content block), all with identical usage data.
        let entries = deduplicateByRequestId(rawEntries)

        let daily = aggregateDailyUsage(entries: entries, since: cutoff)
        let rateLimits = computeRateLimits(entries: entries, now: now)

        return ParseResult(daily: daily, rateLimits: rateLimits)
    }

    // MARK: - File Scanning

    private func scanJSONLFiles(in dir: URL, modifiedAfter: Date) -> [ParsedEntry] {
        var entries: [ParsedEntry] = []
        let fm = FileManager.default

        guard fm.fileExists(atPath: dir.path),
              let enumerator = fm.enumerator(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return entries }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl" else { continue }

            if let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               modDate < modifiedAfter {
                continue
            }

            if let fileEntries = parseJSONLFile(at: fileURL) {
                entries.append(contentsOf: fileEntries)
            }
        }

        return entries
    }

    private func parseJSONLFile(at url: URL) -> [ParsedEntry]? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var entries: [ParsedEntry] = []
        let decoder = JSONDecoder()

        for line in content.components(separatedBy: .newlines) {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let raw = try? decoder.decode(RawJournalEntry.self, from: data),
                  raw.type == "assistant",
                  let usage = raw.message?.usage,
                  let model = raw.message?.model,
                  model != "<synthetic>",
                  let timestamp = raw.parsedTimestamp else { continue }

            entries.append(ParsedEntry(
                timestamp: timestamp,
                sessionId: raw.sessionId,
                requestId: raw.requestId,
                model: model,
                inputTokens: UInt64(usage.inputTokens ?? 0),
                outputTokens: UInt64(usage.outputTokens ?? 0),
                cacheCreationTokens: UInt64(usage.cacheCreationInputTokens ?? 0),
                cacheReadTokens: UInt64(usage.cacheReadInputTokens ?? 0)
            ))
        }

        return entries
    }

    // MARK: - Deduplication

    private func deduplicateByRequestId(_ entries: [ParsedEntry]) -> [ParsedEntry] {
        var seen = Set<String>()
        var result: [ParsedEntry] = []

        for entry in entries {
            guard let rid = entry.requestId else {
                result.append(entry)
                continue
            }
            if seen.insert(rid).inserted {
                result.append(entry)
            }
        }

        return result
    }

    // MARK: - Daily Aggregation

    private func aggregateDailyUsage(entries: [ParsedEntry], since: Date) -> [DailyUsage] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var dayMap: [String: DayAccumulator] = [:]

        for entry in entries {
            guard entry.timestamp >= since else { continue }

            let dateStr = dateFormatter.string(from: entry.timestamp)
            var acc = dayMap[dateStr] ?? DayAccumulator()

            acc.inputTokens += entry.inputTokens
            acc.outputTokens += entry.outputTokens
            acc.cacheCreationTokens += entry.cacheCreationTokens
            acc.cacheReadTokens += entry.cacheReadTokens
            acc.models.insert(entry.model)

            var modelAcc = acc.modelAccumulators[entry.model] ?? ModelAccumulator()
            modelAcc.inputTokens += entry.inputTokens
            modelAcc.outputTokens += entry.outputTokens
            modelAcc.cacheCreationTokens += entry.cacheCreationTokens
            modelAcc.cacheReadTokens += entry.cacheReadTokens
            acc.modelAccumulators[entry.model] = modelAcc

            dayMap[dateStr] = acc
        }

        return dayMap.map { (date, acc) in
            let totalTokens = acc.inputTokens + acc.outputTokens + acc.cacheCreationTokens + acc.cacheReadTokens

            let modelBreakdowns: [ModelBreakdown] = acc.modelAccumulators.map { (model, modelAcc) in
                let pricing = TokenPricing.forModel(model)
                let cost = pricing.cost(
                    input: modelAcc.inputTokens,
                    output: modelAcc.outputTokens,
                    cacheCreation: modelAcc.cacheCreationTokens,
                    cacheRead: modelAcc.cacheReadTokens
                )
                return ModelBreakdown(
                    modelName: model,
                    inputTokens: modelAcc.inputTokens,
                    outputTokens: modelAcc.outputTokens,
                    cacheCreationTokens: modelAcc.cacheCreationTokens,
                    cacheReadTokens: modelAcc.cacheReadTokens,
                    cost: cost
                )
            }.sorted { $0.cost > $1.cost }

            let totalCost = modelBreakdowns.reduce(0) { $0 + $1.cost }

            return DailyUsage(
                date: date,
                inputTokens: acc.inputTokens,
                outputTokens: acc.outputTokens,
                cacheCreationTokens: acc.cacheCreationTokens,
                cacheReadTokens: acc.cacheReadTokens,
                totalTokens: totalTokens,
                totalCost: totalCost,
                modelsUsed: Array(acc.models).sorted(),
                modelBreakdowns: modelBreakdowns
            )
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Rate Limits

    private func computeRateLimits(entries: [ParsedEntry], now: Date) -> RateLimitInfo {
        let fiveHoursAgo = now.addingTimeInterval(-5 * 60 * 60)
        let weekAgo = now.addingTimeInterval(-168 * 60 * 60)

        let sessionEntries = entries.filter { $0.timestamp >= fiveHoursAgo }
        let weeklyEntries = entries.filter { $0.timestamp >= weekAgo }

        return RateLimitInfo(
            session: buildWindowInfo(from: sessionEntries, windowHours: 5, now: now),
            weekly: buildWindowInfo(from: weeklyEntries, windowHours: 168, now: now)
        )
    }

    private func buildWindowInfo(from entries: [ParsedEntry], windowHours: UInt32, now: Date) -> WindowInfo {
        var inputTokens: UInt64 = 0
        var outputTokens: UInt64 = 0
        var sessionIds = Set<String>()
        var oldestTime: Date?

        for entry in entries {
            inputTokens += entry.inputTokens
            outputTokens += entry.outputTokens
            if let sid = entry.sessionId {
                sessionIds.insert(sid)
            }
            if oldestTime == nil || entry.timestamp < oldestTime! {
                oldestTime = entry.timestamp
            }
        }

        let tokensUsed = inputTokens + outputTokens

        var resetsAt: String?
        var minutesUntilReset: UInt32?

        if let oldest = oldestTime {
            let resetDate = oldest.addingTimeInterval(Double(windowHours) * 60 * 60)
            if resetDate > now {
                let formatter = ISO8601DateFormatter()
                resetsAt = formatter.string(from: resetDate)
                minutesUntilReset = UInt32(resetDate.timeIntervalSince(now) / 60)
            }
        }

        let oldestTimeStr: String? = oldestTime.map { ISO8601DateFormatter().string(from: $0) }

        return WindowInfo(
            tokensUsed: tokensUsed,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            sessionsActive: UInt32(sessionIds.count),
            oldestMessageTime: oldestTimeStr,
            resetsAt: resetsAt,
            minutesUntilReset: minutesUntilReset,
            windowHours: windowHours
        )
    }
}

// MARK: - Internal Types

private struct ParsedEntry {
    let timestamp: Date
    let sessionId: String?
    let requestId: String?
    let model: String
    let inputTokens: UInt64
    let outputTokens: UInt64
    let cacheCreationTokens: UInt64
    let cacheReadTokens: UInt64
}

private struct DayAccumulator {
    var inputTokens: UInt64 = 0
    var outputTokens: UInt64 = 0
    var cacheCreationTokens: UInt64 = 0
    var cacheReadTokens: UInt64 = 0
    var models: Set<String> = []
    var modelAccumulators: [String: ModelAccumulator] = [:]
}

private struct ModelAccumulator {
    var inputTokens: UInt64 = 0
    var outputTokens: UInt64 = 0
    var cacheCreationTokens: UInt64 = 0
    var cacheReadTokens: UInt64 = 0
}

// MARK: - JSONL Models

private struct RawJournalEntry: Codable {
    let type: String?
    let timestamp: String?
    let sessionId: String?
    let requestId: String?
    let message: RawJournalMessage?

    var parsedTimestamp: Date? {
        guard let ts = timestamp else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: ts) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: ts)
    }
}

private struct RawJournalMessage: Codable {
    let model: String?
    let usage: RawJournalUsage?
}

private struct RawJournalUsage: Codable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

// MARK: - Pricing (per million tokens, from LiteLLM)

struct TokenPricing {
    let input: Double
    let output: Double
    let cacheCreation: Double
    let cacheRead: Double

    func cost(input: UInt64, output: UInt64, cacheCreation: UInt64, cacheRead: UInt64) -> Double {
        (Double(input) * self.input + Double(output) * self.output +
         Double(cacheCreation) * self.cacheCreation + Double(cacheRead) * self.cacheRead) / 1_000_000
    }

    static func forModel(_ id: String) -> TokenPricing {
        let lower = id.lowercased()
        if lower.contains("opus-4-5") || lower.contains("opus-4.5") {
            // Opus 4.5: $5/$25/MTok (cheaper than Opus 4/3)
            return TokenPricing(input: 5.0, output: 25.0, cacheCreation: 6.25, cacheRead: 0.50)
        }
        if lower.contains("opus") {
            // Opus 4 / 4.1 / 3: $15/$75/MTok
            return TokenPricing(input: 15.0, output: 75.0, cacheCreation: 18.75, cacheRead: 1.50)
        }
        if lower.contains("sonnet") {
            return TokenPricing(input: 3.0, output: 15.0, cacheCreation: 3.75, cacheRead: 0.30)
        }
        if lower.contains("haiku") {
            return TokenPricing(input: 1.0, output: 5.0, cacheCreation: 1.25, cacheRead: 0.10)
        }
        // Default to Sonnet pricing
        return TokenPricing(input: 3.0, output: 15.0, cacheCreation: 3.75, cacheRead: 0.30)
    }
}
