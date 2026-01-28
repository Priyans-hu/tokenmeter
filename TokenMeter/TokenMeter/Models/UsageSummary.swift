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

    enum CodingKeys: String, CodingKey {
        case daily
        case todayCost = "today_cost"
        case weekCost = "week_cost"
        case monthCost = "month_cost"
        case todayTokens = "today_tokens"
        case todayModelBreakdowns = "today_model_breakdowns"
        case rateLimits = "rate_limits"
        case lastUpdated = "last_updated"
    }
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

    enum CodingKeys: String, CodingKey {
        case date
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationTokens = "cache_creation_tokens"
        case cacheReadTokens = "cache_read_tokens"
        case totalTokens = "total_tokens"
        case totalCost = "total_cost"
        case modelsUsed = "models_used"
        case modelBreakdowns = "model_breakdowns"
    }
}

struct ModelBreakdown: Codable, Identifiable {
    var id: String { modelName }

    let modelName: String
    let inputTokens: UInt64
    let outputTokens: UInt64
    let cacheCreationTokens: UInt64
    let cacheReadTokens: UInt64
    let cost: Double

    enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationTokens = "cache_creation_tokens"
        case cacheReadTokens = "cache_read_tokens"
        case cost
    }

    var displayName: String {
        if modelName.contains("opus") { return "Opus" }
        if modelName.contains("sonnet") { return "Sonnet" }
        if modelName.contains("haiku") { return "Haiku" }
        return modelName
    }

    var color: String {
        if modelName.contains("opus") { return "#8B5CF6" }      // Purple
        if modelName.contains("sonnet") { return "#3B82F6" }    // Blue
        if modelName.contains("haiku") { return "#10B981" }     // Green
        return "#6B7280"                                         // Gray
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

    enum CodingKeys: String, CodingKey {
        case tokensUsed = "tokens_used"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case sessionsActive = "sessions_active"
        case oldestMessageTime = "oldest_message_time"
        case resetsAt = "resets_at"
        case minutesUntilReset = "minutes_until_reset"
        case windowHours = "window_hours"
    }
}
