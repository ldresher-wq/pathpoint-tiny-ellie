import AppKit

class TerminalView: NSView {
    let scrollView = NSScrollView()
    let textView = NSTextView()
    let inputField = NSTextField()
    let liveStatusContainer = NSView()
    let liveStatusSpinner = NSProgressIndicator()
    let liveStatusLabel = NSTextField(labelWithString: "")
    let attachmentLabel = NSTextField(labelWithString: "")
    let attachButton = NSButton(title: "Attach", target: nil, action: nil)
    let returnButton = NSButton(title: "Return to Genie", target: nil, action: nil)
    var onSendMessage: ((String, [SessionAttachment]) -> Void)?
    var onReturnToLenny: (() -> Void)?

    var characterColor: NSColor?
    var themeOverride: PopoverTheme?
    var currentAssistantText = ""
    var isStreaming = false
    var placeholderText = "Ask LennyTheGenie..."
    var pendingAttachments: [SessionAttachment] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    var theme: PopoverTheme {
        var t = themeOverride ?? PopoverTheme.current
        if let color = characterColor {
            t = t.withCharacterColor(color)
        }
        t = t.withCustomFont()
        return t
    }
}
