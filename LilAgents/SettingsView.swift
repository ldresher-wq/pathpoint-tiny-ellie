import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.archiveAccessModeKey) private var archiveAccessMode = AppSettings.ArchiveAccessMode.starterPack.rawValue
    @AppStorage(AppSettings.officialLennyMCPTokenKey) private var officialToken = ""
    @AppStorage(AppSettings.debugLoggingEnabledKey) private var debugLoggingEnabled = true

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {

                // Archive Source
                SettingsSection(icon: "archivebox.fill", title: "Archive Source") {
                    Picker("Source", selection: $archiveAccessMode) {
                        Text("Starter pack  —  local free search")
                            .tag(AppSettings.ArchiveAccessMode.starterPack.rawValue)
                        Text("Official Lenny MCP")
                            .tag(AppSettings.ArchiveAccessMode.officialMCP.rawValue)
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()

                    Text("Starter pack searches the bundled free archive locally on device. Official MCP uses your own Lenny access through Claude Code or Codex.")
                        .settingsCaption()
                }

                // MCP Configuration
                SettingsSection(icon: "key.fill", title: "Official MCP") {
                    SecureField("Optional bearer token", text: $officialToken)
                        .textFieldStyle(.roundedBorder)

                    Text("Leave blank to use your CLI MCP configuration. Paste your bearer token here to let the app inject the official MCP server directly.")
                        .settingsCaption()

                    VStack(alignment: .leading, spacing: 8) {
                        SettingsCodeBlock(
                            label: "Claude Code",
                            code: "claude mcp add lennysdata --transport http https://mcp.lennysdata.com/mcp --header \"Authorization: Bearer <your-token>\""
                        )
                        SettingsCodeBlock(
                            label: "Codex  (two steps)",
                            code: "codex mcp add lennysdata --url https://mcp.lennysdata.com/mcp\ncodex mcp login lennysdata"
                        )
                    }

                    HStack(alignment: .center) {
                        Label(statusText, systemImage: statusIcon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        if !officialToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button("Clear token") { officialToken = "" }
                                .controlSize(.small)
                                .buttonStyle(.bordered)
                        }
                    }
                }

                // Debug Logging
                SettingsSection(icon: "ant.fill", title: "Debug Logging") {
                    Toggle("Print verbose session logs to the Xcode console", isOn: $debugLoggingEnabled)

                    Text("Logs backend selection, archive mode, MCP setup, CLI arguments, and parsed responses. Sensitive tokens are redacted in all output.")
                        .settingsCaption()
                }
            }
            .padding(16)
        }
        .frame(width: 560, alignment: .topLeading)
    }

    private var statusText: String {
        let trimmed = officialToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if archiveAccessMode == AppSettings.ArchiveAccessMode.starterPack.rawValue {
            return "Using bundled starter pack"
        }
        return trimmed.isEmpty ? "Official MCP via CLI config" : "Official MCP with bearer token"
    }

    private var statusIcon: String {
        archiveAccessMode == AppSettings.ArchiveAccessMode.starterPack.rawValue
            ? "internaldrive.fill" : "network"
    }
}

// MARK: - Reusable section card

private struct SettingsSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(title, systemImage: icon)
                .font(.headline)
                .padding(.bottom, 2)
        }
    }
}

// MARK: - Code block

private struct SettingsCodeBlock: View {
    let label: String
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(code)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(.separator.opacity(0.5), lineWidth: 0.75)
                )
        }
    }
}

// MARK: - Convenience modifier

private extension Text {
    func settingsCaption() -> some View {
        self
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
