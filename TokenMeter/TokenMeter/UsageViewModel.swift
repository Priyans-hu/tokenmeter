import Foundation
import Combine

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var summary: UsageSummary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var updateInfo: UpdateInfo?
    @Published var showSettings = false
    @Published var selectedPlan: ClaudePlan {
        didSet { UserDefaults.standard.set(selectedPlan.rawValue, forKey: "claudePlan") }
    }

    private let parser = NativeUsageParser()
    private let updateChecker = UpdateChecker(currentVersion: Bundle.main.appVersion)

    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 300

    init() {
        let planStr = UserDefaults.standard.string(forKey: "claudePlan") ?? "pro"
        selectedPlan = ClaudePlan(rawValue: planStr) ?? .pro

        loadCachedData()
        Task {
            await refresh()
            await checkForUpdates()
        }
        startTimer()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil

        let result = await Task.detached { [parser] in
            parser.parse(days: 30)
        }.value

        let summary = aggregateSummary(daily: result.daily, rateLimits: result.rateLimits)
        self.summary = summary
        saveCachedData(summary)

        isLoading = false
    }

    func checkForUpdates() async {
        updateInfo = await updateChecker.checkForUpdates()
    }

    func dismissUpdate() {
        updateInfo = nil
    }

    // MARK: - Private

    private func aggregateSummary(daily: [DailyUsage], rateLimits: RateLimitInfo) -> UsageSummary {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())

        let today = daily.first { $0.date == todayStr }
        let todayCost = today?.totalCost ?? 0
        let todayTokens = today?.totalTokens ?? 0
        let todayBreakdowns = today?.modelBreakdowns ?? []

        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -6, to: Date())!
        let weekCost = daily
            .filter { item in
                guard let date = formatter.date(from: item.date) else { return false }
                return date >= weekStart
            }
            .reduce(0.0) { $0 + $1.totalCost }

        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let monthCost = daily
            .filter { item in
                guard let date = formatter.date(from: item.date) else { return false }
                return date >= monthStart
            }
            .reduce(0.0) { $0 + $1.totalCost }

        let isoFormatter = ISO8601DateFormatter()
        let lastUpdated = isoFormatter.string(from: Date())

        return UsageSummary(
            daily: daily,
            todayCost: todayCost,
            weekCost: weekCost,
            monthCost: monthCost,
            todayTokens: todayTokens,
            todayModelBreakdowns: todayBreakdowns,
            rateLimits: rateLimits,
            lastUpdated: lastUpdated
        )
    }

    private func startTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    private func loadCachedData() {
        guard let data = UserDefaults.standard.data(forKey: "cachedSummary"),
              let cached = try? JSONDecoder().decode(UsageSummary.self, from: data) else { return }
        summary = cached
    }

    private func saveCachedData(_ summary: UsageSummary) {
        guard let data = try? JSONEncoder().encode(summary) else { return }
        UserDefaults.standard.set(data, forKey: "cachedSummary")
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}
