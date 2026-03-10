# Claude Code Settings for the Agentic Engineering Framework

This document describes all Claude Code settings required for the framework to function correctly.

## Settings File Locations

| File | Scope | Shared? | Purpose |
|------|-------|---------|---------|
| `~/.claude/settings.json` | Global (all projects) | No | Permissions, plugins, update channel |
| `.claude/settings.json` | Project (committed) | Yes | Hooks, enforcement gates |
| `.claude/settings.local.json` | Local (gitignored) | No | Personal overrides |
| `~/.claude.json` | Internal state | No | Managed by Claude Code (OAuth, caches, preferences) |

**Precedence:** Local > Project > Global (for conflicts). Arrays merge across scopes.

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
      "Task(*)",
      "mcp__plugin_playwright_playwright__*"
    ],
    "defaultMode": "dontAsk"
  },
  "enabledPlugins": {
    "context7@claude-plugins-official": true,
    "playwright@claude-plugins-official": true,
    "commit-commands@claude-plugins-official": true,
    "code-review@claude-plugins-official": true,
    "code-simplifier@claude-plugins-official": true,
    "frontend-design@claude-plugins-official": true,
    "typescript-lsp@claude-plugins-official": true
  },
  "autoUpdatesChannel": "stable"
}
```

### Permission Mode: `dontAsk`

The framework uses `dontAsk` mode with explicit allow rules. This means:
- Tools NOT in the allow list are **auto-denied** (no prompt)
- Tools IN the allow list execute **without asking**
- This is essential because the framework's PreToolUse hooks act as the permission layer instead

**Why not `default` mode?** The framework's hook-based enforcement (task gate, tier 0 guard, budget gate) replaces Claude Code's built-in permission prompts. Using `default` mode would double-prompt the user — once from hooks, once from Claude Code.

**Why not `bypassPermissions`?** That skips ALL checks including hooks. The framework needs hooks to run.

### Broad Tool Permissions

All core tools are allowed with `(*)` wildcards because:
- `Write(*)` / `Edit(*)` — Framework hooks (`check-active-task.sh`) gate writes, not Claude Code permissions
- `Bash(*)` — Framework hooks (`check-tier0.sh`, `budget-gate.sh`) gate dangerous commands
- `Task(*)` — Sub-agent dispatch is hook-monitored (`check-dispatch.sh`)

**Risk:** If hooks are misconfigured, there are no backup permissions. Run `fw doctor` to verify hooks are wired.

### Enabled Plugins

| Plugin | Why Enabled | Framework Use |
|--------|-------------|---------------|
| `context7` | Up-to-date library documentation | Research during build tasks |
| `playwright` | Browser automation for testing | Watchtower UI verification |
| `commit-commands` | Git commit workflows | Commit helper (optional) |
| `code-review` | PR review capabilities | Code review skill |
| `code-simplifier` | Code cleanup agent | Refactoring tasks |
| `frontend-design` | UI design generation | Watchtower UI development |
| `typescript-lsp` | TypeScript language server | JS/TS code intelligence |

**Disabled plugins:**
- `superpowers` — Conflicts with framework instruction precedence (claims "supercedes any other instructions")
- `feature-dev` — Not needed; framework has its own task-driven workflow

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

**Risk if enabled:** The agent loses task context, focus state, and conversation history at unpredictable moments. Handover quality degrades because the agent doesn't know compaction is coming.

### `verbose: true`

Shows detailed output from Claude Code internals. Helps debug hook failures and permission issues.

### `autoUpdates: false`

Prevents mid-session updates that could change behavior. Updates are applied manually between sessions.

---

## Project Hooks (`.claude/settings.json`)

The framework's enforcement system runs through Claude Code hooks. This is the most critical configuration.

### PreToolUse Hooks (Gates — Can Block)

| Matcher | Script | Purpose | Exit 2 = Block |
|---------|--------|---------|-----------------|
| `EnterPlanMode` | `block-plan-mode.sh` | Blocks built-in plan mode (use `/plan` instead) | Yes |
| `Write\|Edit` | `check-active-task.sh` | Task gate (P-002): no file edits without active task | Yes |
| `Bash` | `check-tier0.sh` | Tier 0 guard: blocks destructive commands (force push, rm -rf, DROP TABLE) | Yes |
| `Write\|Edit\|Bash` | `budget-gate.sh` | Context budget enforcement: blocks source edits at ≥75% context | Yes |

**How blocking works:** Exit code 2 = action blocked, stderr shown to agent. Exit code 0 = proceed. Other = warning only.

### PostToolUse Hooks (Observers — Cannot Block)

| Matcher | Script | Purpose |
|---------|--------|---------|
| `` (all tools) | `checkpoint.sh post-tool` | Context budget monitoring, auto-handover at critical |
| `Bash` | `error-watchdog.sh` | Detects repeated errors, suggests healing |
| `Task\|TaskOutput` | `check-dispatch.sh` | Sub-agent dispatch guard (context flood prevention) |
| `Write` | `check-fabric-new-file.sh` | Reminds to register new source files in component fabric |

### Session Hooks

| Event | Matcher | Script | Purpose |
|-------|---------|--------|---------|
| `PreCompact` | `` | `pre-compact.sh` | Auto-generates handover before compaction |
| `SessionStart` | `compact` | `post-compact-resume.sh` | Re-injects context after compaction |
| `SessionStart` | `resume` | `post-compact-resume.sh` | Re-injects context on `/resume` |

### Hook Execution Model

- Hooks fire on **every** tool call matching the pattern
- PreToolUse hooks run **before** the tool — can prevent execution
- PostToolUse hooks run **after** — observe only
- Hooks snapshot at session start — editing `.claude/settings.json` requires restart
- Timeout: 600s default for command hooks

---

## Local Overrides (`.claude/settings.local.json`)

Currently minimal:

```json
{
  "prefersReducedMotion": false
}
```

Use this file for personal preferences that shouldn't affect other users:
- Custom permission overrides
- Different plugin selections
- Display preferences

---

## Recommendations for Improving Agent Success Rate

### 1. Consider `alwaysThinkingEnabled: true` (Global)

Extended thinking improves complex reasoning (inception decisions, multi-file refactoring). Add to `~/.claude/settings.json`:
```json
"alwaysThinkingEnabled": true
```

### 2. Set `BASH_DEFAULT_TIMEOUT_MS` Higher for Long Operations

Embedding builds, audit runs, and fabric analysis can exceed the default 120s timeout:
```bash
export BASH_DEFAULT_TIMEOUT_MS=300000  # 5 minutes
```

### 3. Add `SessionEnd` Hook for Auto-Handover

Currently no `SessionEnd` hook exists. Adding one would catch sessions that end without handover:
```json
{
  "matcher": "",
  "hooks": [{
    "type": "command",
    "command": "/opt/999-Agentic-Engineering-Framework/agents/handover/handover.sh --auto"
  }]
}
```

### 4. Add `UserPromptSubmit` Hook for Task Gate

Currently the task gate only fires on Write/Edit. A UserPromptSubmit hook could remind the agent to set focus before ANY work begins, not just file modifications.

### 5. Consider Sandbox Mode for External Adopters

For users who don't trust broad `Bash(*)` permissions, enable sandbox with framework-specific allowlists:
```json
{
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": ["//.tasks", "//.context", "//.fabric", "//docs"]
    }
  }
}
```

### 6. Pin Model for Consistency

Add to global settings to prevent model drift:
```json
"model": "claude-opus-4-6"
```

---

## Verification Checklist

Run these to verify settings are correctly applied:

```bash
# Check hooks are wired
fw doctor

# Verify task gate works (should block without active task)
# Try to edit a file without setting focus — should see BLOCKED message

# Verify budget gate works
cat .context/working/.budget-status

# Verify tier 0 guard
# The check-tier0.sh script should be executable
test -x agents/context/check-tier0.sh && echo "OK" || echo "MISSING"

# Verify auto-compact is disabled
grep autoCompactEnabled ~/.claude.json
# Should show: false

# Verify permission mode
grep defaultMode ~/.claude/settings.json
# Should show: dontAsk
```

---

## Quick Setup for New Installations

1. Copy `.claude/settings.json` from the framework repo (hooks are project-scoped)
2. Configure global permissions:
   ```bash
   # Add to ~/.claude/settings.json
   cat > ~/.claude/settings.json << 'EOF'
   {
     "permissions": {
       "allow": ["Bash(*)", "Read(*)", "Glob(*)", "Grep(*)", "Write(*)", "Edit(*)", "WebFetch(*)", "WebSearch(*)", "AskUserQuestion(*)", "Task(*)"],
       "defaultMode": "dontAsk"
     }
   }
   EOF
   ```
3. Disable auto-compact (set `autoCompactEnabled: false` in `~/.claude.json`)
4. Run `fw doctor` to verify everything is wired
