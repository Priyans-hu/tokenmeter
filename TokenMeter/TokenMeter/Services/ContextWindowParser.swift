import Foundation

struct ContextWindowParser {
    private let projectsDir: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        projectsDir = home.appendingPathComponent(".claude/projects")
    }

    func parse() -> RateLimitInfo {
        let now = Date()
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)

        var sessionEntries: [JournalEntry] = []
        var weeklyEntries: [JournalEntry] = []

        let fiveHoursAgo = now.addingTimeInterval(-5 * 60 * 60)
        let weekAgo = now.addingTimeInterval(-168 * 60 * 60)

        // Scan JSONL files
        let entries = scanJSONLFiles(modifiedAfter: sevenDaysAgo)

        for entry in entries {
            guard let timestamp = entry.parsedTimestamp else { continue }

            if timestamp >= fiveHoursAgo {
                sessionEntries.append(entry)
            }
            if timestamp >= weekAgo {
                weeklyEntries.append(entry)
            }
        }

        return RateLimitInfo(
            session: buildWindowInfo(from: sessionEntries, windowHours: 5, now: now),
            weekly: buildWindowInfo(from: weeklyEntries, windowHours: 168, now: now)
        )
    }

    private func scanJSONLFiles(modifiedAfter: Date) -> [JournalEntry] {
        var entries: [JournalEntry] = []
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(
            at: projectsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return entries }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl" else { continue }

            // Check if file was modified recently
            if let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               modDate < modifiedAfter {
                continue
            }

            // Parse file
            if let fileEntries = parseJSONLFile(at: fileURL) {
                entries.append(contentsOf: fileEntries)
            }
        }

        return entries
    }

    private func parseJSONLFile(at url: URL) -> [JournalEntry]? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var entries: [JournalEntry] = []
        let decoder = JSONDecoder()

        for line in content.components(separatedBy: .newlines) {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let entry = try? decoder.decode(JournalEntry.self, from: data),
                  entry.type == "assistant",
                  entry.message?.usage != nil else { continue }

            entries.append(entry)
        }

        return entries
    }

    private func buildWindowInfo(from entries: [JournalEntry], windowHours: UInt32, now: Date) -> WindowInfo {
        var inputTokens: UInt64 = 0
        var outputTokens: UInt64 = 0
        var sessionIds = Set<String>()
        var oldestTime: Date?

        for entry in entries {
            if let usage = entry.message?.usage {
                inputTokens += UInt64(usage.inputTokens ?? 0)
                outputTokens += UInt64(usage.outputTokens ?? 0)
            }
            if let sid = entry.sessionId {
                sessionIds.insert(sid)
            }
            if let ts = entry.parsedTimestamp {
                if oldestTime == nil || ts < oldestTime! {
                    oldestTime = ts
                }
            }
        }

        let tokensUsed = inputTokens + outputTokens

        // Calculate reset time
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

        let oldestTimeStr: String? = oldestTime.map { date in
            let formatter = ISO8601DateFormatter()
            return formatter.string(from: date)
        }

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

// MARK: - Journal Entry Model

private struct JournalEntry: Codable {
    let type: String?
    let timestamp: String?
    let sessionId: String?
    let message: JournalMessage?

    var parsedTimestamp: Date? {
        guard let ts = timestamp else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: ts) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: ts)
    }
}

private struct JournalMessage: Codable {
    let usage: JournalUsage?
}

private struct JournalUsage: Codable {
    let inputTokens: Int?
    let outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}
