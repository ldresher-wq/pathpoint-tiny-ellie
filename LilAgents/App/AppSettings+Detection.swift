import Foundation

extension AppSettings {
    // Shared with AppSettings+MCPConfig via resolveShellEnvironment()
    static let shellEnvironmentMCPTokenKey = "LENNYSDATA_MCP_AUTH_TOKEN"
    private static var cachedShellEnvironment: [String: String]?

    static var detectedOfficialMCPSources: [OfficialMCPSource] {
        var sources: [OfficialMCPSource] = []

        if claudeGlobalConfigURLs.contains(where: containsOfficialMCPConfiguration(at:)) {
            sources.append(.claudeGlobalConfig)
        }
        if hasDetectedCodexOfficialMCPConfiguration {
            sources.append(.codexGlobalConfig)
        }
        if officialLennyMCPToken != nil {
            sources.append(.settingsToken)
        }
        if shellEnvironmentOfficialMCPToken() != nil {
            sources.append(.environmentToken)
        }

        return sources
    }

    static var hasDetectedOfficialMCPConfiguration: Bool {
        !detectedOfficialMCPSources.isEmpty
    }

    static var hasDetectedCodexLogin: Bool {
        guard let executable = executablePathForDetection(named: "codex") else { return false }
        if hasDetectedOpenAIAPIKey {
            return true
        }
        let result = runCommand(executablePath: executable, arguments: ["login", "status"])
        guard result.status == 0 else { return false }

        let output = "\(result.stdout)\n\(result.stderr)".lowercased()
        if output.contains("not logged in") || output.contains("login required") {
            return false
        }
        if output.contains("logged in") || output.contains("chatgpt") {
            return true
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static var hasDetectedClaudeLogin: Bool {
        guard let executable = executablePathForDetection(named: "claude") else { return false }
        if hasDetectedAnthropicAPIKey {
            return true
        }
        let result = runCommand(executablePath: executable, arguments: ["auth", "status"])
        if let data = result.stdout.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let loggedIn = json["loggedIn"] as? Bool {
            return loggedIn
        }
        let output = "\(result.stdout)\n\(result.stderr)".lowercased()
        if output.contains("not logged in") || output.contains("login required") {
            return false
        }
        return result.status == 0
    }

    static func refreshDetectionState() {
        cachedShellEnvironment = nil
    }

    static var hasDetectedOpenAIAPIKey: Bool {
        if let key = openAIAPIKey, !key.isEmpty {
            return true
        }
        let envValue = resolveShellEnvironment()["OPENAI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return envValue?.isEmpty == false
    }

    static var hasDetectedAnthropicAPIKey: Bool {
        let envValue = resolveShellEnvironment()["ANTHROPIC_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return envValue?.isEmpty == false
    }

    static var hasDetectedCodexOfficialMCPConfiguration: Bool {
        if containsOfficialMCPConfiguration(at: codexGlobalConfigURL) {
            return true
        }

        guard let executable = executablePathForDetection(named: "codex") else { return false }
        let result = runCommand(executablePath: executable, arguments: ["mcp", "list", "--json"])
        guard result.status == 0 else { return false }

        let combinedOutput = "\(result.stdout)\n\(result.stderr)".lowercased()
        if combinedOutput.contains("\"name\":\"lennysdata\"") || combinedOutput.contains("\"lennysdata\"") {
            return true
        }
        return combinedOutput.contains("lennysdata") && combinedOutput.contains(ClaudeSession.Constants.lennyMCPURL.lowercased())
    }

    // MARK: - Shell environment

    static func resolveShellEnvironment() -> [String: String] {
        if let cachedShellEnvironment {
            return cachedShellEnvironment
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-i", "-c", "echo '---ENV_START---' && env && echo '---ENV_END---'"]
        let stdout = Pipe()
        proc.standardOutput = stdout
        proc.standardError = Pipe()

        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            cachedShellEnvironment = [:]
            return [:]
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        var environment: [String: String] = [:]

        if let startRange = output.range(of: "---ENV_START---\n"),
           let endRange = output.range(of: "\n---ENV_END---") {
            let envString = String(output[startRange.upperBound..<endRange.lowerBound])
            for line in envString.components(separatedBy: "\n") {
                guard let eqRange = line.range(of: "=") else { continue }
                let key = String(line[..<eqRange.lowerBound])
                let value = String(line[eqRange.upperBound...])
                environment[key] = value
            }
        }

        cachedShellEnvironment = environment
        return environment
    }

    // MARK: - Executable path detection

    private static func executablePathForDetection(named name: String) -> String? {
        if let rawPath = ProcessInfo.processInfo.environment["PATH"],
           let path = executablePathForDetection(named: name, rawPath: rawPath) {
            return path
        }

        let fallbackPaths: [String]
        let home = homeDirectoryURL.path
        switch name {
        case "claude":
            fallbackPaths = [
                "\(home)/.local/bin/claude",
                "/opt/homebrew/bin/claude",
                "/usr/local/bin/claude"
            ]
        case "codex":
            var codexPaths = [
                "\(home)/.local/bin/codex",
                "\(home)/.nvm/versions/node/current/bin/codex",
                "/opt/homebrew/bin/codex",
                "/usr/local/bin/codex"
            ]
            // Scan nvm node versions in case "current" symlink doesn't exist
            let nvmNodeDir = "\(home)/.nvm/versions/node"
            if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmNodeDir) {
                let sorted = versions.sorted { $0.localizedStandardCompare($1) == .orderedDescending }
                for version in sorted {
                    codexPaths.append("\(nvmNodeDir)/\(version)/bin/codex")
                }
            }
            fallbackPaths = codexPaths
        default:
            fallbackPaths = []
        }

        if let path = fallbackPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return path
        }

        return executablePathFromLoginShellForDetection(named: name)
    }

    private static func executablePathForDetection(named name: String, rawPath: String) -> String? {
        for directory in rawPath.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func executablePathFromLoginShellForDetection(named name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "command -v \(name)"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (output?.isEmpty == false) ? output : nil
    }

    static func runCommand(executablePath: String, arguments: [String]) -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (-1, "", error.localizedDescription)
        }

        let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, out, err)
    }
}
