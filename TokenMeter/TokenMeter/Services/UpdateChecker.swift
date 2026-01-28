import Foundation

struct UpdateInfo {
    let version: String
    let url: String
    let notes: String?
}

actor UpdateChecker {
    private let currentVersion: String
    private let repoOwner = "Priyans-hu"
    private let repoName = "tokenmeter"

    init(currentVersion: String) {
        self.currentVersion = currentVersion
    }

    func checkForUpdates() async -> UpdateInfo? {
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

            let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
            if isNewerVersion(latestVersion, than: currentVersion) {
                return UpdateInfo(
                    version: latestVersion,
                    url: release.htmlUrl,
                    notes: release.body
                )
            }
        } catch {
            // Silently fail - update check is non-critical
        }

        return nil
    }

    private func isNewerVersion(_ latest: String, than current: String) -> Bool {
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(latestParts.count, currentParts.count) {
            let l = i < latestParts.count ? latestParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }
}

private struct GitHubRelease: Codable {
    let tagName: String
    let htmlUrl: String
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case body
    }
}
