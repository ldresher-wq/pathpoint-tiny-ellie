import AppKit

// MARK: - Hoverable button used for all interactive rows

class HoverButton: NSButton {
    var normalBg: CGColor = NSColor.clear.cgColor
    var hoverBg: CGColor = NSColor.clear.cgColor

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

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

extension TerminalView {
    func setExpertSuggestions(_ experts: [ResponderExpert]) {
        currentExpertSuggestions = experts
        expertSuggestionsCollapsed = false
        renderExpertSuggestions()
    }

    func setExpertSuggestionsCollapsed(_ experts: [ResponderExpert]) {
        currentExpertSuggestions = experts
        expertSuggestionsCollapsed = true
        renderExpertSuggestions()
    }

    func hideExpertSuggestions(clearState: Bool = true) {
        if clearState {
            currentExpertSuggestions = []
            expertSuggestionsCollapsed = false
        }
        expertSuggestionTargets.removeAll()
        expertSuggestionStack.arrangedSubviews.forEach { view in
            expertSuggestionStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        setPanelVisibility(expertSuggestionContainer, hidden: true)
        relayoutPanels()
    }

    private func renderExpertSuggestions() {
        let experts = currentExpertSuggestions
        expertSuggestionTargets.removeAll()
        expertSuggestionStack.arrangedSubviews.forEach { view in
            expertSuggestionStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard !experts.isEmpty else {
            setPanelVisibility(expertSuggestionContainer, hidden: true)
            relayoutPanels()
            return
        }

        expertSuggestionLabel.stringValue = expertSuggestionsCollapsed
            ? "Suggested experts from this answer"
            : "Open an expert for a more specific follow-up."
        let t = theme

        if expertSuggestionsCollapsed {
            let button = HoverButton(title: "", target: self, action: #selector(expandExpertSuggestionsTapped))
            button.isBordered = false
            button.wantsLayer = true
            button.normalBg = t.inputBg.cgColor
            button.hoverBg = t.accentColor.withAlphaComponent(0.07).cgColor
            button.layer?.backgroundColor = t.inputBg.cgColor
            button.layer?.cornerRadius = 10
            button.layer?.borderWidth = 1
            button.layer?.borderColor = t.separatorColor.withAlphaComponent(0.45).cgColor

            let pstyle = NSMutableParagraphStyle()
            pstyle.alignment = .left
            pstyle.firstLineHeadIndent = 14
            pstyle.headIndent = 14

            let names = experts.prefix(3).map(\.name).joined(separator: ", ")
            let title = "\(experts.count) expert\(experts.count == 1 ? "" : "s"): \(names) · Show options"
            button.attributedTitle = NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                    .foregroundColor: t.textDim,
                    .paragraphStyle: pstyle
                ]
            )
            button.setButtonType(.momentaryPushIn)
            button.translatesAutoresizingMaskIntoConstraints = false
            expertSuggestionStack.addArrangedSubview(button)

            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalTo: expertSuggestionStack.widthAnchor),
                button.heightAnchor.constraint(equalToConstant: 36)
            ])

            setPanelVisibility(expertSuggestionContainer, hidden: false)
            relayoutPanels()
            return
        }

        for expert in experts {
            let identifier = normalizeExpertSuggestionID(expert.name)
            expertSuggestionTargets[identifier] = expert

            let button = HoverButton(title: "", target: self, action: #selector(expertSuggestionButtonTapped(_:)))
            button.isBordered = false
            button.wantsLayer = true
            button.normalBg = t.bubbleBg.cgColor
            button.hoverBg = t.accentColor.withAlphaComponent(0.07).cgColor
            button.layer?.backgroundColor = t.bubbleBg.cgColor
            button.layer?.cornerRadius = 10
            button.layer?.borderWidth = 1
            button.layer?.borderColor = t.separatorColor.withAlphaComponent(0.40).cgColor

            let pstyle = NSMutableParagraphStyle()
            pstyle.alignment = .left
            pstyle.firstLineHeadIndent = 14
            pstyle.headIndent = 14
            pstyle.lineBreakMode = .byTruncatingTail

            button.attributedTitle = NSAttributedString(
                string: expert.name,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                    .foregroundColor: t.textPrimary,
                    .paragraphStyle: pstyle
                ]
            )
            button.setButtonType(.momentaryPushIn)
            button.identifier = NSUserInterfaceItemIdentifier(identifier)
            button.translatesAutoresizingMaskIntoConstraints = false
            expertSuggestionStack.addArrangedSubview(button)
            
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalTo: expertSuggestionStack.widthAnchor),
                button.heightAnchor.constraint(equalToConstant: 36)
            ])
        }

        setPanelVisibility(expertSuggestionContainer, hidden: false)
        relayoutPanels()
    }

    func setPickedExpert(_ expert: ResponderExpert) {
        expertSuggestionTargets.removeAll()
        expertSuggestionStack.arrangedSubviews.forEach { view in
            expertSuggestionStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let t = theme
        expertSuggestionLabel.stringValue = "\(expert.name) picked"

        let button = HoverButton(title: "", target: self, action: #selector(returnToLennyTapped))
        button.isBordered = false
        button.wantsLayer = true
        button.normalBg = t.inputBg.cgColor
        button.hoverBg = t.accentColor.withAlphaComponent(0.07).cgColor
        button.layer?.backgroundColor = t.inputBg.cgColor
        button.layer?.cornerRadius = 10
        button.layer?.borderWidth = 1
        button.layer?.borderColor = t.separatorColor.withAlphaComponent(0.45).cgColor

        let pstyle = NSMutableParagraphStyle()
        pstyle.alignment = .left
        pstyle.firstLineHeadIndent = 14
        pstyle.headIndent = 14
        pstyle.lineBreakMode = .byTruncatingTail

        button.attributedTitle = NSAttributedString(
            string: "End conversation · select another expert",
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: t.textDim,
                .paragraphStyle: pstyle
            ]
        )
        button.setButtonType(.momentaryPushIn)
        button.translatesAutoresizingMaskIntoConstraints = false
        expertSuggestionStack.addArrangedSubview(button)
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalTo: expertSuggestionStack.widthAnchor),
            button.heightAnchor.constraint(equalToConstant: 36)
        ])

        setPanelVisibility(expertSuggestionContainer, hidden: false)
        relayoutPanels()
    }

    func setLiveStatus(_ text: String, isBusy: Bool, isError: Bool = false) {
        let t = theme
        guard !text.isEmpty else {
            clearLiveStatus()
            return
        }

        // Hide input area controls
        inputField.isHidden = true
        sendButton.isHidden = true
        attachButton.isHidden = true

        // Build attributed string: status text + dim "close anytime" hint when busy
        let mainColor = isError ? t.errorColor : (isBusy ? t.accentColor : t.successColor)
        let attrStr = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: mainColor
            ]
        )
        if isBusy && !isError {
            attrStr.append(NSAttributedString(
                string: "  ·  Close anytime",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: t.textDim
                ]
            ))
        }
        liveStatusLabel.attributedStringValue = attrStr

        liveStatusLabel.isHidden = false
        liveStatusSpinner.stopAnimation(nil)
        liveStatusSpinner.isHidden = true
        if isBusy && !isError {
            startLiveStatusAvatarShuffle()
        } else {
            stopLiveStatusAvatarShuffle()
        }
    }

    func clearLiveStatus() {
        liveStatusLabel.attributedStringValue = NSAttributedString(string: "")
        liveStatusSpinner.stopAnimation(nil)
        stopLiveStatusAvatarShuffle()
        
        liveStatusSpinner.isHidden = true
        liveStatusLabel.isHidden = true
        
        // Show input area controls
        inputField.isHidden = false
        sendButton.isHidden = false
        attachButton.isHidden = false
    }

    @objc func expertSuggestionButtonTapped(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue,
              let expert = expertSuggestionTargets[identifier] else {
            return
        }

        setExpertSuggestionsCollapsed(currentExpertSuggestions)
        onSelectExpert?(expert)
    }

    @objc func expandExpertSuggestionsTapped() {
        expertSuggestionsCollapsed = false
        renderExpertSuggestions()
    }

    func normalizeExpertSuggestionID(_ name: String) -> String {
        let lowered = name.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : "-"
        }
        let raw = String(scalars)
        return raw.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    func startLiveStatusAvatarShuffle() {
        if liveStatusAvatarPaths.isEmpty {
            liveStatusAvatarPaths = randomExpertAvatarPaths(limit: Int.random(in: 12...20))
            liveStatusAvatarIndex = 0
        }
        guard !liveStatusAvatarPaths.isEmpty else {
            liveStatusAvatarView.isHidden = true
            return
        }

        liveStatusAvatarView.isHidden = false
        advanceLiveStatusAvatar()

        if liveStatusAvatarTimer == nil {
            liveStatusAvatarTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] _ in
                self?.advanceLiveStatusAvatar()
            }
            if let timer = liveStatusAvatarTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    func stopLiveStatusAvatarShuffle() {
        liveStatusAvatarTimer?.invalidate()
        liveStatusAvatarTimer = nil
        liveStatusAvatarPaths.removeAll()
        liveStatusAvatarIndex = 0
        liveStatusAvatarView.image = nil
        liveStatusAvatarView.isHidden = true
    }

    func advanceLiveStatusAvatar() {
        guard !liveStatusAvatarPaths.isEmpty else { return }
        if liveStatusAvatarIndex >= liveStatusAvatarPaths.count {
            liveStatusAvatarPaths.shuffle()
            liveStatusAvatarIndex = 0
        }
        let path = liveStatusAvatarPaths[liveStatusAvatarIndex]
        liveStatusAvatarIndex += 1
        if let image = NSImage(contentsOfFile: path) {
            liveStatusAvatarView.image = image
        }
    }

    func randomExpertAvatarPaths(limit: Int) -> [String] {
        guard let resourceURL = Bundle.main.resourceURL else { return [] }
        let avatarDir = resourceURL.appendingPathComponent("ExpertAvatars", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: avatarDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let candidates = files
            .filter { $0.pathExtension.lowercased() == "png" }
            .map(\.path)
            .shuffled()
        return Array(candidates.prefix(max(1, limit)))
    }

}
