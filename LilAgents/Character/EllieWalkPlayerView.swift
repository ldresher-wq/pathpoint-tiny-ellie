import AppKit
import AVFoundation

class EllieWalkPlayerView: NSView {
    private let playerLayer = AVPlayerLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = CGColor.clear
        layer?.isOpaque = false
        playerLayer.videoGravity = .resizeAspect
        playerLayer.isOpaque = false
        playerLayer.backgroundColor = CGColor.clear
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }

    func setPlayer(_ player: AVPlayer?) {
        playerLayer.player = player
    }

    func setMirrored(_ mirrored: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.transform = mirrored
            ? CATransform3DMakeScale(-1, 1, 1)
            : CATransform3DIdentity
        CATransaction.commit()
    }
}
