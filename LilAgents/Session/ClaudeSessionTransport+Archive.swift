import Foundation

extension ClaudeSession {
    private static let githubArchiveRawBase = "https://raw.githubusercontent.com/pathpoint/pathpoint-knowledge-base/main"

    func githubArchiveContext(for backend: Backend, expert: ResponderExpert?) -> String {
        let expertHint = expert.map { "\nFocus on content featuring \($0.name)." } ?? ""
        switch backend {
        case .claudeCodeCLI, .codexCLI:
            return """
            Use WebFetch to search Pathpoint's knowledge base on GitHub:\(expertHint)
            1. Fetch the index to discover what's available:
               \(Self.githubArchiveRawBase)/index.json
               (JSON with content arrays; each entry has: title, filename, date, description)
            2. Fetch 1–3 of the most relevant files:
               \(Self.githubArchiveRawBase)/{filename}
            3. Ground your answer in what you retrieved.
            Do not describe the fetching steps in your response.
            """
        case .openAIResponsesAPI:
            return """
            Pathpoint's knowledge base:\(expertHint)
            Index: \(Self.githubArchiveRawBase)/index.json
            Files: \(Self.githubArchiveRawBase)/{filename}
            Answer based on Pathpoint's E&S insurance content. Cite specific sources when relevant.
            """
        }
    }

    func searchStarterArchive(message: String, expert: ResponderExpert?) -> (promptContext: String, experts: [ResponderExpert], summary: String, resultSummary: String) {
        let query = [expert?.name, message]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        SessionDebugLogger.log("starter-pack", "search query=\(query)")

        // --- Class code appetite lookup ---
        let classCodeRows = ClassCodeArchive.shared.search(query: query, limit: 8)
        let classCodeContext = ClassCodeArchive.shared.promptContext(for: classCodeRows)

        // --- FAQ lookup ---
        let faqMatches = LocalArchive.shared.search(query: query, limit: 3)

        let hasClassCodes = !classCodeRows.isEmpty
        let hasFAQs = !faqMatches.isEmpty

        if !hasClassCodes && !hasFAQs {
            let promptContext = """
            The bundled starter archive did not contain a strong match for this query.
            Be transparent that the starter pack only includes a limited set of Pathpoint FAQs and class code appetite data.
            Suggest switching Settings to Official Pathpoint MCP for the full archive if needed.
            """
            return (
                promptContext,
                [],
                "Searching the bundled starter pack",
                "No strong matches found in the bundled starter pack"
            )
        }

        var contextParts: [String] = []

        if hasClassCodes {
            contextParts.append(classCodeContext)
        }

        if hasFAQs {
            let faqLines = faqMatches.enumerated().map { index, match in
                let subtitle = match.entry.subtitle ?? match.entry.description ?? ""
                let subtitleSuffix = subtitle.isEmpty ? "" : "\nSubtitle: \(subtitle)"
                return """
                \(index + 1). [FAQ] \(match.entry.title) (\(match.entry.date))\(subtitleSuffix)
                Excerpt: \(match.excerpt)
                """
            }
            contextParts.append("Related FAQ content:\n" + faqLines.joined(separator: "\n\n"))
        }

        let promptContext = contextParts.joined(separator: "\n\n---\n\n")

        let experts = faqMatches.compactMap { match -> ResponderExpert? in
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

        let totalCount = classCodeRows.count + faqMatches.count
        return (
            promptContext,
            Array(uniqueExperts.prefix(3)),
            "Searching the bundled starter pack",
            "Loaded \(totalCount) starter-pack result\(totalCount == 1 ? "" : "s") (\(classCodeRows.count) class code\(classCodeRows.count == 1 ? "" : "s"), \(faqMatches.count) FAQ\(faqMatches.count == 1 ? "" : "s"))"
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
}
