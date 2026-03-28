import AppKit

extension TerminalView {
    func setupViews() {
        let t = theme
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        let padding: CGFloat = 16
        let topInset: CGFloat = 12
        let topControlHeight: CGFloat = 30
        let expertSuggestionHeight: CGFloat = 102
        let attachmentHeight: CGFloat = 20
        let composerHeight: CGFloat = 56
        let bottomInset: CGFloat = 14
        let interSectionSpacing: CGFloat = 10
        let panelRadius = max(t.inputCornerRadius, 12)

        let composerY = bottomInset
        let attachmentY = composerY + composerHeight + 4
        let suggestionY = attachmentY + attachmentHeight + interSectionSpacing
        let scrollY = suggestionY + expertSuggestionHeight + interSectionSpacing
        let topControlY = frame.height - topInset - topControlHeight
        let scrollHeight = max(160, topControlY - 8 - scrollY)

        scrollView.frame = NSRect(
            x: padding,
            y: scrollY,
            width: frame.width - padding * 2,
            height: scrollHeight
        )
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.contentInsets = NSEdgeInsets(top: 2, left: 0, bottom: 8, right: 0)

        textView.frame = scrollView.contentView.bounds
        textView.autoresizingMask = [.width]
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textColor = t.textPrimary
        textView.font = t.font
        textView.isRichText = true
        textView.textContainerInset = NSSize(width: 18, height: 16)
        let defaultPara = NSMutableParagraphStyle()
        defaultPara.paragraphSpacing = 12
        defaultPara.lineSpacing = 3
        textView.defaultParagraphStyle = defaultPara
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.delegate = self
        textView.linkTextAttributes = [
            .foregroundColor: t.accentColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        scrollView.documentView = textView
        addSubview(scrollView)

        liveStatusContainer.frame = NSRect(
            x: padding,
            y: topControlY,
            width: frame.width - padding * 2,
            height: topControlHeight
        )
        liveStatusContainer.autoresizingMask = [.width, .minYMargin]
        stylePanel(liveStatusContainer, background: t.inputBg.withAlphaComponent(0.92), border: t.separatorColor.withAlphaComponent(0.34), radius: topControlHeight / 2)
        liveStatusContainer.alphaValue = 0
        liveStatusContainer.isHidden = true
        addSubview(liveStatusContainer)

        liveStatusSpinner.style = .spinning
        liveStatusSpinner.controlSize = .small
        liveStatusSpinner.frame = NSRect(x: 12, y: 8, width: 14, height: 14)
        liveStatusSpinner.isDisplayedWhenStopped = false
        liveStatusContainer.addSubview(liveStatusSpinner)

        liveStatusLabel.frame = NSRect(x: 34, y: 7, width: liveStatusContainer.frame.width - 46, height: 16)
        liveStatusLabel.autoresizingMask = [.width]
        liveStatusLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        liveStatusLabel.textColor = t.textDim
        liveStatusLabel.lineBreakMode = .byTruncatingTail
        liveStatusContainer.addSubview(liveStatusLabel)

        expertSuggestionContainer.frame = NSRect(
            x: padding,
            y: suggestionY,
            width: frame.width - padding * 2,
            height: expertSuggestionHeight
        )
        expertSuggestionContainer.autoresizingMask = [.width, .maxYMargin]
        stylePanel(expertSuggestionContainer, background: t.inputBg.withAlphaComponent(0.96), border: t.separatorColor.withAlphaComponent(0.34), radius: panelRadius)
        expertSuggestionContainer.alphaValue = 0
        expertSuggestionContainer.isHidden = true
        addSubview(expertSuggestionContainer)

        expertSuggestionLabel.frame = NSRect(x: 14, y: expertSuggestionHeight - 28, width: expertSuggestionContainer.frame.width - 28, height: 16)
        expertSuggestionLabel.autoresizingMask = [.width]
        expertSuggestionLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        expertSuggestionLabel.textColor = t.textDim
        expertSuggestionLabel.stringValue = "Open an expert for a more specific follow-up."
        expertSuggestionContainer.addSubview(expertSuggestionLabel)

        expertSuggestionStack.orientation = .vertical
        expertSuggestionStack.alignment = .leading
        expertSuggestionStack.distribution = .fillEqually
        expertSuggestionStack.spacing = 6
        expertSuggestionStack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        expertSuggestionStack.frame = NSRect(x: 14, y: 12, width: expertSuggestionContainer.frame.width - 28, height: 56)
        expertSuggestionStack.autoresizingMask = [.width]
        expertSuggestionContainer.addSubview(expertSuggestionStack)

        attachmentLabel.frame = NSRect(
            x: padding + 2,
            y: attachmentY,
            width: frame.width - padding * 2 - 4,
            height: attachmentHeight
        )
        attachmentLabel.autoresizingMask = [.width]
        attachmentLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        attachmentLabel.textColor = t.textDim
        attachmentLabel.lineBreakMode = .byTruncatingMiddle
        attachmentLabel.isHidden = true
        addSubview(attachmentLabel)

        let composerPanel = NSView(frame: NSRect(
            x: padding,
            y: composerY,
            width: frame.width - padding * 2,
            height: composerHeight
        ))
        composerPanel.autoresizingMask = [.width, .maxYMargin]
        stylePanel(composerPanel, background: t.inputBg.withAlphaComponent(0.98), border: t.separatorColor.withAlphaComponent(0.40), radius: panelRadius + 4)
        addSubview(composerPanel)

        let sendButtonSize: CGFloat = 34
        let attachButtonSize: CGFloat = 28
        let rightInset: CGFloat = 12
        let sendY = (composerHeight - sendButtonSize) / 2
        let attachY = (composerHeight - attachButtonSize) / 2
        let sendX = composerPanel.frame.width - rightInset - sendButtonSize
        let attachX = sendX - 8 - attachButtonSize

        sendButton.frame = NSRect(x: sendX, y: sendY, width: sendButtonSize, height: sendButtonSize)
        sendButton.autoresizingMask = [.minXMargin]
        sendButton.isBordered = false
        sendButton.wantsLayer = true
        sendButton.layer?.backgroundColor = t.accentColor.cgColor
        sendButton.layer?.cornerRadius = sendButtonSize / 2
        if let img = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "Send message") {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
            sendButton.image = img.withSymbolConfiguration(config)
        }
        sendButton.imageScaling = .scaleProportionallyDown
        sendButton.contentTintColor = .white
        sendButton.target = self
        sendButton.action = #selector(inputSubmitted)
        composerPanel.addSubview(sendButton)

        attachButton.frame = NSRect(x: attachX, y: attachY, width: attachButtonSize, height: attachButtonSize)
        attachButton.autoresizingMask = [.minXMargin]
        attachButton.isBordered = false
        attachButton.wantsLayer = true
        attachButton.layer?.backgroundColor = t.bubbleBg.withAlphaComponent(0.85).cgColor
        attachButton.layer?.cornerRadius = attachButtonSize / 2
        if let img = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Attach file") {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            attachButton.image = img.withSymbolConfiguration(config)
        }
        attachButton.imageScaling = .scaleProportionallyDown
        attachButton.contentTintColor = t.textDim
        attachButton.target = self
        attachButton.action = #selector(attachButtonTapped)
        composerPanel.addSubview(attachButton)

        inputField.frame = NSRect(
            x: 14,
            y: 8,
            width: attachX - 24,
            height: composerHeight - 16
        )
        inputField.autoresizingMask = [.width]
        inputField.focusRingType = .none
        inputField.wantsLayer = true
        inputField.layer?.backgroundColor = NSColor.clear.cgColor
        let paddedCell = PaddedTextFieldCell(textCell: "")
        paddedCell.isEditable = true
        paddedCell.isScrollable = true
        paddedCell.font = t.font
        paddedCell.textColor = t.textPrimary
        paddedCell.drawsBackground = false
        paddedCell.isBezeled = false
        paddedCell.fieldBackgroundColor = nil
        paddedCell.fieldCornerRadius = 0
        paddedCell.placeholderAttributedString = NSAttributedString(
            string: placeholderText,
            attributes: [.font: t.font, .foregroundColor: t.textDim]
        )
        inputField.cell = paddedCell
        inputField.target = self
        inputField.action = #selector(inputSubmitted)
        composerPanel.addSubview(inputField)

        registerForDraggedTypes([.fileURL])
    }

    @objc func inputSubmitted() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }

        let attachments = pendingAttachments
        inputField.stringValue = ""
        pendingAttachments.removeAll()
        refreshAttachmentLabel()

        appendUser(text, attachments: attachments)
        isStreaming = true
        currentAssistantText = ""
        onSendMessage?(text, attachments)
    }

    @objc func returnToLennyTapped() {
        onReturnToLenny?()
    }

    @objc func attachButtonTapped() {
        presentAttachmentPicker()
    }

    func updatePlaceholder(_ text: String) {
        placeholderText = text
        guard let paddedCell = inputField.cell as? PaddedTextFieldCell else { return }
        let t = theme
        paddedCell.placeholderAttributedString = NSAttributedString(
            string: text,
            attributes: [.font: t.font, .foregroundColor: t.textDim]
        )
        inputField.needsDisplay = true
    }

    func setReturnToLennyVisible(_ visible: Bool) {
        returnButton.isHidden = !visible
    }

    func setExpertSuggestions(_ experts: [ResponderExpert]) {
        expertSuggestionTargets.removeAll()
        expertSuggestionStack.arrangedSubviews.forEach { view in
            expertSuggestionStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard !experts.isEmpty else {
            setPanelVisibility(expertSuggestionContainer, hidden: true)
            return
        }

        let t = theme
        for expert in experts {
            let identifier = normalizeExpertSuggestionID(expert.name)
            expertSuggestionTargets[identifier] = expert

            let button = NSButton(title: "", target: self, action: #selector(expertSuggestionButtonTapped(_:)))
            button.isBordered = false
            button.bezelStyle = .regularSquare
            button.wantsLayer = true
            button.layer?.backgroundColor = t.bubbleBg.cgColor
            button.layer?.cornerRadius = 12
            button.layer?.borderWidth = 0.75
            button.layer?.borderColor = t.separatorColor.withAlphaComponent(0.50).cgColor
            button.attributedTitle = NSAttributedString(
                string: expert.name,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11.5, weight: .semibold),
                    .foregroundColor: t.titleText
                ]
            )
            button.setButtonType(.momentaryPushIn)
            button.imagePosition = .noImage
            button.identifier = NSUserInterfaceItemIdentifier(identifier)
            button.contentTintColor = t.titleText
            button.alignment = .left
            button.frame.size.height = 25
            expertSuggestionStack.addArrangedSubview(button)
        }

        setPanelVisibility(expertSuggestionContainer, hidden: false)
    }

    func setLiveStatus(_ text: String, isBusy: Bool, isError: Bool = false) {
        let t = theme
        guard !text.isEmpty else {
            clearLiveStatus()
            return
        }

        liveStatusContainer.layer?.borderColor = (isError ? t.errorColor : t.separatorColor.withAlphaComponent(0.42)).cgColor
        liveStatusContainer.layer?.backgroundColor = (isError ? t.errorColor.withAlphaComponent(0.08) : t.inputBg.withAlphaComponent(0.96)).cgColor
        liveStatusLabel.textColor = isError ? t.errorColor : (isBusy ? t.accentColor : t.successColor)
        liveStatusLabel.stringValue = text
        setPanelVisibility(liveStatusContainer, hidden: false)

        if isBusy {
            liveStatusSpinner.startAnimation(nil)
        } else {
            liveStatusSpinner.stopAnimation(nil)
        }
    }

    func clearLiveStatus() {
        liveStatusLabel.stringValue = ""
        liveStatusSpinner.stopAnimation(nil)
        setPanelVisibility(liveStatusContainer, hidden: true)
    }

    @objc func expertSuggestionButtonTapped(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue,
              let expert = expertSuggestionTargets[identifier] else {
            return
        }

        onSelectExpert?(expert)
    }

    private func normalizeExpertSuggestionID(_ name: String) -> String {
        let lowered = name.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : "-"
        }
        let raw = String(scalars)
        return raw.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func stylePanel(_ view: NSView, background: NSColor, border: NSColor, radius: CGFloat) {
        view.wantsLayer = true
        view.layer?.backgroundColor = background.cgColor
        view.layer?.cornerRadius = radius
        view.layer?.borderWidth = 0.75
        view.layer?.borderColor = border.cgColor
    }

    private func setPanelVisibility(_ view: NSView, hidden: Bool) {
        if hidden {
            guard !view.isHidden else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                view.animator().alphaValue = 0
            } completionHandler: {
                view.isHidden = true
            }
        } else {
            guard view.isHidden else { return }
            view.alphaValue = 0
            view.isHidden = false
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                view.animator().alphaValue = 1
            }
        }
    }
}

extension TerminalView: NSTextViewDelegate {
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL,
              url.scheme == "lilagents-expert",
              let host = url.host,
              let expert = expertSuggestionTargets[host] else {
            return false
        }

        onSelectExpert?(expert)
        return true
    }
}
