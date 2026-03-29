import AppKit

class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class CharacterContentView: NSView {
    weak var character: WalkerCharacter?
    private var mouseDownPoint: NSPoint?
    private var didDrag = false
    private let dragThreshold: CGFloat = 4

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let character else { return nil }

        let menu = NSMenu()

        let dontMoveItem = NSMenuItem(title: "Don't move", action: #selector(toggleMovementLocked(_:)), keyEquivalent: "")
        dontMoveItem.target = self
        dontMoveItem.state = character.movementLocked ? .on : .off
        menu.addItem(dontMoveItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(AppDelegate.openSettings), keyEquivalent: "")
        settingsItem.target = NSApp.delegate
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit Lil-Lenny", action: #selector(AppDelegate.quitApp), keyEquivalent: "")
        quitItem.target = NSApp.delegate
        menu.addItem(quitItem)

        return menu
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        guard bounds.contains(localPoint) else { return nil }

        // AVPlayerLayer is GPU-rendered so layer.render(in:) won't capture video pixels.
        // Use CGWindowListCreateImage to sample actual on-screen alpha at click point.
        let screenPoint = window?.convertPoint(toScreen: convert(localPoint, to: nil)) ?? .zero
        // Use the full virtual display height for the CG coordinate flip, not just
        // the main screen. NSScreen coordinates have origin at bottom-left of the
        // primary display, while CG uses top-left. The primary screen's height is
        // the correct basis for the flip across all monitors.
        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let flippedY = primaryScreen.frame.height - screenPoint.y

        let captureRect = CGRect(x: screenPoint.x - 0.5, y: flippedY - 0.5, width: 1, height: 1)
        guard let windowID = window?.windowNumber, windowID > 0 else { return nil }

        if let image = CGWindowListCreateImage(
            captureRect,
            .optionIncludingWindow,
            CGWindowID(windowID),
            [.boundsIgnoreFraming, .bestResolution]
        ) {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var pixel: [UInt8] = [0, 0, 0, 0]
            if let ctx = CGContext(
                data: &pixel, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                if pixel[3] > 30 {
                    return self
                }
                return nil
            }
        }

        // Fallback: accept click if within center 60% of the view
        let insetX = bounds.width * 0.2
        let insetY = bounds.height * 0.15
        let hitRect = bounds.insetBy(dx: insetX, dy: insetY)
        return hitRect.contains(localPoint) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        didDrag = false
        character?.beginHorizontalDrag(at: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownPoint else { return }
        let currentPoint = convert(event.locationInWindow, from: nil)
        if !didDrag, abs(currentPoint.x - mouseDownPoint.x) >= dragThreshold {
            didDrag = true
        }
        if didDrag {
            character?.continueHorizontalDrag(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            character?.endHorizontalDrag()
        } else {
            character?.cancelHorizontalDrag()
            character?.handleClick()
        }
        mouseDownPoint = nil
        didDrag = false
    }

    override func rightMouseDown(with event: NSEvent) {
        mouseDownPoint = nil
        didDrag = false
        if let menu = menu(for: event) {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
    }

    @objc private func toggleMovementLocked(_ sender: NSMenuItem) {
        guard let character else { return }
        character.setMovementLocked(!character.movementLocked)
    }
}
