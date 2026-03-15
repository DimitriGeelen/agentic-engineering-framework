# Claude Code Settings for the Agentic Engineering Framework

This document describes all Claude Code settings required for the framework to function correctly.

**Last updated:** 2026-03-15 (T-435 inception, post-T-498 vendored model)

## Settings File Locations

| File | Scope | Shared? | Purpose |
|------|-------|---------|---------|
| `managed-settings.json` | System (server-deployed) | Org-wide | Enterprise/Teams overrides |
| `.claude/settings.local.json` | Local (gitignored) | No | Personal overrides |
| `.claude/settings.json` | Project (committed) | Yes | Hooks, enforcement gates |
| `~/.claude/settings.json` | Global (all projects) | No | Permissions, plugins, update channel |
| `~/.claude.json` | Internal state | No | Managed by Claude Code (OAuth, preferences) |

**Precedence:** Managed > Local > Project > Global. Arrays merge across scopes.

---

## Required Global Settings (`~/.claude/settings.json`)

```json
{
  "permissions": {
    "allow": [
      "Bash(*)",
      "Read(*)",
      "Glob(*)",
      "Grep(*)",
      "Write(*)",
      "Edit(*)",
      "WebFetch(*)",
      "WebSearch(*)",
      "AskUserQuestion(*)",
      "Task(*)"
    ],
    "defaultMode": "dontAsk"
  },
  "autoUpdatesChannel": "stable"
}
```

### Permission Mode: `dontAsk`

The framework uses `dontAsk` mode with explicit allow rules. This means:
- Tools NOT in the allow list are **auto-denied** (no prompt)
- Tools IN the allow list execute **without asking**
- This is essential because the framework's PreToolUse hooks act as the permission layer instead

**Why not `normal` mode?** The framework's hook-based enforcement (task gate, tier 0 guard, budget gate) replaces Claude Code's built-in permission prompts. Using `normal` mode would double-prompt the user — once from hooks, once from Claude Code.

**Why not bypassing permissions?** That skips ALL checks including hooks. The framework needs hooks to run.

### Broad Tool Permissions

All core tools are allowed with `(*)` wildcards because:
- `Write(*)` / `Edit(*)` — Framework hooks (`check-active-task.sh`) gate writes, not Claude Code permissions
- `Bash(*)` — Framework hooks (`check-tier0.sh`, `budget-gate.sh`) gate dangerous commands
- `Task(*)` — Sub-agent dispatch is hook-monitored (`check-dispatch.sh`)

**Risk:** If hooks are misconfigured, there are no backup permissions. Run `fw doctor` to verify hooks are wired.

### Plugins (Optional)

Plugins are user-specific and not part of core framework config. Useful ones:
- `context7` — Up-to-date library documentation
- `playwright` — Browser automation for Watchtower UI testing
- `code-review` — PR review capabilities

**Disabled by default:**
- `superpowers` — Conflicts with framework instruction precedence (claims "supercedes any other instructions")
- `feature-dev` — Conflicts with framework task-driven workflow

---

## Required Global Preferences (`~/.claude.json`)

These settings in the internal config file are critical:

```
autoCompactEnabled: false
verbose: true
autoUpdates: false
```

### `autoCompactEnabled: false` (CRITICAL)

**Why:** Auto-compaction destroys working memory mid-session. The framework uses structured handovers (D-027) instead:
1. `PreCompact` hook auto-generates a handover before compaction
2. `SessionStart:compact` hook re-injects context into the fresh session
3. Manual `/compact` is available when the human decides

**Risk if enabled:** The agent loses task context, focus state, and conversation history at unpredictable moments.

### `verbose: true`

Shows detailed output from Claude Code internals. Helps debug hook failures and permission issues.

### `autoUpdates: false`

Prevents mid-session updates that could change behavior. Updates are applied manually between sessions.

---

## Project Hooks (`.claude/settings.json`)

The framework's enforcement system runs through Claude Code hooks. This is the most critical configuration. All hooks use portable paths (`.agentic-framework/bin/fw hook <name>`) — no hardcoded absolute paths (T-496/T-498).

### All Available Hook Events (Claude Code 2026)

| Event | Can Block? | Matcher? | Framework Uses |
|-------|-----------|----------|----------------|
| `SessionStart` | No | Yes | post-compact-resume (compact, resume) |
| `InstructionsLoaded` | No | No | — |
| `UserPromptSubmit` | Yes | No | — (see Rec #4) |
| `PreToolUse` | Yes | Yes | task gate, tier0, budget, plan blocker |
| `PermissionRequest` | Yes | No | — |
| `PostToolUse` | No (async) | Yes | checkpoint, error-watchdog, dispatch, fabric |
| `PostToolUseFailure` | No (async) | No | — |
| `Notification` | No | No | — |
| `SubagentStart` | No | No | — |
| `SubagentStop` | Yes | No | — |
| `Stop` | Yes | No | — (see Rec #3) |
| `TeammateIdle` | Yes | No | — |
| `TaskCompleted` | Yes | No | — |
| `ConfigChange` | Yes | No | — |
| `WorktreeCreate` | Yes | No | — |
| `WorktreeRemove` | No | No | — |
| `PreCompact` | No | Yes | pre-compact (auto-handover) |
| `PostCompact` | ? | ? | — (new, undocumented) |
| `Elicitation` | Yes | No | — |

### Current Framework Hooks (11 total)

**PreToolUse (4 hooks — Gates that can block):**

| Matcher | Hook Name | Purpose | Exit 2 = Block |
|---------|-----------|---------|----------------|
| `EnterPlanMode` | `block-plan-mode` | Blocks built-in plan mode (use `/plan` instead) | Yes |
| `Write\|Edit` | `check-active-task` | Task gate (P-002): no file edits without active task | Yes |
| `Bash` | `check-tier0` | Tier 0 guard: blocks destructive commands | Yes |
| `Write\|Edit\|Bash` | `budget-gate` | Context budget: blocks source edits at critical | Yes |

**PostToolUse (4 hooks — Observers, cannot block):**

| Matcher | Hook Name | Purpose |
|---------|-----------|---------|
| `` (all) | `checkpoint post-tool` | Context budget monitoring, auto-handover |
| `Bash` | `error-watchdog` | Detects repeated errors, suggests healing |
| `Task\|TaskOutput` | `check-dispatch` | Sub-agent dispatch guard |
| `Write` | `check-fabric-new-file` | Reminds to register new source files |

**Session hooks (3 hooks):**

| Event | Matcher | Hook Name | Purpose |
|-------|---------|-----------|---------|
| `PreCompact` | `` | `pre-compact` | Auto-generates handover |
| `SessionStart` | `compact` | `post-compact-resume` | Re-injects context |
| `SessionStart` | `resume` | `post-compact-resume` | Re-injects context |

### Hook Execution Model

- Hooks fire on **every** tool call matching the pattern
- PreToolUse hooks run **before** the tool — can prevent execution (exit 2)
- PostToolUse hooks run **after** — observe only (async)
- Hooks snapshot at session start — editing `.claude/settings.json` requires restart
- Exit codes: 0 = proceed, 2 = block (stderr shown to agent), other = warning

---

## Local Overrides (`.claude/settings.local.json`)

Use this file for personal preferences that shouldn't affect other users:
- Custom permission overrides
- Different plugin selections
- Display preferences

---

## Recommendations Assessment

### Rec #1: Extended Thinking — ALREADY ACTIVE

Extended thinking is enabled by default on Opus 4.6 and Sonnet 4.6 with adaptive reasoning. No setting change needed.

**New option:** `/effort low|medium|high` controls reasoning depth. Could be useful to document for users — `high` for inception decisions, `low` for routine edits.

**Verdict:** No action needed. Document `/effort` in onboarding.

### Rec #2: Bash Timeout — IMPLEMENT

`BASH_DEFAULT_TIMEOUT_MS` defaults to 120s. Framework operations (audit, fabric analysis, embedding builds) can exceed this. Set in `claude-fw` wrapper or document for users.

**Verdict:** Add `export BASH_DEFAULT_TIMEOUT_MS=300000` to `claude-fw` wrapper.

### Rec #3: Session End Hook — REVISED

`SessionEnd` does not exist. The `Stop` event fires when Claude finishes a response (can block). This is NOT the same as session end — it fires after every response.

The real gap: no hook fires when the user closes the terminal or types `/exit`. The framework already mitigates this with:
- Budget gate auto-handover at critical
- Commit cadence rule (work safe at last commit)
- `/compact` PreCompact hook

**Verdict:** No action. The gap is structural (Claude Code limitation). Existing mitigations are sufficient.

### Rec #4: UserPromptSubmit Hook — EXPLORE

`UserPromptSubmit` exists and can block. No matcher support, so it fires on every prompt. Could remind agent to check focus before starting work.

**Risk:** Fires on EVERY prompt — adds latency to every interaction. The task gate on Write/Edit catches 95% of cases. The remaining 5% (agent starts reading code before setting focus) is low risk.

**Verdict:** Defer. Cost (latency on every prompt) outweighs benefit (catching the rare case where agent reads before setting focus). Revisit if task gate misses become frequent.

### Rec #5: Sandbox Mode — DEFER

Sandbox mode exists and is sophisticated. Relevant for external adopters who don't trust `Bash(*)`. Not relevant for current single-user setup.

**Verdict:** Defer to post-launch. Document as "recommended for teams" in onboarding docs.

### Rec #6: Model Pinning — REJECT

Model pinning via `"model": "claude-opus-4-6"` prevents using different models for different tasks. The framework is model-agnostic by design (D4: Portability). Users should choose their model.

**Verdict:** Reject. Document how to pin if desired, but don't recommend it.

### NEW Rec #7: `PostCompact` Hook

New event — could replace/supplement the `SessionStart:compact` hook for post-compaction context injection. Undocumented, so defer until API stabilizes.

**Verdict:** Watch. Add when documented.

### NEW Rec #8: `SubagentStop` Hook

Could enforce sub-agent result size limits structurally (block if output too large). Currently handled by `check-dispatch.sh` on PostToolUse, which is advisory only.

**Verdict:** Explore in future. Could solve G-015 (sub-agent results bypass governance).

---

## Verification Checklist

```bash
# Check hooks are wired
fw doctor

# Verify task gate works (should block without active task)
# Try to edit a file without setting focus — should see BLOCKED message

# Verify budget gate works
cat .context/working/.budget-status

# Verify auto-compact is disabled
grep autoCompactEnabled ~/.claude.json
# Should show: false

# Verify permission mode
grep defaultMode ~/.claude/settings.json
# Should show: dontAsk
```

---

## Quick Setup for New Installations

1. Run `fw init /path/to/project` — creates `.claude/settings.json` with all hooks (portable paths)
2. Configure global permissions:
   ```bash
   cat > ~/.claude/settings.json << 'EOF'
   {
     "permissions": {
       "allow": ["Bash(*)", "Read(*)", "Glob(*)", "Grep(*)", "Write(*)", "Edit(*)", "WebFetch(*)", "WebSearch(*)", "AskUserQuestion(*)", "Task(*)"],
       "defaultMode": "dontAsk"
     }
   }
   EOF
   ```
3. Disable auto-compact: `claude config set autoCompact false` (or set in `~/.claude.json`)
4. Run `fw doctor` to verify everything is wired
