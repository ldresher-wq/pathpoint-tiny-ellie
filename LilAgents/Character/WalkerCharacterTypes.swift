import AppKit

enum WalkerFacing {
    case front
    case left
    case right
    case back
}

enum WalkerPersona {
    case ellie
    case expert(ResponderExpert)
}

enum WalkerCharacterAssets {
    static let ellieAssetsDirectory = "CharacterSprites"
}
