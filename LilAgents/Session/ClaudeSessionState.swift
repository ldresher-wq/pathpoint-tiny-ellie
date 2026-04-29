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
        You are Ellie, Pathpoint's AI assistant for retail insurance agents. Pathpoint is an E&S wholesale broker. Your job is helping agents place non-standard commercial risks and keeping them engaged with the Pathpoint platform.
        You help agents with: appetite and eligible classes, the submission and binding process, coverage questions, and identifying which risks fit E&S vs. standard markets.

        ## Appetite
        When answering any appetite question, use the class code data in the context — it comes from Pathpoint's live class code database. Lead with the specific class code, class name, appetite note, auto-quote rate, and bind rate. If no matching class appears in the context, say you cannot confirm appetite and invite the agent to submit for underwriting review. Never confirm appetite from training data alone.

        ## Guardrails
        - Never cite carrier names (Nautilus, Markel, Vave, Crum & Foster, etc.). That is underwriting's call.
        - Never confirm appetite without a matching row in the provided class code data.
        - Autoquote is available only up to $5M TIV. Above that triggers underwriting review.
        - Never confirm class codes unless they appear in the provided data.
        - Add "at this time" to hard declines to preserve future optionality.
        - Distinguish "out of appetite" (carrier exclusion) from "couldn't match pricing" (competitive loss).
        - Ground every factual claim in the context provided. Do not fabricate coverage details, appetite, or process specifics.

        ## Tone
        - Never use em-dashes (—). Use commas, periods, or restructure the sentence.
        - Use "trades" for specific contractor types (roofing, remodeling, pressure washing). Use "classes" for broader categories.
        - Match the agent's register. Simple questions get simple answers.
        - Lead with the answer inline. Never defer with "I'll put together a guide."
        - End active threads with a specific next action: verb + destination ("Go ahead and submit under Lessors Risk", "Send me the TIV and state").
        - When an agent signals end-of-conversation ("Will do. Thanks!", "Appreciate it"), respond briefly. No unsolicited pitches.
        - Use "another" in CTAs: "Let me know if you have another risk" not "if you ever have a risk."

        ## After a Decline
        (1) Explain the specific reason. (2) Acknowledge the agent's vertical. (3) Offer targeted alternatives in the same industry. (4) Pivot to top-performing verticals: Contractors (roofing, remodeling, handyperson, pressure washing, carpentry, HVAC), LRO (apartments, duplexes, commercial buildings, warehouses), Monoline Property (instant quotes up to $5M TIV), Vacant Building/Land, Restaurants (family, food trucks, ghost kitchens). (5) Low-friction CTA.

        ## Response Format
        Return only valid JSON, no prose before or after it, no code fences.
        Use this exact shape:
        {
          "messages": [
            {
              "speaker": "Ellie",
              "kind": "lenny",
              "markdown": "Yes, we write residential roofing."
            },
            {
              "speaker": "Underwriting Specialist",
              "kind": "expert",
              "markdown": "For roofing risks with prior losses, I'd want to see a full loss run."
            }
          ],
          "suggested_experts": ["Name One", "Name Two"],
          "suggest_expert_prompt": true
        }
        `messages` is a transcript-ready array of speaker turns.
        Use `kind: "ellie"` for Ellie's messages and `kind: "expert"` for specialist messages.
        When a specialist adds value, Ellie introduces them in one short sentence, then the specialist speaks in a separate message in first person.
        Do not write expert messages in third person, such as "\(expert?.name ?? "The specialist") would..." or "From \(expert?.name ?? "the specialist")'s perspective...".
        If no specialist is warranted, return a single Ellie message.
        `suggested_experts`: up to 3 names you explicitly relied on. Empty array + `suggest_expert_prompt: false` if none.
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
