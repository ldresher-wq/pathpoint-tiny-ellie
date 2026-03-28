import AppKit

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - Hoverable chip card for welcome suggestions

class HoverChipView: NSView {
    var onTapped: (() -> Void)?
    private let normalBg: CGColor
    private let hoverBg: CGColor

    init(symbol: String, label: String, theme: PopoverTheme) {
        self.normalBg = theme.inputBg.cgColor
        self.hoverBg = theme.accentColor.withAlphaComponent(0.06).cgColor
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = normalBg
        layer?.cornerRadius = 10
        layer?.borderWidth = 1.0
        layer?.borderColor = theme.separatorColor.withAlphaComponent(0.55).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        // Internal horizontal stack handles all alignment and padding
        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.alignment = .centerY
        hStack.spacing = 10
        hStack.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        hStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hStack)

        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: topAnchor),
            hStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            hStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
        ])

        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            iconView.image = img.withSymbolConfiguration(config)
        }
        iconView.contentTintColor = theme.accentColor
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 16).isActive = true
        hStack.addArrangedSubview(iconView)

        let textLabel = NSTextField(labelWithString: label)
        textLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .regular)
        textLabel.textColor = theme.textPrimary
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.maximumNumberOfLines = 2
        textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        hStack.addArrangedSubview(textLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            animator().layer?.backgroundColor = hoverBg
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            animator().layer?.backgroundColor = normalBg
        }
    }

    override func mouseDown(with event: NSEvent) {
        onTapped?()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

// MARK: - Welcome chips grid

class WelcomeChipsView: NSView {
    var onChipTapped: ((String) -> Void)?
    private let theme: PopoverTheme

    // (SF Symbol, display label, full question sent on tap)
    private let suggestions: [(String, String, String)] = [
        ("dollarsign.circle",     "How should I price my SaaS?",         "How should I price my SaaS?"),
        ("arrow.up.right.circle", "Best B2B growth tactics",              "What are the best B2B growth tactics?"),
        ("map",                   "How do I build a product roadmap?",    "How do I build a product roadmap?"),
        ("lightbulb",             "What makes a great product manager?",  "What makes a great product manager?"),
    ]

    init(theme: PopoverTheme) {
        self.theme = theme
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false

        let outerStack = NSStackView()
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 8
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outerStack)

        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            outerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])

        let pairs = stride(from: 0, to: suggestions.count, by: 2).map { i -> [(String, String, String)] in
            let end = min(i + 2, suggestions.count)
            return Array(suggestions[i..<end])
        }

        for pair in pairs {
            let rowStack = NSStackView()
            rowStack.orientation = .horizontal
            rowStack.alignment = .centerY
            rowStack.spacing = 8
            rowStack.distribution = .fillEqually
            rowStack.translatesAutoresizingMaskIntoConstraints = false

            var rowChips: [HoverChipView] = []
            for (symbol, label, sendText) in pair {
                let chip = HoverChipView(symbol: symbol, label: label, theme: theme)
                chip.onTapped = { [weak self] in self?.onChipTapped?(sendText) }
                rowStack.addArrangedSubview(chip)
                rowChips.append(chip)
            }
            // Ensure chips in the same row share an equal height
            if rowChips.count == 2 {
                rowChips[1].heightAnchor.constraint(equalTo: rowChips[0].heightAnchor).isActive = true
            }
            outerStack.addArrangedSubview(rowStack)
            rowStack.widthAnchor.constraint(equalTo: outerStack.widthAnchor).isActive = true
        }
    }
}

class ChatBubbleView: NSView, NSTextViewDelegate {
    let textView = NSTextView()
    let headerLabel = NSTextField(labelWithString: "")
    let bubbleBackground = NSView()
    private let isUser: Bool
    private let theme: PopoverTheme

    init(text: NSAttributedString, isUser: Bool, speakerName: String, theme: PopoverTheme) {
        self.isUser = isUser
        self.theme = theme
        super.init(frame: .zero)
        setupViews()
        populate(text: text, name: speakerName)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        headerLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        headerLabel.textColor = isUser ? theme.textDim : theme.accentColor
        headerLabel.alignment = .left
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.isEditable = false
        headerLabel.isBordered = false
        headerLabel.drawsBackground = false
        addSubview(headerLabel)

        bubbleBackground.wantsLayer = true
        bubbleBackground.layer?.cornerRadius = theme.bubbleCornerRadius
        bubbleBackground.layer?.backgroundColor = isUser
            ? theme.accentColor.withAlphaComponent(0.10).cgColor
            : theme.bubbleBg.cgColor
        bubbleBackground.layer?.borderWidth = isUser ? 0 : 0.75
        bubbleBackground.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.36).cgColor
        bubbleBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bubbleBackground)

        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        textView.linkTextAttributes = [
            .foregroundColor: theme.accentColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        let p = NSMutableParagraphStyle()
        p.lineSpacing = 4
        p.paragraphSpacing = 7
        p.alignment = .left
        textView.defaultParagraphStyle = p
        
        bubbleBackground.addSubview(textView)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: bubbleBackground.leadingAnchor, constant: 4),
            headerLabel.trailingAnchor.constraint(equalTo: bubbleBackground.trailingAnchor, constant: -4),

            bubbleBackground.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),
            bubbleBackground.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            textView.topAnchor.constraint(equalTo: bubbleBackground.topAnchor),
            textView.bottomAnchor.constraint(equalTo: bubbleBackground.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: bubbleBackground.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: bubbleBackground.trailingAnchor)
        ])

        if isUser {
            bubbleBackground.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
            bubbleBackground.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40).isActive = true
        } else {
            bubbleBackground.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
            bubbleBackground.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40).isActive = true
        }
    }

    private func populate(text: NSAttributedString, name: String) {
        headerLabel.stringValue = name
        configureTextContainer()
        textView.textStorage?.setAttributedString(text)
        recalculateSize()
    }

    func setText(_ newText: NSAttributedString) {
        configureTextContainer()
        textView.textStorage?.setAttributedString(newText)
        recalculateSize()
    }

    func appendText(_ newText: NSAttributedString) {
        configureTextContainer()
        textView.textStorage?.append(newText)
        recalculateSize()
    }

    private func configureTextContainer() {
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude)
    }

    private func recalculateSize() {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Start large
        textContainer.containerSize = NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let rect = layoutManager.usedRect(for: textContainer)
        
        let targetContentWidth = rect.width
        let paddingWidth: CGFloat = 28 // left+right 14px

        let maxWidth: CGFloat = 500
        let desiredWidth = targetContentWidth + paddingWidth

        // Cleanup old layout constraints
        textView.constraints.filter { $0.firstAttribute == .width || $0.firstAttribute == .height }.forEach { textView.removeConstraint($0) }
        
        if desiredWidth >= maxWidth {
            textContainer.containerSize = NSSize(width: maxWidth - paddingWidth, height: CGFloat.greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)
            let newRect = layoutManager.usedRect(for: textContainer)
            textView.widthAnchor.constraint(equalToConstant: maxWidth).isActive = true
            textView.heightAnchor.constraint(equalToConstant: newRect.height + 24).isActive = true
        } else {
            let finalWidth = max(desiredWidth, 60)
            textView.widthAnchor.constraint(equalToConstant: finalWidth).isActive = true
            textView.heightAnchor.constraint(equalToConstant: rect.height + 24).isActive = true
        }
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        var view: NSView? = self.superview
        while let v = view {
            if let terminal = v as? TerminalView {
                guard let url = link as? URL,
                      url.scheme == "lilagents-expert",
                      let host = url.host,
                      let expert = terminal.expertSuggestionTargets[host] else {
                    return false
                }
                terminal.onSelectExpert?(expert)
                return true
            }
            view = v.superview
        }
        return false
    }
}

extension TerminalView {
    func showWelcomeGreeting() {
        let t = theme
        let greeting = "Hey! I'm Lenny — your guide to product, growth, and startup strategy.\n\nI pull answers from my newsletter and podcast archive so you don't have to read everything. What's on your mind?"
        let attrText = NSAttributedString(string: greeting, attributes: [
            .font: t.font,
            .foregroundColor: t.textPrimary,
        ])
        let bubble = ChatBubbleView(text: attrText, isUser: false, speakerName: "Lenny", theme: t)
        transcriptStack.addArrangedSubview(bubble)
        bubble.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true

        let chips = WelcomeChipsView(theme: t)
        chips.onChipTapped = { [weak self] text in
            guard let self else { return }
            self.transcriptStack.removeArrangedSubview(chips)
            chips.removeFromSuperview()
            self.welcomeChipsView = nil
            self.inputField.stringValue = text
            self.inputSubmitted()
        }
        transcriptStack.addArrangedSubview(chips)
        chips.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
        welcomeChipsView = chips

        // Scroll to top so greeting appears at the top of the window, not the bottom
        scrollToTop()
    }

    func appendUser(_ text: String, attachments: [SessionAttachment] = []) {
        let t = theme
        let visibleText = text.isEmpty ? "(with attachments)" : text
        let attrText = NSMutableAttributedString(string: visibleText, attributes: [
            .font: t.fontBold,
            .foregroundColor: t.textPrimary
        ])

        if !attachments.isEmpty {
            let attachText = attachments.map(\.displayName).joined(separator: ", ")
            attrText.append(NSAttributedString(string: "\n📎 \(attachText)", attributes: [
                .font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
                .foregroundColor: t.textDim
            ]))
        }
        
        let bubble = ChatBubbleView(text: attrText, isUser: true, speakerName: "You", theme: t)
        transcriptStack.addArrangedSubview(bubble)
        bubble.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
        scrollToBottom()
    }

    func appendStreamingText(_ text: String) {
        var cleaned = text
        if currentAssistantText.isEmpty {
            cleaned = cleaned.replacingOccurrences(of: "^\\n+", with: "", options: .regularExpression)
        }
        currentAssistantText += cleaned
        if !cleaned.isEmpty {
            if let lastBubble = transcriptStack.arrangedSubviews.last as? ChatBubbleView {
                let formatted = TerminalMarkdownRenderer.render(currentAssistantText, theme: theme)
                lastBubble.setText(formatted)
            } else {
                beginAssistantTurn(name: theme.titleString)
                if let lastBubble = transcriptStack.arrangedSubviews.last as? ChatBubbleView {
                    let formatted = TerminalMarkdownRenderer.render(currentAssistantText, theme: theme)
                    lastBubble.setText(formatted)
                }
            }
            scrollToBottom()
        }
    }

    func beginAssistantTurn(name: String?) {
        let labelName = name ?? theme.titleString
        let bubble = ChatBubbleView(text: NSAttributedString(string: ""), isUser: false, speakerName: labelName, theme: theme)
        transcriptStack.addArrangedSubview(bubble)
        bubble.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
        scrollToBottom()
    }

    func endStreaming() {
        isStreaming = false
    }

    func appendError(_ text: String) {
        let t = theme
        let errorText = NSAttributedString(string: text, attributes: [
            .font: t.font,
            .foregroundColor: t.errorColor
        ])
        let bubble = ChatBubbleView(text: errorText, isUser: false, speakerName: "System", theme: t)
        transcriptStack.addArrangedSubview(bubble)
        bubble.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
        scrollToBottom()
    }

    func appendStatus(_ text: String) {
        // Handled entirely by live status pill
    }

    func appendExpertSuggestion(_ experts: [ResponderExpert]) {
        // Handled by Panel
    }

    func appendToolUse(toolName: String, summary: String) {
        endStreaming()
        let statusText = summary.isEmpty ? toolName : "\(toolName): \(summary)"
        setLiveStatus(statusText, isBusy: true, isError: false)
    }

    func appendToolResult(summary: String, isError: Bool) {
        setLiveStatus(summary, isBusy: !isError, isError: isError)
    }

    func replayHistory(_ messages: [ClaudeSession.Message]) {
        let t = theme
        transcriptStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
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
                if let lastBubble = transcriptStack.arrangedSubviews.last as? ChatBubbleView {
                    let formatted = TerminalMarkdownRenderer.render(msg.text + "\n", theme: t)
                    lastBubble.appendText(formatted)
                }
            case .error:
                appendError(msg.text)
            case .toolUse, .toolResult:
                continue
            }
            lastRole = msg.role
        }

        if lastRole == .assistant {
            endStreaming()
        }
        scrollToBottom()
    }

    func scrollToBottom() {
        resizeTranscriptToFitContent()
        if let docView = scrollView.documentView {
            let maxScroll = docView.bounds.height - scrollView.contentSize.height
            if maxScroll > 0 {
                docView.scroll(NSPoint(x: 0, y: maxScroll))
            }
        }
    }

    func scrollToTop() {
        resizeTranscriptToFitContent()
        scrollView.documentView?.scroll(NSPoint(x: 0, y: 0))
    }

    func resizeTranscriptToFitContent() {
        transcriptStack.layoutSubtreeIfNeeded()
        let stackHeight = transcriptStack.fittingSize.height
        let targetHeight = max(scrollView.contentSize.height, stackHeight + 10)
        transcriptContainer.frame.size.height = targetHeight
    }
}
