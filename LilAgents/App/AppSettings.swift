import Foundation

enum AppSettings {

    // MARK: - Model enums

    enum ClaudeModel: String, CaseIterable {
        case `default`
        case opus46 = "claude-opus-4-6"
        case sonnet46 = "claude-sonnet-4-6"
        case haiku45 = "claude-haiku-4-5-20251001"

        var label: String {
            switch self {
            case .default: return "Claude"
            case .opus46: return "Claude Opus 4.6"
            case .sonnet46: return "Claude Sonnet 4.6"
            case .haiku45: return "Claude Haiku 4.5"
            }
        }
    }

    enum OpenAIModel: String, CaseIterable {
        case gpt54 = "gpt-5.4"
        case gpt54Pro = "gpt-5.4-pro"
        case gpt54Mini = "gpt-5.4-mini"
        case gpt54Nano = "gpt-5.4-nano"
        case gpt41 = "gpt-4.1"
        case gpt5 = "gpt-5"
        case gpt5Mini = "gpt-5-mini"
        case gpt5Nano = "gpt-5-nano"

        var label: String {
            switch self {
            case .gpt54: return "GPT-5.4"
            case .gpt54Pro: return "GPT-5.4 Pro"
            case .gpt54Mini: return "GPT-5.4 mini"
            case .gpt54Nano: return "GPT-5.4 nano"
            case .gpt41: return "GPT-4.1"
            case .gpt5: return "GPT-5"
            case .gpt5Mini: return "GPT-5 mini"
            case .gpt5Nano: return "GPT-5 nano"
            }
        }
    }

    enum CodexModel: String, CaseIterable {
        case `default`
        case gpt54 = "gpt-5.4"
        case gpt54Mini = "gpt-5.4-mini"
        case gpt53Codex = "gpt-5.3-codex"

        var label: String {
            switch self {
            case .default: return "Codex"
            case .gpt54: return "GPT-5.4"
            case .gpt54Mini: return "GPT-5.4 mini"
            case .gpt53Codex: return "GPT-5.3 Codex"
            }
        }
    }

    enum PreferredTransport: String {
        case automatic
        case claudeCode
        case codex
        case openAIAPI
    }

    enum ArchiveAccessMode: String {
        case starterPack
        case officialMCP
    }

    enum WelcomePreviewMode: String, CaseIterable {
        case live
        case starterPackWithBanner
        case starterPackConnected
        case officialConnected

        var label: String {
            switch self {
            case .live:                 return "Live behavior"
            case .starterPackWithBanner: return "Starter Pack + banner"
            case .starterPackConnected: return "Starter Pack, already connected"
            case .officialConnected:    return "Official MCP connected"
            }
        }
    }

    enum OfficialMCPSource: String, CaseIterable {
        case claudeGlobalConfig
        case codexGlobalConfig
        case settingsToken
        case environmentToken

        var label: String {
            switch self {
            case .claudeGlobalConfig: return "Claude Code"
            case .codexGlobalConfig:  return "Codex"
            case .settingsToken:      return "saved token"
            case .environmentToken:   return "shell token"
            }
        }
    }

    // MARK: - UserDefaults keys

    static let preferredTransportKey    = "preferredTransport"
    static let archiveAccessModeKey     = "archiveAccessMode"
    static let officialLennyMCPTokenKey = "officialLennyMCPToken"
    static let openAIAPIKeyKey          = "openAIAPIKey"
    static let debugLoggingEnabledKey   = "debugLoggingEnabled"
    static let preferredClaudeModelKey  = "preferredClaudeModel"
    static let preferredCodexModelKey   = "preferredCodexModel"
    static let preferredOpenAIModelKey  = "preferredOpenAIModel"
    static let welcomePreviewModeKey    = "welcomePreviewMode"

    // MARK: - Preferences

    static var preferredTransport: PreferredTransport {
        get {
            let rawValue = UserDefaults.standard.string(forKey: preferredTransportKey) ?? PreferredTransport.automatic.rawValue
            return PreferredTransport(rawValue: rawValue) ?? .automatic
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: preferredTransportKey) }
    }

    static var archiveAccessMode: ArchiveAccessMode {
        get {
            let rawValue = UserDefaults.standard.string(forKey: archiveAccessModeKey) ?? defaultArchiveAccessMode.rawValue
            return ArchiveAccessMode(rawValue: rawValue) ?? .starterPack
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: archiveAccessModeKey) }
    }

    static var hasStoredArchiveAccessModePreference: Bool {
        UserDefaults.standard.object(forKey: archiveAccessModeKey) != nil
    }

    static var officialLennyMCPToken: String? {
        get {
            let value = UserDefaults.standard.string(forKey: officialLennyMCPTokenKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: officialLennyMCPTokenKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: officialLennyMCPTokenKey)
            }
        }
    }

    static var openAIAPIKey: String? {
        get {
            let value = UserDefaults.standard.string(forKey: openAIAPIKeyKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: openAIAPIKeyKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: openAIAPIKeyKey)
            }
        }
    }

    static var effectiveArchiveAccessMode: ArchiveAccessMode {
        guard archiveAccessMode != .starterPack else { return .starterPack }
        return detectedOfficialMCPSources.isEmpty ? .starterPack : .officialMCP
    }

    static var defaultArchiveAccessMode: ArchiveAccessMode {
        detectedOfficialMCPSources.isEmpty ? .starterPack : .officialMCP
    }

    static var debugLoggingEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: debugLoggingEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: debugLoggingEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: debugLoggingEnabledKey) }
    }

    static var preferredClaudeModel: ClaudeModel {
        get {
            let rawValue = UserDefaults.standard.string(forKey: preferredClaudeModelKey) ?? ClaudeModel.default.rawValue
            return ClaudeModel(rawValue: rawValue) ?? .default
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: preferredClaudeModelKey) }
    }

    static var preferredCodexModel: CodexModel {
        get {
            let rawValue = UserDefaults.standard.string(forKey: preferredCodexModelKey) ?? CodexModel.default.rawValue
            return CodexModel(rawValue: rawValue) ?? .default
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: preferredCodexModelKey) }
    }

    static var preferredOpenAIModel: OpenAIModel {
        get {
            let rawValue = UserDefaults.standard.string(forKey: preferredOpenAIModelKey) ?? OpenAIModel.gpt54Mini.rawValue
            return OpenAIModel(rawValue: rawValue) ?? .gpt54Mini
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: preferredOpenAIModelKey) }
    }

    static var welcomePreviewMode: WelcomePreviewMode {
        get {
            let rawValue = UserDefaults.standard.string(forKey: welcomePreviewModeKey) ?? WelcomePreviewMode.live.rawValue
            return WelcomePreviewMode(rawValue: rawValue) ?? .live
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: welcomePreviewModeKey) }
    }

    // MARK: - Reset

    static func resetAllData() throws {
        let defaults = UserDefaults.standard
        let managedKeys = [
            preferredTransportKey,
            archiveAccessModeKey,
            officialLennyMCPTokenKey,
            openAIAPIKeyKey,
            debugLoggingEnabledKey,
            preferredClaudeModelKey,
            preferredCodexModelKey,
            preferredOpenAIModelKey,
            welcomePreviewModeKey,
            "hasCompletedOnboarding"
        ]

        for key in managedKeys {
            defaults.removeObject(forKey: key)
        }

        try removeOfficialMCPConfiguration()
        refreshDetectionState()
        NotificationCenter.default.post(name: .lilLennyDidResetData, object: nil)
    }
}

extension Notification.Name {
    static let lilLennyDidResetData = Notification.Name("LilLennyDidResetData")
}
