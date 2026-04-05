import Foundation

extension ClaudeSession {
    func preferredWorkingDirectoryURL() -> URL {
        // Always use a temp dir — avoids macOS TCC prompts for home/Documents folder access.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LilLennyCLI", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func logStartupDiagnostics() {
        Task.detached(priority: .utility) {
            let fm = FileManager.default

            // ── Runtimes ─────────────────────────────────────────────────────
            // Use ProcessInfo for PATH-based executable lookup (AppSettings.resolveShellEnvironment is private).
            let processEnv = ProcessInfo.processInfo.environment
            let claudePath = self.executablePath(named: "claude", environment: processEnv)
            let codexPath  = self.executablePath(named: "codex",  environment: processEnv)

            let claudeFound = claudePath != nil
            let codexFound  = codexPath  != nil

            let claudeLoggedIn = AppSettings.hasDetectedClaudeLogin
            let codexLoggedIn  = AppSettings.hasDetectedCodexLogin

            let anthropicKey     = AppSettings.hasDetectedAnthropicAPIKey
            let openaiKey        = AppSettings.hasDetectedOpenAIAPIKey
            let mcpEnvToken      = !(processEnv[ClaudeSession.Constants.lennyMCPAuthEnvVar] ?? "").isEmpty
            let mcpSettingsToken = AppSettings.officialLennyMCPToken != nil

            // ── MCP in config files ──────────────────────────────────────────
            let claudeConfigURLs = AppSettings.claudeGlobalConfigURLs
            let codexConfigURL   = AppSettings.codexGlobalConfigURL
            let codexConfigMCP   = AppSettings.containsOfficialMCPConfiguration(at: codexConfigURL)
            let codexConfigMCPViaList = AppSettings.hasDetectedCodexOfficialMCPConfiguration

            // ── Archive mode ─────────────────────────────────────────────────
            let mcpSources  = AppSettings.detectedOfficialMCPSources
            let archiveMode = AppSettings.effectiveArchiveAccessMode
            let preferredTransport = AppSettings.preferredTransport

            // ── Print ────────────────────────────────────────────────────────
            var lines: [String] = []
            lines.append("╔══════════════════════════════════════════════════╗")
            lines.append("║           Lil-Lenny startup diagnostics          ║")
            lines.append("╚══════════════════════════════════════════════════╝")

            lines.append("")
            lines.append("── Runtimes ────────────────────────────────────────")
            lines.append("  claude  executable : \(claudeFound  ? (claudePath ?? "?") : "NOT FOUND")")
            lines.append("  codex   executable : \(codexFound   ? (codexPath  ?? "?") : "NOT FOUND")")
            lines.append("  claude  logged in  : \(claudeLoggedIn ? "YES" : "NO")\(anthropicKey ? " (via ANTHROPIC_API_KEY)" : "")")
            lines.append("  codex   logged in  : \(codexLoggedIn  ? "YES" : "NO")\(openaiKey    ? " (via OPENAI_API_KEY)"    : "")")

            lines.append("")
            lines.append("── API Keys ────────────────────────────────────────")
            lines.append("  ANTHROPIC_API_KEY         : \(anthropicKey      ? "present" : "missing")")
            lines.append("  OPENAI_API_KEY            : \(openaiKey         ? "present" : "missing")")
            lines.append("  LENNYSDATA_MCP_AUTH_TOKEN : \(mcpEnvToken       ? "present (env)"      : "missing")")
            lines.append("  Lenny MCP token (Settings): \(mcpSettingsToken  ? "present (settings)" : "missing")")

            lines.append("")
            lines.append("── Lenny MCP config detection ──────────────────────")
            for url in claudeConfigURLs {
                let exists = fm.fileExists(atPath: url.path)
                let hasMCP = AppSettings.containsOfficialMCPConfiguration(at: url)
                lines.append("  \(url.lastPathComponent.padding(toLength: 28, withPad: " ", startingAt: 0)): \(exists ? "exists" : "missing")\(hasMCP ? " ✓ has Lenny MCP" : "")")
            }
            let codexConfigExists = fm.fileExists(atPath: codexConfigURL.path)
            lines.append("  \(codexConfigURL.lastPathComponent.padding(toLength: 28, withPad: " ", startingAt: 0)): \(codexConfigExists ? "exists" : "missing")\(codexConfigMCP ? " ✓ has Lenny MCP" : "")\((!codexConfigMCP && codexConfigMCPViaList) ? " ✓ via codex mcp list" : "")")

            lines.append("")
            lines.append("── Detected MCP sources ────────────────────────────")
            if mcpSources.isEmpty {
                lines.append("  (none)")
            } else {
                for src in mcpSources {
                    lines.append("  ✓ \(src.label)")
                }
            }

            lines.append("")
            lines.append("── Active configuration ─────────────────────────────")
            lines.append("  Preferred transport : \(preferredTransport.rawValue)")
            lines.append("  Archive mode        : \(archiveMode.rawValue)")
            lines.append("  Claude model        : \(AppSettings.preferredClaudeModel.label)")
            lines.append("  Codex model         : \(AppSettings.preferredCodexModel.label)")
            lines.append("  OpenAI model        : \(AppSettings.preferredOpenAIModel.label)")

            lines.append("────────────────────────────────────────────────────")

            let report = lines.joined(separator: "\n")
            SessionDebugLogger.logMultiline("startup", header: "environment diagnostics", body: report)
        }
    }
}
