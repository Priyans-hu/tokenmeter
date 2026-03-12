import Foundation
import Security
import os.log

struct APIUsageResponse: Codable {
    let fiveHour: APIWindowUtilization?
    let sevenDay: APIWindowUtilization?
    let sevenDayOpus: APIWindowUtilization?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
    }
}

struct APIWindowUtilization: Codable {
    let utilization: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

struct CredentialMeta {
    let rateLimitTier: String?
    let subscriptionType: String?
    let organizationName: String?
    let accountId: String?

    var detectedPlan: ClaudePlan? {
        guard let tier = rateLimitTier else { return nil }
        if tier.contains("max_20x") { return .max20 }
        if tier.contains("max_5x") { return .max5 }
        if tier.contains("max") { return .max5 }
        if tier.contains("pro") { return .pro }
        return nil
    }
}

actor UsageAPIService {
    private let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let logger = Logger(subsystem: "com.tokenmeter", category: "api")

    // In-memory cache — read keychain once per app session, not on every refresh.
    // On 401 we retry with a fresh keychain read (once), but don't prompt the user
    // repeatedly — if the retry also fails, we wait until next refresh cycle.
    private var cachedOAuth: [String: Any]?
    private var keychainUnavailable = false
    private var lastKeychainRead: Date?

    /// Minimum interval between Keychain reads to avoid repeated macOS password prompts.
    private let keychainCooldown: TimeInterval = 300 // 5 minutes

    func fetchUsage() async -> APIUsageResponse? {
        guard let token = readOAuthToken() else { return nil }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        // Try with beta header first, fall back without it
        if let result = await fetchWithBetaHeader(request: request) {
            return result
        }
        return await fetchWithoutBetaHeader(request: request)
    }

    func readCredentialMeta() -> CredentialMeta? {
        guard let json = cachedOrReadKeychainJSON() else { return nil }
        let tier = json["rateLimitTier"] as? String
        let sub = json["subscriptionType"] as? String
        let org = json["organizationName"] as? String
        let accountId = json["accountUuid"] as? String
        return CredentialMeta(
            rateLimitTier: tier,
            subscriptionType: sub,
            organizationName: org,
            accountId: accountId
        )
    }

    // MARK: - API Fetch Helpers

    private func fetchWithBetaHeader(request: URLRequest) async -> APIUsageResponse? {
        var req = request
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        return await executeRequest(req, retryOnAuth: true)
    }

    private func fetchWithoutBetaHeader(request: URLRequest) async -> APIUsageResponse? {
        Self.logger.info("fetchUsage: retrying without beta header")
        return await executeRequest(request, retryOnAuth: false)
    }

    private func executeRequest(_ request: URLRequest, retryOnAuth: Bool) async -> APIUsageResponse? {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }

            if http.statusCode == 401 {
                if retryOnAuth {
                    // Token may have been rotated by Claude Code — try one fresh keychain read
                    return await retryWithFreshToken(request: request)
                }
                return nil
            }
            guard http.statusCode == 200 else {
                Self.logger.warning("fetchUsage: HTTP \(http.statusCode)")
                return nil
            }
            return try JSONDecoder().decode(APIUsageResponse.self, from: data)
        } catch {
            return nil
        }
    }

    private func retryWithFreshToken(request: URLRequest) async -> APIUsageResponse? {
        Self.logger.info("fetchUsage: 401 received, refreshing token from keychain")
        cachedOAuth = nil

        guard let newToken = readOAuthToken() else {
            Self.logger.warning("fetchUsage: no token after keychain refresh")
            return nil
        }

        var retryReq = request
        retryReq.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
        return await executeRequest(retryReq, retryOnAuth: false)
    }

    // MARK: - Keychain

    private func cachedOrReadKeychainJSON() -> [String: Any]? {
        if let cached = cachedOAuth {
            return cached
        }

        // Rate-limit keychain reads to avoid repeated macOS password prompts.
        // If we already tried recently and failed, don't try again until cooldown expires.
        if keychainUnavailable, let last = lastKeychainRead,
           Date().timeIntervalSince(last) < keychainCooldown {
            return nil
        }

        guard let json = readKeychainJSON() else {
            keychainUnavailable = true
            lastKeychainRead = Date()
            return nil
        }

        cachedOAuth = json
        keychainUnavailable = false
        lastKeychainRead = Date()
        return json
    }

    private func readKeychainJSON() -> [String: Any]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecUserCanceled || status == errSecAuthFailed {
            Self.logger.warning("readKeychainJSON: user denied or auth failed (status: \(status))")
            return nil
        }

        guard status == errSecSuccess,
              let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any]
        else { return nil }

        return oauth
    }

    private func readOAuthToken() -> String? {
        cachedOrReadKeychainJSON()?["accessToken"] as? String
    }
}
