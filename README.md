# lil agents

![lil agents](hero-thumbnail.png)

Tiny AI companions that live on your macOS dock.

**Bruce** and **Jazz** walk back and forth above your dock. Click one to open an AI terminal grounded in Lenny’s archive. They walk, they think, they vibe.

## features

- Animated characters rendered from transparent HEVC video
- Click a character to chat in a themed popover terminal
- Four visual themes: Peach, Midnight, Cloud, Moss
- Thinking bubbles with playful phrases while Claude works
- Sound effects on completion
- First-run onboarding with a friendly welcome
- Auto-updates via Sparkle

## requirements

- macOS Sonoma (14.0+)
- [Claude Code CLI](https://claude.ai/download) or [Codex CLI](https://developers.openai.com/codex/cli)

## building

Open `lil-agents.xcodeproj` in Xcode and hit run.

## privacy

lil agents runs on your Mac and does not send personal data anywhere except through the AI transport you configure.

- **Your data stays local by default.** The app plays bundled animations and calculates your dock size to position the characters. No user account, analytics, or separate app database is involved.
- **AI transport.** Conversations run through one of these paths, in order: Claude Code CLI, Codex CLI, or the direct OpenAI Responses API fallback. Any data sent to Anthropic or OpenAI is governed by their terms and privacy policy.
- **Archive access.** The app connects the selected transport to Lenny’s MCP server. A bundled free archive token is used by default, and paid Lenny members can override it in Settings or with `LENNYSDATA_MCP_AUTH_TOKEN`.
- **No accounts.** No login, no user database, no analytics in the app.
- **Updates.** lil agents uses Sparkle to check for updates, which sends your app version and macOS version. Nothing else.

## license

MIT License. See [LICENSE](LICENSE) for details.
