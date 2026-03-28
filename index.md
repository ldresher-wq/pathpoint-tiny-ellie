# lil-agents Code Index

This document is a fast map of the current codebase: what the app does, where the main logic lives, and how the files relate to each other.

## What This App Is

`lil-agents` is a macOS accessory app that places a character above the Dock and turns that character into a conversational entry point.

Current behavior:
- The main character is Lenny.
- User questions can run through Claude Code CLI, Codex CLI, or a direct OpenAI Responses API fallback.
- Archive access has two modes:
  - `starterPack`: bundled local free archive search under `LilAgents/StarterArchive`
  - `officialMCP`: the official Lenny MCP path, using the user's own CLI setup or bearer token
- The app can surface relevant experts after a response completes.
- Expert switching is no longer automatic.
- Suggested experts now appear in a dedicated visible suggestion bar with buttons.
- Clicking a suggested expert button opens that expert's own dialog above that avatar.
- The app maintains separate follow-up threads for Lenny and each guest.

## Top-Level Structure

### App shell
- `LilAgents/LilAgentsApp.swift`
  App entry point, menu bar setup, app delegate, expert status items, theme/display controls, and the Settings window host.

- `LilAgents/LilAgentsController.swift`
  Coordinates all on-screen characters, display-link ticking, Dock geometry, expert focus, and companion guest avatars.

- `LilAgents/AppSettings.swift`
  Persistent app settings for archive mode, official MCP token override, and debug logging.

- `LilAgents/SettingsView.swift`
  Settings UI for archive mode selection, official MCP token entry, debug logging, and setup instructions.

### Main character system
- `LilAgents/WalkerCharacter.swift`
  Thin shell for the character object.

- `LilAgents/WalkerCharacterTypes.swift`
  Shared enums/constants for `WalkerCharacter`.

- `LilAgents/WalkerCharacterCore.swift`
  Character setup, asset loading, persona switching, click handling, companion avatar configuration.

- `LilAgents/WalkerCharacterPopover.swift`
  Popover creation, session wiring, input placeholder updates, popover opening/closing, live dialog behavior.

- `LilAgents/WalkerCharacterVisuals.swift`
  Handoff effects, smoke/genie visuals, thinking/completion bubbles, sound playback.

- `LilAgents/WalkerCharacterMovement.swift`
  Walking state, pause timing, movement interpolation, per-frame position updates.

### Session / AI / MCP
- `LilAgents/ClaudeSession.swift`
  Thin orchestration shell for a single conversation session, including staged expert suggestions.

- `LilAgents/ClaudeSessionModels.swift`
  Data models such as `ResponderExpert`, attachments, and message structures.

- `LilAgents/ClaudeSessionState.swift`
  Per-thread conversation state and history helpers.

- `LilAgents/ClaudeSessionTransport.swift`
  Backend resolution, local starter-pack search, Claude/Codex/OpenAI transport handling, official MCP configuration, structured JSON answer parsing, logging, and error handling.

- `LilAgents/ClaudeSessionExpertResolution.swift`
  Local/MCP expert extraction, scoring, avatar resolution, assistant-text fallback parsing, and guest context building.

- `LilAgents/LocalArchive.swift`
  Local starter-pack indexing and retrieval over the bundled free newsletter and podcast subset.

- `LilAgents/SessionDebugLogger.swift`
  Structured debug logging for backend selection, archive mode, requests, subprocess output, and responses.

### Popover / terminal UI
- `LilAgents/TerminalView.swift`
  Thin shell for the chat UI view, including deferred expert suggestions and the visible expert button bar.

- `LilAgents/TerminalView+Setup.swift`
  View creation, layout, controls, status bar, expert suggestion button bar, input field, attachment label, drag/drop registration.

- `LilAgents/TerminalView+Transcript.swift`
  Transcript appending, replay, user/assistant/status/error lines, and transcript sizing/scroll behavior.

- `LilAgents/TerminalView+Attachments.swift`
  Drag-and-drop attachment extraction and attachment label refresh.

- `LilAgents/TerminalMarkdownRenderer.swift`
  Markdown and inline markdown rendering for transcript output.

- `LilAgents/PaddedTextFieldCell.swift`
  Custom text field cell used by the composer input.

### Theme / support
- `LilAgents/PopoverTheme.swift`
  Theme definitions, colors, typography, and character-color adjustments.

- `LilAgents/CharacterContentView.swift`
  Transparent clickable character host view with alpha-aware hit testing.

## Asset Structure

### Bundled runtime assets
- `LilAgents/CharacterSprites/`
  Lenny directional PNG sprites.

- `LilAgents/ExpertAvatars/`
  Guest avatar PNGs bundled into the app.

- `LilAgents/StarterArchive/`
  Local free archive bundle used for starter-pack search.

- `LilAgents/Sounds/`
  Sound effects.

- `LilAgents/Assets.xcassets/`
  Standard app asset catalog resources.

### Legacy assets still present
- `LilAgents/walk-bruce-01.mov`
- `LilAgents/walk-jazz-01.mov`

These are old assets from the original app and are no longer the main runtime character path.

## Runtime Flow

## 1. App launch
1. `LilAgentsApp.swift` creates the app delegate and menu bar UI.
2. `LilAgentsController.start()` creates the main Lenny character.
3. The controller starts a display link and updates character positions every frame.

## 2. User asks a question
1. The user clicks Lenny.
2. `WalkerCharacterPopover` opens the popover above the character.
3. `ClaudeSession` resolves the current archive mode and the best available backend.
4. In `starterPack` mode, `LocalArchive` retrieves bundled local context.
5. In `officialMCP` mode, the app prefers Claude Code CLI, then Codex CLI, then direct OpenAI Responses API fallback.
6. Official mode can use:
   - the user's existing Claude/Codex MCP configuration
   - or a bearer token entered in Settings
7. The response path emits:
   - live status updates
   - transcript content
   - optional staged expert suggestions
   - structured answer parsing when the model returns the JSON response envelope
   - verbose debug logs when enabled

## 3. Expert suggestions appear
1. `ClaudeSessionExpertResolution` identifies relevant experts from local search, MCP-derived data, or assistant text fallback.
2. `LilAgentsController` creates or updates companion avatars as needed.
3. The app does not auto-switch to another expert.
4. After the response completes, the popover shows a dedicated expert suggestion bar with visible buttons.
5. Clicking one of those buttons opens that expert's own dialog above that avatar.

## 4. Follow-up mode
- Each guest has their own conversation history.
- Lenny has a separate thread.
- Switching avatars restores the correct thread and context.
- Expert suggestions are staged until the end of the turn so the current speaker does not change mid-response.

## Navigation Guide

### If you want to change AI behavior
Start with:
- `LilAgents/ClaudeSessionTransport.swift`
- `LilAgents/ClaudeSessionExpertResolution.swift`
- `LilAgents/ClaudeSessionModels.swift`
- `LilAgents/LocalArchive.swift`

### If you want to change which guests appear
Start with:
- `LilAgents/ClaudeSessionExpertResolution.swift`
- `LilAgents/LilAgentsController.swift`
- `LilAgents/WalkerCharacterPopover.swift`

### If you want to change character behavior or animations
Start with:
- `LilAgents/WalkerCharacterCore.swift`
- `LilAgents/WalkerCharacterVisuals.swift`
- `LilAgents/WalkerCharacterMovement.swift`

### If you want to change the chat popup
Start with:
- `LilAgents/TerminalView+Setup.swift`
- `LilAgents/TerminalView+Transcript.swift`
- `LilAgents/TerminalMarkdownRenderer.swift`
- `LilAgents/WalkerCharacterPopover.swift`

### If you want to change menu bar behavior
Start with:
- `LilAgents/LilAgentsApp.swift`

### If you want to change settings or archive-source behavior
Start with:
- `LilAgents/AppSettings.swift`
- `LilAgents/SettingsView.swift`
- `LilAgents/ClaudeSessionTransport.swift`
- `LilAgents/LocalArchive.swift`

### If you want to inspect verbose runtime logs
Start with:
- `LilAgents/SessionDebugLogger.swift`
- `LilAgents/ClaudeSessionTransport.swift`

## Current Larger Files

After the refactor, most responsibilities are split, but a few helper files are still on the larger side:
- `LilAgents/ClaudeSessionExpertResolution.swift`
- `LilAgents/ClaudeSessionTransport.swift`
- `LilAgents/WalkerCharacterVisuals.swift`
- `LilAgents/WalkerCharacterPopover.swift`

These are the next best candidates if you want to continue breaking the codebase into smaller units.

## Notes

- The Xcode project is explicit-file based, so new Swift files usually need to be added to `lil-agents.xcodeproj/project.pbxproj`.
- The app currently depends on bundled avatar resources under `LilAgents/CharacterSprites` and `LilAgents/ExpertAvatars`.
- The starter-pack experience depends on bundled content under `LilAgents/StarterArchive`.
- Official Lenny archive access depends on the user's own MCP setup or token, depending on the selected mode.
- Debug logging is intentionally verbose and is meant for Xcode console inspection while developing.
- There is also a helper script folder:
  - `Scripts/convert_avatars_to_png.swift`

## Suggested Reading Order

If you are new to the codebase, read in this order:
1. `LilAgents/LilAgentsApp.swift`
2. `LilAgents/LilAgentsController.swift`
3. `LilAgents/AppSettings.swift`
4. `LilAgents/SettingsView.swift`
5. `LilAgents/WalkerCharacter.swift`
6. `LilAgents/WalkerCharacterPopover.swift`
7. `LilAgents/ClaudeSession.swift`
8. `LilAgents/ClaudeSessionTransport.swift`
9. `LilAgents/LocalArchive.swift`
10. `LilAgents/ClaudeSessionExpertResolution.swift`
11. `LilAgents/SessionDebugLogger.swift`
12. `LilAgents/TerminalView.swift`
13. `LilAgents/TerminalView+Setup.swift`
