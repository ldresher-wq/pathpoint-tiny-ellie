import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.archiveAccessModeKey) private var archiveAccessMode = AppSettings.ArchiveAccessMode.starterPack.rawValue
    @AppStorage(AppSettings.officialLennyMCPTokenKey) private var officialToken = ""
    @AppStorage(AppSettings.debugLoggingEnabledKey) private var debugLoggingEnabled = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Archive Source")
                        .font(.headline)

                    Picker("Source", selection: $archiveAccessMode) {
                        Text("Starter pack (local free search)").tag(AppSettings.ArchiveAccessMode.starterPack.rawValue)
                        Text("Official Lenny MCP").tag(AppSettings.ArchiveAccessMode.officialMCP.rawValue)
                    }
                    .pickerStyle(.radioGroup)

                    Text("Starter pack searches the bundled free archive locally. Official MCP uses your own Lenny access through Claude Code or Codex.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Official MCP")
                        .font(.headline)

                    SecureField("Optional official Lenny MCP bearer token", text: $officialToken)
                        .textFieldStyle(.roundedBorder)

                    Text("If this field is blank, the app expects you to configure Lenny MCP directly in your Claude Code or Codex client. If you paste your own bearer token here, the app can inject the official MCP server directly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Claude Code")
                            .font(.caption.weight(.semibold))
                        Text("`claude mcp add lennysdata --transport http https://mcp.lennysdata.com/mcp --header \"Authorization: Bearer <your-token>\"`")
                            .font(.caption.monospaced())

                        Text("Codex")
                            .font(.caption.weight(.semibold))
                        Text("`codex mcp add lennysdata --url https://mcp.lennysdata.com/mcp`")
                            .font(.caption.monospaced())
                        Text("`codex mcp login lennysdata`")
                            .font(.caption.monospaced())
                    }

                    HStack {
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if !officialToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button("Clear") {
                                officialToken = ""
                            }
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Debug Logging")
                        .font(.headline)

                    Toggle("Print verbose session logs to the Xcode console", isOn: $debugLoggingEnabled)

                    Text("When enabled, the app logs backend selection, archive mode, local search hits, MCP setup, CLI arguments, prompt bodies, raw subprocess output, and parsed responses. Sensitive tokens are redacted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 560, alignment: .topLeading)
    }

    private var statusText: String {
        let trimmed = officialToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if archiveAccessMode == AppSettings.ArchiveAccessMode.starterPack.rawValue {
            return "Currently using the bundled free starter pack."
        }
        return trimmed.isEmpty
            ? "Official MCP mode enabled. The app will use your CLI MCP configuration."
            : "Official MCP mode enabled with your custom bearer token."
    }
}
