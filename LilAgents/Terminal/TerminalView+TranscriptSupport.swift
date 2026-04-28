import AppKit

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - Hoverable chip card for welcome suggestions

class HoverChipView: NSView {
    var onTapped: (() -> Void)?
    private let normalBg: CGColor
    private let hoverBg: CGColor
    private weak var contentStack: NSStackView?

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

        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.alignment = .centerY
        hStack.spacing = 10
        hStack.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        hStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack = hStack
        addSubview(hStack)

        let minimumHeight = heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        minimumHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: topAnchor),
            hStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            hStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            minimumHeight,
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

        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        guard let contentStack else { return super.intrinsicContentSize }
        let fitting = contentStack.fittingSize
        return NSSize(width: NSView.noIntrinsicMetric, height: max(48, fitting.height))
    }

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
    private weak var outerStackView: NSStackView?

    private let suggestions: [(String, String, String)]

    static let defaultSuggestionPool: [(String, String, String)] = [
        ("building.2",                "What classes does Pathpoint write?",            "What classes of business does Pathpoint write?"),
        ("doc.text.magnifyingglass",  "How do I submit a new risk?",                   "How do I submit a new risk to Pathpoint?"),
        ("shield.lefthalf.filled",    "E&S vs admitted — what's the difference?",      "What's the difference between E&S and admitted markets?"),
        ("chart.bar.doc.horizontal",  "What info is needed for a submission?",         "What information do I need to include in a Pathpoint submission?"),
        ("building.columns",          "Commercial property appetite",                  "What is Pathpoint's appetite for commercial property risks?"),
        ("person.3.sequence",         "Habitational risks — does Pathpoint write them?", "Does Pathpoint write habitational risks? What are the requirements?"),
        ("waveform.path.ecg",         "Hard-to-place risk — where to start?",          "I have a hard-to-place risk. How should I approach submitting it to Pathpoint?"),
        ("creditcard",                "How does Pathpoint's quoting work?",            "How does Pathpoint's quoting process work for retail agents?"),
        ("megaphone",                 "What markets does Pathpoint access?",           "What carrier markets does Pathpoint have access to?"),
        ("briefcase",                 "General liability appetite",                    "What is Pathpoint's appetite for general liability coverage?")
    ]

    static let starterPackSuggestionPool: [(String, String, String)] = [
        ("building.2",                "What classes does Pathpoint write?",            "What classes of business does Pathpoint write?"),
        ("doc.text.magnifyingglass",  "How do I submit a new risk?",                   "How do I submit a new risk to Pathpoint?"),
        ("shield.lefthalf.filled",    "E&S vs admitted — what's the difference?",      "What's the difference between E&S and admitted markets?"),
        ("chart.bar.doc.horizontal",  "What info is needed for a submission?",         "What information do I need to include in a Pathpoint submission?"),
        ("building.columns",          "Commercial property appetite",                  "What is Pathpoint's appetite for commercial property risks?"),
        ("person.3.sequence",         "Habitational risks — does Pathpoint write them?", "Does Pathpoint write habitational risks? What are the requirements?"),
        ("waveform.path.ecg",         "Hard-to-place risk — where to start?",          "I have a hard-to-place risk. How should I approach submitting it to Pathpoint?"),
        ("creditcard",                "How does Pathpoint's quoting work?",            "How does Pathpoint's quoting process work for retail agents?"),
        ("megaphone",                 "What markets does Pathpoint access?",           "What carrier markets does Pathpoint have access to?"),
        ("briefcase",                 "General liability appetite",                    "What is Pathpoint's appetite for general liability coverage?")
    ]

    init(theme: PopoverTheme, suggestions: [(String, String, String)] = WelcomeChipsView.defaultSuggestionPool) {
        self.theme = theme
        self.suggestions = suggestions
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
        outerStackView = outerStack
        addSubview(outerStack)

        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            outerStack.bottomAnchor.constraint(equalTo: bottomAnchor),
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

            for (symbol, label, sendText) in pair {
                let chip = HoverChipView(symbol: symbol, label: label, theme: theme)
                chip.onTapped = { [weak self] in self?.onChipTapped?(sendText) }
                rowStack.addArrangedSubview(chip)
            }
            outerStack.addArrangedSubview(rowStack)
            rowStack.widthAnchor.constraint(equalTo: outerStack.widthAnchor).isActive = true
        }

        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    override var intrinsicContentSize: NSSize {
        guard let outerStackView else { return super.intrinsicContentSize }
        let fitting = outerStackView.fittingSize
        return NSSize(width: NSView.noIntrinsicMetric, height: fitting.height)
    }
}

class ConnectionSetupCardView: NSView {
    var onOpenSettings: (() -> Void)?

    private let theme: PopoverTheme

    init(theme: PopoverTheme) {
        self.theme = theme
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = theme.inputBg.cgColor
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = theme.separatorColor.withAlphaComponent(0.45).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])

        let title = NSTextField(wrappingLabelWithString: "Set up your AI connection")
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.textColor = theme.textPrimary
        title.maximumNumberOfLines = 0
        stack.addArrangedSubview(title)
        title.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let body = NSTextField(wrappingLabelWithString: "Open Settings to connect Claude, Codex/ChatGPT, or OpenAI. Once one is connected, Tiny Ellie is ready to chat.")
        body.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        body.textColor = theme.textDim
        body.maximumNumberOfLines = 0
        stack.addArrangedSubview(body)
        body.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let settingsButton = HoverButton(title: "", target: self, action: #selector(openSettingsTapped))
        settingsButton.isBordered = false
        settingsButton.wantsLayer = true
        settingsButton.normalBg = theme.accentColor.cgColor
        settingsButton.hoverBg = theme.accentColor.withAlphaComponent(0.82).cgColor
        settingsButton.layer?.backgroundColor = settingsButton.normalBg
        settingsButton.layer?.cornerRadius = 12
        settingsButton.horizontalContentPadding = 16
        settingsButton.verticalContentPadding = 6
        settingsButton.attributedTitle = NSAttributedString(string: "Open Settings", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white
        ])
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.heightAnchor.constraint(equalToConstant: 34).isActive = true
        stack.addArrangedSubview(settingsButton)

        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    @objc private func openSettingsTapped() {
        onOpenSettings?()
    }
}
