import AppKit
import Lottie

extension WalkerCharacter {
    private static let importedGuestArrivalEffectName = "fall-smoke-dust"
    private static let importedGuestArrivalEffectExtension = "json"

    func animatePersonaSwap() {
        guard let imageView else { return }
        imageView.alphaValue = 0.5
        imageView.wantsLayer = true
        imageView.layer?.transform = CATransform3DMakeScale(0.92, 0.92, 1.0)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            imageView.animator().alphaValue = 1.0
        }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.28)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        imageView.layer?.transform = CATransform3DIdentity
        CATransaction.commit()
    }

    func playHandoffEffect(from previousPersona: WalkerPersona, to newPersona: WalkerPersona) {
        guard case .lenny = previousPersona else {
            if case .lenny = newPersona {
                showHandoffCloud(accent: NSColor(red: 0.96, green: 0.63, blue: 0.23, alpha: 1.0), trailing: true)
            } else {
                showHandoffCloud(accent: NSColor(red: 0.72, green: 0.9, blue: 1.0, alpha: 1.0), trailing: false)
            }
            return
        }

        switch newPersona {
        case .lenny:
            showHandoffCloud(accent: NSColor(red: 0.96, green: 0.63, blue: 0.23, alpha: 1.0), trailing: true)
        case .expert:
            if !showImportedGuestArrivalEffect() {
                showHandoffCloud(accent: NSColor(red: 0.72, green: 0.9, blue: 1.0, alpha: 1.0), trailing: false)
            }
        }
    }

    private func showImportedGuestArrivalEffect() -> Bool {
        guard let effectURL = Bundle.main.url(
            forResource: Self.importedGuestArrivalEffectName,
            withExtension: Self.importedGuestArrivalEffectExtension
        ) else {
            return false
        }

        guard let effectWindow = handoffEffectWindow ?? makeHandoffEffectWindow() else { return false }
        handoffEffectWindow = effectWindow
        guard let contentView = effectWindow.contentView else { return false }

        contentView.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        let animationView = configuredHandoffEffectAnimationView(in: contentView.bounds)
        animationView.frame = contentView.bounds
        if animationView.superview == nil {
            contentView.addSubview(animationView)
        }
        guard let animation = LottieAnimation.filepath(effectURL.path) else { return false }
        animationView.stop()
        animationView.animation = animation

        let charFrame = window.frame
        let effectSize: CGFloat = 200
        effectWindow.setFrame(
            CGRect(
                x: charFrame.midX - effectSize / 2,
                y: charFrame.midY - effectSize / 2 + 10,
                width: effectSize,
                height: effectSize
            ),
            display: false
        )
        effectWindow.orderFrontRegardless()
        animationView.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) { [weak self] in
            guard let self else { return }
            self.handoffEffectAnimationView?.stop()
            self.handoffEffectAnimationView?.removeFromSuperview()
            self.handoffEffectWindow?.orderOut(nil)
            self.handoffEffectWindow?.contentView?.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        }

        return true
    }

    private func configuredHandoffEffectAnimationView(in frame: CGRect) -> LottieAnimationView {
        if let handoffEffectAnimationView {
            handoffEffectAnimationView.frame = frame
            return handoffEffectAnimationView
        }

        let animationView = LottieAnimationView(frame: frame)
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.loopMode = .playOnce
        animationView.autoresizingMask = [.width, .height]
        handoffEffectAnimationView = animationView
        return animationView
    }

    private func showHandoffCloud(accent: NSColor, trailing: Bool) {
        guard let effectWindow = handoffEffectWindow ?? makeHandoffEffectWindow() else { return }
        handoffEffectWindow = effectWindow
        guard let contentView = effectWindow.contentView else { return }

        handoffEffectAnimationView?.stop()
        handoffEffectAnimationView?.removeFromSuperview()
        contentView.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        contentView.alphaValue = 1.0

        let charFrame = window.frame
        let effectSize: CGFloat = 188
        effectWindow.setFrame(
            CGRect(
                x: charFrame.midX - effectSize / 2,
                y: charFrame.midY - effectSize / 2 + 8,
                width: effectSize,
                height: effectSize
            ),
            display: false
        )
        effectWindow.orderFrontRegardless()

        let smokeColor = accent.usingColorSpace(.deviceRGB) ?? accent
        let puffSpecs: [(CGPoint, CGFloat, CFTimeInterval)] = [
            (CGPoint(x: 50, y: 88), 34, 0.00),
            (CGPoint(x: 78, y: 118), 44, 0.04),
            (CGPoint(x: 114, y: 104), 40, 0.08),
            (CGPoint(x: 134, y: 82), 32, 0.12),
            (CGPoint(x: 94, y: 72), 54, 0.16),
            (CGPoint(x: 64, y: 58), 26, 0.20),
            (CGPoint(x: 126, y: 54), 24, 0.24)
        ]

        for (index, spec) in puffSpecs.enumerated() {
            let puff = CAShapeLayer()
            let origin = CGPoint(x: spec.0.x - spec.1 / 2, y: spec.0.y - spec.1 / 2)
            puff.path = CGPath(ellipseIn: CGRect(origin: origin, size: CGSize(width: spec.1, height: spec.1)), transform: nil)
            let alpha = trailing ? 0.26 : 0.18
            puff.fillColor = smokeColor.withAlphaComponent(alpha).cgColor
            puff.strokeColor = smokeColor.withAlphaComponent(trailing ? 0.42 : 0.32).cgColor
            puff.lineWidth = trailing ? 1.4 : 1.0
            puff.opacity = 0.0
            puff.transform = CATransform3DMakeScale(0.35, 0.35, 1.0)
            contentView.layer?.addSublayer(puff)

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0.0, 0.95, trailing ? 0.5 : 0.3, 0.0]
            opacity.keyTimes = [0.0, 0.18, 0.55, 1.0]
            opacity.duration = 0.62
            opacity.beginTime = CACurrentMediaTime() + spec.2
            opacity.fillMode = .forwards
            opacity.isRemovedOnCompletion = false

            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.35
            scale.toValue = trailing ? 1.8 : 1.45
            scale.duration = 0.62
            scale.beginTime = opacity.beginTime
            scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
            scale.fillMode = .forwards
            scale.isRemovedOnCompletion = false

            let drift = CABasicAnimation(keyPath: "position")
            drift.fromValue = NSValue(point: spec.0)
            let direction: CGFloat = trailing ? -12 : 14
            let verticalLift: CGFloat = trailing ? 18 : 28
            drift.toValue = NSValue(point: CGPoint(x: spec.0.x + direction + CGFloat(index * 2), y: spec.0.y + verticalLift))
            drift.duration = 0.62
            drift.beginTime = opacity.beginTime
            drift.timingFunction = CAMediaTimingFunction(name: .easeOut)
            drift.fillMode = .forwards
            drift.isRemovedOnCompletion = false

            puff.add(opacity, forKey: "opacity")
            puff.add(scale, forKey: "scale")
            puff.add(drift, forKey: "drift")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { [weak self] in
            guard let self else { return }
            self.handoffEffectWindow?.orderOut(nil)
            self.handoffEffectWindow?.contentView?.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        }
    }

    private func makeHandoffEffectWindow() -> NSWindow? {
        let win = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 188, height: 188),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 6)
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 188, height: 188))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        win.contentView = view
        return win
    }

    private static let thinkingPhrases = [
        "digging...", "searching...", "checking the archive...",
        "one sec...", "looking...", "pulling excerpts...",
        "finding the best answer..."
    ]

    private static let completionPhrases = [
        "found one!", "got it!", "ready!", "answer’s up", "here you go"
    ]

    private static let bubbleH: CGFloat = 26
    private static let expertNameTagH: CGFloat = 24
    private static let completionSounds: [(name: String, ext: String)] = [
        ("ping-aa", "mp3"), ("ping-bb", "mp3"), ("ping-cc", "mp3"),
        ("ping-dd", "mp3"), ("ping-ee", "mp3"), ("ping-ff", "mp3"),
        ("ping-gg", "mp3"), ("ping-hh", "mp3"), ("ping-jj", "m4a")
    ]

    private static var lastSoundIndex: Int = -1

    func updateThinkingBubble() {
        let now = CACurrentMediaTime()

        if showingCompletion {
            if now >= completionBubbleExpiry {
                showingCompletion = false
                hideBubble()
                return
            }
            if isIdleForPopover {
                completionBubbleExpiry += 1.0 / 60.0
                hideBubble()
            } else {
                showBubble(text: currentPhrase, isCompletion: true)
            }
            return
        }

        if isClaudeBusy && !isIdleForPopover {
            let oldPhrase = currentPhrase
            updateThinkingPhrase()
            if currentPhrase != oldPhrase && !oldPhrase.isEmpty && !phraseAnimating {
                animatePhraseChange(to: currentPhrase, isCompletion: false)
            } else if !phraseAnimating {
                showBubble(text: currentPhrase, isCompletion: false)
            }
        } else if !showingCompletion {
            hideBubble()
        }
    }

    func hideBubble() {
        if thinkingBubbleWindow?.isVisible ?? false {
            thinkingBubbleWindow?.orderOut(nil)
        }
    }

    func updateExpertNameTag() {
        let name = representedExpert?.name ?? focusedExpert?.name
        guard let name, !name.isEmpty else {
            hideExpertNameTag()
            return
        }

        if expertNameWindow == nil {
            createExpertNameTag()
        }

        let t = resolvedTheme
        let font = NSFont.systemFont(ofSize: 11, weight: .bold)
        let horizontalPadding: CGFloat = 12
        let textWidth = ceil((name as NSString).size(withAttributes: [.font: font]).width)
        let tagWidth = min(max(textWidth + horizontalPadding * 2, 82), 180)
        let tagHeight = Self.expertNameTagH

        let charFrame = window.frame
        let x = charFrame.midX - tagWidth / 2
        let y = charFrame.maxY - 4
        expertNameWindow?.setFrame(CGRect(x: x, y: y, width: tagWidth, height: tagHeight), display: false)

        if let container = expertNameWindow?.contentView {
            container.frame = NSRect(x: 0, y: 0, width: tagWidth, height: tagHeight)
            container.layer?.backgroundColor = t.titleBarBg.withAlphaComponent(0.96).cgColor
            container.layer?.borderColor = t.popoverBorder.withAlphaComponent(0.55).cgColor
            container.layer?.cornerRadius = tagHeight / 2

            if let label = container.viewWithTag(410) as? NSTextField {
                label.frame = NSRect(x: horizontalPadding, y: 4, width: tagWidth - horizontalPadding * 2, height: 16)
                label.font = font
                label.textColor = t.titleText
                label.stringValue = name
            }
        }

        if !(expertNameWindow?.isVisible ?? false) {
            expertNameWindow?.alphaValue = 1.0
            expertNameWindow?.orderFrontRegardless()
        }
    }

    func hideExpertNameTag() {
        if expertNameWindow?.isVisible ?? false {
            expertNameWindow?.orderOut(nil)
        }
    }

    private func animatePhraseChange(to newText: String, isCompletion: Bool) {
        guard let win = thinkingBubbleWindow, win.isVisible,
              let label = win.contentView?.viewWithTag(100) as? NSTextField else {
            showBubble(text: newText, isCompletion: isCompletion)
            return
        }
        phraseAnimating = true

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.allowsImplicitAnimation = true
            label.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.showBubble(text: newText, isCompletion: isCompletion)
            label.alphaValue = 0.0
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                ctx.allowsImplicitAnimation = true
                label.animator().alphaValue = 1.0
            }, completionHandler: {
                self?.phraseAnimating = false
            })
        })
    }

    func showBubble(text: String, isCompletion: Bool) {
        let t = resolvedTheme
        if thinkingBubbleWindow == nil {
            createThinkingBubble()
        }

        let h = Self.bubbleH
        let padding: CGFloat = 16
        let font = t.bubbleFont
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let bubbleW = max(ceil(textSize.width) + padding * 2, 48)

        let charFrame = window.frame
        let x = charFrame.midX - bubbleW / 2
        let y = charFrame.origin.y + charFrame.height * 0.88
        thinkingBubbleWindow?.setFrame(CGRect(x: x, y: y, width: bubbleW, height: h), display: false)

        let borderColor = isCompletion ? t.bubbleCompletionBorder.cgColor : t.bubbleBorder.cgColor
        let textColor = isCompletion ? t.bubbleCompletionText : t.bubbleText

        if let container = thinkingBubbleWindow?.contentView {
            container.frame = NSRect(x: 0, y: 0, width: bubbleW, height: h)
            container.layer?.backgroundColor = t.bubbleBg.cgColor
            container.layer?.cornerRadius = t.bubbleCornerRadius
            container.layer?.borderColor = borderColor
            if let label = container.viewWithTag(100) as? NSTextField {
                label.font = font
                let lineH = ceil(textSize.height)
                let labelY = round((h - lineH) / 2) - 1
                label.frame = NSRect(x: 0, y: labelY, width: bubbleW, height: lineH + 2)
                label.stringValue = text
                label.textColor = textColor
            }
        }

        if !(thinkingBubbleWindow?.isVisible ?? false) {
            thinkingBubbleWindow?.alphaValue = 1.0
            thinkingBubbleWindow?.orderFrontRegardless()
        }
    }

    func updateThinkingPhrase() {
        let now = CACurrentMediaTime()
        if currentPhrase.isEmpty || now - lastPhraseUpdate > Double.random(in: 3.0...5.0) {
            var next = Self.thinkingPhrases.randomElement() ?? "..."
            while next == currentPhrase && Self.thinkingPhrases.count > 1 {
                next = Self.thinkingPhrases.randomElement() ?? "..."
            }
            currentPhrase = next
            lastPhraseUpdate = now
        }
    }

    func showCompletionBubble() {
        currentPhrase = Self.completionPhrases.randomElement() ?? "done!"
        showingCompletion = true
        completionBubbleExpiry = CACurrentMediaTime() + 3.0
        lastPhraseUpdate = 0
        phraseAnimating = false
        if !isIdleForPopover {
            showBubble(text: currentPhrase, isCompletion: true)
        }
    }

    func createThinkingBubble() {
        let t = resolvedTheme
        let w: CGFloat = 80
        let h = Self.bubbleH
        let win = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: w, height: h),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 5)
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let container = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        container.wantsLayer = true
        container.layer?.backgroundColor = t.bubbleBg.cgColor
        container.layer?.cornerRadius = t.bubbleCornerRadius
        container.layer?.borderWidth = 1
        container.layer?.borderColor = t.bubbleBorder.cgColor

        let font = t.bubbleFont
        let lineH = ceil(("Xg" as NSString).size(withAttributes: [.font: font]).height)
        let labelY = round((h - lineH) / 2) - 1

        let label = NSTextField(labelWithString: "")
        label.font = font
        label.textColor = t.bubbleText
        label.alignment = .center
        label.drawsBackground = false
        label.isBordered = false
        label.isEditable = false
        label.frame = NSRect(x: 0, y: labelY, width: w, height: lineH + 2)
        label.tag = 100
        container.addSubview(label)

        win.contentView = container
        thinkingBubbleWindow = win
    }

    func createExpertNameTag() {
        let t = resolvedTheme
        let w: CGFloat = 120
        let h = Self.expertNameTagH
        let win = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: w, height: h),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 4)
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let container = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        container.wantsLayer = true
        container.layer?.backgroundColor = t.titleBarBg.withAlphaComponent(0.96).cgColor
        container.layer?.cornerRadius = h / 2
        container.layer?.borderWidth = 1
        container.layer?.borderColor = t.popoverBorder.withAlphaComponent(0.55).cgColor
        container.layer?.shadowColor = NSColor.black.withAlphaComponent(0.12).cgColor
        container.layer?.shadowOpacity = 1
        container.layer?.shadowRadius = 8
        container.layer?.shadowOffset = CGSize(width: 0, height: -1)

        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        label.textColor = t.titleText
        label.alignment = .center
        label.drawsBackground = false
        label.isBordered = false
        label.isEditable = false
        label.frame = NSRect(x: 12, y: 4, width: w - 24, height: 16)
        label.tag = 410
        container.addSubview(label)

        win.contentView = container
        expertNameWindow = win
    }

    func playCompletionSound() {
        guard Self.soundsEnabled else { return }
        var idx: Int
        repeat {
            idx = Int.random(in: 0..<Self.completionSounds.count)
        } while idx == Self.lastSoundIndex && Self.completionSounds.count > 1
        Self.lastSoundIndex = idx

        let s = Self.completionSounds[idx]
        if let url = Bundle.main.url(forResource: s.name, withExtension: s.ext, subdirectory: "Sounds"),
           let sound = NSSound(contentsOf: url, byReference: true) {
            sound.play()
        }
    }

    static var soundsEnabled = true
}
