# Implementation Log — 2026-03-28

This log summarizes the implementation work completed today around archive access, backend routing, logging, settings, and expert handoff behavior.

## Scope

Main goals covered:
- move free users to a local bundled archive path instead of requiring MCP
- support official Lenny MCP as an optional user-configured path
- prefer Claude Code CLI or Codex CLI before direct OpenAI API fallback
- expose archive and token settings in-app
- add verbose session logging for transport debugging
- remove automatic expert/avatar switching during active responses
- replace auto-switching with post-response clickable expert suggestions
- move expert suggestions into a dedicated visible button bar after transcript-based rendering proved too fragile
- redesign the popover around a single default visual system with a larger transcript and simpler UI

## Architecture Changes

### 1. Archive source split

The app now has two archive-access modes:
- `starterPack`
  Uses bundled local content in `LilAgents/StarterArchive`
- `officialMCP`
  Uses the official Lenny MCP path through Claude Code CLI, Codex CLI, or direct OpenAI API fallback

The free/starter experience no longer depends on a remote MCP token.

### 2. Backend resolution order

The session transport now resolves backends in this order:
1. Claude Code CLI
2. Codex CLI
3. Direct OpenAI Responses API fallback

This logic now lives in the session transport rather than assuming a single remote API path.

### 3. Settings and persistence

Added persistent app settings for:
- archive access mode
- optional official Lenny bearer token override
- debug logging toggle

The Settings UI was also reworked after the previous window implementation opened a blank window.

## File-Level Changes

### `LilAgents/AppSettings.swift`

Added persisted settings for:
- `archiveAccessMode`
- `officialLennyMCPToken`
- `debugLoggingEnabled`

### `LilAgents/LocalArchive.swift`

Added local starter-pack retrieval behavior over bundled newsletter and podcast content.

### `LilAgents/SessionDebugLogger.swift`

Added a structured logger that prints:
- backend selection
- archive mode
- token-source resolution
- local archive search queries
- CLI invocation details
- stdout/stderr snippets
- OpenAI payload/response summaries
- assistant output completion events

Sensitive token values are redacted before logging.

### `LilAgents/SettingsView.swift`

Reworked the settings window content and added:
- archive source picker
- official MCP bearer token field
- debug logging toggle
- Claude/Codex setup instructions for official MCP mode

### `LilAgents/LilAgentsApp.swift`

Updated settings-window hosting so the menu-bar `Settings…` action opens a real rendered SwiftUI view through `NSHostingController`.

### `LilAgents/ClaudeSession.swift`

Added staged expert handling through:
- `pendingExperts`

### `LilAgents/ClaudeSessionState.swift`

Turn failure now clears any staged experts so stale suggestions are not published after an error.

### `LilAgents/ClaudeSessionTransport.swift`

This file had the largest transport changes:
- backend selection and environment probing
- starter-pack local search path
- official MCP path for Claude/Codex/OpenAI
- structured JSON answer contract for CLI responses
- verbose session logging
- delayed expert publishing until response completion
- assistant-text expert fallback parsing
- safer CLI working directory selection

Later follow-up fixes also addressed:
- duplicate token-source logging in the same turn
- `cwd=/` subprocess launches
- expert parsing via model-returned JSON instead of only freeform text heuristics

### `LilAgents/ClaudeSessionExpertResolution.swift`

Updated expert handling to support:
- extracting expert candidates from assistant freeform text
- restricting suggestions to names that resolve to bundled avatar assets

The current behavior is intentionally stricter: if there is no matching bundled avatar, the app does not surface that expert in the suggestion UI.

### `LilAgents/TerminalView.swift`

Added support for:
- expert-selection callbacks
- deferred expert suggestion state
- a dedicated visible expert suggestion bar

### `LilAgents/TerminalView+Setup.swift`

Added:
- transcript-link handling through `NSTextViewDelegate`
- visible expert suggestion container UI
- clickable expert suggestion buttons

Later in the day this was redesigned into:
- a larger transcript-first layout
- a simpler composer panel
- a compact stacked expert-suggestion panel instead of fragile chip-style pills

### `LilAgents/TerminalView+Transcript.swift`

Updated transcript rendering and scroll sizing behavior.

The original inline transcript suggestion rendering remains in code, but the primary user-facing suggestion UI is now the dedicated button bar because the transcript path was visually unreliable.

### `LilAgents/WalkerCharacterPopover.swift`

Changed session wiring so:
- experts are staged during the answer
- the app does not auto-focus a new expert mid-turn
- visible expert suggestion buttons appear only after the answer finishes
- selecting a suggestion explicitly opens that expert

Later UI work also changed:
- larger popover sizing
- simplified onboarding and header copy
- reduced decorative chrome in favor of a more native macOS utility-window feel

### `LilAgents/PopoverTheme.swift`

The visual system was simplified to a single default theme:
- old multi-theme experimentation remains in code for now, but only one theme is active
- the default palette moved away from the earlier orange treatment toward a cleaner slate/blue system

## Behavior Changes

### Previous behavior

The older flow effectively assumed:
- one main remote OpenAI transport
- MCP as the primary archive source
- expert extraction leading to immediate UI changes

### Current behavior

The current flow is:
1. user asks a question
2. session resolves archive mode
3. session resolves best backend
4. local starter pack or official MCP path is used
5. response streams back through the chosen transport
6. expert suggestions are staged, not auto-opened
7. the model returns structured answer data when possible
8. the popover shows visible expert suggestion buttons after the response completes

## Runtime Observations From Log Review

Earlier log review exposed several issues:
- official MCP token from Settings was working
- Claude was being selected correctly
- one run showed Claude-side permission-denial noise around MCP file access
- duplicate token-source logging was present
- Claude subprocesses were launching with `cwd=/`
- expert handoff was too eager and confusing

Later follow-up work addressed:
- auto-switch removal
- structured JSON output for expert suggestion parsing
- assistant-text expert inference
- stricter avatar-backed suggestion filtering
- safer subprocess working directory
- more diagnostic logging
- transcript visibility issues by moving suggestions into a dedicated panel and then refining that panel into a stacked list after chip rendering clipped in AppKit

One important interpretation note from the logs:
- at least one `log.md` the user shared was clearly produced by an older binary because it still showed stale behaviors after the fixes had already been made

## Verification

The project was rebuilt successfully after the transport and expert-flow changes with:

```sh
xcodebuild -project lil-agents.xcodeproj -scheme LilAgents -sdk macosx -configuration Debug build
```

## Known Remaining Risks

- Official MCP behavior still ultimately depends on the user's local Claude/Codex environment and runtime permissions.
- If the app is not fully restarted after a rebuild, logs can reflect stale binaries and make debugging misleading.
- Starter-pack retrieval quality is intentionally narrower than the full archive and may produce weaker answers for people or topics not included in the bundled subset.
- The codebase still contains both transcript-link suggestion plumbing and the newer button-bar suggestion UI; if the suggestion system is simplified later, that duplication is a good cleanup target.
- The active popover design is materially cleaner than the old one, but visual tuning still depends on live screenshot review because AppKit spacing and text rendering are sensitive to runtime metrics.

## Documentation Update

`index.md` was updated today to reflect:
- starter-pack local archive mode
- official MCP mode
- Claude/Codex/OpenAI transport routing
- settings and debug logging
- post-response expert suggestion flow instead of automatic handoff
- the final visible expert-button bar UI
- the later single-theme popover redesign with a larger transcript and simplified suggestion panel
