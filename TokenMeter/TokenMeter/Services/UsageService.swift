import Foundation

enum UsageServiceError: Error, LocalizedError {
    case binaryNotFound
    case executionFailed(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "ccusage not found. Install with: npm install -g ccusage"
        case .executionFailed(let msg):
            return "ccusage failed: \(msg)"
        case .parseError(let msg):
            return "Failed to parse ccusage output: \(msg)"
        }
    }
}

actor UsageService {
    private var cachedBinaryPath: String?

    func fetchDaily(since: String, until: String) async throws -> [DailyUsage] {
        let binaryPath = try await findBinary()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["daily", "--json", "--since", since, "--until", until]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw UsageServiceError.executionFailed(errorMsg)
        }

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()

        do {
            let decoder = JSONDecoder()
            return try decoder.decode([DailyUsage].self, from: outputData)
        } catch {
            throw UsageServiceError.parseError(error.localizedDescription)
        }
    }

    private func findBinary() async throws -> String {
        if let cached = cachedBinaryPath {
            return cached
        }

        let searchPaths = buildSearchPaths()

        for path in searchPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                cachedBinaryPath = path
                return path
            }
        }

        // Try `which ccusage`
        if let whichPath = try? runWhich() {
            cachedBinaryPath = whichPath
            return whichPath
        }

        throw UsageServiceError.binaryNotFound
    }

    private func buildSearchPaths() -> [String] {
        var paths: [String] = []
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // NVM paths
        let nvmDir = "\(home)/.nvm/versions/node"
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: nvmDir) {
            for version in contents.sorted().reversed() {
                paths.append("\(nvmDir)/\(version)/bin/ccusage")
            }
        }

        // Common paths
        paths.append("/usr/local/bin/ccusage")
        paths.append("/opt/homebrew/bin/ccusage")
        paths.append("\(home)/.npm-global/bin/ccusage")

        return paths
    }

    private func runWhich() throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ccusage"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        }
        return nil
    }
}
