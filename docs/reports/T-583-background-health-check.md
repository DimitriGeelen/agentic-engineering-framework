# T-583: Background Health Check — Periodic Silent-Failure Detection

## Problem Statement

Framework is blind between explicit `fw doctor` / `fw audit` runs. Hooks can break silently mid-session — protection appears to exist but never fires. Real example: `check-project-boundary.sh` was built but not added to `settings.json`, so the boundary gate never activated.

**OpenClaw reference:** Runs health monitor every 5 minutes detecting stale sockets, stuck sessions, half-dead connections.

## Current State

### Existing Health Mechanisms

| Mechanism | When | What it checks | Blind spots |
|-----------|------|----------------|-------------|
| `fw doctor` | On-demand | 15+ checks (hooks, paths, tools) | Never runs automatically |
| `fw audit` | Cron every 15min + pre-push | Full compliance scan | Cron runs outside session — doesn't catch mid-session breaks |
| `checkpoint.sh` (PostToolUse) | Every tool call | Budget level, auto-handover | Only checks budget, not structural health |
| `budget-gate.sh` (PreToolUse) | Every Write/Edit/Bash | Token usage | Only checks budget |
| `check-active-task.sh` (PreToolUse) | Every Write/Edit | Task existence, status, onboarding | Only checks task state |

**Gap:** No mechanism detects mid-session hook breakage, YAML corruption, or focus inconsistency. Between `fw context init` and `fw handover`, the framework assumes everything works.

### What `fw doctor` Already Checks

Reading `bin/fw` doctor subcommand and related checks:
- Hook files exist and are executable
- settings.json has expected hook entries
- Framework paths resolve correctly
- Python/bash/git tools available
- Task directory structure intact

### PostToolUse `checkpoint.sh` as Integration Point

`checkpoint.sh` runs after every tool call. It already:
1. Reads token usage from session transcript
2. Writes budget status to `.context/working/.budget-status`
3. Triggers auto-handover at critical level

**Proposal:** Piggyback on checkpoint.sh — every Nth tool call (e.g., every 20), run a lightweight subset of `fw doctor` checks.

## Proposed Health Checks (Quick Probe)

**Target: <200ms every 20 tool calls (~5 minutes of active work)**

1. **Hook resolution** — Do all hooks in `.claude/settings.json` resolve to executable scripts? (~50ms)
2. **Focus validity** — Does `focus.yaml` parse and point to a real task in `.tasks/active/`? (~20ms)
3. **Session validity** — Is the session ID in `session.yaml` still current? (~10ms)
4. **Task YAML** — Does the active task file parse without errors? (~30ms)
5. **Git hooks** — Are `commit-msg` and `pre-push` hooks still executable? (~20ms)

**NOT included (too slow):**
- Full audit scan (takes 5-30 seconds)
- Fabric drift detection
- Network/API health
- Ollama/embedding health

## Design Options

### Option A: Checkpoint.sh Counter-Based Probe

Add a counter to `checkpoint.sh`. Every 20th call, run the quick probe. Write results to `.context/working/.health-status`. If any check fails, emit a WARNING to stderr (visible to agent).

```bash
# In checkpoint.sh, after budget check:
HEALTH_COUNTER_FILE="$WORKING_DIR/.health-counter"
counter=$(cat "$HEALTH_COUNTER_FILE" 2>/dev/null || echo 0)
counter=$((counter + 1))
echo "$counter" > "$HEALTH_COUNTER_FILE"

if [ $((counter % 20)) -eq 0 ]; then
    _quick_health_probe
fi
```

**Pro:** Leverages existing hook. No new hook needed. Minimal overhead.
**Con:** Checkpoint.sh is already complex. Adding more responsibilities increases failure surface.

### Option B: Separate Health Probe Hook (PostToolUse)

Add a dedicated health probe hook alongside checkpoint.sh. Lighter than checkpoint.sh — only runs every Nth call.

**Pro:** Separation of concerns. Health probe can be enabled/disabled independently.
**Con:** Additional hook overhead. Another entry in settings.json.

### Option C: Cron-Based In-Session Probe

Instead of hook-based, use the existing cron audit to run a lighter "session health" check if a session is active (detected via session.yaml timestamp).

**Pro:** No hook overhead at all. Uses existing infrastructure.
**Con:** Cron runs outside the Claude Code process — can't emit warnings to the agent.

## Recommendation

**Option A (checkpoint.sh counter-based)** — simplest integration, leverages existing infrastructure, adds ~200ms overhead every ~5 minutes. Health status file enables Watchtower to show a health indicator.

**Effort:** ~1 session. Add counter + probe to checkpoint.sh, write `.health-status`, emit warnings.

## Go/No-Go Assessment

**GO criteria:**
- [x] Concrete evidence of silent hook failures (check-project-boundary.sh incident)
- [x] Lightweight probe possible (<200ms, every 20 calls)
- [x] Natural integration point exists (checkpoint.sh)

**NO-GO criteria:**
- [ ] Probe too slow (measured examples above)
- [ ] No evidence of mid-session breakage (we have evidence)

**Recommendation: GO** with Option A.
