import AppKit

extension TerminalView {

    // MARK: - Paragraph styles

    private var assistantParagraph: NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 3
        p.paragraphSpacing = 4
        p.tailIndent = -16 // Padding from right edge
        return p
    }

    private func ensureNewline() {
        if let storage = textView.textStorage, storage.length > 0,
           !storage.string.hasSuffix("\n") {
            storage.append(NSAttributedString(string: "\n"))
        }
    }

    // MARK: - User bubble

    func appendUser(_ text: String, attachments: [SessionAttachment] = []) {
        let t = theme
        ensureNewline()

        // Label line: right-aligned "You"
        let labelPara = NSMutableParagraphStyle()
        labelPara.alignment = .right
        labelPara.paragraphSpacingBefore = 14
        labelPara.paragraphSpacing = 3
        labelPara.tailIndent = -16
        
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10.5, weight: .bold),
            .foregroundColor: t.textDim,
            .paragraphStyle: labelPara
        ]
        textView.textStorage?.append(NSAttributedString(string: "You\n", attributes: labelAttrs))

        // Message text: right-aligned
        let bubblePara = NSMutableParagraphStyle()
        bubblePara.alignment = .right
        bubblePara.paragraphSpacing = 2
        bubblePara.lineSpacing = 2
        bubblePara.tailIndent = -16
        
        let visibleText = text.isEmpty ? "(with attachments)" : text
        let bubbleAttrs: [NSAttributedString.Key: Any] = [
            .font: t.fontBold,
            .foregroundColor: t.textPrimary,
            .paragraphStyle: bubblePara
        ]
        textView.textStorage?.append(NSAttributedString(string: "\(visibleText)\n", attributes: bubbleAttrs))

        // Attachment note
        if !attachments.isEmpty {
            let attachText = attachments.map(\.displayName).joined(separator: ", ")
            let attachPara = NSMutableParagraphStyle()
            attachPara.alignment = .right
            attachPara.paragraphSpacing = 10
            attachPara.tailIndent = -16
            textView.textStorage?.append(NSAttributedString(string: "📎 \(attachText)\n", attributes: [
                .font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
                .foregroundColor: t.textDim,
                .paragraphStyle: attachPara
            ]))
        } else {
            // Spacer below bubble
            let spacerPara = NSMutableParagraphStyle()
            spacerPara.paragraphSpacing = 10
            textView.textStorage?.append(NSAttributedString(string: "\n", attributes: [
                .font: NSFont.systemFont(ofSize: 4),
                .paragraphStyle: spacerPara
            ]))
        }
        scrollToBottom()
    }

    // MARK: - Assistant streaming

    func appendStreamingText(_ text: String) {
        var cleaned = text
        // Strip leading newlines at start of response
        if currentAssistantText.isEmpty {
            cleaned = cleaned.replacingOccurrences(of: "^\\n+", with: "", options: .regularExpression)
        }
        currentAssistantText += cleaned
        if !cleaned.isEmpty {
            textView.textStorage?.append(TerminalMarkdownRenderer.render(cleaned, theme: theme))
            scrollToBottom()
        }
    }

    func beginAssistantTurn(name: String?) {
        let t = theme
        ensureNewline()
        let labelPara = NSMutableParagraphStyle()
        labelPara.alignment = .left
        labelPara.paragraphSpacingBefore = 14
        labelPara.paragraphSpacing = 4
        let labelName = name ?? t.titleString
        textView.textStorage?.append(NSAttributedString(string: "\(labelName)\n", attributes: [
            .font: NSFont.systemFont(ofSize: 10.5, weight: .semibold),
            .foregroundColor: t.accentColor,
            .paragraphStyle: labelPara
        ]))
    }

    func endStreaming() {
        isStreaming = false
        // Add breathing room after the assistant message
        let spacerPara = NSMutableParagraphStyle()
        spacerPara.paragraphSpacing = 12
        textView.textStorage?.append(NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 4),
            .paragraphStyle: spacerPara
        ]))
    }

    // MARK: - Error

    func appendError(_ text: String) {
        let t = theme
        ensureNewline()
        let errorPara = NSMutableParagraphStyle()
        errorPara.paragraphSpacingBefore = 8
        errorPara.paragraphSpacing = 8
        textView.textStorage?.append(NSAttributedString(string: text + "\n", attributes: [
            .font: t.font,
            .foregroundColor: t.errorColor,
            .paragraphStyle: errorPara
        ]))
        scrollToBottom()
    }

    // MARK: - Status (inline, minimal)

    func appendStatus(_ text: String) {
        // Status lives in the live-status pill, not the transcript.
        // Intentionally no-op for transcript — use setLiveStatus instead.
    }

    // MARK: - Expert suggestion text (no longer injected into transcript)

    func appendExpertSuggestion(_ experts: [ResponderExpert]) {
        // Expert suggestions are shown in the suggestion panel, not in the transcript.
        // We just update the panel from WalkerCharacterSessionWiring.
    }

    // MARK: - Tool use (shown in live status only)

    func appendToolUse(toolName: String, summary: String) {
        endStreaming()
        setLiveStatus(summary.isEmpty ? toolName : summary, isBusy: true, isError: false)
    }

    func appendToolResult(summary: String, isError: Bool) {
        setLiveStatus(summary, isBusy: false, isError: isError)
    }

    // MARK: - History replay

    func replayHistory(_ messages: [ClaudeSession.Message]) {
        let t = theme
        textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        currentAssistantText = ""
        var lastRole: ClaudeSession.Message.Role?
        for msg in messages {
            switch msg.role {
            case .user:
                appendUser(msg.text)
            case .assistant:
                if lastRole != .assistant {
                    beginAssistantTurn(name: t.titleString)
                }
                textView.textStorage?.append(TerminalMarkdownRenderer.render(msg.text + "\n", theme: t))
            case .error:
                appendError(msg.text)
            case .toolUse, .toolResult:
                continue
            }
            lastRole = msg.role
        }
        // Close the last assistant message if needed
        if lastRole == .assistant {
            endStreaming()
        }
        scrollToBottom()
    }

    // MARK: - Scroll helpers

    func scrollToBottom() {
        resizeTranscriptToFitContent()
        textView.scrollToEndOfDocument(nil)
    }

    func resizeTranscriptToFitContent() {
        guard let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager else { return }
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let targetHeight = max(scrollView.contentSize.height,
                               ceil(usedRect.height + textView.textContainerInset.height * 2 + 12))
        if abs(textView.frame.height - targetHeight) > 1 {
            textView.frame.size.height = targetHeight
        }
    }
}
