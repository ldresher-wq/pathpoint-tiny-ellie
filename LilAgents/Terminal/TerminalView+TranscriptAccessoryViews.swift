import AppKit

class TranscriptStatusSpinnerView: NSView {
    private let theme: PopoverTheme
    private let trackLayer = CAShapeLayer()
    private let arcLayer = CAShapeLayer()

    init(theme: PopoverTheme) {
        self.theme = theme
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setupLayers()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        updatePaths()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            layer?.removeAnimation(forKey: "spin")
        } else {
            startAnimating()
        }
    }

    private func setupLayers() {
        trackLayer.fillColor = NSColor.clear.cgColor
        trackLayer.strokeColor = theme.separatorColor.withAlphaComponent(0.22).cgColor
        trackLayer.lineWidth = 2
        trackLayer.lineCap = .round

        arcLayer.fillColor = NSColor.clear.cgColor
        arcLayer.strokeColor = theme.accentColor.cgColor
        arcLayer.lineWidth = 2
        arcLayer.lineCap = .round
        arcLayer.strokeStart = 0.12
        arcLayer.strokeEnd = 0.78

        layer?.addSublayer(trackLayer)
        layer?.addSublayer(arcLayer)
        startAnimating()
    }

    private func updatePaths() {
        let inset: CGFloat = 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let path = NSBezierPath(ovalIn: rect).cgPath
        trackLayer.frame = bounds
        arcLayer.frame = bounds
        trackLayer.path = path
        arcLayer.path = path
    }

    private func startAnimating() {
        guard layer?.animation(forKey: "spin") == nil else { return }
        let spin = CABasicAnimation(keyPath: "transform.rotation")
        spin.fromValue = 0
        spin.toValue = Double.pi * 2
        spin.duration = 0.9
        spin.repeatCount = .infinity
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        layer?.add(spin, forKey: "spin")
    }
}

class TranscriptStatusView: NSView {
    private let theme: PopoverTheme
    private let contentStack = NSStackView()
    private let avatarContainer = NSView()
    private let detailStack = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let activityBadge = NSView()
    private let activityStack = NSStackView()
    private let spinnerView: TranscriptStatusSpinnerView
    private let textLabel = NSTextField(labelWithString: "")
    private var avatarWidthConstraint: NSLayoutConstraint?

    init(theme: PopoverTheme, text: String, experts: [ResponderExpert] = []) {
        self.theme = theme
        self.spinnerView = TranscriptStatusSpinnerView(theme: theme)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupViews()
        update(text: text, experts: experts)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        let preferredWidth = contentStack.widthAnchor.constraint(lessThanOrEqualToConstant: 468)
        preferredWidth.priority = .defaultHigh

        contentStack.orientation = .horizontal
        contentStack.alignment = .top
        contentStack.spacing = 12
        contentStack.edgeInsets = NSEdgeInsetsZero
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.setContentHuggingPriority(.required, for: .horizontal)
        avatarContainer.setContentCompressionResistancePriority(.required, for: .horizontal)
        avatarWidthConstraint = avatarContainer.widthAnchor.constraint(equalToConstant: 28)
        avatarWidthConstraint?.isActive = true
        contentStack.addArrangedSubview(avatarContainer)

        detailStack.orientation = .vertical
        detailStack.alignment = .leading
        detailStack.spacing = 6
        detailStack.edgeInsets = NSEdgeInsetsZero
        detailStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(detailStack)

        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = theme.accentColor
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.maximumNumberOfLines = 2
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        detailStack.addArrangedSubview(titleLabel)

        activityBadge.wantsLayer = true
        activityBadge.translatesAutoresizingMaskIntoConstraints = false
        activityBadge.layer?.backgroundColor = theme.inputBg.withAlphaComponent(0.68).cgColor
        activityBadge.layer?.borderWidth = 1
        activityBadge.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.14).cgColor
        activityBadge.layer?.cornerRadius = 17
        activityBadge.layer?.shadowColor = theme.accentColor.withAlphaComponent(0.08).cgColor
        activityBadge.layer?.shadowOpacity = 1
        activityBadge.layer?.shadowRadius = 8
        activityBadge.layer?.shadowOffset = CGSize(width: 0, height: -1)
        detailStack.addArrangedSubview(activityBadge)

        activityStack.orientation = .horizontal
        activityStack.alignment = .centerY
        activityStack.spacing = 10
        activityStack.edgeInsets = NSEdgeInsetsZero
        activityStack.translatesAutoresizingMaskIntoConstraints = false
        activityBadge.addSubview(activityStack)

        activityStack.addArrangedSubview(spinnerView)

        textLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        textLabel.textColor = theme.textPrimary
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.maximumNumberOfLines = 2
        textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        activityStack.addArrangedSubview(textLabel)

        NSLayoutConstraint.activate([
            avatarContainer.heightAnchor.constraint(equalToConstant: 28),

            activityStack.topAnchor.constraint(equalTo: activityBadge.topAnchor, constant: 8),
            activityStack.leadingAnchor.constraint(equalTo: activityBadge.leadingAnchor, constant: 12),
            activityStack.trailingAnchor.constraint(equalTo: activityBadge.trailingAnchor, constant: -14),
            activityStack.bottomAnchor.constraint(equalTo: activityBadge.bottomAnchor, constant: -8),

            spinnerView.widthAnchor.constraint(equalToConstant: 16),
            spinnerView.heightAnchor.constraint(equalToConstant: 16),

            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -56),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            preferredWidth
        ])
    }

    func update(text: String, experts: [ResponderExpert] = []) {
        textLabel.stringValue = text
        titleLabel.stringValue = expertTitle(for: experts)
        populateAvatar(experts: experts)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
    }

    private func populateAvatar(experts: [ResponderExpert]) {
        avatarContainer.subviews.forEach { $0.removeFromSuperview() }

        let visibleExperts = Array(experts.prefix(3))
        let avatarSize: CGFloat = 28
        let overlap: CGFloat = 9
        let width = visibleExperts.isEmpty
            ? avatarSize
            : avatarSize + CGFloat(max(0, visibleExperts.count - 1)) * (avatarSize - overlap)
        avatarWidthConstraint?.constant = width

        if !visibleExperts.isEmpty {
            for (index, expert) in visibleExperts.enumerated() {
                guard let image = resolvedAvatarImage(at: expert.avatarPath) else { continue }

                let avatarShell = NSView()
                avatarShell.wantsLayer = true
                avatarShell.layer?.cornerRadius = avatarSize / 2
                avatarShell.layer?.masksToBounds = true
                avatarShell.layer?.borderWidth = 2
                avatarShell.layer?.borderColor = theme.inputBg.cgColor
                avatarShell.layer?.shadowColor = NSColor.black.withAlphaComponent(0.08).cgColor
                avatarShell.layer?.shadowOpacity = 1
                avatarShell.layer?.shadowRadius = 3
                avatarShell.layer?.shadowOffset = CGSize(width: 0, height: -1)
                avatarShell.translatesAutoresizingMaskIntoConstraints = false
                avatarContainer.addSubview(avatarShell)

                let avatarView = NSImageView()
                avatarView.image = image
                avatarView.imageScaling = .scaleAxesIndependently
                avatarView.translatesAutoresizingMaskIntoConstraints = false
                avatarShell.addSubview(avatarView)

                let xOffset = CGFloat(index) * (avatarSize - overlap)
                NSLayoutConstraint.activate([
                    avatarShell.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
                    avatarShell.leadingAnchor.constraint(equalTo: avatarContainer.leadingAnchor, constant: xOffset),
                    avatarShell.widthAnchor.constraint(equalToConstant: avatarSize),
                    avatarShell.heightAnchor.constraint(equalToConstant: avatarSize),

                    avatarView.topAnchor.constraint(equalTo: avatarShell.topAnchor),
                    avatarView.leadingAnchor.constraint(equalTo: avatarShell.leadingAnchor),
                    avatarView.trailingAnchor.constraint(equalTo: avatarShell.trailingAnchor),
                    avatarView.bottomAnchor.constraint(equalTo: avatarShell.bottomAnchor)
                ])
            }
            return
        }

        guard let image = resolvedLennyAvatarImage() else { return }
        let avatarShell = NSView()
        avatarShell.wantsLayer = true
        avatarShell.layer?.cornerRadius = avatarSize / 2
        avatarShell.layer?.masksToBounds = true
        avatarShell.layer?.borderWidth = 1.5
        avatarShell.layer?.borderColor = theme.inputBg.cgColor
        avatarShell.layer?.shadowColor = theme.accentColor.withAlphaComponent(0.12).cgColor
        avatarShell.layer?.shadowOpacity = 1
        avatarShell.layer?.shadowRadius = 4
        avatarShell.layer?.shadowOffset = CGSize(width: 0, height: -1)
        avatarShell.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.addSubview(avatarShell)

        let avatarView = NSImageView()
        avatarView.image = image
        avatarView.imageScaling = .scaleAxesIndependently
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarShell.addSubview(avatarView)

        NSLayoutConstraint.activate([
            avatarShell.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarShell.leadingAnchor.constraint(equalTo: avatarContainer.leadingAnchor),
            avatarShell.widthAnchor.constraint(equalToConstant: avatarSize),
            avatarShell.heightAnchor.constraint(equalToConstant: avatarSize),

            avatarView.topAnchor.constraint(equalTo: avatarShell.topAnchor),
            avatarView.leadingAnchor.constraint(equalTo: avatarShell.leadingAnchor),
            avatarView.trailingAnchor.constraint(equalTo: avatarShell.trailingAnchor),
            avatarView.bottomAnchor.constraint(equalTo: avatarShell.bottomAnchor)
        ])
    }

    private func expertTitle(for experts: [ResponderExpert]) -> String {
        let names = experts.map(\.name)
        switch names.count {
        case 0:
            return "Lil-Lenny"
        case 1:
            return names[0]
        case 2:
            return "\(names[0]) and \(names[1])"
        default:
            let leadingNames = names.dropLast().joined(separator: ", ")
            if let last = names.last {
                return "\(leadingNames), and \(last)"
            }
            return names.joined(separator: ", ")
        }
    }

}
