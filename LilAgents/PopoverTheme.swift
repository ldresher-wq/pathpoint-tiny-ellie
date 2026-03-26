import AppKit

struct PopoverTheme {
    let name: String
    // Popover
    let popoverBg: NSColor
    let popoverBorder: NSColor
    let popoverBorderWidth: CGFloat
    let popoverCornerRadius: CGFloat
    let titleBarBg: NSColor
    let titleText: NSColor
    let titleFont: NSFont
    let titleString: String
    let separatorColor: NSColor
    // Terminal
    let font: NSFont
    let fontBold: NSFont
    let textPrimary: NSColor
    let textDim: NSColor
    let accentColor: NSColor
    let errorColor: NSColor
    let successColor: NSColor
    let inputBg: NSColor
    let inputCornerRadius: CGFloat
    // Bubble
    let bubbleBg: NSColor
    let bubbleBorder: NSColor
    let bubbleText: NSColor
    let bubbleCompletionBorder: NSColor
    let bubbleCompletionText: NSColor
    let bubbleFont: NSFont
    let bubbleCornerRadius: CGFloat

    // MARK: - Presets

    static let teenageEngineering = PopoverTheme(
        name: "Midnight",
        popoverBg: NSColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 0.96),
        popoverBorder: NSColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 0.7),
        popoverBorderWidth: 1.5,
        popoverCornerRadius: 12,
        titleBarBg: NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0),
        titleText: NSColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0),
        titleFont: NSFont(name: "SFMono-Bold", size: 10) ?? .monospacedSystemFont(ofSize: 10, weight: .bold),
        titleString: "LENNY",
        separatorColor: NSColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 0.3),
        font: NSFont(name: "SFMono-Regular", size: 11.5) ?? .monospacedSystemFont(ofSize: 11.5, weight: .regular),
        fontBold: NSFont(name: "SFMono-Medium", size: 11.5) ?? .monospacedSystemFont(ofSize: 11.5, weight: .medium),
        textPrimary: NSColor.white,
        textDim: NSColor(white: 0.6, alpha: 1.0),
        accentColor: NSColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0),
        errorColor: NSColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 1.0),
        successColor: NSColor(red: 0.4, green: 0.65, blue: 0.4, alpha: 1.0),
        inputBg: NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0),
        inputCornerRadius: 4,
        bubbleBg: NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.92),
        bubbleBorder: NSColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 0.6),
        bubbleText: NSColor(white: 0.7, alpha: 1.0),
        bubbleCompletionBorder: NSColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 0.7),
        bubbleCompletionText: NSColor(red: 0.3, green: 0.85, blue: 0.3, alpha: 1.0),
        bubbleFont: .monospacedSystemFont(ofSize: 10, weight: .medium),
        bubbleCornerRadius: 12
    )

    static let playful = PopoverTheme(
        name: "Peach",
        popoverBg: NSColor(red: 0.986, green: 0.956, blue: 0.905, alpha: 0.985),
        popoverBorder: NSColor(red: 0.882, green: 0.671, blue: 0.365, alpha: 0.72),
        popoverBorderWidth: 1.5,
        popoverCornerRadius: 30,
        titleBarBg: NSColor(red: 0.965, green: 0.892, blue: 0.760, alpha: 0.88),
        titleText: NSColor(red: 0.420, green: 0.285, blue: 0.170, alpha: 1.0),
        titleFont: NSFont(name: "Avenir Next Demi Bold", size: 11) ?? .systemFont(ofSize: 11, weight: .semibold),
        titleString: "LennyTheGenie",
        separatorColor: NSColor(red: 0.858, green: 0.741, blue: 0.546, alpha: 0.36),
        font: NSFont(name: "Avenir Next Regular", size: 13) ?? .systemFont(ofSize: 13, weight: .regular),
        fontBold: NSFont(name: "Avenir Next Demi Bold", size: 13) ?? .systemFont(ofSize: 13, weight: .semibold),
        textPrimary: NSColor(red: 0.204, green: 0.157, blue: 0.122, alpha: 1.0),
        textDim: NSColor(red: 0.475, green: 0.399, blue: 0.331, alpha: 1.0),
        accentColor: NSColor(red: 0.769, green: 0.447, blue: 0.157, alpha: 1.0),
        errorColor: NSColor(red: 0.776, green: 0.257, blue: 0.184, alpha: 1.0),
        successColor: NSColor(red: 0.251, green: 0.553, blue: 0.412, alpha: 1.0),
        inputBg: NSColor(red: 0.997, green: 0.983, blue: 0.962, alpha: 0.98),
        inputCornerRadius: 18,
        bubbleBg: NSColor(red: 0.992, green: 0.941, blue: 0.865, alpha: 0.96),
        bubbleBorder: NSColor(red: 0.882, green: 0.671, blue: 0.365, alpha: 0.55),
        bubbleText: NSColor(red: 0.454, green: 0.359, blue: 0.284, alpha: 1.0),
        bubbleCompletionBorder: NSColor(red: 0.3, green: 0.75, blue: 0.5, alpha: 0.7),
        bubbleCompletionText: NSColor(red: 0.2, green: 0.6, blue: 0.4, alpha: 1.0),
        bubbleFont: NSFont(name: "Avenir Next Demi Bold", size: 11) ?? .systemFont(ofSize: 11, weight: .semibold),
        bubbleCornerRadius: 16
    )

    static let wii = PopoverTheme(
        name: "Cloud",
        popoverBg: NSColor(red: 0.94, green: 0.95, blue: 0.96, alpha: 0.98),
        popoverBorder: NSColor(red: 0.78, green: 0.80, blue: 0.84, alpha: 0.6),
        popoverBorderWidth: 1,
        popoverCornerRadius: 16,
        titleBarBg: NSColor(red: 0.88, green: 0.90, blue: 0.93, alpha: 1.0),
        titleText: NSColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1.0),
        titleFont: .systemFont(ofSize: 12, weight: .semibold),
        titleString: "lenny ~",
        separatorColor: NSColor(red: 0.8, green: 0.82, blue: 0.85, alpha: 0.4),
        font: .systemFont(ofSize: 12, weight: .regular),
        fontBold: .systemFont(ofSize: 12, weight: .semibold),
        textPrimary: NSColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0),
        textDim: NSColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0),
        accentColor: NSColor(red: 0.0, green: 0.47, blue: 0.84, alpha: 1.0),
        errorColor: NSColor(red: 0.85, green: 0.2, blue: 0.15, alpha: 1.0),
        successColor: NSColor(red: 0.2, green: 0.65, blue: 0.3, alpha: 1.0),
        inputBg: NSColor.white,
        inputCornerRadius: 8,
        bubbleBg: NSColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 0.95),
        bubbleBorder: NSColor(red: 0.0, green: 0.47, blue: 0.84, alpha: 0.4),
        bubbleText: NSColor(red: 0.45, green: 0.47, blue: 0.52, alpha: 1.0),
        bubbleCompletionBorder: NSColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 0.6),
        bubbleCompletionText: NSColor(red: 0.15, green: 0.55, blue: 0.2, alpha: 1.0),
        bubbleFont: .systemFont(ofSize: 10, weight: .semibold),
        bubbleCornerRadius: 12
    )

    static let iPod = PopoverTheme(
        name: "Moss",
        popoverBg: NSColor(red: 0.82, green: 0.84, blue: 0.78, alpha: 0.98),
        popoverBorder: NSColor(red: 0.55, green: 0.58, blue: 0.50, alpha: 0.8),
        popoverBorderWidth: 2,
        popoverCornerRadius: 10,
        titleBarBg: NSColor(red: 0.72, green: 0.75, blue: 0.68, alpha: 1.0),
        titleText: NSColor(red: 0.15, green: 0.17, blue: 0.12, alpha: 1.0),
        titleFont: NSFont(name: "Chicago", size: 11) ?? .systemFont(ofSize: 11, weight: .bold),
        titleString: "Lenny",
        separatorColor: NSColor(red: 0.55, green: 0.58, blue: 0.50, alpha: 0.5),
        font: NSFont(name: "Geneva", size: 11) ?? .monospacedSystemFont(ofSize: 11, weight: .regular),
        fontBold: NSFont(name: "Geneva", size: 11) ?? .monospacedSystemFont(ofSize: 11, weight: .bold),
        textPrimary: NSColor(red: 0.1, green: 0.12, blue: 0.08, alpha: 1.0),
        textDim: NSColor(red: 0.35, green: 0.38, blue: 0.30, alpha: 1.0),
        accentColor: NSColor(red: 0.2, green: 0.22, blue: 0.15, alpha: 1.0),
        errorColor: NSColor(red: 0.6, green: 0.15, blue: 0.1, alpha: 1.0),
        successColor: NSColor(red: 0.15, green: 0.4, blue: 0.15, alpha: 1.0),
        inputBg: NSColor(red: 0.88, green: 0.90, blue: 0.84, alpha: 1.0),
        inputCornerRadius: 3,
        bubbleBg: NSColor(red: 0.82, green: 0.84, blue: 0.78, alpha: 0.95),
        bubbleBorder: NSColor(red: 0.55, green: 0.58, blue: 0.50, alpha: 0.7),
        bubbleText: NSColor(red: 0.4, green: 0.42, blue: 0.38, alpha: 1.0),
        bubbleCompletionBorder: NSColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 0.7),
        bubbleCompletionText: NSColor(red: 0.15, green: 0.4, blue: 0.15, alpha: 1.0),
        bubbleFont: NSFont(name: "Geneva", size: 10) ?? .monospacedSystemFont(ofSize: 10, weight: .medium),
        bubbleCornerRadius: 8
    )

    static let allThemes: [PopoverTheme] = [.playful, .teenageEngineering, .wii, .iPod]
    static var current: PopoverTheme = .playful
    static var customFontName: String? = ".AppleSystemUIFontRounded"
    static var customFontSize: CGFloat = 13

    // MARK: - Theme Modifiers

    func withCharacterColor(_ color: NSColor) -> PopoverTheme {
        guard name == "Peach" else { return self }
        guard let rgbColor = color.usingColorSpace(.deviceRGB) else { return self }
        let r = rgbColor.redComponent
        let g = rgbColor.greenComponent
        let b = rgbColor.blueComponent
        let light = NSColor(red: min(r + 0.4, 1), green: min(g + 0.4, 1), blue: min(b + 0.4, 1), alpha: 0.25)
        let border = NSColor(red: r, green: g, blue: b, alpha: 0.6)
        return PopoverTheme(
            name: name, popoverBg: popoverBg,
            popoverBorder: border,
            popoverBorderWidth: popoverBorderWidth, popoverCornerRadius: popoverCornerRadius,
            titleBarBg: NSColor(red: min(r * 0.3 + 0.7, 1), green: min(g * 0.3 + 0.7, 1), blue: min(b * 0.3 + 0.7, 1), alpha: 1.0),
            titleText: color, titleFont: titleFont, titleString: titleString,
            separatorColor: light,
            font: font, fontBold: fontBold,
            textPrimary: textPrimary, textDim: textDim,
            accentColor: color,
            errorColor: errorColor, successColor: successColor,
            inputBg: inputBg, inputCornerRadius: inputCornerRadius,
            bubbleBg: NSColor(red: min(r * 0.15 + 0.85, 1), green: min(g * 0.15 + 0.85, 1), blue: min(b * 0.15 + 0.85, 1), alpha: 0.95),
            bubbleBorder: border,
            bubbleText: bubbleText,
            bubbleCompletionBorder: bubbleCompletionBorder, bubbleCompletionText: bubbleCompletionText,
            bubbleFont: bubbleFont, bubbleCornerRadius: bubbleCornerRadius
        )
    }

    func withCustomFont() -> PopoverTheme {
        // Midnight uses its own mono font — don't override
        guard name != "Midnight" else { return self }
        guard let fontName = PopoverTheme.customFontName,
              let baseFont = NSFont(name: fontName, size: PopoverTheme.customFontSize) else { return self }
        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
        let smallFont = NSFont(name: fontName, size: PopoverTheme.customFontSize - 1) ?? baseFont
        return PopoverTheme(
            name: name, popoverBg: popoverBg, popoverBorder: popoverBorder,
            popoverBorderWidth: popoverBorderWidth, popoverCornerRadius: popoverCornerRadius,
            titleBarBg: titleBarBg, titleText: titleText, titleFont: titleFont, titleString: titleString,
            separatorColor: separatorColor,
            font: baseFont, fontBold: boldFont,
            textPrimary: textPrimary, textDim: textDim, accentColor: accentColor,
            errorColor: errorColor, successColor: successColor,
            inputBg: inputBg, inputCornerRadius: inputCornerRadius,
            bubbleBg: bubbleBg, bubbleBorder: bubbleBorder, bubbleText: bubbleText,
            bubbleCompletionBorder: bubbleCompletionBorder, bubbleCompletionText: bubbleCompletionText,
            bubbleFont: smallFont, bubbleCornerRadius: bubbleCornerRadius
        )
    }

    var rgbPopoverBackground: NSColor {
        popoverBg.usingColorSpace(.deviceRGB) ?? popoverBg
    }
}
