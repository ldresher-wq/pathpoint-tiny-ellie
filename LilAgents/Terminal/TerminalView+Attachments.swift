import AppKit
import Foundation
import PDFKit

final class AttachmentPreviewChipView: NSView {
    let attachment: SessionAttachment
    var onRemove: (() -> Void)?

    private let theme: PopoverTheme
    private let previewView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let removeButton = HoverButton(title: "", target: nil, action: nil)

    init(attachment: SessionAttachment, theme: PopoverTheme) {
        self.attachment = attachment
        self.theme = theme
        super.init(frame: NSRect(x: 0, y: 0, width: 172, height: TerminalView.Layout.attachmentChipHeight))
        setupViews()
        populate()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = theme.bubbleBg.cgColor
        layer?.cornerRadius = 12
        layer?.borderWidth = 0.75
        layer?.borderColor = theme.separatorColor.withAlphaComponent(0.42).cgColor

        previewView.frame = NSRect(x: 8, y: 7, width: 28, height: 28)
        previewView.wantsLayer = true
        previewView.layer?.cornerRadius = 7
        previewView.layer?.masksToBounds = true
        previewView.imageScaling = .scaleProportionallyUpOrDown
        previewView.imageAlignment = .alignCenter
        addSubview(previewView)

        titleLabel.frame = NSRect(x: 44, y: 18, width: 96, height: 15)
        titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        titleLabel.textColor = theme.textPrimary
        titleLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(titleLabel)

        detailLabel.frame = NSRect(x: 44, y: 7, width: 96, height: 12)
        detailLabel.font = NSFont.systemFont(ofSize: 9.5, weight: .medium)
        detailLabel.textColor = theme.textDim
        detailLabel.lineBreakMode = .byTruncatingTail
        addSubview(detailLabel)

        removeButton.frame = NSRect(x: 142, y: 9, width: 24, height: 24)
        removeButton.isBordered = false
        removeButton.wantsLayer = true
        removeButton.normalBg = theme.separatorColor.withAlphaComponent(0.10).cgColor
        removeButton.hoverBg = theme.separatorColor.withAlphaComponent(0.22).cgColor
        removeButton.layer?.backgroundColor = theme.separatorColor.withAlphaComponent(0.10).cgColor
        removeButton.layer?.cornerRadius = 12
        if let image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Remove attachment") {
            let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
            removeButton.image = image.withSymbolConfiguration(config)
        }
        removeButton.imageScaling = .scaleProportionallyDown
        removeButton.contentTintColor = theme.textDim
        removeButton.target = self
        removeButton.action = #selector(removeTapped)
        addSubview(removeButton)
    }

    private func populate() {
        titleLabel.stringValue = attachment.displayName
        detailLabel.stringValue = "\(attachment.detail) • \(attachment.fileExtensionLabel)"

        if let previewImage = AttachmentPreviewChipView.previewImage(for: attachment) {
            previewView.image = previewImage
        } else {
            previewView.image = NSWorkspace.shared.icon(forFile: attachment.url.path)
            previewView.contentTintColor = nil
        }
    }

    @objc private func removeTapped() {
        onRemove?()
    }

    static func previewImage(for attachment: SessionAttachment) -> NSImage? {
        switch attachment.kind {
        case .image:
            return NSImage(contentsOf: attachment.url)
        case .document:
            if attachment.url.pathExtension.lowercased() == "pdf",
               let document = PDFDocument(url: attachment.url),
               let page = document.page(at: 0) {
                return page.thumbnail(of: NSSize(width: 56, height: 56), for: .cropBox)
            }

            let icon = NSWorkspace.shared.icon(forFile: attachment.url.path)
            icon.size = NSSize(width: 28, height: 28)
            return icon
        }
    }
}

extension TerminalView {
    func presentAttachmentPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = true
        panel.title = "Add Attachments"
        panel.message = "Choose screenshots, PDFs, CSVs, docs, code, or links to send with your question."
        panel.allowedContentTypes = SessionAttachment.supportedContentTypes

        guard panel.runModal() == .OK else { return }
        queueAttachments(panel.urls.compactMap(SessionAttachment.from(url:)))
    }

    func refreshAttachmentPreviews() {
        attachmentPreviewStack.arrangedSubviews.forEach { view in
            attachmentPreviewStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard !pendingAttachments.isEmpty else {
            attachmentStrip.isHidden = true
            attachmentHintLabel.isHidden = !isShowingDropTarget
            attachmentScrollView.isHidden = isShowingDropTarget
            relayoutPanels()
            return
        }

        let t = theme
        for attachment in pendingAttachments {
            let chip = AttachmentPreviewChipView(attachment: attachment, theme: t)
            chip.translatesAutoresizingMaskIntoConstraints = false
            chip.onRemove = { [weak self] in
                self?.removeAttachment(attachment)
            }
            attachmentPreviewStack.addArrangedSubview(chip)
            NSLayoutConstraint.activate([
                chip.widthAnchor.constraint(equalToConstant: 172),
                chip.heightAnchor.constraint(equalToConstant: Layout.attachmentChipHeight)
            ])
        }

        attachmentStrip.isHidden = false
        attachmentHintLabel.isHidden = true
        attachmentScrollView.isHidden = false
        relayoutPanels()
    }

    func setDropTargetVisible(_ visible: Bool) {
        isShowingDropTarget = visible
        let t = theme
        attachmentStrip.isHidden = !visible && pendingAttachments.isEmpty
        attachmentHintLabel.isHidden = !visible || !pendingAttachments.isEmpty
        attachmentScrollView.isHidden = visible && pendingAttachments.isEmpty
        attachmentStrip.layer?.borderColor = (visible ? t.accentColor.withAlphaComponent(0.75) : t.separatorColor.withAlphaComponent(0.36)).cgColor
        attachmentStrip.layer?.backgroundColor = (visible ? t.accentColor.withAlphaComponent(0.08) : t.inputBg.withAlphaComponent(0.96)).cgColor
        relayoutPanels()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let canAccept = dragContainsSupportedAttachment(from: sender.draggingPasteboard)
        setDropTargetVisible(canAccept)
        return canAccept ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let canAccept = dragContainsSupportedAttachment(from: sender.draggingPasteboard)
        setDropTargetVisible(canAccept)
        return canAccept ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setDropTargetVisible(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let attachments = draggedAttachments(from: sender)
        setDropTargetVisible(false)
        guard !attachments.isEmpty else { return false }
        queueAttachments(attachments)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        setDropTargetVisible(false)
    }

    private func queueAttachments(_ attachments: [SessionAttachment]) {
        guard !attachments.isEmpty else { return }

        let newAttachments = attachments.filter { !pendingAttachments.contains($0) }
        guard !newAttachments.isEmpty else { return }

        pendingAttachments.append(contentsOf: newAttachments)
        refreshAttachmentPreviews()
        appendStatus("Queued \(newAttachments.count) attachment\(newAttachments.count == 1 ? "" : "s")")
    }

    private func removeAttachment(_ attachment: SessionAttachment) {
        pendingAttachments.removeAll { $0 == attachment }
        refreshAttachmentPreviews()
    }

    private func draggedAttachments(from sender: NSDraggingInfo) -> [SessionAttachment] {
        attachments(from: sender.draggingPasteboard)
    }

    private func attachments(from pasteboard: NSPasteboard) -> [SessionAttachment] {
        var attachments: [SessionAttachment] = []

        let fileOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: fileOptions) as? [URL] ?? []
        attachments.append(contentsOf: fileURLs.compactMap(SessionAttachment.from(url:)))

        if attachments.isEmpty,
           let remoteURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in remoteURLs where !url.isFileURL {
                if let attachment = createURLAttachment(url) {
                    attachments.append(attachment)
                }
            }
        }

        if attachments.isEmpty,
           let image = NSImage(pasteboard: pasteboard),
           let attachment = createImageAttachment(image) {
            attachments.append(attachment)
        }

        if attachments.isEmpty,
           let rawString = pasteboard.string(forType: .string),
           let attachment = createTextAttachment(rawString, suggestedName: "Dropped Note.txt") {
            attachments.append(attachment)
        }

        return attachments
    }

    private func dragContainsSupportedAttachment(from pasteboard: NSPasteboard) -> Bool {
        let fileOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: fileOptions) as? [URL],
           fileURLs.contains(where: { SessionAttachment.from(url: $0) != nil }) {
            return true
        }

        if let remoteURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           remoteURLs.contains(where: { !$0.isFileURL }) {
            return true
        }

        if NSImage(pasteboard: pasteboard) != nil {
            return true
        }

        if let rawString = pasteboard.string(forType: .string),
           !rawString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }

        return false
    }

    private func createImageAttachment(_ image: NSImage) -> SessionAttachment? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let url = temporaryAttachmentURL(named: "Dropped Image.png")
        do {
            try pngData.write(to: url, options: .atomic)
            return SessionAttachment.from(url: url)
        } catch {
            return nil
        }
    }

    private func createTextAttachment(_ text: String, suggestedName: String) -> SessionAttachment? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let url = temporaryAttachmentURL(named: suggestedName)
        do {
            try trimmed.write(to: url, atomically: true, encoding: .utf8)
            return SessionAttachment.from(url: url)
        } catch {
            return nil
        }
    }

    private func createURLAttachment(_ url: URL) -> SessionAttachment? {
        createTextAttachment(url.absoluteString, suggestedName: "Dropped Link.txt")
    }

    private func temporaryAttachmentURL(named suggestedName: String) -> URL {
        let cleanedBase = ((suggestedName as NSString).deletingPathExtension)
            .replacingOccurrences(of: "[^A-Za-z0-9 _-]", with: "-", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackBase = cleanedBase.isEmpty ? "Attachment" : cleanedBase
        let fileExtension = (suggestedName as NSString).pathExtension.isEmpty ? "txt" : (suggestedName as NSString).pathExtension
        let uniqueName = "\(fallbackBase)-\(UUID().uuidString.prefix(8)).\(fileExtension)"
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(uniqueName)
    }
}
