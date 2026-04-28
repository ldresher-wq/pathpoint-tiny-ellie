import Foundation

extension ClaudeSession {
    var history: [Message] { history(for: focusedExpert) }

    func history(for expert: ResponderExpert?) -> [Message] {
        conversations[key(for: expert)]?.history ?? []
    }

    func key(for expert: ResponderExpert?) -> String {
        if let expert {
            return "expert:\(normalize(expert.name))"
        }
        return "ellie"
    }

    func appendHistory(_ message: Message, to key: String) {
        var state = conversations[key] ?? ConversationState()
        state.history.append(message)
        conversations[key] = state
    }

    func lastReadHistoryCount(for expert: ResponderExpert?) -> Int {
        conversations[key(for: expert)]?.lastReadHistoryCount ?? 0
    }

    func markConversationRead(for expert: ResponderExpert?) {
        let conversationKey = key(for: expert)
        var state = conversations[conversationKey] ?? ConversationState()
        let historyCount = state.history.count
        guard historyCount > state.lastReadHistoryCount else { return }
        state.lastReadHistoryCount = historyCount
        conversations[conversationKey] = state
    }

    func expertSuggestionEntries(for expert: ResponderExpert?) -> [ExpertSuggestionEntry] {
        conversations[key(for: expert)]?.expertSuggestionEntries ?? []
    }

    func appendExpertSuggestionEntry(_ experts: [ResponderExpert], for expert: ResponderExpert?) {
        guard !experts.isEmpty else { return }

        let conversationKey = key(for: expert)
        var state = conversations[conversationKey] ?? ConversationState()

        if let lastEntry = state.expertSuggestionEntries.last,
           lastEntry.anchorHistoryCount == state.history.count,
           lastEntry.experts.map(\.name) == experts.map(\.name) {
            conversations[conversationKey] = state
            return
        }

        state.expertSuggestionEntries.append(ExpertSuggestionEntry(
            anchorHistoryCount: state.history.count,
            experts: experts
        ))
        conversations[conversationKey] = state
    }

    func collapseExpertSuggestionEntry(_ entryID: UUID, pickedExpert: ResponderExpert, for expert: ResponderExpert?) {
        let conversationKey = key(for: expert)
        guard var state = conversations[conversationKey],
              let index = state.expertSuggestionEntries.firstIndex(where: { $0.id == entryID }) else { return }

        state.expertSuggestionEntries[index].pickedExpert = pickedExpert
        state.expertSuggestionEntries[index].isCollapsed = true
        conversations[conversationKey] = state
    }

    func expandExpertSuggestionEntry(_ entryID: UUID, for expert: ResponderExpert?) {
        let conversationKey = key(for: expert)
        guard var state = conversations[conversationKey],
              let index = state.expertSuggestionEntries.firstIndex(where: { $0.id == entryID }) else { return }

        state.expertSuggestionEntries[index].isCollapsed = false
        conversations[conversationKey] = state
    }

    func finishTurn() {
        isBusy = false
        onTurnComplete?()
    }

    func failTurn(_ text: String) {
        failTurn(text, conversationKey: key(for: focusedExpert))
    }

    func failTurn(_ text: String, conversationKey: String) {
        isBusy = false
        pendingExperts.removeAll()
        assistantExplicitlyRequestedExperts = false
        appendHistory(Message(role: .error, text: text), to: conversationKey)
        onError?(text)
        onTurnComplete?()
    }

    func buildInstructions(for expert: ResponderExpert?, expectMCP: Bool) -> String {
        let base = """
        You are Ellie, Pathpoint's AI assistant for retail insurance agents. Pathpoint is an E&S (Excess & Surplus lines) wholesale broker that helps retail agents place non-standard, hard-to-place, and specialty commercial insurance risks.
        Your role is AI-SDR for Pathpoint. Your primary job is to keep retail insurance agents engaged with the Pathpoint platform so they continue to submit E&S business through Pathpoint. Every interaction should leave the agent feeling confident, informed, and motivated to bring their next E&S risk to Pathpoint.
        You help retail agents with: understanding Pathpoint's appetite and eligible classes of business, navigating the submission process, getting quotes and coverage questions answered, understanding E&S market dynamics, and identifying which risks are a good fit for Pathpoint versus standard markets.
        Always be professional, accurate, warm, and helpful. Never guess or fabricate specific policy terms, rates, or coverage details — if you are uncertain, say so clearly and invite the agent to submit for a quote or speak with an underwriter.
        Ground every factual claim about Pathpoint's appetite, products, or processes in the knowledge base content you explicitly retrieved via the available tools.
        Do NOT fabricate coverage details, appetite information, or process specifics from training data.
        Write clear, practical answers that help the agent move forward. Match response length to the complexity of the question — concise for simple questions, thorough for complex ones.
        Return only valid JSON, with no prose before or after it and no code fences.
        Use this exact shape:
        {
          "messages": [
            {
              "speaker": "Ellie",
              "kind": "lenny",
              "markdown": "Great question — let me pull up Pathpoint's appetite for that class."
            },
            {
              "speaker": "Underwriting Specialist",
              "kind": "expert",
              "markdown": "For habitational risks with prior losses, we'd want to see a full loss run and the property's current condition report."
            }
          ],
          "suggested_experts": ["Name One", "Name Two"],
          "suggest_expert_prompt": true
        }
        `messages` should be a transcript-ready array of separate speaker messages.
        Use `kind: "lenny"` for Ellie's main messages and `kind: "expert"` for specialist responses.
        When a specialist perspective is relevant, Ellie should briefly introduce them, then the specialist speaks in a separate message.
        Expert messages must be written in first person from that specialist's perspective.
        Do not write expert messages in third person, such as "\(expert?.name ?? "The specialist") would..." or "From \(expert?.name ?? "the specialist")'s perspective...".
        Keep Ellie's introduction line to one short sentence.
        If Ellie tags a specialist in the intro line, use the visible `@Name` form.
        Do not include mini-bios or long justification in Ellie's intro line.
        Let the specialist messages carry the substance.
        If no specialist is warranted, return a single Ellie message.
        `suggested_experts` should include up to 3 relevant specialists you explicitly relied on or cited.
        If there are no useful expert suggestions, return an empty array and set `suggest_expert_prompt` to false.
        """

        let mcpInstructions = expectMCP ? """

        The Pathpoint MCP server is available with the following tools:
        - `index.md` — Pathpoint's master index mapping topics, classes of business, and processes to content sources
        - `read_excerpt` — Retrieve targeted excerpts from Pathpoint knowledge base sources
        - `read_content` — Read full content blocks from the Pathpoint knowledge base

        When Pathpoint MCP tools are available, prefer a fast routing pass before deep reading:
        1. Call the `index.md` first to identify the right class of business, topic, or process.
        2. If the index points to a likely source, use `read_excerpt` to narrow to that content next.
        3. Only then use `read_content` for deeper full-text reads if needed.
        Always ground your answer in the content you retrieved. Prefer the minimum number of MCP calls needed for a grounded answer.
        """ : ""

        if let expert {
            return base + mcpInstructions + """

            The user explicitly switched into \(expert.name)'s view.
            Answer in first person as \(expert.name).
            Return exactly one expert message spoken by \(expert.name), unless the user explicitly asks to compare with others.
            \(expectMCP ? "If MCP tools are available, check `index.md` for \(expert.name) first, then stay in that context unless the user asks to pivot." : "Use the provided context for \(expert.name) if available, and stay in that context unless the user asks to pivot.")
            Do not mention the knowledge base, MCP, retrieval, references, or source-gathering process in the final answer unless the user explicitly asks about it.
            Speak as \(expert.name), not as an assistant describing \(expert.name).
            \(expert.responseScript)
            \(expertContextPrompt(expert.archiveContext))
            """
        }

        return base + mcpInstructions
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
            return "Follow-up focus: \(expert.name)\nAnswer from \(expert.name)'s perspective.\nQuestion: \(baseMessage)\(attachmentContext)\(archiveSection)"
        }
        return baseMessage + attachmentContext + archiveSection
    }

    func expertContextPrompt(_ context: String) -> String {
        let trimmed = context.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("Explicitly suggested by the assistant") else {
            return ""
        }
        return "Ground the answer in this expert context first:\n\(trimmed)"
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

    func buildConversationPrompt(message: String, attachments: [SessionAttachment], expert: ResponderExpert?, conversationKey: String, archiveContext: String?, expectMCP: Bool) -> String {
        let instructions = buildInstructions(for: expert, expectMCP: expectMCP)
        let priorMessages = promptHistory(for: conversationKey, expert: expert)
        let transcript = priorMessages.compactMap { message -> String? in
            switch message.role {
            case .user:
                return "User: \(trimPromptContext(message.text, limit: 700))"
            case .assistant:
                let label = message.speaker?.name ?? "Assistant"
                return "\(label): \(trimPromptContext(message.text, limit: 1_400))"
            case .error:
                return "System error: \(trimPromptContext(message.text, limit: 500))"
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

        if expectMCP {
            sections.append("Retrieve information ONLY using the Pathpoint MCP tools. Do not use WebFetch, WebSearch, or any other tool. Do not draw on training data for Pathpoint-specific content. Start with `index.md` for fast routing, then narrow to the right class/topic, then read deeper only as needed. In expert mode, route through `index.md` to that specialist first. Return only the JSON object described above.")
        } else {
            sections.append("Retrieve information ONLY from the Pathpoint knowledge base content explicitly provided above. Do not use WebSearch. Do not fetch from any other website. Do not use training knowledge for Pathpoint-specific content. Answer based solely on what you retrieved. Return only the JSON object described above.")
        }
        return sections.joined(separator: "\n\n")
    }

    func promptHistory(for conversationKey: String, expert: ResponderExpert?) -> ArraySlice<Message> {
        let history = conversations[conversationKey]?.history ?? []
        let trimmed = Array(history.dropLast())
        let maxMessages = expert == nil ? 6 : 4
        return trimmed.suffix(maxMessages)
    }

    func trimPromptContext(_ text: String, limit: Int) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count > limit else { return normalized }
        return String(normalized.prefix(limit)) + "\n[Truncated for prompt length]"
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

    func assistantMessages(from segments: [AssistantSegment]) -> [Message] {
        segments.map { segment in
            Message(
                role: .assistant,
                text: segment.markdown,
                speaker: segment.speaker,
                followUpExpert: segment.followUpExpert
            )
        }
    }

    func ellieSpeaker() -> TranscriptSpeaker {
        TranscriptSpeaker(name: "Ellie", avatarPath: nil, kind: .lenny)
    }

    func systemSpeaker() -> TranscriptSpeaker {
        TranscriptSpeaker(name: "System", avatarPath: nil, kind: .system)
    }

    func speaker(for expert: ResponderExpert) -> TranscriptSpeaker {
        TranscriptSpeaker(name: expert.name, title: expert.title, avatarPath: expert.avatarPath, kind: .expert)
    }
}
