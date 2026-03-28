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
        hey! i’m LennyTheGenie.

        ask me a startup, product, growth, pricing, or AI question and i’ll search Lenny’s archive for the best answers.

        by default i’ll use Claude Code or Codex if either one is configured. if not, i’ll fall back to the direct OpenAI API.

        when the right expert shows up, i’ll hand you off to them. you can always switch back to lenny.
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

        if let expert = focusedExpert {
            terminalView?.appendStatus("Follow-up mode: \(expert.name)")
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
            terminalView?.updatePlaceholder("Ask \(expert.name)...")
        } else {
            terminalView?.updatePlaceholder("Ask LennyTheGenie...")
        }
    }

    var resolvedTheme: PopoverTheme {
        (themeOverride ?? PopoverTheme.current).withCharacterColor(characterColor).withCustomFont()
    }

    func createPopoverWindow() {
        let t = resolvedTheme
        let popoverWidth: CGFloat = 520
        let popoverHeight: CGFloat = 376

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
        win.appearance = NSAppearance(named: brightness < 0.5 ? .darkAqua : .aqua)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight))
        container.wantsLayer = true
        container.layer?.backgroundColor = t.popoverBg.cgColor
        container.layer?.cornerRadius = t.popoverCornerRadius
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = t.popoverBorderWidth
        container.layer?.borderColor = t.popoverBorder.cgColor
        container.autoresizingMask = [.width, .height]
        addDecorativeBackdrop(to: container, theme: t, size: CGSize(width: popoverWidth, height: popoverHeight))

        let titleBar = NSView(frame: NSRect(x: 0, y: popoverHeight - 64, width: popoverWidth, height: 64))
        titleBar.wantsLayer = true
        titleBar.layer?.backgroundColor = NSColor.clear.cgColor
        container.addSubview(titleBar)

        let eyebrow = NSTextField(labelWithString: "ARCHIVE-GROUNDED GUIDE")
        eyebrow.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        eyebrow.textColor = t.accentColor
        eyebrow.frame = NSRect(x: 24, y: 42, width: popoverWidth - 160, height: 14)
        titleBar.addSubview(eyebrow)

        let titleLabel = NSTextField(labelWithString: t.titleString)
        titleLabel.font = NSFont(name: "Avenir Next Heavy", size: 28) ?? .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = t.titleText
        titleLabel.frame = NSRect(x: 24, y: 12, width: popoverWidth - 180, height: 30)
        titleBar.addSubview(titleLabel)

        let subtitle = NSTextField(labelWithString: "Ask one question. Get the archive. Summon the right expert.")
        subtitle.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        subtitle.textColor = t.textDim
        subtitle.frame = NSRect(x: 24, y: -2, width: popoverWidth - 180, height: 16)
        titleBar.addSubview(subtitle)

        let badge = NSView(frame: NSRect(x: popoverWidth - 144, y: 18, width: 118, height: 28))
        badge.wantsLayer = true
        badge.layer?.backgroundColor = t.inputBg.withAlphaComponent(0.88).cgColor
        badge.layer?.cornerRadius = 14
        badge.layer?.borderWidth = 1
        badge.layer?.borderColor = t.separatorColor.withAlphaComponent(0.45).cgColor
        titleBar.addSubview(badge)

        let badgeLabel = NSTextField(labelWithString: focusedExpert?.name ?? "Genie Mode")
        badgeLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        badgeLabel.textColor = t.titleText
        badgeLabel.alignment = .center
        badgeLabel.frame = NSRect(x: 8, y: 6, width: 102, height: 16)
        badge.addSubview(badgeLabel)

        let sep = NSView(frame: NSRect(x: 24, y: popoverHeight - 66, width: popoverWidth - 48, height: 1))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = t.separatorColor.withAlphaComponent(0.55).cgColor
        container.addSubview(sep)

        let terminal = TerminalView(frame: NSRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight - 68))
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
        terminal.setReturnToLennyVisible(focusedExpert != nil)
        container.addSubview(terminal)

        win.contentView = container
        popoverWindow = win
        terminalView = terminal
    }

    private func addDecorativeBackdrop(to container: NSView, theme t: PopoverTheme, size: CGSize) {
        guard let layer = container.layer else { return }

        let glow = CAGradientLayer()
        glow.frame = CGRect(origin: .zero, size: size)
        glow.colors = [
            t.titleBarBg.withAlphaComponent(0.92).cgColor,
            t.popoverBg.withAlphaComponent(0.0).cgColor
        ]
        glow.startPoint = CGPoint(x: 0.15, y: 1.0)
        glow.endPoint = CGPoint(x: 0.72, y: 0.2)
        layer.addSublayer(glow)

        let orbSpecs: [(CGRect, NSColor)] = [
            (CGRect(x: size.width - 132, y: size.height - 104, width: 92, height: 92), t.accentColor.withAlphaComponent(0.07)),
            (CGRect(x: -24, y: size.height - 92, width: 86, height: 86), t.titleBarBg.withAlphaComponent(0.24)),
            (CGRect(x: size.width - 86, y: 16, width: 56, height: 56), t.successColor.withAlphaComponent(0.05))
        ]

        for spec in orbSpecs {
            let orb = CAShapeLayer()
            orb.path = CGPath(ellipseIn: spec.0, transform: nil)
            orb.fillColor = spec.1.cgColor
            layer.addSublayer(orb)
        }
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
                self.terminalView?.appendStatus("Expert suggestions ready: \(names)")
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
            self.terminalView?.setExpertSuggestions(experts)
            let names = experts.map(\.name).joined(separator: ", ")
            let summary = experts.isEmpty
                ? "Staged expert suggestions: 0"
                : "Staged expert suggestions until response completes: \(experts.count) (\(names))"
            self.terminalView?.appendStatus(summary)
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
