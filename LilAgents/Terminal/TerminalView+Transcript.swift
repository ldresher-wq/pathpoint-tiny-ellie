import AppKit

private func resolvedExpertAvatarImage(at path: String) -> NSImage? {
    let resolvedPath = pngAvatarPath(for: path) ?? path
    return NSImage(contentsOfFile: resolvedPath)
}

private func pngAvatarPath(for path: String) -> String? {
    guard path.lowercased().hasSuffix(".webp"),
          let image = NSImage(contentsOfFile: path),
          let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return nil
    }

    let cacheDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lenny-avatar-cache", isDirectory: true)
    try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

    let fileName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent + ".png"
    let pngURL = cacheDir.appendingPathComponent(fileName)

    if !FileManager.default.fileExists(atPath: pngURL.path) {
        try? pngData.write(to: pngURL)
    }

    return pngURL.path
}

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

        // Internal horizontal stack handles all alignment and padding
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

class ExpertSuggestionCardView: NSView {
    var onExpertTapped: ((UUID, ResponderExpert) -> Void)?
    private let theme: PopoverTheme
    private let entry: ExpertSuggestionEntry

    init(theme: PopoverTheme, entry: ExpertSuggestionEntry) {
        self.theme = theme
        self.entry = entry
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false

        let shell = NSView()
        shell.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shell)
        let preferredWidth = shell.widthAnchor.constraint(equalTo: widthAnchor, constant: -56)
        preferredWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            shell.topAnchor.constraint(equalTo: topAnchor),
            shell.leadingAnchor.constraint(equalTo: leadingAnchor),
            shell.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -56),
            shell.widthAnchor.constraint(lessThanOrEqualToConstant: 396),
            preferredWidth,
            shell.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let titleLabel = NSTextField(labelWithString: "Have follow-up questions? Chat with these experts.")
        titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        titleLabel.textColor = theme.textDim
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(titleLabel)

        let list = NSStackView()
        list.orientation = .vertical
        list.alignment = .leading
        list.distribution = .fill
        list.spacing = 8
        list.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(list)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: shell.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -4),

            list.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            list.leadingAnchor.constraint(equalTo: shell.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: shell.trailingAnchor),
            list.bottomAnchor.constraint(equalTo: shell.bottomAnchor)
        ])

        for expert in entry.experts {
            let chip = makeExpertChip(for: expert)
            list.addArrangedSubview(chip)
            chip.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        }
    }

    private func makeExpertChip(for expert: ResponderExpert) -> NSView {
        let button = HoverButton(title: "", target: nil, action: nil)
        button.isBordered = false
        button.wantsLayer = true
        button.normalBg = theme.inputBg.cgColor
        button.hoverBg = theme.accentColor.withAlphaComponent(0.06).cgColor
        button.layer?.backgroundColor = theme.inputBg.cgColor
        button.layer?.cornerRadius = 16
        button.layer?.borderWidth = 1
        button.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.52).cgColor
        button.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 13, left: 14, bottom: 13, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: button.topAnchor),
            stack.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            button.heightAnchor.constraint(equalToConstant: 54)
        ])

        let avatarContainer = NSView()
        avatarContainer.wantsLayer = true
        avatarContainer.layer?.backgroundColor = theme.accentColor.withAlphaComponent(0.10).cgColor
        avatarContainer.layer?.cornerRadius = 12
        avatarContainer.layer?.masksToBounds = true
        avatarContainer.layer?.borderWidth = 1
        avatarContainer.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.40).cgColor
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.widthAnchor.constraint(equalToConstant: 24).isActive = true
        avatarContainer.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stack.addArrangedSubview(avatarContainer)

        if let image = resolvedExpertAvatarImage(at: expert.avatarPath) {
            let avatarView = NSImageView()
            avatarView.image = image
            avatarView.imageScaling = .scaleAxesIndependently
            avatarView.translatesAutoresizingMaskIntoConstraints = false
            avatarContainer.addSubview(avatarView)

            NSLayoutConstraint.activate([
                avatarView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
                avatarView.leadingAnchor.constraint(equalTo: avatarContainer.leadingAnchor),
                avatarView.trailingAnchor.constraint(equalTo: avatarContainer.trailingAnchor),
                avatarView.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor)
            ])
        } else {
            let icon = NSImageView()
            if let image = NSImage(systemSymbolName: "person.crop.circle.fill", accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                icon.image = image.withSymbolConfiguration(config)
            }
            icon.contentTintColor = theme.accentColor
            icon.translatesAutoresizingMaskIntoConstraints = false
            avatarContainer.addSubview(icon)

            NSLayoutConstraint.activate([
                icon.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 14),
                icon.heightAnchor.constraint(equalToConstant: 14)
            ])
        }

        let label = NSTextField(labelWithString: expert.name)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = theme.textPrimary
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(label)

        button.target = self
        button.action = #selector(expertTapped(_:))
        button.identifier = NSUserInterfaceItemIdentifier(expert.name)
        return button
    }

    @objc private func expertTapped(_ sender: NSButton) {
        guard let name = sender.identifier?.rawValue,
              let expert = entry.experts.first(where: { $0.name == name }) else { return }
        WalkerCharacter.playSelectionSound()
        onExpertTapped?(entry.id, expert)
    }
}

class CompactSuggestionView: NSView {
    var onRetap: ((UUID) -> Void)?
    private let theme: PopoverTheme
    private let entry: ExpertSuggestionEntry

    init(theme: PopoverTheme, entry: ExpertSuggestionEntry) {
        self.theme = theme
        self.entry = entry
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false

        let shell = NSView()
        shell.wantsLayer = true
        shell.layer?.backgroundColor = theme.inputBg.cgColor
        shell.layer?.cornerRadius = 14
        shell.layer?.borderWidth = 1
        shell.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.30).cgColor
        shell.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shell)
        let preferredWidth = shell.widthAnchor.constraint(equalTo: widthAnchor, constant: -56)
        preferredWidth.priority = .defaultHigh

        let summary = NSTextField(labelWithString: "Now chatting with \(entry.pickedExpert?.name ?? "your specialist")")
        summary.font = NSFont.systemFont(ofSize: 12.5, weight: .medium)
        summary.textColor = theme.textDim
        summary.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(summary)

        let button = HoverButton(title: "", target: self, action: #selector(retap))
        button.isBordered = false
        button.wantsLayer = true
        button.normalBg = theme.bubbleBg.cgColor
        button.hoverBg = theme.accentColor.withAlphaComponent(0.08).cgColor
        button.layer?.backgroundColor = theme.bubbleBg.cgColor
        button.layer?.cornerRadius = 11
        button.layer?.borderWidth = 1
        button.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.42).cgColor
        button.attributedTitle = NSAttributedString(
            string: "Switch",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: theme.textPrimary
            ]
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(button)

        NSLayoutConstraint.activate([
            shell.topAnchor.constraint(equalTo: topAnchor),
            shell.leadingAnchor.constraint(equalTo: leadingAnchor),
            shell.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -56),
            shell.widthAnchor.constraint(lessThanOrEqualToConstant: 396),
            preferredWidth,
            shell.bottomAnchor.constraint(equalTo: bottomAnchor),

            summary.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 14),
            summary.centerYAnchor.constraint(equalTo: shell.centerYAnchor),

            button.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -10),
            button.topAnchor.constraint(equalTo: shell.topAnchor, constant: 8),
            button.bottomAnchor.constraint(equalTo: shell.bottomAnchor, constant: -8),
            button.widthAnchor.constraint(equalToConstant: 68),

            summary.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -12),
            shell.heightAnchor.constraint(equalToConstant: 46)
        ])
    }

    @objc private func retap() {
        onRetap?(entry.id)
    }
}

class ChatBubbleView: NSView, NSTextViewDelegate {
    let textView = NSTextView()
    let headerLabel = NSTextField(labelWithString: "")
    let bubbleBackground = NSView()
    let avatarContainer = NSView()
    let actionRow = NSStackView()
    private let copyButton = HoverButton(title: "", target: nil, action: nil)
    private let followUpButton = HoverButton(title: "", target: nil, action: nil)
    private let isUser: Bool
    private let theme: PopoverTheme
    private var textWidthConstraint: NSLayoutConstraint?
    private var textHeightConstraint: NSLayoutConstraint?
    private var onCopy: (() -> Void)?
    private var onFollowUp: (() -> Void)?

    init(text: NSAttributedString, isUser: Bool, speaker: TranscriptSpeaker, theme: PopoverTheme, onCopy: (() -> Void)? = nil, onFollowUp: (() -> Void)? = nil) {
        self.isUser = isUser
        self.theme = theme
        self.onCopy = onCopy
        self.onFollowUp = onFollowUp
        super.init(frame: .zero)
        setupViews()
        populate(text: text, speaker: speaker)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        avatarContainer.wantsLayer = true
        avatarContainer.layer?.cornerRadius = 14
        avatarContainer.layer?.masksToBounds = true
        avatarContainer.layer?.borderWidth = 1
        avatarContainer.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.30).cgColor
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.widthAnchor.constraint(equalToConstant: isUser ? 0 : 28).isActive = true
        avatarContainer.heightAnchor.constraint(equalToConstant: isUser ? 0 : 28).isActive = true
        avatarContainer.isHidden = isUser
        row.addArrangedSubview(avatarContainer)

        let contentColumn = NSStackView()
        contentColumn.orientation = .vertical
        contentColumn.alignment = .leading
        contentColumn.spacing = 5
        contentColumn.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(contentColumn)

        headerLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        headerLabel.textColor = isUser ? theme.textDim : theme.accentColor
        headerLabel.alignment = .left
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.isEditable = false
        headerLabel.isBordered = false
        headerLabel.drawsBackground = false
        contentColumn.addArrangedSubview(headerLabel)

        bubbleBackground.wantsLayer = true
        bubbleBackground.layer?.cornerRadius = theme.bubbleCornerRadius
        bubbleBackground.layer?.backgroundColor = isUser
            ? theme.accentColor.withAlphaComponent(0.10).cgColor
            : theme.bubbleBg.cgColor
        bubbleBackground.layer?.borderWidth = isUser ? 0 : 0.75
        bubbleBackground.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.36).cgColor
        bubbleBackground.translatesAutoresizingMaskIntoConstraints = false
        contentColumn.addArrangedSubview(bubbleBackground)

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

        actionRow.orientation = .horizontal
        actionRow.alignment = .centerY
        actionRow.spacing = 8
        actionRow.translatesAutoresizingMaskIntoConstraints = false
        contentColumn.addArrangedSubview(actionRow)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),

            textView.topAnchor.constraint(equalTo: bubbleBackground.topAnchor),
            textView.bottomAnchor.constraint(equalTo: bubbleBackground.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: bubbleBackground.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: bubbleBackground.trailingAnchor),

            bubbleBackground.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: isUser ? 0 : -56),
            bubbleBackground.leadingAnchor.constraint(equalTo: contentColumn.leadingAnchor),
        ])
    }

    private func configureAction(_ button: HoverButton, title: String, primary: Bool = false, action: Selector) {
        button.isBordered = false
        button.wantsLayer = true
        let background = primary ? theme.accentColor.withAlphaComponent(0.10) : theme.inputBg
        button.normalBg = background.cgColor
        button.hoverBg = (primary ? theme.accentColor.withAlphaComponent(0.18) : theme.accentColor.withAlphaComponent(0.06)).cgColor
        button.layer?.backgroundColor = button.normalBg
        button.layer?.cornerRadius = 12
        button.layer?.borderWidth = 1
        button.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.34).cgColor
        button.contentTintColor = primary ? theme.accentColor : theme.textPrimary
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 11.5, weight: .medium),
            .foregroundColor: primary ? theme.accentColor : theme.textPrimary
        ])
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: title == "Copy" ? 52 : 104).isActive = true
    }

    private func populate(text: NSAttributedString, speaker: TranscriptSpeaker) {
        headerLabel.stringValue = speaker.name
        populateAvatar(for: speaker)
        configureTextContainer()
        textView.textStorage?.setAttributedString(text)
        configureActions(for: speaker)
        recalculateSize()
    }

    private func populateAvatar(for speaker: TranscriptSpeaker) {
        avatarContainer.subviews.forEach { $0.removeFromSuperview() }
        guard !isUser else { return }

        if let avatarPath = speaker.avatarPath, let image = resolvedExpertAvatarImage(at: avatarPath) {
            let avatarView = NSImageView()
            avatarView.image = image
            avatarView.imageScaling = .scaleAxesIndependently
            avatarView.translatesAutoresizingMaskIntoConstraints = false
            avatarContainer.addSubview(avatarView)
            NSLayoutConstraint.activate([
                avatarView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
                avatarView.leadingAnchor.constraint(equalTo: avatarContainer.leadingAnchor),
                avatarView.trailingAnchor.constraint(equalTo: avatarContainer.trailingAnchor),
                avatarView.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor)
            ])
            return
        }

        let icon = NSImageView()
        let symbolName = speaker.kind == .lenny ? "sparkles" : "person.crop.circle.fill"
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            icon.image = image.withSymbolConfiguration(config)
        }
        icon.contentTintColor = theme.accentColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 15),
            icon.heightAnchor.constraint(equalToConstant: 15)
        ])
    }

    private func configureActions(for speaker: TranscriptSpeaker) {
        actionRow.arrangedSubviews.forEach {
            actionRow.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        if !isUser, speaker.kind != .system {
            configureAction(copyButton, title: "Copy", action: #selector(copyTapped))
            actionRow.addArrangedSubview(copyButton)
        }

        if speaker.kind == .expert, onFollowUp != nil {
            configureAction(followUpButton, title: "Ask follow-up", primary: true, action: #selector(followUpTapped))
            actionRow.addArrangedSubview(followUpButton)
        }

        actionRow.isHidden = actionRow.arrangedSubviews.isEmpty
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

    @objc private func copyTapped() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView.string, forType: .string)
        onCopy?()
    }

    @objc private func followUpTapped() {
        WalkerCharacter.playSelectionSound()
        onFollowUp?()
    }

    private func configureTextContainer() {
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude)
    }

    private func recalculateSize() {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        textContainer.containerSize = NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let rect = layoutManager.usedRect(for: textContainer)

        let targetContentWidth = rect.width
        let paddingWidth: CGFloat = 28
        let maxWidth: CGFloat = 380
        let desiredWidth = targetContentWidth + paddingWidth

        if let textWidthConstraint {
            textView.removeConstraint(textWidthConstraint)
            self.textWidthConstraint = nil
        }
        if let textHeightConstraint {
            textView.removeConstraint(textHeightConstraint)
            self.textHeightConstraint = nil
        }

        if desiredWidth >= maxWidth {
            textContainer.containerSize = NSSize(width: maxWidth - paddingWidth, height: CGFloat.greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)
            let newRect = layoutManager.usedRect(for: textContainer)
            textWidthConstraint = textView.widthAnchor.constraint(equalToConstant: maxWidth)
            textHeightConstraint = textView.heightAnchor.constraint(equalToConstant: newRect.height + 24)
        } else {
            let finalWidth = max(desiredWidth, 60)
            textWidthConstraint = textView.widthAnchor.constraint(equalToConstant: finalWidth)
            textHeightConstraint = textView.heightAnchor.constraint(equalToConstant: rect.height + 24)
        }

        textWidthConstraint?.isActive = true
        textHeightConstraint?.isActive = true
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
                WalkerCharacter.playSelectionSound()
                terminal.onSelectExpert?(expert)
                return true
            }
            view = v.superview
        }
        return false
    }
}

class SourceBadgeView: NSView {
    init(text: String, theme: PopoverTheme) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let shell = NSView()
        shell.wantsLayer = true
        shell.layer?.backgroundColor = theme.inputBg.cgColor
        shell.layer?.cornerRadius = 12
        shell.layer?.borderWidth = 1
        shell.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.32).cgColor
        shell.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shell)

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(stack)

        let icon = NSImageView()
        if let image = NSImage(systemSymbolName: "archivebox.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            icon.image = image.withSymbolConfiguration(config)
        }
        icon.contentTintColor = theme.accentColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 12).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 12).isActive = true
        stack.addArrangedSubview(icon)

        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        label.textColor = theme.textDim
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        stack.addArrangedSubview(label)

        NSLayoutConstraint.activate([
            shell.topAnchor.constraint(equalTo: topAnchor),
            shell.leadingAnchor.constraint(equalTo: leadingAnchor),
            shell.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -56),
            shell.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: shell.topAnchor),
            stack.leadingAnchor.constraint(equalTo: shell.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: shell.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: shell.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

class TranscriptStatusView: NSView {
    private let theme: PopoverTheme
    private let avatarStack = NSStackView()
    private let textLabel = NSTextField(labelWithString: "")

    init(theme: PopoverTheme, text: String, experts: [ResponderExpert]) {
        self.theme = theme
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupViews()
        update(text: text, experts: experts)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        let shell = NSView()
        shell.wantsLayer = true
        shell.layer?.backgroundColor = theme.bubbleBg.cgColor
        shell.layer?.cornerRadius = 14
        shell.layer?.borderWidth = 1
        shell.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.28).cgColor
        shell.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shell)
        let preferredWidth = shell.widthAnchor.constraint(equalTo: widthAnchor, constant: -56)
        preferredWidth.priority = .defaultHigh

        let titleLabel = NSTextField(labelWithString: "Lil-Lenny")
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = theme.accentColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(titleLabel)

        avatarStack.orientation = .horizontal
        avatarStack.alignment = .centerY
        avatarStack.spacing = 6
        avatarStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        avatarStack.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(avatarStack)

        textLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .medium)
        textLabel.textColor = theme.textPrimary
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.maximumNumberOfLines = 4
        textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(textLabel)

        NSLayoutConstraint.activate([
            shell.topAnchor.constraint(equalTo: topAnchor),
            shell.leadingAnchor.constraint(equalTo: leadingAnchor),
            shell.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -56),
            shell.widthAnchor.constraint(lessThanOrEqualToConstant: 396),
            preferredWidth,
            shell.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: shell.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -14),

            avatarStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            avatarStack.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 14),
            avatarStack.trailingAnchor.constraint(lessThanOrEqualTo: shell.trailingAnchor, constant: -14),

            textLabel.topAnchor.constraint(equalTo: avatarStack.bottomAnchor, constant: 8),
            textLabel.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 14),
            textLabel.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -14),
            textLabel.bottomAnchor.constraint(equalTo: shell.bottomAnchor, constant: -12)
        ])
    }

    func update(text: String, experts: [ResponderExpert]) {
        textLabel.stringValue = text
        avatarStack.arrangedSubviews.forEach {
            avatarStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for expert in Array(experts.prefix(3)) {
            let avatar = NSView()
            avatar.wantsLayer = true
            avatar.layer?.cornerRadius = 12
            avatar.layer?.masksToBounds = true
            avatar.layer?.borderWidth = 1
            avatar.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.28).cgColor
            avatar.translatesAutoresizingMaskIntoConstraints = false
            avatar.widthAnchor.constraint(equalToConstant: 24).isActive = true
            avatar.heightAnchor.constraint(equalToConstant: 24).isActive = true
            if let image = resolvedExpertAvatarImage(at: expert.avatarPath) {
                let view = NSImageView()
                view.image = image
                view.imageScaling = .scaleAxesIndependently
                view.translatesAutoresizingMaskIntoConstraints = false
                avatar.addSubview(view)
                NSLayoutConstraint.activate([
                    view.topAnchor.constraint(equalTo: avatar.topAnchor),
                    view.leadingAnchor.constraint(equalTo: avatar.leadingAnchor),
                    view.trailingAnchor.constraint(equalTo: avatar.trailingAnchor),
                    view.bottomAnchor.constraint(equalTo: avatar.bottomAnchor)
                ])
            }
            avatar.toolTip = expert.name
            avatarStack.addArrangedSubview(avatar)
        }

        avatarStack.isHidden = experts.isEmpty
    }
}

extension TerminalView {
    private func appendBubble(text: NSAttributedString, isUser: Bool, speaker: TranscriptSpeaker, followUpExpert: ResponderExpert? = nil) {
        let bubble = ChatBubbleView(
            text: text,
            isUser: isUser,
            speaker: speaker,
            theme: theme,
            onCopy: {
                WalkerCharacter.playSelectionSound()
            },
            onFollowUp: { [weak self] in
                guard let self, let followUpExpert else { return }
                self.onSelectExpert?(followUpExpert)
            }
        )
        transcriptStack.addArrangedSubview(bubble)
        bubble.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
    }

    func expertSuggestionCardHeight(for expertCount: Int) -> CGFloat {
        let count = CGFloat(expertCount)
        return 30 + (count * 54) + max(0, count - 1) * 8
    }

    private func appendSuggestionEntryView(_ entry: ExpertSuggestionEntry) {
        if entry.isCollapsed, entry.pickedExpert != nil {
            let compact = CompactSuggestionView(theme: theme, entry: entry)
            compact.onRetap = { [weak self] entryID in
                self?.onEditExpertSuggestion?(entryID)
            }
            transcriptStack.addArrangedSubview(compact)
            compact.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
            compact.heightAnchor.constraint(equalToConstant: 46).isActive = true
            return
        }

        let suggestionsView = ExpertSuggestionCardView(theme: theme, entry: entry)
        suggestionsView.onExpertTapped = { [weak self] entryID, expert in
            self?.onSelectExpertSuggestion?(entryID, expert)
        }
        transcriptStack.addArrangedSubview(suggestionsView)
        suggestionsView.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
        suggestionsView.heightAnchor.constraint(equalToConstant: expertSuggestionCardHeight(for: entry.experts.count)).isActive = true
    }

    func showWelcomeGreeting() {
        clearTranscriptSuggestionView()
        hideWelcomeSuggestionsPanel()
        let t = theme
        let greeting = "I'm Lil-Lenny. Ask me anything about product, growth, leadership, pricing, startups, or AI.\n\nYour desktop shortcut to LennyData."
        let attrText = NSAttributedString(string: greeting, attributes: [
            .font: t.font,
            .foregroundColor: t.textPrimary,
        ])
        appendBubble(text: attrText, isUser: false, speaker: TranscriptSpeaker(name: "Lil-Lenny", avatarPath: nil, kind: .lenny))

        showWelcomeSuggestionsPanel()
        scrollToTop()
    }

    func showExpertGreeting(for expert: ResponderExpert) {
        clearTranscriptSuggestionView()
        hideWelcomeSuggestionsPanel()

        let greeting = "I'm \(expert.name). What would you like to dig into?"
        let attrText = NSAttributedString(string: greeting, attributes: [
            .font: theme.font,
            .foregroundColor: theme.textPrimary,
        ])
        transcriptStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        appendBubble(text: attrText, isUser: false, speaker: TranscriptSpeaker(name: expert.name, avatarPath: expert.avatarPath, kind: .expert))
        currentAssistantText = ""
        scrollToTop()
    }

    func appendUser(_ text: String, attachments: [SessionAttachment] = []) {
        let t = theme
        let visibleText = text.isEmpty ? "Sent with attachment" : text
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
        
        appendBubble(text: attrText, isUser: true, speaker: TranscriptSpeaker(name: "You", avatarPath: nil, kind: .user))
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
        let speaker = TranscriptSpeaker(name: labelName, avatarPath: nil, kind: labelName.lowercased() == "lil-lenny" ? .lenny : .system)
        appendBubble(text: NSAttributedString(string: ""), isUser: false, speaker: speaker)
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
        appendBubble(text: errorText, isUser: false, speaker: TranscriptSpeaker(name: "System", avatarPath: nil, kind: .system))
        scrollToBottom()
    }

    func appendStatus(_ text: String) {
        // Handled entirely by live status pill
    }

    func renderTranscriptLiveStatus(_ text: String, experts: [ResponderExpert] = []) {
        if let statusView = transcriptLiveStatusView as? TranscriptStatusView {
            statusView.update(text: text, experts: experts)
        } else {
            let statusView = TranscriptStatusView(theme: theme, text: text, experts: experts)
            transcriptStack.addArrangedSubview(statusView)
            statusView.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
            transcriptLiveStatusView = statusView
        }
        scrollToBottom()
    }

    func clearTranscriptLiveStatus() {
        if let view = transcriptLiveStatusView {
            transcriptStack.removeArrangedSubview(view)
            view.removeFromSuperview()
            transcriptLiveStatusView = nil
        }
    }

    func appendExpertSuggestion(_ experts: [ResponderExpert]) {
        currentExpertSuggestions = experts
        expertSuggestionsCollapsed = false
        renderTranscriptSuggestions()
    }

    func appendToolUse(toolName: String, summary: String, experts: [ResponderExpert] = []) {
        endStreaming()
        let statusText = summary.isEmpty ? toolName : "\(toolName): \(summary)"
        setLiveStatus(statusText, isBusy: true, isError: false, experts: experts)
    }

    func appendToolResult(summary: String, isError: Bool, experts: [ResponderExpert] = []) {
        if summary.hasPrefix("Source: ") {
            let badge = SourceBadgeView(text: summary, theme: theme)
            transcriptStack.addArrangedSubview(badge)
            badge.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
            scrollToBottom()
        }
        setLiveStatus(summary, isBusy: !isError, isError: isError, experts: experts)
    }

    func replayHistory(_ messages: [ClaudeSession.Message]) {
        replayConversation(messages, expertSuggestions: [])
    }

    func replayConversation(_ messages: [ClaudeSession.Message], expertSuggestions: [ExpertSuggestionEntry]) {
        let t = theme
        transcriptStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        transcriptSuggestionView = nil
        transcriptLiveStatusView = nil
        hideWelcomeSuggestionsPanel()
        currentAssistantText = ""
        var lastRole: ClaudeSession.Message.Role?
        let suggestionsByAnchor = Dictionary(grouping: expertSuggestions, by: \.anchorHistoryCount)
        
        for (index, msg) in messages.enumerated() {
            switch msg.role {
            case .user:
                appendUser(msg.text)
            case .assistant:
                let speaker = msg.speaker ?? TranscriptSpeaker(name: t.titleString, avatarPath: nil, kind: .lenny)
                let formatted = TerminalMarkdownRenderer.render(msg.text + "\n", theme: t)
                appendBubble(text: formatted, isUser: false, speaker: speaker, followUpExpert: msg.followUpExpert)
            case .error:
                appendError(msg.text)
            case .toolUse:
                continue
            case .toolResult:
                if msg.text.hasPrefix("Source: ") {
                    let badge = SourceBadgeView(text: msg.text, theme: t)
                    transcriptStack.addArrangedSubview(badge)
                    badge.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
                }
                continue
            }
            lastRole = msg.role

            let anchorHistoryCount = index + 1
            if let entries = suggestionsByAnchor[anchorHistoryCount] {
                for entry in entries {
                    appendSuggestionEntryView(entry)
                }
            }
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
