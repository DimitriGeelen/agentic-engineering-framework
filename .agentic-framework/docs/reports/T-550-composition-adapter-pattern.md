# T-550: Composition-Based Adapter Pattern — Research Artifact

## Problem Statement

**For whom:** Framework portability (D4) across agent providers and terminal backends.
**Why now:** OpenClaw uses composition-with-optional-slots for 17+ channel integrations. Evaluate whether this pattern applies to: (1) agent provider abstraction, (2) TermLink backend types.
**Urgency:** Low. No multi-adapter problem exists today.

## Current Abstraction Surfaces

### Agent Provider (Claude Code is the only consumer)
- CLAUDE.md: 6 Claude Code-specific references
- FRAMEWORK.md: Provider-neutral guide exists (D4 compliance)
- `.claude/settings.json`: Hooks are Claude Code-specific (PreToolUse, PostToolUse, etc.)
- Hook scripts: `check-active-task.sh`, `budget-gate.sh`, `check-tier0.sh` — all read Claude Code JSON input format
- **Coupling depth:** Deep. Hooks parse Claude Code's tool_name/tool_input JSON. Settings use Claude Code's hook matcher syntax. Task tool, Agent tool, etc. are Claude Code-specific.

### TermLink Backends (tmux is the primary backend)
- TermLink is a Rust binary with backend abstraction built into its own codebase
- Framework wrapper (`agents/termlink/termlink.sh`) talks to `termlink` CLI — backend-agnostic
- The framework doesn't need to know which backend TermLink uses (tmux, screen, etc.)
- **Coupling depth:** Low. Framework calls `termlink spawn/interact/signal` — backend is TermLink's concern.

## Analysis

### Would the composition pattern help?

**For agent providers:** Theoretically, yes. Different agents (Claude Code, Cursor, Windsurf) would implement different optional slots:
- `onPreToolUse(tool_name, tool_input)` — gate hook
- `onPostToolUse(tool_name, result)` — monitoring hook
- `readContextBudget()` — token tracking
- `dispatchSubAgent(prompt)` — parallel work

But the implementation would require:
1. Abstracting Claude Code's JSON hook input format into a provider-neutral format
2. Creating provider-specific adapters that translate each agent's native format
3. Maintaining parallel hook configs for each provider
4. Testing with actual other agents (none currently available for testing)

**For TermLink backends:** No. TermLink already handles this internally. The framework doesn't need to know about backends.

### Evidence Against Building Now

1. **Zero demand:** No user has asked to run the framework with Cursor, Windsurf, or Copilot
2. **No reference implementations:** We'd be building an abstraction for imaginary consumers
3. **Deep coupling is structural:** The hook system relies on Claude Code's exact JSON format. Abstracting this isn't a trivial adapter — it's a rewrite of the entire hook pipeline
4. **D4 already partially addressed:** FRAMEWORK.md provides provider-neutral documentation. The actual enforcement hooks are inherently provider-specific.
5. **OpenClaw's pattern worked because they had 17 real channels.** We have 1 agent provider and 0 demand for a second.

## Assumption Testing

- A1: Composition pattern applies to agent providers (NOT VALIDATED — no second provider to test with)
- A2: TermLink backend abstraction needs framework-level adapter (INVALID — TermLink handles this internally)
- A3: Multi-adapter problem exists or is imminent (INVALID — zero demand, single provider)
- A4: OpenClaw's pattern is transferable (PARTIALLY VALID — pattern is sound, but our problem space doesn't justify it)

## Recommendation: DEFER

**Rationale:**
1. No multi-adapter problem exists — building an abstraction for one consumer is premature
2. TermLink backend abstraction is TermLink's responsibility, not the framework's
3. Deep coupling to Claude Code is structural — abstracting would require rewriting the hook pipeline
4. D4 is served by FRAMEWORK.md (documentation-level portability) without runtime abstraction
5. "When/if" scenario: revisit when a second agent provider is actively being targeted

**Revisit when:**
- A real user wants to run the framework with Cursor or Windsurf
- A second agent provider implements MCP server hooks (standard hook format)
- Agent tooling converges on a common hook API (unlikely near-term)

**If GO later:** Start with provider-neutral hook envelope (standard JSON format) → provider-specific adapters that translate native formats → test with one real alternative provider.
