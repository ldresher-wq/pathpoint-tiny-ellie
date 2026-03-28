import AppKit
import Foundation
import PDFKit

extension ClaudeSession {
    func preferredWorkingDirectoryURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    func start() {
        SessionDebugLogger.log("session", "start() called")
        resolvePreferredBackend { [weak self] backend, environment, message in
            guard let self else { return }
            SessionDebugLogger.log("session", "start() backend resolution completed. backend=\(String(describing: backend)) environment=\(SessionDebugLogger.summarizeEnvironment(environment))")
            guard let backend else {
                let msg = message ?? self.backendSetupMessage(environment: environment)
                SessionDebugLogger.log("session", "start() failed: \(msg)")
                self.onError?(msg)
                self.appendHistory(Message(role: .error, text: msg), to: self.key(for: self.focusedExpert))
                return
            }

            self.selectedBackend = backend
            self.isRunning = true
            SessionDebugLogger.log("session", "session ready. selectedBackend=\(backendStatusMessage(for: backend))")
            self.onSessionReady?()
        }
    }

    func send(message: String, attachments: [SessionAttachment] = []) {
        let activeExpert = focusedExpert
        let conversationKey = key(for: activeExpert)
        appendHistory(Message(role: .user, text: historyText(message: message, attachments: attachments)), to: conversationKey)
        isBusy = true
        SessionDebugLogger.logMultiline(
            "turn",
            header: "send() called. conversationKey=\(conversationKey) expert=\(activeExpert?.name ?? "none") archiveMode=\(AppSettings.archiveAccessMode.rawValue) attachments=\(SessionDebugLogger.summarizeAttachments(attachments))",
            body: "User message:\n\(message)"
        )

        resolvePreferredBackend { [weak self] backend, environment, messageText in
            guard let self else { return }
            SessionDebugLogger.log("turn", "resolved backend=\(String(describing: backend)) environment=\(SessionDebugLogger.summarizeEnvironment(environment))")
            guard let backend else {
                SessionDebugLogger.log("turn", "backend resolution failed: \(messageText ?? "unknown error")")
                self.failTurn(messageText ?? self.backendSetupMessage(environment: environment), conversationKey: conversationKey)
                return
            }

            self.selectedBackend = backend
            let status = self.backendStatusMessage(for: backend)
            self.onToolResult?(status, false)
            self.appendHistory(Message(role: .toolResult, text: status), to: conversationKey)

            let archiveMode = AppSettings.archiveAccessMode
            if archiveMode == .starterPack {
                let localResult = self.searchStarterArchive(message: message, expert: activeExpert)
                let expertNames = localResult.experts.map(\.name).joined(separator: ", ")
                SessionDebugLogger.logMultiline(
                    "starter-pack",
                    header: "starter pack search complete. summary=\(localResult.summary) result=\(localResult.resultSummary) experts=\(expertNames)",
                    body: localResult.promptContext
                )
                self.onToolUse?("Searching Starter Pack", ["summary": localResult.summary])
                self.appendHistory(Message(role: .toolUse, text: "Searching Starter Pack: \(localResult.summary)"), to: conversationKey)
                self.onToolResult?(localResult.resultSummary, false)
                self.appendHistory(Message(role: .toolResult, text: localResult.resultSummary), to: conversationKey)
                self.pendingExperts = localResult.experts
                SessionDebugLogger.log("experts", "staged \(localResult.experts.count) starter-pack expert candidate(s) until response completion")

                switch backend {
                case let .claudeCodeCLI(path):
                    self.callClaudeCodeCLI(
                        executablePath: path,
                        message: message,
                        attachments: attachments,
                        environment: environment,
                        expert: activeExpert,
                        conversationKey: conversationKey,
                        archiveContext: localResult.promptContext,
                        officialMCPToken: nil
                    )

                case let .codexCLI(path):
                    self.callCodexCLI(
                        executablePath: path,
                        message: message,
                        attachments: attachments,
                        environment: environment,
                        expert: activeExpert,
                        conversationKey: conversationKey,
                        archiveContext: localResult.promptContext,
                        useBundledMCP: false
                    )

                case .openAIResponsesAPI:
                    guard let key = environment["OPENAI_API_KEY"], !key.isEmpty else {
                        SessionDebugLogger.log("turn", "starter pack mode selected openai fallback but OPENAI_API_KEY missing")
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
                        archiveContext: localResult.promptContext
                    )
                }
                return
            }

            switch backend {
            case let .claudeCodeCLI(path):
                self.callClaudeCodeCLI(
                    executablePath: path,
                    message: message,
                    attachments: attachments,
                    environment: environment,
                    expert: activeExpert,
                    conversationKey: conversationKey,
                    archiveContext: nil,
                    officialMCPToken: self.officialMCPToken(from: environment)
                )

            case let .codexCLI(path):
                self.callCodexCLI(
                    executablePath: path,
                    message: message,
                    attachments: attachments,
                    environment: environment,
                    expert: activeExpert,
                    conversationKey: conversationKey,
                    archiveContext: nil,
                    useBundledMCP: self.officialMCPToken(from: environment) != nil
                )

            case .openAIResponsesAPI:
                guard let key = environment["OPENAI_API_KEY"], !key.isEmpty else {
                    SessionDebugLogger.log("turn", "official MCP path selected openai fallback but OPENAI_API_KEY missing")
                    self.failTurn(self.backendSetupMessage(environment: environment), conversationKey: conversationKey)
                    return
                }
                guard let token = self.officialMCPToken(from: environment) else {
                    SessionDebugLogger.log("turn", "official MCP path selected openai fallback but no official token available")
                    self.failTurn("Official MCP mode is enabled, but no official Lenny token is configured for direct API usage. Add your own bearer token in Settings or switch back to the starter pack.", conversationKey: conversationKey)
                    return
                }
                self.callOpenAI(
                    message: message,
                    attachments: attachments,
                    apiKey: key,
                    expert: activeExpert,
                    conversationKey: conversationKey,
                    mcpToken: token,
                    archiveContext: nil
                )
            }
        }
    }

    func terminate() {
        isRunning = false
        isBusy = false
        onProcessExit?()
    }

    func callOpenAI(message: String, attachments: [SessionAttachment], apiKey: String, expert: ResponderExpert?, conversationKey: String, mcpToken: String?, archiveContext: String?) {
        let prompt = buildUserPrompt(message: message, attachments: attachments, expert: expert, archiveContext: archiveContext)
        let input: [[String: Any]] = [[
            "role": "user",
            "content": buildInputContent(prompt: prompt, attachments: attachments)
        ]]

        let instructions = buildInstructions(for: expert)
        var payload: [String: Any] = [
            "model": Constants.openAIModel,
            "instructions": instructions,
            "input": input
        ]

        if let mcpToken {
            payload["tools"] = [[
                "type": "mcp",
                "server_label": Constants.lennyMCPServerLabel,
                "server_description": "Lenny Rachitsky's archive of newsletter posts and podcast transcripts about startups, product, growth, pricing, leadership, career, and AI product work.",
                "server_url": Constants.lennyMCPURL,
                "headers": [
                    "Authorization": "Bearer \(mcpToken)"
                ],
                "require_approval": "never",
                "allowed_tools": Constants.lennyAllowedTools
            ]]
        }

        if let previousResponseID = conversations[conversationKey]?.previousResponseID {
            payload["previous_response_id"] = previousResponseID
        }

        if let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
           let payloadText = String(data: payloadData, encoding: .utf8) {
            SessionDebugLogger.logMultiline(
                "openai",
                header: "dispatching OpenAI Responses API request. conversationKey=\(conversationKey) expert=\(expert?.name ?? "none") mcpInjected=\(mcpToken != nil)",
                body: payloadText
            )
        }

        let planningSummary = mcpToken == nil
            ? (expert == nil ? "Answering using the bundled starter archive context" : "Continuing \(expert!.name)'s thread using the bundled starter archive context")
            : (expert == nil ? "Understanding your question and deciding which archive tools to use" : "Continuing \(expert!.name)'s thread with the right archive context")
        onToolUse?("Planning", ["summary": planningSummary])
        appendHistory(Message(role: .toolUse, text: "Planning: \(planningSummary)"), to: conversationKey)

        var request = URLRequest(url: Constants.openAIEndpoint, timeoutInterval: Constants.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            failTurn("Couldn’t encode the OpenAI request.", conversationKey: conversationKey)
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    SessionDebugLogger.log("openai", "request failed: \(error.localizedDescription)")
                    self.failTurn("OpenAI request failed: \(error.localizedDescription)", conversationKey: conversationKey)
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    SessionDebugLogger.log("openai", "response unreadable")
                    self.failTurn("OpenAI returned an unreadable response.", conversationKey: conversationKey)
                    return
                }
                if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
                   let jsonText = String(data: jsonData, encoding: .utf8) {
                    SessionDebugLogger.logMultiline("openai", header: "received OpenAI response", body: jsonText)
                }
                self.handleOpenAIResponse(json, conversationKey: conversationKey)
            }
        }.resume()
    }

    func handleOpenAIResponse(_ json: [String: Any], conversationKey: String) {
        SessionDebugLogger.log("openai", "handleOpenAIResponse() outputItems=\((json["output"] as? [[String: Any]] ?? []).count)")
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            SessionDebugLogger.log("openai", "model returned error: \(message)")
            failTurn("OpenAI error: \(message)", conversationKey: conversationKey)
            return
        }

        if let responseID = json["id"] as? String {
            var state = conversations[conversationKey] ?? ConversationState()
            state.previousResponseID = responseID
            conversations[conversationKey] = state
        }

        let outputItems = json["output"] as? [[String: Any]] ?? []
        var experts: [ResponderExpert] = []

        for item in outputItems {
            guard let type = item["type"] as? String else { continue }
            switch type {
            case "mcp_list_tools":
                let tools = item["tools"] as? [[String: Any]] ?? []
                let count = tools.count
                SessionDebugLogger.log("mcp", "mcp_list_tools returned \(count) tool(s)")
                let summary = "Connected to Lenny archive, \(count) tools ready"
                onToolResult?(summary, false)
                appendHistory(Message(role: .toolResult, text: summary), to: conversationKey)

            case "mcp_call":
                let name = item["name"] as? String ?? "mcp_call"
                let arguments = item["arguments"] as? [String: Any] ?? [:]
                SessionDebugLogger.logMultiline("mcp", header: "mcp_call \(name)", body: "arguments=\(arguments)\noutput=\(String(describing: item["output"]))")
                let processStep = processDisplay(for: name, arguments: arguments)
                onToolUse?(processStep.title, ["summary": processStep.summary])
                appendHistory(Message(role: .toolUse, text: "\(processStep.title): \(processStep.summary)"), to: conversationKey)

                let output = item["output"]
                let extractedExperts = expertsFromMCPPayloads(arguments: arguments, output: output)
                for expert in extractedExperts where !experts.contains(expert) {
                    experts.append(expert)
                }

                let resultSummary = processResultDisplay(for: name, arguments: arguments, output: output)
                onToolResult?(resultSummary, false)
                appendHistory(Message(role: .toolResult, text: resultSummary), to: conversationKey)

            case "message":
                continue

            default:
                continue
            }
        }

        pendingExperts = experts
        SessionDebugLogger.log("experts", "staged \(experts.count) MCP-derived expert candidate(s) until response completion")

        let outputText = (json["output_text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let outputText, !outputText.isEmpty {
            let cleanedOutput = prepareAssistantOutput(outputText)
            publishPendingExperts(fallbackText: cleanedOutput)
            SessionDebugLogger.logMultiline("assistant", header: "final assistant response", body: cleanedOutput)
            let composeSummary = "Composing the final answer"
            onToolUse?("Writing", ["summary": composeSummary])
            appendHistory(Message(role: .toolUse, text: "Writing: \(composeSummary)"), to: conversationKey)
            appendHistory(Message(role: .assistant, text: cleanedOutput), to: conversationKey)
            onText?(cleanedOutput)
            finishTurn()
            return
        }

        if let messageText = extractMessageText(from: outputItems), !messageText.isEmpty {
            let cleanedMessage = prepareAssistantOutput(messageText)
            publishPendingExperts(fallbackText: cleanedMessage)
            SessionDebugLogger.logMultiline("assistant", header: "final assistant message response", body: cleanedMessage)
            let composeSummary = "Composing the final answer"
            onToolUse?("Writing", ["summary": composeSummary])
            appendHistory(Message(role: .toolUse, text: "Writing: \(composeSummary)"), to: conversationKey)
            appendHistory(Message(role: .assistant, text: cleanedMessage), to: conversationKey)
            onText?(cleanedMessage)
            finishTurn()
            return
        }

        failTurn("The model returned no final answer.", conversationKey: conversationKey)
    }

    func buildInstructions(for expert: ResponderExpert?) -> String {
        let base = """
        You are answering as Lenny inside a macOS companion app.
        Use the provided archive context first. When MCP tools are available, use them when helpful.
        Prefer Lenny archive content for startup, product, growth, pricing, leadership, career, and AI product questions.
        Give a concise, practical answer in markdown, but wrap it in a JSON object.
        Mention the relevant expert names naturally when they appear in the archive.
        Return only valid JSON, with no prose before or after it and no code fences.
        Use this exact shape:
        {
          "answer_markdown": "markdown answer here",
          "suggested_experts": ["Name One", "Name Two"],
          "suggest_expert_prompt": true
        }
        `suggested_experts` should include up to 3 relevant archive experts you explicitly relied on or cited.
        If there are no useful expert suggestions, return an empty array and set `suggest_expert_prompt` to false.
        """

        if let expert {
            return base + """

            The user is currently in follow-up mode for \(expert.name).
            \(expert.responseScript)
            Prefer tools, excerpts, and synthesis related to \(expert.name) when relevant.
            Ground the answer in this retrieved context first before broadening out:
            \(expert.archiveContext)
            """
        }

        return base
    }

    func buildUserPrompt(message: String, attachments: [SessionAttachment], expert: ResponderExpert?, archiveContext: String? = nil) -> String {
        let baseMessage = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Please analyze the attached file(s) and answer based on them."
            : message

        let attachmentContext: String
        if attachments.isEmpty {
            attachmentContext = ""
        } else {
            let names = attachments.map(\.displayName).joined(separator: ", ")
            attachmentContext = "\n\nAttached files: \(names)"
        }

        let archiveSection = archiveContext.map { "\n\nArchive context:\n\($0)" } ?? ""

        if let expert {
            return "Follow-up focus: \(expert.name)\n\nUser question: \(baseMessage)\(attachmentContext)\(archiveSection)"
        }
        return baseMessage + attachmentContext + archiveSection
    }

    func buildInputContent(prompt: String, attachments: [SessionAttachment]) -> [[String: Any]] {
        var content: [[String: Any]] = [[
            "type": "input_text",
            "text": prompt
        ]]

        for attachment in attachments {
            switch attachment.kind {
            case .image:
                guard let imageURL = imageDataURL(for: attachment.url) else { continue }
                content.append([
                    "type": "input_text",
                    "text": "Attached image: \(attachment.displayName)"
                ])
                content.append([
                    "type": "input_image",
                    "image_url": imageURL,
                    "detail": "auto"
                ])

            case .document:
                guard let extractedText = documentText(for: attachment.url), !extractedText.isEmpty else { continue }
                content.append([
                    "type": "input_text",
                    "text": "Attached document: \(attachment.displayName)\n\n\(extractedText)"
                ])
            }
        }

        return content
    }

    func historyText(message: String, attachments: [SessionAttachment]) -> String {
        guard !attachments.isEmpty else { return message }
        let attachmentLine = attachments.map(\.displayName).joined(separator: ", ")
        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "[attachments] \(attachmentLine)"
        }
        return "\(message)\n[attachments] \(attachmentLine)"
    }

    func resolveOpenAIKey(completion: @escaping (String?) -> Void) {
        resolveShellEnvironment { environment in
            completion(environment["OPENAI_API_KEY"])
        }
    }

    func resolveShellEnvironment(completion: @escaping ([String: String]) -> Void) {
        if let cached = Self.shellEnvironment {
            Self.openAIKey = cached["OPENAI_API_KEY"]
            SessionDebugLogger.log("env", "using cached shell environment: \(SessionDebugLogger.summarizeEnvironment(cached))")
            completion(cached)
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-i", "-c", "echo '---ENV_START---' && env && echo '---ENV_END---'"]
        let stdout = Pipe()
        proc.standardOutput = stdout
        proc.standardError = Pipe()
        proc.terminationHandler = { _ in
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
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

                Self.shellEnvironment = environment
                Self.openAIKey = environment["OPENAI_API_KEY"]
                SessionDebugLogger.log("env", "resolved shell environment: \(SessionDebugLogger.summarizeEnvironment(environment))")
                completion(environment)
            }
        }

        do {
            try proc.run()
        } catch {
            completion([:])
        }
    }

    func resolvePreferredBackend(completion: @escaping (Backend?, [String: String], String?) -> Void) {
        resolveShellEnvironment { [weak self] environment in
            guard let self else {
                completion(nil, environment, nil)
                return
            }

            SessionDebugLogger.log("backend", "resolving preferred backend. archiveMode=\(AppSettings.archiveAccessMode.rawValue)")

            self.resolveClaudeCodeBackend(environment: environment) { claudeBackend in
                if let claudeBackend {
                    SessionDebugLogger.log("backend", "selected Claude backend")
                    completion(claudeBackend, environment, nil)
                    return
                }

                self.resolveCodexBackend(environment: environment) { codexBackend in
                    if let codexBackend {
                        SessionDebugLogger.log("backend", "selected Codex backend")
                        completion(codexBackend, environment, nil)
                        return
                    }

                    if let key = environment["OPENAI_API_KEY"], !key.isEmpty {
                        SessionDebugLogger.log("backend", "selected direct OpenAI Responses API backend")
                        completion(.openAIResponsesAPI, environment, nil)
                        return
                    }

                    SessionDebugLogger.log("backend", "no backend available")
                    completion(nil, environment, self.backendSetupMessage(environment: environment))
                }
            }
        }
    }

    func resolveClaudeCodeBackend(environment: [String: String], completion: @escaping (Backend?) -> Void) {
        guard let executable = executablePath(named: "claude", environment: environment) else {
            SessionDebugLogger.log("backend", "claude executable not found")
            completion(nil)
            return
        }

        if let apiKey = environment["ANTHROPIC_API_KEY"], !apiKey.isEmpty {
            SessionDebugLogger.log("backend", "claude available via ANTHROPIC_API_KEY")
            completion(.claudeCodeCLI(path: executable))
            return
        }

        runProcess(
            executablePath: executable,
            arguments: ["auth", "status"],
            environment: environment,
            workingDirectory: nil
        ) { status, stdout, _ in
            let isLoggedIn = self.isClaudeAuthenticated(exitCode: status, stdout: stdout)
            SessionDebugLogger.log("backend", "claude auth status exitCode=\(status) authenticated=\(isLoggedIn)")
            completion(isLoggedIn ? .claudeCodeCLI(path: executable) : nil)
        }
    }

    func resolveCodexBackend(environment: [String: String], completion: @escaping (Backend?) -> Void) {
        guard let executable = executablePath(named: "codex", environment: environment) else {
            SessionDebugLogger.log("backend", "codex executable not found")
            completion(nil)
            return
        }

        if let apiKey = environment["OPENAI_API_KEY"], !apiKey.isEmpty {
            SessionDebugLogger.log("backend", "codex available via OPENAI_API_KEY")
            completion(.codexCLI(path: executable))
            return
        }

        runProcess(
            executablePath: executable,
            arguments: ["login", "status"],
            environment: environment,
            workingDirectory: nil
        ) { status, stdout, _ in
            let normalized = stdout.lowercased()
            let isLoggedIn = status == 0 && (normalized.contains("logged in") || normalized.contains("chatgpt"))
            SessionDebugLogger.log("backend", "codex login status exitCode=\(status) authenticated=\(isLoggedIn)")
            completion(isLoggedIn ? .codexCLI(path: executable) : nil)
        }
    }

    func executablePath(named name: String, environment: [String: String]) -> String? {
        let rawPath = environment["PATH"] ?? ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in rawPath.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    func isClaudeAuthenticated(exitCode: Int32, stdout: String) -> Bool {
        if let data = stdout.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let loggedIn = json["loggedIn"] as? Bool {
            return loggedIn
        }
        return exitCode == 0
    }

    func officialMCPToken(from environment: [String: String]) -> String? {
        if let override = AppSettings.officialLennyMCPToken {
            SessionDebugLogger.log("mcp", "using official MCP token from Settings")
            return override
        }
        if let custom = environment[Constants.lennyMCPAuthEnvVar]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            SessionDebugLogger.log("mcp", "using official MCP token from environment variable \(Constants.lennyMCPAuthEnvVar)")
            return custom
        }
        SessionDebugLogger.log("mcp", "no official MCP token available")
        return nil
    }

    func backendStatusMessage(for backend: Backend) -> String {
        let archiveLabel = AppSettings.archiveAccessMode == .starterPack
            ? "bundled starter archive"
            : "official Lenny MCP"
        switch backend {
        case .claudeCodeCLI:
            return "Using Claude Code CLI with \(archiveLabel)"
        case .codexCLI:
            return "Using Codex CLI with \(archiveLabel)"
        case .openAIResponsesAPI:
            return "Using direct OpenAI Responses API with \(archiveLabel)"
        }
    }

    func backendSetupMessage(environment: [String: String]) -> String {
        let hasOpenAIKey = !(environment["OPENAI_API_KEY"] ?? "").isEmpty
        let hasAnthropicKey = !(environment["ANTHROPIC_API_KEY"] ?? "").isEmpty
        let hasCustomMCPKey = !(environment[Constants.lennyMCPAuthEnvVar] ?? "").isEmpty

        var lines = [
            "No default AI transport is configured yet.",
            "",
            "Preferred setup order:",
            "1. Claude Code CLI with `ANTHROPIC_API_KEY` or Claude login",
            "2. Codex CLI with ChatGPT login or `OPENAI_API_KEY`",
            "3. Direct OpenAI API fallback with `OPENAI_API_KEY`",
            "",
            "Free mode uses the bundled starter archive locally.",
            "Official MCP mode requires your own Lenny setup in Settings or your own token via `\(Constants.lennyMCPAuthEnvVar)`."
        ]

        if hasAnthropicKey || hasOpenAIKey || hasCustomMCPKey {
            lines.append("")
            lines.append("Detected in your shell:")
            if hasAnthropicKey { lines.append("- `ANTHROPIC_API_KEY`") }
            if hasOpenAIKey { lines.append("- `OPENAI_API_KEY`") }
            if hasCustomMCPKey { lines.append("- `\(Constants.lennyMCPAuthEnvVar)`") }
        }

        return lines.joined(separator: "\n")
    }

    func buildConversationPrompt(message: String, attachments: [SessionAttachment], expert: ResponderExpert?, conversationKey: String, archiveContext: String?, expectMCP: Bool) -> String {
        let instructions = buildInstructions(for: expert)
        let priorMessages = (conversations[conversationKey]?.history ?? []).dropLast()
        let transcript = priorMessages.compactMap { message -> String? in
            switch message.role {
            case .user:
                return "User: \(message.text)"
            case .assistant:
                return "Assistant: \(message.text)"
            case .error:
                return "System error: \(message.text)"
            case .toolUse, .toolResult:
                return nil
            }
        }.joined(separator: "\n\n")

        var sections = [
            "System instructions:\n\(instructions)"
        ]

        if !transcript.isEmpty {
            sections.append("Conversation so far:\n\(transcript)")
        }

        sections.append("Latest user message:\n\(buildUserPrompt(message: message, attachments: attachments, expert: expert, archiveContext: archiveContext))")

        let attachmentContext = attachmentPromptSections(for: attachments)
        if !attachmentContext.isEmpty {
            sections.append("Attachment context:\n\(attachmentContext)")
        }

        sections.append(expectMCP ? "Use the Lenny archive MCP tools whenever they help answer the question. Return only the JSON object described above." : "Answer using the bundled starter archive context above. Be explicit when the starter pack does not include enough evidence. Return only the JSON object described above.")
        return sections.joined(separator: "\n\n")
    }

    func attachmentPromptSections(for attachments: [SessionAttachment]) -> String {
        attachments.compactMap { attachment in
            switch attachment.kind {
            case .image:
                return "Image attachment: \(attachment.displayName) at \(attachment.url.path)"
            case .document:
                guard let extractedText = documentText(for: attachment.url), !extractedText.isEmpty else {
                    return "Document attachment: \(attachment.displayName)"
                }
                return "Document attachment: \(attachment.displayName)\n\(extractedText)"
            }
        }.joined(separator: "\n\n")
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
            return ResponderExpert(
                name: name,
                avatarPath: avatarPath,
                archiveContext: "- \(match.entry.title) (\(match.entry.date)): \(match.excerpt)",
                responseScript: responseScript(for: name, context: "- \(match.entry.title) (\(match.entry.date)): \(match.excerpt)")
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
        var experts = pendingExperts
        pendingExperts.removeAll()

        if experts.isEmpty, let fallbackText {
            experts = expertsFromAssistantText(fallbackText)
            if !experts.isEmpty {
                SessionDebugLogger.log("experts", "derived \(experts.count) expert candidate(s) from assistant text fallback")
            }
        }

        guard !experts.isEmpty else {
            SessionDebugLogger.log("experts", "no staged experts to publish")
            return
        }

        let names = experts.map(\.name).joined(separator: ", ")
        SessionDebugLogger.log("experts", "publishing \(experts.count) expert candidate(s) after response completion: \(names)")
        onExpertsUpdated?(experts)
    }

    func callClaudeCodeCLI(executablePath: String, message: String, attachments: [SessionAttachment], environment: [String: String], expert: ResponderExpert?, conversationKey: String, archiveContext: String?, officialMCPToken: String?) {
        let useOfficialMCP = officialMCPToken != nil
        let planningSummary = useOfficialMCP
            ? (expert == nil ? "Using Claude Code CLI and the official Lenny MCP server" : "Continuing \(expert!.name)'s thread through Claude Code CLI and the official Lenny MCP server")
            : (expert == nil ? "Using Claude Code CLI with bundled starter archive context" : "Continuing \(expert!.name)'s thread through Claude Code CLI and bundled starter archive context")
        onToolUse?("Planning", ["summary": planningSummary])
        appendHistory(Message(role: .toolUse, text: "Planning: \(planningSummary)"), to: conversationKey)

        let prompt = buildConversationPrompt(message: message, attachments: attachments, expert: expert, conversationKey: conversationKey, archiveContext: archiveContext, expectMCP: useOfficialMCP)
        var configURL: URL?

        if useOfficialMCP, let token = officialMCPToken {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("lil-agents-claude-mcp-\(UUID().uuidString).json")
            let config: [String: Any] = [
                "mcpServers": [
                    Constants.lennyMCPServerLabel: [
                        "type": "http",
                        "url": Constants.lennyMCPURL,
                        "headers": [
                            "Authorization": "Bearer \(token)"
                        ]
                    ]
                ]
            ]

            do {
                let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted])
                try data.write(to: url, options: [.atomic])
                configURL = url
            } catch {
                failTurn("Couldn’t prepare the Claude Code MCP config.", conversationKey: conversationKey)
                return
            }
        }

        var args = [
            "-p",
            prompt,
            "--output-format",
            "json",
            "--permission-mode",
            "dontAsk"
        ]

        if useOfficialMCP {
            args.append(contentsOf: ["--allowedTools", "mcp__\(Constants.lennyMCPServerLabel)__*"])
            if let configURL {
                args.append(contentsOf: ["--mcp-config", configURL.path, "--strict-mcp-config"])
            }
        }

        if environment["ANTHROPIC_API_KEY"] != nil {
            args.append("--bare")
        }

        SessionDebugLogger.logMultiline(
            "claude-cli",
            header: "dispatching Claude Code CLI. executable=\(executablePath) useOfficialMCP=\(useOfficialMCP) configURL=\(configURL?.path ?? "none") args=\(args)",
            body: prompt
        )

        runProcess(
            executablePath: executablePath,
            arguments: args,
            environment: environment,
            workingDirectory: preferredWorkingDirectoryURL()
        ) { [weak self] status, stdout, stderr in
            guard let self else { return }
            if let configURL {
                try? FileManager.default.removeItem(at: configURL)
            }

            SessionDebugLogger.logMultiline(
                "claude-cli",
                header: "Claude Code CLI finished. exitCode=\(status)",
                body: "stdout:\n\(stdout)\n\nstderr:\n\(stderr)"
            )
            self.logClaudeCLIResultMetadata(from: stdout)

            let outputText = self.extractClaudeCLIResult(from: stdout)
            if status == 0, let outputText, !outputText.isEmpty {
                self.finishCLIResponse(outputText, conversationKey: conversationKey)
                return
            }

            let errorText = self.normalizeCLIError(stdout: stdout, stderr: stderr, fallback: "Claude Code CLI could not complete the request.")
            self.failTurn(errorText, conversationKey: conversationKey)
        }
    }

    func callCodexCLI(executablePath: String, message: String, attachments: [SessionAttachment], environment: [String: String], expert: ResponderExpert?, conversationKey: String, archiveContext: String?, useBundledMCP: Bool) {
        let planningSummary = useBundledMCP
            ? (expert == nil ? "Using Codex CLI and the official Lenny MCP server" : "Continuing \(expert!.name)'s thread through Codex CLI and the official Lenny MCP server")
            : (expert == nil ? "Using Codex CLI with bundled starter archive context" : "Continuing \(expert!.name)'s thread through Codex CLI and bundled starter archive context")
        onToolUse?("Planning", ["summary": planningSummary])
        appendHistory(Message(role: .toolUse, text: "Planning: \(planningSummary)"), to: conversationKey)

        let prompt = buildConversationPrompt(message: message, attachments: attachments, expert: expert, conversationKey: conversationKey, archiveContext: archiveContext, expectMCP: useBundledMCP)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("lil-agents-codex-last-message-\(UUID().uuidString).md")
        var runtimeEnvironment = environment
        if let token = officialMCPToken(from: environment) {
            runtimeEnvironment[Constants.lennyMCPAuthEnvVar] = token
        }

        var args = [
            "exec",
            "--skip-git-repo-check",
            "-s",
            "read-only",
            "-o",
            outputURL.path
        ]

        if useBundledMCP {
            if officialMCPToken(from: environment) != nil {
                args.append(contentsOf: [
                    "-c",
                    "mcp_servers.\(Constants.lennyMCPServerLabel).url=\"\(Constants.lennyMCPURL)\"",
                    "-c",
                    "mcp_servers.\(Constants.lennyMCPServerLabel).bearer_token_env_var=\"\(Constants.lennyMCPAuthEnvVar)\""
                ])
            }
        }

        args.append(prompt)

        for attachment in attachments where attachment.kind == .image {
            args.insert(contentsOf: ["-i", attachment.url.path], at: args.count - 1)
        }

        SessionDebugLogger.logMultiline(
            "codex-cli",
            header: "dispatching Codex CLI. executable=\(executablePath) useOfficialMCP=\(useBundledMCP) args=\(args)",
            body: prompt
        )

        runProcess(
            executablePath: executablePath,
            arguments: args,
            environment: runtimeEnvironment,
            workingDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        ) { [weak self] status, stdout, stderr in
            guard let self else { return }
            defer { try? FileManager.default.removeItem(at: outputURL) }

            SessionDebugLogger.logMultiline(
                "codex-cli",
                header: "Codex CLI finished. exitCode=\(status) outputFile=\(outputURL.path)",
                body: "stdout:\n\(stdout)\n\nstderr:\n\(stderr)"
            )

            let outputText = (try? String(contentsOf: outputURL, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let outputText {
                SessionDebugLogger.logMultiline("codex-cli", header: "Codex CLI output file contents", body: outputText)
            }

            if status == 0, let outputText, !outputText.isEmpty {
                self.finishCLIResponse(outputText, conversationKey: conversationKey)
                return
            }

            let errorText = self.normalizeCLIError(stdout: stdout, stderr: stderr, fallback: "Codex CLI could not complete the request.")
            self.failTurn(errorText, conversationKey: conversationKey)
        }
    }

    func finishCLIResponse(_ outputText: String, conversationKey: String) {
        let cleanedOutput = prepareAssistantOutput(outputText)
        publishPendingExperts(fallbackText: cleanedOutput)
        SessionDebugLogger.logMultiline("assistant", header: "finishCLIResponse()", body: cleanedOutput)
        let composeSummary = "Composing the final answer"
        onToolUse?("Writing", ["summary": composeSummary])
        appendHistory(Message(role: .toolUse, text: "Writing: \(composeSummary)"), to: conversationKey)
        appendHistory(Message(role: .assistant, text: cleanedOutput), to: conversationKey)
        onText?(cleanedOutput)
        finishTurn()
    }

    func prepareAssistantOutput(_ outputText: String) -> String {
        if let payload = parseStructuredAssistantPayload(from: outputText) {
            if pendingExperts.isEmpty, payload.suggestExpertPrompt {
                let structuredExperts = payload.suggestedExperts.compactMap { name -> ResponderExpert? in
                    guard let avatarPath = avatarPath(for: name) else { return nil }
                    let context = "Explicitly suggested by the assistant in the latest answer."
                    return ResponderExpert(
                        name: name,
                        avatarPath: avatarPath,
                        archiveContext: context,
                        responseScript: responseScript(for: name, context: context)
                    )
                }

                if !structuredExperts.isEmpty {
                    pendingExperts = Array(structuredExperts.prefix(3))
                    let names = pendingExperts.map(\.name).joined(separator: ", ")
                    SessionDebugLogger.log("experts", "parsed \(pendingExperts.count) JSON expert candidate(s) from assistant output: \(names)")
                }
            }

            return payload.answerMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let structuredNames = structuredExpertSuggestionNames(from: outputText)
        if pendingExperts.isEmpty, !structuredNames.isEmpty {
            let structuredExperts = structuredNames.compactMap { name -> ResponderExpert? in
                guard let avatarPath = avatarPath(for: name) else { return nil }
                let context = "Explicitly suggested by the assistant in the latest answer."
                return ResponderExpert(
                    name: name,
                    avatarPath: avatarPath,
                    archiveContext: context,
                    responseScript: responseScript(for: name, context: context)
                )
            }

            if !structuredExperts.isEmpty {
                pendingExperts = Array(structuredExperts.prefix(3))
                let names = pendingExperts.map(\.name).joined(separator: ", ")
                SessionDebugLogger.log("experts", "parsed \(pendingExperts.count) structured expert candidate(s) from assistant output: \(names)")
            }
        }

        return cleanedAssistantText(outputText)
    }

    func parseStructuredAssistantPayload(from outputText: String) -> (answerMarkdown: String, suggestedExperts: [String], suggestExpertPrompt: Bool)? {
        let trimmed = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonCandidate = trimmed
            .replacingOccurrences(of: #"^```json\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^```\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonCandidate.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let answerMarkdown = json["answer_markdown"] as? String else {
            return nil
        }

        let suggestedExperts = (json["suggested_experts"] as? [String] ?? [])
            .compactMap { canonicalExpertName(for: $0) }
        let suggestExpertPrompt = json["suggest_expert_prompt"] as? Bool ?? !suggestedExperts.isEmpty

        SessionDebugLogger.log("assistant", "parsed structured JSON assistant payload. suggestedExperts=\(suggestedExperts.joined(separator: ", ")) prompt=\(suggestExpertPrompt)")
        return (answerMarkdown, suggestedExperts, suggestExpertPrompt)
    }

    func extractClaudeCLIResult(from stdout: String) -> String? {
        guard let data = stdout.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let result = json["result"] as? String {
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let output = json["output"] as? String {
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    func logClaudeCLIResultMetadata(from stdout: String) {
        guard let data = stdout.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if let permissionDenials = json["permission_denials"] as? [[String: Any]], !permissionDenials.isEmpty {
            SessionDebugLogger.logMultiline(
                "claude-cli",
                header: "Claude Code permission denials detected: \(permissionDenials.count)",
                body: String(describing: permissionDenials)
            )
        }

        if let numTurns = json["num_turns"] as? Int,
           let duration = json["duration_ms"] as? Int {
            SessionDebugLogger.log("claude-cli", "Claude Code metadata num_turns=\(numTurns) duration_ms=\(duration)")
        }
    }

    func normalizeCLIError(stdout: String, stderr: String, fallback: String) -> String {
        let combined = [stderr, stdout]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard !combined.isEmpty else { return fallback }
        return combined
    }

    func runProcess(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: URL?,
        completion: @escaping (Int32, String, String) -> Void
    ) {
        SessionDebugLogger.log("process", "launching process executable=\(executablePath) args=\(arguments) cwd=\(workingDirectory?.path ?? FileManager.default.currentDirectoryPath)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = workingDirectory

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        process.terminationHandler = { _ in
            let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
            let stdoutText = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                completion(process.terminationStatus, stdoutText, stderrText)
            }
        }

        do {
            try process.run()
        } catch {
            completion(-1, "", error.localizedDescription)
        }
    }

    func imageDataURL(for url: URL) -> String? {
        guard let image = NSImage(contentsOf: url) else { return nil }

        let maxDimension: CGFloat = 1600
        let originalSize = image.size
        let scale = min(1, maxDimension / max(originalSize.width, originalSize.height))
        let targetSize = NSSize(width: max(1, originalSize.width * scale), height: max(1, originalSize.height * scale))

        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize), from: NSRect(origin: .zero, size: originalSize), operation: .copy, fraction: 1.0)
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }

        let hasAlpha = bitmap.hasAlpha
        let data: Data?
        let mimeType: String

        if hasAlpha {
            data = bitmap.representation(using: .png, properties: [:])
            mimeType = "image/png"
        } else {
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
            mimeType = "image/jpeg"
        }

        guard let encoded = data?.base64EncodedString() else { return nil }
        return "data:\(mimeType);base64,\(encoded)"
    }

    func documentText(for url: URL) -> String? {
        let ext = url.pathExtension.lowercased()

        if ext == "pdf" {
            guard let pdf = PDFDocument(url: url) else { return nil }
            return trimmedDocumentText(pdf.string)
        }

        if ext == "rtf",
           let attributed = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
            return trimmedDocumentText(attributed.string)
        }

        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return trimmedDocumentText(text)
    }

    func trimmedDocumentText(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(12_000))
    }
}
