import Darwin
import Foundation

extension ClaudeSession {
    func preferredWorkingDirectoryURL() -> URL {
        // Always use a temp dir — avoids macOS TCC prompts for home/Documents folder access.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LilLennyCLI", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static let githubArchiveRawBase = "https://raw.githubusercontent.com/LennysNewsletter/lennys-newsletterpodcastdata/main"

    func githubArchiveContext(for backend: Backend, expert: ResponderExpert?) -> String {
        let expertHint = expert.map { "\nFocus on content featuring \($0.name)." } ?? ""
        switch backend {
        case .claudeCodeCLI, .codexCLI:
            return """
            Use WebFetch to search Lenny's public archive on GitHub:\(expertHint)
            1. Fetch the index to discover what's available:
               \(Self.githubArchiveRawBase)/index.json
               (JSON with "podcasts" and "newsletters" arrays; each entry has: title, filename, date, guest, description, word_count)
            2. Fetch 1–3 of the most relevant files:
               \(Self.githubArchiveRawBase)/{filename}
               (e.g. "podcasts/ryan-hoover.md" or "newsletters/lenny-2024-01-15.md")
            3. Ground your answer in what you retrieved.
            Do not describe the fetching steps in your response.
            """
        case .openAIResponsesAPI:
            return """
            Lenny's public archive:\(expertHint)
            Index: \(Self.githubArchiveRawBase)/index.json
            Files: \(Self.githubArchiveRawBase)/{filename}
            Answer using your knowledge of Lenny Rachitsky's content. Cite specific episodes or newsletters when relevant.
            """
        }
    }

    func start() {
        SessionDebugLogger.log("session", "start() called")
        resolvePreferredBackend { [weak self] backend, environment, message in
            guard let self else { return }
            SessionDebugLogger.log("session", "start() backend resolution completed. backend=\(String(describing: backend)) environment=\(SessionDebugLogger.summarizeEnvironment(environment))")
            guard let backend else {
                let msg = message ?? self.backendSetupMessage(environment: environment)
                SessionDebugLogger.log("session", "start() failed: \(msg)")
                self.onSetupRequired?(msg)
                return
            }

            self.selectedBackend = backend
            self.isRunning = true
            SessionDebugLogger.log("session", "session ready. selectedBackend=\(self.backendStatusMessage(for: backend, environment: environment))")
            self.onSessionReady?()
        }
    }

    func send(message: String, attachments: [SessionAttachment] = []) {
        let activeExpert = focusedExpert
        let conversationKey = key(for: activeExpert)
        isCancellingTurn = false
        pendingExperts.removeAll()
        liveToolCallsByID.removeAll()
        assistantExplicitlyRequestedExperts = false
        appendHistory(Message(role: .user, text: historyText(message: message, attachments: attachments)), to: conversationKey)
        isBusy = true
        SessionDebugLogger.logMultiline(
            "turn",
            header: "send() called. conversationKey=\(conversationKey) expert=\(activeExpert?.name ?? "none") archiveMode=\(AppSettings.effectiveArchiveAccessMode.rawValue) attachments=\(SessionDebugLogger.summarizeAttachments(attachments))",
            body: "User message:\n\(message)"
        )

        resolvePreferredBackend { [weak self] backend, environment, messageText in
            guard let self else { return }
            SessionDebugLogger.log("turn", "resolved backend=\(String(describing: backend)) environment=\(SessionDebugLogger.summarizeEnvironment(environment))")
            guard let backend else {
                SessionDebugLogger.log("turn", "backend resolution failed: \(messageText ?? "unknown error")")
                self.onSetupRequired?(messageText ?? self.backendSetupMessage(environment: environment))
                return
            }

            self.selectedBackend = backend
            let archiveMode = self.effectiveArchiveAccessMode(environment: environment)
            let status = self.backendStatusMessage(for: backend, environment: environment)
            self.onToolResult?(status, false)
            self.appendHistory(Message(role: .toolResult, text: status), to: conversationKey)

            let sourceSummary = archiveMode == .starterPack
                ? "Source: Lenny's public archive (GitHub)"
                : "Source: Official Lenny archive"
            self.onToolResult?(sourceSummary, false)
            self.appendHistory(Message(role: .toolResult, text: sourceSummary), to: conversationKey)

            if archiveMode == .starterPack {
                let archiveContext = self.githubArchiveContext(for: backend, expert: activeExpert)
                SessionDebugLogger.log("archive", "using GitHub archive context. backend=\(backend) expert=\(activeExpert?.name ?? "none")")
                self.onToolUse?("Searching Lenny archive", ["summary": "Fetching from Lenny's public archive"])
                self.appendHistory(Message(role: .toolUse, text: "Searching Lenny archive"), to: conversationKey)
                self.onToolResult?("Archive ready", false)
                self.appendHistory(Message(role: .toolResult, text: "Archive ready"), to: conversationKey)

                switch backend {
                case let .claudeCodeCLI(path):
                    self.callClaudeCodeCLI(
                        executablePath: path,
                        message: message,
                        attachments: attachments,
                        environment: environment,
                        expert: activeExpert,
                        conversationKey: conversationKey,
                        archiveContext: archiveContext,
                        officialMCPToken: nil,
                        useOfficialMCP: false
                    )

                case let .codexCLI(path):
                    self.callCodexCLI(
                        executablePath: path,
                        message: message,
                        attachments: attachments,
                        environment: environment,
                        expert: activeExpert,
                        conversationKey: conversationKey,
                        archiveContext: archiveContext,
                        useOfficialMCP: false
                    )

                case .openAIResponsesAPI:
                    guard let key = environment["OPENAI_API_KEY"], !key.isEmpty else {
                        SessionDebugLogger.log("turn", "starter pack openai fallback but OPENAI_API_KEY missing")
                        self.failTurn(self.backendSetupMessage(environment: environment), conversationKey: conversationKey)
                        return
                    }
                    self.callOpenAI(
                        message: message,
                        attachments: attachments,
                        apiKey: key,
                        expert: activeExpert,
                        conversationKey: conversationKey,
                        mcpToken: nil,
                        archiveContext: archiveContext
                    )
                }
                return
            }

            if let token = self.officialMCPToken(from: environment) {
                if case .codexCLI = backend, self.backendSupportsOfficialMCP(backend, environment: environment) {
                    self.dispatchResolvedBackend(
                        backend,
                        message: message,
                        attachments: attachments,
                        environment: environment,
                        expert: activeExpert,
                        conversationKey: conversationKey,
                        archiveContext: nil,
                        officialMCPToken: token,
                        useOfficialMCP: true
                    )
                    return
                }

                self.fetchOfficialArchiveContext(
                    message: message,
                    expert: activeExpert,
                    token: token,
                    conversationKey: conversationKey
                ) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .failure(let error):
                        let normalizedError = self.normalizedLennyMCPAuthError(from: error.localizedDescription) ?? error.localizedDescription
                        self.failTurn(normalizedError, conversationKey: conversationKey)

                    case let .success(officialResult):
                        self.pendingExperts = officialResult.experts
                        SessionDebugLogger.log(
                            "experts",
                            "staged \(officialResult.experts.count) official-archive expert candidate(s) until response completion"
                        )
                        self.dispatchResolvedBackend(
                            backend,
                            message: message,
                            attachments: attachments,
                            environment: environment,
                            expert: activeExpert,
                            conversationKey: conversationKey,
                            archiveContext: officialResult.promptContext,
                            officialMCPToken: nil,
                            useOfficialMCP: false
                        )
                    }
                }
                return
            }

            // No explicit MCP token — fall back to GitHub archive rather than attempting
            // MCP via the global config (which may time out or lack auth).
            let archiveContext = self.githubArchiveContext(for: backend, expert: activeExpert)
            SessionDebugLogger.log("archive", "no MCP token, using GitHub archive fallback")
            self.onToolUse?("Searching Lenny archive", ["summary": "Fetching from Lenny's public archive"])
            self.appendHistory(Message(role: .toolUse, text: "Searching Lenny archive"), to: conversationKey)
            self.onToolResult?("Archive ready", false)
            self.appendHistory(Message(role: .toolResult, text: "Archive ready"), to: conversationKey)

            switch backend {
            case let .claudeCodeCLI(path):
                self.callClaudeCodeCLI(
                    executablePath: path,
                    message: message,
                    attachments: attachments,
                    environment: environment,
                    expert: activeExpert,
                    conversationKey: conversationKey,
                    archiveContext: archiveContext,
                    officialMCPToken: nil,
                    useOfficialMCP: false
                )
            case let .codexCLI(path):
                self.callCodexCLI(
                    executablePath: path,
                    message: message,
                    attachments: attachments,
                    environment: environment,
                    expert: activeExpert,
                    conversationKey: conversationKey,
                    archiveContext: archiveContext,
                    useOfficialMCP: false
                )
            case .openAIResponsesAPI:
                guard let key = environment["OPENAI_API_KEY"], !key.isEmpty else {
                    self.failTurn(self.backendSetupMessage(environment: environment), conversationKey: conversationKey)
                    return
                }
                self.callOpenAI(
                    message: message,
                    attachments: attachments,
                    apiKey: key,
                    expert: activeExpert,
                    conversationKey: conversationKey,
                    mcpToken: nil,
                    archiveContext: archiveContext
                )
            }
        }
    }

    func terminate() {
        currentProcess?.terminate()
        currentProcess = nil
        currentDataTask?.cancel()
        currentDataTask = nil
        currentStreamingTask?.cancel()
        currentStreamingTask = nil
        isRunning = false
        isBusy = false
        livePresenceExperts.removeAll()
        liveToolCallsByID.removeAll()
        onProcessExit?()
    }

    func cancelActiveTurn() {
        isCancellingTurn = true
        if let process = currentProcess {
            let processID = process.processIdentifier
            if process.isRunning {
                process.interrupt()
                process.terminate()

                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self, self.isCancellingTurn else { return }
                    guard process.isRunning else { return }
                    kill(processID, SIGKILL)
                }
            }
        }
        currentProcess = nil
        currentDataTask?.cancel()
        currentDataTask = nil
        currentStreamingTask?.cancel()
        currentStreamingTask = nil
        isBusy = false
        pendingExperts.removeAll()
        assistantExplicitlyRequestedExperts = false
        livePresenceExperts.removeAll()
        liveToolCallsByID.removeAll()
    }

    func searchStarterArchive(message: String, expert: ResponderExpert?) -> (promptContext: String, experts: [ResponderExpert], summary: String, resultSummary: String) {
        let query = [expert?.name, message]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        SessionDebugLogger.log("starter-pack", "search query=\(query)")
        let matches = LocalArchive.shared.search(query: query, limit: 4)

        if matches.isEmpty {
            let promptContext = """
            The bundled starter archive did not contain a strong match for this query.
            Be transparent that the starter pack only includes 10 newsletters and 50 podcast transcripts.
            Suggest switching Settings to Official Lenny MCP for the full archive if needed.
            """
            return (
                promptContext,
                [],
                "Searching the bundled starter pack",
                "No strong matches found in the bundled starter pack"
            )
        }

        let contextLines = matches.enumerated().map { index, match in
            let subtitle = match.entry.subtitle ?? match.entry.description ?? ""
            let subtitleSuffix = subtitle.isEmpty ? "" : "\nSubtitle: \(subtitle)"
            return """
            \(index + 1). [\(match.entry.typeLabel.capitalized)] \(match.entry.title) (\(match.entry.date))
            File: \(match.entry.filename)\(subtitleSuffix)
            Excerpt: \(match.excerpt)
            """
        }
        let promptContext = contextLines.joined(separator: "\n\n")

        let experts = matches.compactMap { match -> ResponderExpert? in
            let name = match.entry.guest ?? speakerName(fromTitle: match.entry.title)
            guard let name, let avatarPath = avatarPath(for: name) else { return nil }
            return makeResponderExpert(
                name: name,
                avatarPath: avatarPath,
                archiveContext: "- \(match.entry.title) (\(match.entry.date)): \(match.excerpt)"
            )
        }

        let uniqueExperts = experts.reduce(into: [ResponderExpert]()) { partial, expert in
            if !partial.contains(where: { $0.name == expert.name }) {
                partial.append(expert)
            }
        }

        return (
            promptContext,
            Array(uniqueExperts.prefix(3)),
            "Searching the bundled starter pack",
            "Loaded \(matches.count) starter-pack match\(matches.count == 1 ? "" : "es")"
        )
    }

    func publishPendingExperts(fallbackText: String? = nil) {
        let experts = pendingExperts
        pendingExperts.removeAll()
        let assistantRequestedExperts = assistantExplicitlyRequestedExperts
        assistantExplicitlyRequestedExperts = false

        guard assistantRequestedExperts else {
            if let fallbackText, fallbackText.contains("\"answer_markdown\"") {
                SessionDebugLogger.log("experts", "skipping staged experts because assistant output was not parsed cleanly")
            } else {
                SessionDebugLogger.log("experts", "skipping staged experts because assistant did not explicitly request them")
            }
            return
        }

        guard !experts.isEmpty else {
            SessionDebugLogger.log("experts", "no staged experts to publish")
            return
        }

        let names = experts.map(\.name).joined(separator: ", ")
        SessionDebugLogger.log("experts", "publishing \(experts.count) expert candidate(s) after response completion: \(names)")
        onExpertsUpdated?(experts)
    }

    private func dispatchResolvedBackend(
        _ backend: Backend,
        message: String,
        attachments: [SessionAttachment],
        environment: [String: String],
        expert: ResponderExpert?,
        conversationKey: String,
        archiveContext: String?,
        officialMCPToken: String?,
        useOfficialMCP: Bool
    ) {
        switch backend {
        case let .claudeCodeCLI(path):
            self.callClaudeCodeCLI(
                executablePath: path,
                message: message,
                attachments: attachments,
                environment: environment,
                expert: expert,
                conversationKey: conversationKey,
                archiveContext: archiveContext,
                officialMCPToken: officialMCPToken,
                useOfficialMCP: useOfficialMCP
            )

        case let .codexCLI(path):
            self.callCodexCLI(
                executablePath: path,
                message: message,
                attachments: attachments,
                environment: environment,
                expert: expert,
                conversationKey: conversationKey,
                archiveContext: archiveContext,
                useOfficialMCP: useOfficialMCP
            )

        case .openAIResponsesAPI:
            guard let key = environment["OPENAI_API_KEY"], !key.isEmpty else {
                SessionDebugLogger.log("turn", "selected openai backend but OPENAI_API_KEY missing")
                self.failTurn(self.backendSetupMessage(environment: environment), conversationKey: conversationKey)
                return
            }
            self.callOpenAI(
                message: message,
                attachments: attachments,
                apiKey: key,
                expert: expert,
                conversationKey: conversationKey,
                mcpToken: useOfficialMCP ? officialMCPToken : nil,
                archiveContext: archiveContext
            )
        }
    }
}
