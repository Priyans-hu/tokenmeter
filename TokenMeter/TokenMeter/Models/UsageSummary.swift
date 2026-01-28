import Foundation

struct UsageSummary: Codable {
    let daily: [DailyUsage]
    let todayCost: Double
    let weekCost: Double
    let monthCost: Double
    let todayTokens: UInt64
    let todayModelBreakdowns: [ModelBreakdown]
    let rateLimits: RateLimitInfo
    let lastUpdated: String
}

// Wrapper for ccusage JSON output: { "daily": [...] }
struct CcusageResponse: Codable {
    let daily: [DailyUsage]
}

struct DailyUsage: Codable, Identifiable {
    var id: String { date }

    let date: String
    let inputTokens: UInt64
    let outputTokens: UInt64
    let cacheCreationTokens: UInt64
    let cacheReadTokens: UInt64
    let totalTokens: UInt64
    let totalCost: Double
    let modelsUsed: [String]
    let modelBreakdowns: [ModelBreakdown]
}

struct ModelBreakdown: Codable, Identifiable {
    var id: String { modelName }

    let modelName: String
    let inputTokens: UInt64
    let outputTokens: UInt64
    let cacheCreationTokens: UInt64
    let cacheReadTokens: UInt64
    let cost: Double

    var displayName: String {
        if modelName.contains("opus") { return "Opus" }
        if modelName.contains("sonnet") { return "Sonnet" }
        if modelName.contains("haiku") { return "Haiku" }
        return modelName
    }

    var color: String {
        if modelName.contains("opus") { return "#8B5CF6" }
        if modelName.contains("sonnet") { return "#3B82F6" }
        if modelName.contains("haiku") { return "#10B981" }
        return "#6B7280"
    }
}

struct RateLimitInfo: Codable {
    let session: WindowInfo
    let weekly: WindowInfo
}

struct WindowInfo: Codable {
    let tokensUsed: UInt64
    let inputTokens: UInt64
    let outputTokens: UInt64
    let sessionsActive: UInt32
    let oldestMessageTime: String?
    let resetsAt: String?
    let minutesUntilReset: UInt32?
    let windowHours: UInt32
}
