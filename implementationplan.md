# Granola-Inspired Multi-Expert Transcript Plan

## Goal

Shift Lil-Lenny from a single-answer transcript with optional expert handoff into a conversation that visibly shows:

- work happening before the final answer is ready
- multiple perspectives as separate messages
- a clearer distinction between Lil-Lenny orchestration and specialist responses
- a more agentic feel earlier in the turn

## Current State

- The transcript is primarily a linear history of `user`, `assistant`, `error`, `toolUse`, and `toolResult` messages.
- The final answer is parsed as one `answer_markdown` string plus optional `suggested_experts`.
- Expert suggestions are rendered as a separate prompt after the answer, not as first-class messages from those experts.
- Live status currently appears in the composer area and not in the transcript itself.
- Streaming output is rendered into a single assistant bubble, usually under the Lil-Lenny title.

## Confirmed UX Direction

### 1. Transcript-first status

- Move generation/status feedback out of the input area and into the transcript/output region.
- Show a live status block under the Lil-Lenny header while work is happening.
- Keep the input area focused on generation state only:
  - label like `Generating...`
  - stop button on the far right

### 2. Group-chat style replies

- Responses should appear as multiple message blocks from different speakers.
- Every non-trivial answer should start with a Lil-Lenny orchestration message.
- Example opening:
  - `@Elena, I think you have some thoughts on this.`
  - `@Elena, @Varun, what are your thoughts?`
- After that, each expert appears in a separate message block with:
  - avatar
  - name
  - markdown response
- Each expert block should support a follow-up affordance directly beneath the message.

### 3. Transcript-native live status with expert presence

- Earlier expert presence should be rendered as part of the transcript-first live status area, not as a separate UI system.
- While the system is still searching or composing, surface likely expert involvement as soon as possible inside the live transcript status stream.
- Example:
  - `Searching LennyData for pricing advice`
  - `Elena Verna is joining the conversation`
  - show avatar before the final expert message is fully rendered
- These are temporary status hints only.
- Once the final answer is rendered, the provisional join/status rows should disappear.

### 4. Per-message actions

- Every expert message should include a CTA directly underneath it.
- That CTA should switch the avatar and continue in the specialist chat.
- Every response message should also have a copy affordance so users can copy the message directly.

## Technical Direction

## Phase 1: Transcript and Composer Restructure

- Add a transcript-native live activity row for the active turn.
- Replace current composer status text with a simpler generation state plus stop affordance.
- Keep status rendering separate from final assistant/expert messages.
- Make transcript-native status capable of showing:
  - generic generation/search steps
  - transport/tool progress
  - provisional expert-presence events with avatar and name
- Add per-message utility actions, starting with `Copy`.

### Likely code areas

- `LilAgents/Terminal/TerminalView+Setup.swift`
- `LilAgents/Terminal/TerminalView+Panels.swift`
- `LilAgents/Terminal/TerminalView+Transcript.swift`
- `LilAgents/Character/WalkerCharacterSessionWiring.swift`

## Phase 2: Richer Message Model

- Introduce a richer conversation message model that can represent:
  - Lil-Lenny orchestration/status
  - standard user messages
  - specialist/expert messages
  - live joining / routing events
  - follow-up affordances attached to a message
- Stop treating the final answer as only one assistant markdown blob.

### Needed model changes

- Extend `ClaudeSession.Message.Role` or replace it with a richer enum/struct.
- Add per-message speaker identity:
  - name
  - avatar
  - source type (`lenny`, `expert`, `system`, `status`)
- Add optional metadata for expert follow-up actions.

### Likely code areas

- `LilAgents/Session/ClaudeSessionModels.swift`
- `LilAgents/Session/ClaudeSessionState.swift`
- `LilAgents/Terminal/TerminalView+Transcript.swift`

## Phase 3: Structured Multi-Speaker Output

- Update the model prompt/response contract so the backend can return multiple speaker segments instead of only:
  - `answer_markdown`
  - `suggested_experts`
  - `suggest_expert_prompt`

### Candidate response shape

```json
{
  "messages": [
    {
      "speaker": "Lil-Lenny",
      "kind": "orchestrator",
      "markdown": "@Elena, I think you have some thoughts on this."
    },
    {
      "speaker": "Elena Verna",
      "kind": "expert",
      "markdown": "From my perspective..."
    }
  ],
  "follow_up_experts": ["Elena Verna"],
  "suggest_expert_prompt": true
}
```

### Notes

- This is the highest-leverage change if the product goal is “show the power of spinning up many agents.”
- Without a structured multi-message output contract, the UI will remain guessy and fragile.
- This structured response format should be used for both:
  - official MCP-backed runs
  - starter-pack/local runs

### Likely code areas

- `LilAgents/Session/ClaudeSessionState.swift`
- `LilAgents/Session/ClaudeSessionCLIParsing.swift`
- `LilAgents/Session/ClaudeSessionOpenAI.swift`
- `LilAgents/Session/ClaudeSessionExpertCatalog.swift`

## Phase 4: Expert Detection from Transport and Tooling

- Detect likely expert names during tool-use / MCP phases and surface provisional participant rows inside the transcript-native live status stream before final output.
- Candidate sources:
  - Claude Code CLI stream events
  - Codex CLI stream events
  - MCP result metadata
  - named references extracted from tool summaries
  - explicit structured hints emitted by the model during tool use

### Safer first version

- Treat these as provisional presence rows:
  - `Elena Verna is being consulted`
  - avatar shown
- Only upgrade to a real expert message when the final structured response includes that expert.
- Remove these provisional rows when the final message set is committed to the transcript.

### Risk

- Name extraction from raw tool/status text can create false positives.
- This should be implemented conservatively and preferably behind structured hints from the model.
- The safest implementation path is:
  - first parse names from reliable structured transport/tool events
  - only then consider regex/name extraction from freeform status strings as a fallback

## Phase 5: Message-Attached Follow-Up Actions

- Add follow-up UI directly beneath each expert message.
- Clicking should:
  - play a sound
  - switch avatar/focus
  - open or continue the expert-specific thread
- Add a `Copy` action to every assistant/expert response block.

### Likely code areas

- `LilAgents/Terminal/TerminalView+Transcript.swift`
- `LilAgents/Character/WalkerCharacterCore.swift`
- `LilAgents/Character/WalkerCharacterPopoverWindow.swift`

## Recommended Implementation Order

1. Move live generation state into transcript output and simplify the composer.
2. Introduce a richer message model with speaker metadata.
3. Change the response format to return multiple message segments.
4. Render each segment as an individual message with avatar and follow-up action.
5. Add provisional “joining” events during MCP/tool phases.

## Confirmed Decisions

1. Use `Lil-Lenny intro + specialist message` for single-specialist answers.
2. For multi-specialist answers, Lil-Lenny should explicitly call on them first, then each expert gets a separate message block even if short.
3. Provisional join/status rows are temporary background hints and should disappear once the final answer renders.
4. The follow-up CTA should appear under every expert message.
5. The new experience should work for both official MCP and starter-pack flows.
6. Every response message should include a copy action.
7. Provisional expert rows belong to the transcript-first status stream and should be sourced from Claude/Codex transport and MCP/tool events when possible.

## Remaining Product Choice

One decision is still open enough to defer until implementation:

- Whether Lil-Lenny response blocks should also get the follow-up CTA, or only the copy action.

My default assumption is:

- Lil-Lenny messages get `Copy`
- expert messages get `Copy` + specialist follow-up CTA
