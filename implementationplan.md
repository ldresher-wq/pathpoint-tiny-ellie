# Codex-Owned MCP Implementation Plan

## Goal

Make Lil-Lenny support Codex-owned MCP calls reliably, so Codex itself can call `lennysdata` during an in-app conversation.

This plan is specifically about runtime transport for Codex. It should not break:

- MCP token save/install logic
- `~/.codex/config.toml` writing
- Claude Code config writing
- Claude Code runtime path
- starter-pack/local archive behavior

## Problem Summary

Current behavior confirms:

- MCP configuration and bearer token wiring are working
- standalone interactive `codex` can use `lennysdata`
- `codex exec` inside Lil-Lenny starts MCP tool calls, then cancels them with:
  - `user cancelled MCP tool call`

This matches upstream issue `openai/codex#16685`: `codex exec` is not a reliable transport for MCP tool execution.

## Non-Goals

This work should not:

- redesign the Claude Code path
- remove existing MCP installer/config behavior
- replace Codex with app-owned archive fetch as the default for the official Codex path
- change how standalone Codex or Claude are configured outside Lil-Lenny

## Architecture Decision

### Keep configuration shared

Preserve current install/config behavior:

- save token in Lil-Lenny settings
- write Codex MCP config when Codex is detected
- write Claude Code MCP config when Claude is detected

This remains useful for:

- direct CLI usage
- external debugging
- future backend paths

### Split runtime transport by backend

Use different runtime strategies:

- Claude Code:
  - keep current path
- Codex:
  - replace one-shot `codex exec` runtime with a true interactive Codex session over a PTY

The bug is specific to Codex exec-mode MCP behavior, so runtime should diverge there.

## Recommended Runtime Strategy

### Codex path

Run plain interactive `codex`, not `codex exec`, inside a PTY.

Why:

- interactive Codex already proves MCP can work
- approvals can be surfaced and answered in-app
- avoids the `exec`-mode cancellation bug

### Claude path

Do not change it in this project.

Why:

- current issue is not about Claude
- touching Claude increases regression risk for no benefit

## Implementation Phases

## Phase 1: Isolate Codex Runtime Strategy

Create a Codex-specific runtime path that is separate from the existing `exec` implementation.

### Requirements

- keep `callClaudeCodeCLI(...)` unchanged
- preserve `callCodexCLI(...)` as a fallback until the new path is ready
- add a new Codex interactive entry point, for example:
  - `callCodexInteractive(...)`

### Expected code areas

- `LilAgents/Session/ClaudeSessionCLI.swift`
- `LilAgents/Session/ClaudeSessionTransport.swift`

## Phase 2: Add PTY-Backed Process Support

The current `runProcess(...)` is pipe-based and optimized for one-shot CLI runs.
Interactive Codex needs a real TTY.

### Requirements

- add PTY process launching support
- keep existing pipe-based process support for Claude/other paths
- capture stdout/stderr-like output from the PTY stream
- allow writing user input back into the running session
- preserve cancellation and termination handling

### Important constraint

This should be implemented as a separate code path, not by overloading the current simple `Pipe` model until it becomes hard to reason about.

### Expected code areas

- `LilAgents/Session/ClaudeSessionSupport.swift`
- possibly a new helper such as:
  - `LilAgents/Session/CodexPTYSession.swift`

## Phase 3: Define Interactive Codex Session Contract

We need a stable way to use interactive Codex inside Lil-Lenny.

### Session lifecycle

- start a fresh Codex interactive session for a turn
- send the user prompt
- let Codex run MCP/tools
- collect the assistant response
- terminate the session after the response is complete

### Why not persistent first

Persistent multi-turn sessions are attractive but add complexity immediately:

- prompt/input framing
- session recovery
- history drift
- stuck state handling

Start with per-turn interactive sessions. If stable, consider persistence later.

## Phase 4: In-App Approval Handling

Lil-Lenny already has approval UI primitives. They should be wired to the real interactive Codex transport.

### Requirements

- detect approval prompt text in the PTY stream
- render the minimized approval card already built in the UI
- support these actions:
  - `Allow`
  - `Allow for this session`
  - `Always allow`
  - `Cancel`
- send the selected choice back to the PTY session

### Success condition

The user should be able to approve `lennysdata.search_content` from Lil-Lenny without switching to terminal.

### Expected code areas

- `LilAgents/Session/ClaudeSessionSupport.swift`
- `LilAgents/Character/WalkerCharacterSessionWiring.swift`
- `LilAgents/Terminal/TerminalView+TranscriptBehavior.swift`
- `LilAgents/Terminal/TerminalView+TranscriptAccessoryViews.swift`

## Phase 5: Interactive Output Parsing

`codex exec --json` gave structured events. Interactive Codex may not.

We need a robust extraction strategy for:

- progress/status text
- approval prompts
- final assistant response

### First version

- treat transport/status text as provisional live status only
- extract the final assistant block conservatively
- keep the current structured JSON response contract in the prompt
- parse the final JSON object from the terminal stream if present

### Fallback

If structured JSON parsing fails:

- show a clear runtime error
- do not silently invent an answer

## Phase 6: Route Only Official Codex MCP Through Interactive Path

The new path should be narrowly scoped.

### Use interactive Codex only when all are true

- backend is Codex
- archive mode is official MCP
- a valid official token is available

### Keep existing behavior for everything else

- starter pack + Codex: current path
- official + Claude Code: current path
- OpenAI fallback: current path

This keeps the blast radius small.

## Phase 7: Logging and Diagnostics

This work will be hard to stabilize without strong logs.

### Add explicit debug logs for

- interactive Codex session start
- PTY launch command
- prompt sent
- approval prompt detected
- approval choice submitted
- final response detected
- termination reason
- timeout/stuck session recovery

### Why

We need to distinguish:

- Codex session launched but never responded
- approval prompt appeared but UI did not render
- approval response was sent but ignored
- response arrived but parser missed it

## Phase 8: Safety and Recovery

Interactive sessions can wedge. Add explicit safeguards.

### Requirements

- timeout for no-output period
- timeout for approval prompt waiting
- explicit cancel/stop behavior
- hard kill fallback if Codex ignores termination
- clear error messaging in transcript

## Acceptance Criteria

This project is successful when all of these are true:

1. In official archive mode with Codex, Lil-Lenny no longer uses `codex exec`.
2. Codex itself initiates `lennysdata` MCP tool calls from inside Lil-Lenny.
3. If approval is required, the minimized approval card appears in Lil-Lenny.
4. Choosing `Allow` or `Always allow` continues the same turn successfully.
5. Claude Code behavior is unchanged.
6. Token/config installation behavior is unchanged for Codex and Claude.
7. Starter-pack behavior is unchanged.

## Risks

- interactive stream format may change across Codex versions
- approval prompt wording may change
- PTY integration is more complex than one-shot `exec`
- structured JSON final output may be less reliable in interactive mode than in `exec --json`

## Mitigations

- keep the implementation Codex-only
- keep the old `exec` path behind a temporary fallback while stabilizing
- add strong logging
- use conservative parsing for final output

## Effort Estimate

### Prototype

- 1 to 2 days

Includes:

- PTY session launch
- prompt injection
- approval card wiring
- basic response extraction

### Production-ready

- 3 to 5 days

Includes:

- recovery behavior
- better parsing
- cancellation correctness
- transcript stability
- regression testing

## Implementation Order

1. Add a dedicated PTY-backed Codex session helper.
2. Add a new interactive Codex runtime method.
3. Route only official Codex MCP turns to that method.
4. Wire approval prompts to the existing minimized approval card.
5. Add final-response extraction and strict failure handling.
6. Add logging and timeout recovery.
7. Test against real `lennysdata` MCP flows.

## Recommendation

Proceed with the interactive Codex PTY path only for official Codex MCP turns.

Do not:

- change Claude Code runtime
- remove existing MCP installer/config logic
- rely on `codex exec` for MCP in Lil-Lenny going forward
