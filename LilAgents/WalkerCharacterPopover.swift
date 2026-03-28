import AppKit

extension WalkerCharacter {
    func openOnboardingPopover() {
        showingCompletion = false
        hideBubble()

        isIdleForPopover = true
        isWalking = false
        isPaused = true
        setFacing(.front)

        if popoverWindow == nil {
            createPopoverWindow()
        }

        terminalView?.inputField.isEditable = false
        terminalView?.updatePlaceholder("")
        let welcome = """
        Lenny is ready.

        Ask about product, growth, pricing, startups, or AI and I’ll pull together the strongest answer from the archive.
        """
        terminalView?.appendStreamingText(welcome)
        terminalView?.endStreaming()

        updatePopoverPosition()
        popoverWindow?.orderFrontRegardless()

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.closeOnboarding()
        }
        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.closeOnboarding(); return nil }
            return event
        }
    }

    private func closeOnboarding() {
        removeEventMonitors()
        popoverWindow?.orderOut(nil)
        popoverWindow = nil
        terminalView = nil
        isIdleForPopover = false
        isOnboarding = false
        isPaused = true
        pauseEndTime = CACurrentMediaTime() + Double.random(in: 1.0...3.0)
        setFacing(.front)
        controller?.completeOnboarding()
    }

    func openPopover() {
        if let siblings = controller?.characters {
            for sibling in siblings where sibling !== self && sibling.isIdleForPopover {
                sibling.closePopover()
            }
        }

        isIdleForPopover = true
        isWalking = false
        isPaused = true
        setFacing(.front)

        showingCompletion = false
        hideBubble()

        if claudeSession == nil {
            let session = ClaudeSession()
            session.focusedExpert = focusedExpert
            claudeSession = session
            wireSession(session)
            session.start()
        }

        if popoverWindow == nil {
            createPopoverWindow()
        }

        updateInputPlaceholder()

        if let terminal = terminalView, let session = claudeSession, !session.history.isEmpty {
            terminal.replayHistory(session.history)
        }

        updatePopoverPosition()
        popoverWindow?.orderFrontRegardless()
        popoverWindow?.makeKey()

        if let terminal = terminalView {
            popoverWindow?.makeFirstResponder(terminal.inputField)
        }

        removeEventMonitors()

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, let popover = self.popoverWindow else { return }
            let popoverFrame = popover.frame
            let charFrame = self.window.frame
            if !popoverFrame.contains(NSEvent.mouseLocation) && !charFrame.contains(NSEvent.mouseLocation) {
                self.closePopover()
            }
        }

        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.closePopover()
                return nil
            }
            return event
        }
    }

    func closePopover() {
        guard isIdleForPopover else { return }

        popoverWindow?.orderOut(nil)
        removeEventMonitors()

        isIdleForPopover = false

        if showingCompletion {
            completionBubbleExpiry = CACurrentMediaTime() + 3.0
            showBubble(text: currentPhrase, isCompletion: true)
        } else if isClaudeBusy {
            currentPhrase = ""
            lastPhraseUpdate = 0
            updateThinkingPhrase()
            showBubble(text: currentPhrase, isCompletion: false)
        } else {
            setFacing(.front)
        }

        let delay = Double.random(in: 2.0...5.0)
        pauseEndTime = CACurrentMediaTime() + delay
    }

    @objc private func returnToGenieTapped() {
        controller?.returnToGenie()
    }

    private func removeEventMonitors() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        if let monitor = escapeKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escapeKeyMonitor = nil
        }
    }

    func updateInputPlaceholder() {
        if let expert = focusedExpert {
            terminalView?.updatePlaceholder("Ask \(expert.name) a follow-up")
        } else {
            terminalView?.updatePlaceholder("Ask about product, growth, pricing, or AI")
        }
    }

    var resolvedTheme: PopoverTheme {
        (themeOverride ?? PopoverTheme.current).withCharacterColor(characterColor).withCustomFont()
    }

    func createPopoverWindow() {
        let t = resolvedTheme
        let popoverWidth: CGFloat = 640
        let popoverHeight: CGFloat = 600

        let win = KeyableWindow(
            contentRect: CGRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 10)
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let rgbPopoverBackground = t.rgbPopoverBackground
        let brightness = rgbPopoverBackground.redComponent * 0.299 + rgbPopoverBackground.greenComponent * 0.587 + rgbPopoverBackground.blueComponent * 0.114
        let isDark = brightness < 0.5
        win.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight))
        container.material = isDark ? .hudWindow : .sidebar
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = t.popoverCornerRadius
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = t.popoverBorderWidth
        container.layer?.borderColor = t.popoverBorder.cgColor
        container.autoresizingMask = [.width, .height]

        let tintView = NSView(frame: NSRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight))
        tintView.wantsLayer = true
        let origAlpha = t.popoverBg.cgColor.alpha
        tintView.layer?.backgroundColor = t.popoverBg.withAlphaComponent(min(origAlpha * 0.86, 0.92)).cgColor
        tintView.autoresizingMask = [.width, .height]
        container.addSubview(tintView)

        let titleBarHeight: CGFloat = 64
        let titleBar = NSView(frame: NSRect(x: 0, y: popoverHeight - titleBarHeight, width: popoverWidth, height: titleBarHeight))
        titleBar.wantsLayer = true
        titleBar.layer?.backgroundColor = t.titleBarBg.withAlphaComponent(0.55).cgColor
        container.addSubview(titleBar)

        let displayTitle = focusedExpert?.name ?? t.titleString
        let titleLabel = NSTextField(labelWithString: displayTitle)
        titleLabel.font = NSFont.systemFont(ofSize: 21, weight: .semibold)
        titleLabel.textColor = t.titleText
        titleLabel.frame = NSRect(x: 24, y: 27, width: popoverWidth - 220, height: 26)
        titleBar.addSubview(titleLabel)

        let subtitle = NSTextField(labelWithString: focusedExpert == nil ? "Archive-grounded answers" : "Focused follow-up mode")
        subtitle.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        subtitle.textColor = t.textDim
        subtitle.frame = NSRect(x: 24, y: 11, width: popoverWidth - 220, height: 16)
        titleBar.addSubview(subtitle)

        if focusedExpert != nil {
            let returnPill = NSButton(title: "", target: self, action: #selector(returnToGenieTapped))
            returnPill.frame = NSRect(x: popoverWidth - 150, y: 18, width: 126, height: 28)
            returnPill.isBordered = false
            returnPill.wantsLayer = true
            returnPill.layer?.backgroundColor = t.inputBg.withAlphaComponent(0.88).cgColor
            returnPill.layer?.cornerRadius = 14
            returnPill.layer?.borderWidth = 0.75
            returnPill.layer?.borderColor = t.separatorColor.withAlphaComponent(0.50).cgColor
            returnPill.attributedTitle = NSAttributedString(
                string: "Back to Lenny",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: t.titleText
                ]
            )
            titleBar.addSubview(returnPill)
        } else {
            let badge = NSView(frame: NSRect(x: popoverWidth - 146, y: 18, width: 122, height: 28))
            badge.wantsLayer = true
            badge.layer?.backgroundColor = t.inputBg.withAlphaComponent(0.88).cgColor
            badge.layer?.cornerRadius = 14
            badge.layer?.borderWidth = 0.75
            badge.layer?.borderColor = t.separatorColor.withAlphaComponent(0.44).cgColor
            titleBar.addSubview(badge)

            let badgeLabel = NSTextField(labelWithString: "Ready to answer")
            badgeLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            badgeLabel.textColor = t.textDim
            badgeLabel.alignment = .center
            badgeLabel.frame = NSRect(x: 8, y: 6, width: 106, height: 16)
            badge.addSubview(badgeLabel)
        }

        // Hairline separator
        let sep = NSView(frame: NSRect(x: 0, y: popoverHeight - titleBarHeight - 1, width: popoverWidth, height: 0.5))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = t.separatorColor.withAlphaComponent(0.35).cgColor
        container.addSubview(sep)

        let terminal = TerminalView(frame: NSRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight - titleBarHeight - 1))
        terminal.characterColor = characterColor
        terminal.themeOverride = themeOverride
        terminal.autoresizingMask = [.width, .height]
        terminal.onSendMessage = { [weak self] message, attachments in
            self?.claudeSession?.focusedExpert = self?.focusedExpert
            self?.claudeSession?.send(message: message, attachments: attachments)
        }
        terminal.onReturnToLenny = { [weak self] in
            self?.controller?.returnToGenie()
        }
        terminal.onSelectExpert = { [weak self] expert in
            self?.controller?.openDialog(for: expert)
        }
        terminal.setReturnToLennyVisible(false)
        container.addSubview(terminal)

        win.contentView = container
        popoverWindow = win
        terminalView = terminal
    }

    private func wireSession(_ session: ClaudeSession) {
        session.onText = { [weak self] text in
            self?.terminalView?.appendStreamingText(text)
        }

        session.onTurnComplete = { [weak self] in
            guard let self else { return }
            let stagedExperts = self.terminalView?.deferredExpertSuggestions ?? []
            SessionDebugLogger.log("ui", "onTurnComplete fired. focusedExpert=\(self.focusedExpert?.name ?? "none") stagedExperts=\(stagedExperts.map(\.name).joined(separator: ", "))")
            self.terminalView?.endStreaming()
            self.terminalView?.clearLiveStatus()
            self.playCompletionSound()
            self.showCompletionBubble()
            if self.focusedExpert == nil, !stagedExperts.isEmpty {
                let names = stagedExperts.map(\.name).joined(separator: ", ")
                self.terminalView?.setExpertSuggestions(stagedExperts)
                SessionDebugLogger.log("ui", "appended expert suggestion prompt to transcript: \(names)")
            } else {
                self.terminalView?.setExpertSuggestions([])
            }
            self.terminalView?.deferredExpertSuggestions = []
        }

        session.onError = { [weak self] text in
            self?.terminalView?.setLiveStatus(text, isBusy: false, isError: true)
            self?.terminalView?.appendError(text)
        }

        session.onToolUse = { [weak self] toolName, input in
            guard let self else { return }
            let summary = self.formatToolInput(input)
            self.terminalView?.appendToolUse(toolName: toolName, summary: summary)
        }

        session.onToolResult = { [weak self] summary, isError in
            self?.terminalView?.appendToolResult(summary: summary, isError: isError)
        }

        session.onProcessExit = { [weak self] in
            self?.terminalView?.endStreaming()
            self?.terminalView?.appendError("Archive session ended.")
        }

        session.onExpertsUpdated = { [weak self] experts in
            guard let self else { return }
            self.terminalView?.deferredExpertSuggestions = experts
            let names = experts.map(\.name).joined(separator: ", ")
            SessionDebugLogger.log("ui", "onExpertsUpdated received \(experts.count) expert(s): \(names)")
        }
    }

    private func formatToolInput(_ input: [String: Any]) -> String {
        if let cmd = input["command"] as? String { return cmd }
        if let path = input["file_path"] as? String { return path }
        if let pattern = input["pattern"] as? String { return pattern }
        if let query = input["query"] as? String { return query }
        return input.keys.sorted().prefix(3).joined(separator: ", ")
    }

    func updatePopoverPosition() {
        guard let popover = popoverWindow, isIdleForPopover else { return }
        guard let screen = NSScreen.main else { return }

        let charFrame = window.frame
        let popoverSize = popover.frame.size
        var x = charFrame.midX - popoverSize.width / 2
        let y = charFrame.maxY - 10

        let screenFrame = screen.frame
        x = max(screenFrame.minX + 4, min(x, screenFrame.maxX - popoverSize.width - 4))
        let clampedY = min(y, screenFrame.maxY - popoverSize.height - 4)

        popover.setFrameOrigin(NSPoint(x: x, y: clampedY))
    }
}
