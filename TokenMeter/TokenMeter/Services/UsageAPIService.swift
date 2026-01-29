import Foundation
import Security

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

    func fetchUsage() async -> APIUsageResponse? {
        guard let token = readOAuthToken() else { return nil }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return try JSONDecoder().decode(APIUsageResponse.self, from: data)
        } catch {
            return nil
        }
    }

    func readCredentialMeta() -> CredentialMeta? {
        guard let json = readKeychainJSON() else { return nil }
        let tier = json["rateLimitTier"] as? String
        let sub = json["subscriptionType"] as? String
        return CredentialMeta(rateLimitTier: tier, subscriptionType: sub)
    }

    // MARK: - Keychain

    private func readKeychainJSON() -> [String: Any]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any]
        else { return nil }

        return oauth
    }

    private func readOAuthToken() -> String? {
        readKeychainJSON()?["accessToken"] as? String
    }
}
