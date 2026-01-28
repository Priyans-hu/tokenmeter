import Foundation
import Combine

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var summary: UsageSummary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var updateInfo: UpdateInfo?
    @Published var showSettings = false

    private let usageService = UsageService()
    private let contextParser = ContextWindowParser()
    private let updateChecker = UpdateChecker(currentVersion: Bundle.main.appVersion)

    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 300 // 5 minutes

    init() {
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

        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"

            let until = Date()
            let since = Calendar.current.date(byAdding: .day, value: -30, to: until)!

            let sinceStr = formatter.string(from: since)
            let untilStr = formatter.string(from: until)

            let daily = try await usageService.fetchDaily(since: sinceStr, until: untilStr)
            let rateLimits = contextParser.parse()

            let summary = aggregateSummary(daily: daily, rateLimits: rateLimits)
            self.summary = summary
            saveCachedData(summary)

        } catch {
            errorMessage = error.localizedDescription
        }

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

        // Today's data
        let today = daily.first { $0.date == todayStr }
        let todayCost = today?.totalCost ?? 0
        let todayTokens = today?.totalTokens ?? 0
        let todayBreakdowns = today?.modelBreakdowns ?? []

        // Week cost (last 7 days)
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -6, to: Date())!
        let weekCost = daily
            .filter { dateString in
                guard let date = formatter.date(from: dateString.date) else { return false }
                return date >= weekStart
            }
            .reduce(0.0) { $0 + $1.totalCost }

        // Month cost (from 1st of month)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let monthCost = daily
            .filter { dateString in
                guard let date = formatter.date(from: dateString.date) else { return false }
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
