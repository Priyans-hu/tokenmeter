import Foundation
import Combine
import UserNotifications

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
    private let apiService = UsageAPIService()
    private let updateChecker = UpdateChecker(currentVersion: Bundle.main.appVersion)

    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 300
    private var lastSessionNotification: Date?
    private var lastWeeklyNotification: Date?

    init() {
        let planStr = UserDefaults.standard.string(forKey: "claudePlan") ?? "pro"
        selectedPlan = ClaudePlan(rawValue: planStr) ?? .pro
        notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true

        loadCachedData()
        requestNotificationPermission()
        Task {
            await refresh()
            await checkForUpdates()
        }
        startTimer()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil

        async let localResult = Task.detached { [parser] in
            parser.parse(days: 30)
        }.value
        async let apiResult = apiService.fetchUsage()

        let result = await localResult
        let apiUsage = await apiResult

        var rateLimits = result.rateLimits
        rateLimits.apiSession = apiUsage?.fiveHour
        rateLimits.apiWeekly = apiUsage?.sevenDay

        let summary = aggregateSummary(daily: result.daily, hourly: result.hourly, rateLimits: rateLimits)
        self.summary = summary
        saveCachedData(summary)
        checkRateLimitAlerts(rateLimits)

        isLoading = false
    }

    func checkForUpdates() async {
        updateInfo = await updateChecker.checkForUpdates()
    }

    func dismissUpdate() {
        updateInfo = nil
    }

    // MARK: - Private

    private func aggregateSummary(daily: [DailyUsage], hourly: [HourlyUsage], rateLimits: RateLimitInfo) -> UsageSummary {
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
            hourly: hourly,
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

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func checkRateLimitAlerts(_ rateLimits: RateLimitInfo) {
        guard notificationsEnabled else { return }
        let now = Date()

        if let api = rateLimits.apiSession, api.utilization >= 80 {
            if lastSessionNotification == nil || now.timeIntervalSince(lastSessionNotification!) > 3600 {
                sendNotification(
                    title: "Session limit at \(Int(api.utilization))%",
                    body: "Your 5-hour rate limit is running low."
                )
                lastSessionNotification = now
            }
        }

        if let api = rateLimits.apiWeekly, api.utilization >= 80 {
            if lastWeeklyNotification == nil || now.timeIntervalSince(lastWeeklyNotification!) > 3600 {
                sendNotification(
                    title: "Weekly limit at \(Int(api.utilization))%",
                    body: "Your 7-day rate limit is running low."
                )
                lastWeeklyNotification = now
            }
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "TokenMeter"
        content.subtitle = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}
