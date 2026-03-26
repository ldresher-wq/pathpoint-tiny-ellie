import AppKit

extension TerminalView {
    func setupViews() {
        let t = theme
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        let inputHeight: CGFloat = 40
        let attachmentHeight: CGFloat = 24
        let topControlHeight: CGFloat = 62
        let padding: CGFloat = 18
        let attachButtonWidth: CGFloat = 98
        let transcriptTopInset: CGFloat = 10
        let composerBottomInset: CGFloat = 12
        let attachmentGap: CGFloat = 8
        let scrollHeight = frame.height - inputHeight - attachmentHeight - topControlHeight - padding - 20

        let transcriptPanel = NSView(frame: NSRect(
            x: padding,
            y: inputHeight + attachmentHeight + composerBottomInset + attachmentGap,
            width: frame.width - padding * 2,
            height: scrollHeight + 8
        ))
        transcriptPanel.autoresizingMask = [.width, .height]
        transcriptPanel.wantsLayer = true
        transcriptPanel.layer?.backgroundColor = t.inputBg.withAlphaComponent(0.74).cgColor
        transcriptPanel.layer?.borderColor = t.separatorColor.withAlphaComponent(0.32).cgColor
        transcriptPanel.layer?.borderWidth = 1
        transcriptPanel.layer?.cornerRadius = 26
        transcriptPanel.layer?.shadowColor = NSColor.black.withAlphaComponent(0.08).cgColor
        transcriptPanel.layer?.shadowOpacity = 1
        transcriptPanel.layer?.shadowRadius = 24
        transcriptPanel.layer?.shadowOffset = CGSize(width: 0, height: -5)
        addSubview(transcriptPanel)

        scrollView.frame = NSRect(
            x: padding + 14,
            y: inputHeight + attachmentHeight + composerBottomInset + attachmentGap + transcriptTopInset,
            width: frame.width - (padding + 14) * 2,
            height: scrollHeight - 10
        )
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        textView.frame = scrollView.contentView.bounds
        textView.autoresizingMask = [.width]
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textColor = t.textPrimary
        textView.font = t.font
        textView.isRichText = true
        textView.textContainerInset = NSSize(width: 10, height: 12)
        let defaultPara = NSMutableParagraphStyle()
        defaultPara.paragraphSpacing = 10
        textView.defaultParagraphStyle = defaultPara
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.linkTextAttributes = [
            .foregroundColor: t.accentColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        scrollView.documentView = textView
        addSubview(scrollView)

        returnButton.frame = NSRect(
            x: frame.width - 152,
            y: frame.height - 48,
            width: 126,
            height: 32
        )
        returnButton.autoresizingMask = [.minXMargin, .minYMargin]
        returnButton.isBordered = false
        returnButton.wantsLayer = true
        returnButton.layer?.backgroundColor = t.inputBg.withAlphaComponent(0.92).cgColor
        returnButton.layer?.cornerRadius = 16
        returnButton.layer?.borderWidth = 1
        returnButton.layer?.borderColor = t.separatorColor.withAlphaComponent(0.55).cgColor
        returnButton.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        returnButton.contentTintColor = t.titleText
        returnButton.target = self
        returnButton.action = #selector(returnToLennyTapped)
        returnButton.isHidden = true
        addSubview(returnButton)

        liveStatusContainer.frame = NSRect(
            x: padding,
            y: frame.height - 48,
            width: frame.width - padding * 2 - 158,
            height: 32
        )
        liveStatusContainer.autoresizingMask = [.width, .minYMargin]
        liveStatusContainer.wantsLayer = true
        liveStatusContainer.layer?.backgroundColor = t.inputBg.withAlphaComponent(0.82).cgColor
        liveStatusContainer.layer?.cornerRadius = 16
        liveStatusContainer.layer?.borderWidth = 1
        liveStatusContainer.layer?.borderColor = t.separatorColor.withAlphaComponent(0.42).cgColor
        liveStatusContainer.isHidden = true
        addSubview(liveStatusContainer)

        liveStatusSpinner.style = .spinning
        liveStatusSpinner.controlSize = .small
        liveStatusSpinner.frame = NSRect(x: 12, y: 8, width: 14, height: 14)
        liveStatusSpinner.isDisplayedWhenStopped = false
        liveStatusContainer.addSubview(liveStatusSpinner)

        liveStatusLabel.frame = NSRect(x: 36, y: 7, width: liveStatusContainer.frame.width - 48, height: 18)
        liveStatusLabel.autoresizingMask = [.width]
        liveStatusLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        liveStatusLabel.textColor = t.textDim
        liveStatusLabel.lineBreakMode = .byTruncatingTail
        liveStatusContainer.addSubview(liveStatusLabel)

        attachmentLabel.frame = NSRect(
            x: padding + 8, y: inputHeight + composerBottomInset + 1,
            width: frame.width - padding * 2 - 8,
            height: attachmentHeight
        )
        attachmentLabel.autoresizingMask = [.width]
        attachmentLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        attachmentLabel.textColor = t.textDim
        attachmentLabel.lineBreakMode = .byTruncatingMiddle
        attachmentLabel.isHidden = true
        addSubview(attachmentLabel)

        let composerPanel = NSView(frame: NSRect(
            x: padding,
            y: composerBottomInset,
            width: frame.width - padding * 2,
            height: inputHeight + 14
        ))
        composerPanel.autoresizingMask = [.width, .maxYMargin]
        composerPanel.wantsLayer = true
        composerPanel.layer?.backgroundColor = t.inputBg.withAlphaComponent(0.95).cgColor
        composerPanel.layer?.cornerRadius = 24
        composerPanel.layer?.borderWidth = 1
        composerPanel.layer?.borderColor = t.separatorColor.withAlphaComponent(0.30).cgColor
        composerPanel.layer?.shadowColor = NSColor.black.withAlphaComponent(0.05).cgColor
        composerPanel.layer?.shadowOpacity = 1
        composerPanel.layer?.shadowRadius = 18
        composerPanel.layer?.shadowOffset = CGSize(width: 0, height: -3)
        addSubview(composerPanel)

        inputField.frame = NSRect(
            x: padding + 16, y: composerBottomInset + 7,
            width: frame.width - padding * 3 - attachButtonWidth - 14,
            height: inputHeight
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
        addSubview(inputField)

        attachButton.frame = NSRect(
            x: frame.width - padding - attachButtonWidth - 10,
            y: composerBottomInset + 7,
            width: attachButtonWidth,
            height: inputHeight
        )
        attachButton.autoresizingMask = [.minXMargin]
        attachButton.isBordered = false
        attachButton.wantsLayer = true
        attachButton.layer?.backgroundColor = t.accentColor.cgColor
        attachButton.layer?.cornerRadius = 18
        attachButton.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        attachButton.contentTintColor = NSColor.white
        attachButton.target = self
        attachButton.action = #selector(attachButtonTapped)
        addSubview(attachButton)

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

    func setLiveStatus(_ text: String, isBusy: Bool, isError: Bool = false) {
        let t = theme
        liveStatusContainer.isHidden = text.isEmpty
        guard !text.isEmpty else {
            liveStatusSpinner.stopAnimation(nil)
            return
        }

        liveStatusContainer.layer?.borderColor = (isError ? t.errorColor : t.separatorColor.withAlphaComponent(0.42)).cgColor
        liveStatusContainer.layer?.backgroundColor = (isError ? t.errorColor.withAlphaComponent(0.10) : t.inputBg.withAlphaComponent(0.88)).cgColor
        liveStatusLabel.textColor = isError ? t.errorColor : (isBusy ? t.accentColor : t.successColor)
        liveStatusLabel.stringValue = text

        if isBusy {
            liveStatusSpinner.startAnimation(nil)
        } else {
            liveStatusSpinner.stopAnimation(nil)
        }
    }

    func clearLiveStatus() {
        liveStatusLabel.stringValue = ""
        liveStatusSpinner.stopAnimation(nil)
        liveStatusContainer.isHidden = true
    }
}
