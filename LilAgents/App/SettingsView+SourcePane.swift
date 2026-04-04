import AppKit
import SwiftUI

extension SettingsView {
    var sourcePane: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsHeader(
                title: "Lenny source",
                subtitle: "Choose whether Lil-Lenny answers from the bundled Starter Pack or the full LennyData archive."
            )

            SettingsSectionCard(title: "Answer source", subtitle: "Starter Pack is local and fast. Full LennyData uses the official archive when available.") {
                VStack(spacing: 0) {
                    sourceRow(
                        mode: .starterPack,
                        title: "Starter Pack",
                        subtitle: "Bundled on this Mac",
                        detail: "Fast, local, and ready immediately for quick questions and demos.",
                        isLast: false
                    )

                    sourceRow(
                        mode: .officialMCP,
                        title: "Full LennyData",
                        subtitle: "Official archive access",
                        detail: "Broader and deeper answers from the full LennyData archive.",
                        isLast: archiveAccessMode != AppSettings.ArchiveAccessMode.officialMCP.rawValue
                    )
                }

                if archiveAccessMode == AppSettings.ArchiveAccessMode.officialMCP.rawValue {
                    Divider()
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 14) {
                        if AppSettings.officialLennyMCPToken != nil {
                            SettingsInfoRow(
                                icon: "checkmark.circle.fill",
                                iconColor: .accentColor,
                                text: "Your auth key is saved on this Mac. Lil-Lenny will use it automatically when you send a message."
                            )
                        } else {
                            HStack(alignment: .center, spacing: 12) {
                                SecureField("Paste auth key", text: $officialToken)
                                    .textFieldStyle(.roundedBorder)

                                Button("Open lennysdata.com") {
                                    NSWorkspace.shared.open(officialArchiveURL)
                                }
                                .buttonStyle(.bordered)
                            }

                            Text("Lil-Lenny stores this auth key locally on this Mac and passes it directly to Claude Code or Codex when you send a message. Nothing is written to your CLI config files.")
                                .settingsCaption()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    func sourceRow(
        mode: AppSettings.ArchiveAccessMode,
        title: String,
        subtitle: String,
        detail: String,
        isLast: Bool
    ) -> some View {
        let selected = archiveAccessMode == mode.rawValue

        Button {
            archiveAccessMode = mode.rawValue
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if selected {
                            SettingsStatusPill(title: "Selected", systemImage: "checkmark.circle.fill", tone: .accent)
                        }
                    }

                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(detail)
                        .settingsCaption()
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.accentColor.opacity(0.06) : Color.clear)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Divider()
                        .padding(.leading, 46)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
