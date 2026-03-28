# T-629 Spike 8: Session-Start Friction Measurement

## Executive Summary

The framework consumes **~22K tokens before the agent does any real work** — roughly 11% of the 200K context window. The Session Start Protocol requires **9 agent actions** (6 mandatory + 3 pre-implementation) before a single line of code can be written. Every Write/Edit call runs through **6 hooks** (3 pre + 3 post); every Bash call runs through **5 hooks**.

---

## 1. SessionStart Hooks (settings.json)

**2 SessionStart hooks configured**, both with the same script:

| Matcher | Script | Fires when |
|---------|--------|------------|
| `compact` | `fw hook post-compact-resume` | After `/compact` |
| `resume` | `fw hook post-compact-resume` | After `claude -c` (auto-restart) |

**On fresh session start (no matcher = "")**: Neither fires. The agent must manually follow the Session Start Protocol.

**On compact/resume**: `post-compact-resume.sh` (168 lines) injects:
- Handover sections (WHERE, WIP, SUGGESTED, GOTCHAS) — truncated to 10+20+5+10 lines
- Onboarding check (loops all active tasks checking tags)
- Current focus from focus.yaml
- All active task listing (loops 73 files, reads 4 YAML fields each)
- Git state (branch, last commit, uncommitted count)
- Fabric topology overview (1,663 bytes)
- Discovery findings (YAML parse via python3)

**Injected context size**: ~9,500 bytes (~2,400 tokens) for resume, plus ~1,663 bytes (~416 tokens) for fabric overview = **~2,800 tokens injected on resume**.

## 2. What the Agent Must Do Manually (Session Start Protocol)

### Phase 1: "Before beginning any work" (6 steps)

| Step | Action | Tokens consumed | Can fail? |
|------|--------|----------------|-----------|
| 1 | `fw context init` | ~200 (command + output) | Yes — dirs missing |
| 2 | Read `LATEST.md` | **~6,805** (27,220 bytes) | Yes — file missing |
| 3 | Review "Suggested First Action" | 0 (part of step 2) | No |
| 4 | `fw context focus T-XXX` | ~100 | Yes — task not found |
| 5 | `fw metrics` | ~500-1,000 | Yes — script error |
| 6 | Fill in handover feedback | ~200 | No |

### Phase 2: "Before ANY implementation" (3 steps)

| Step | Action | Tokens consumed | Can fail? |
|------|--------|----------------|-----------|
| 1 | `fw work-on "name"` or `fw work-on T-XXX` | ~300 | Yes — template missing |
| 2 | Confirm focus in focus.yaml | ~100 | No |
| 3 | Begin implementation | 0 | No |

**Total mandatory reads before work: ~8,200 tokens** just from the protocol steps.

## 3. Auto-Loaded Context (Always Present)

| Source | Size (bytes) | Tokens (est.) | Notes |
|--------|-------------|---------------|-------|
| CLAUDE.md | 53,655 | **~13,414** | Auto-loaded by Claude Code |
| MEMORY.md | 5,355 | ~1,339 | Auto-loaded by Claude Code |
| Skills system-reminder | ~5,000 | ~1,250 | System-injected |
| Git status (system) | ~2,000 | ~500 | Injected by Claude Code |
| **Subtotal (always)** | **~66,010** | **~16,503** | |

## 4. Total Session-Start Context Budget

| Category | Tokens | % of 200K |
|----------|--------|-----------|
| Auto-loaded (CLAUDE.md + MEMORY.md + system) | ~16,503 | 8.3% |
| Agent protocol reads (LATEST.md + commands) | ~8,200 | 4.1% |
| Resume hook injection (compact/resume only) | ~2,800 | 1.4% |
| **Total fresh session** | **~24,703** | **12.4%** |
| **Total after compact** | **~27,503** | **13.8%** |

## 5. Per-Tool-Call Hook Overhead

### PreToolUse hooks (block before execution)

| Matcher | Script | Lines | What it does |
|---------|--------|-------|-------------|
| `EnterPlanMode` | block-plan-mode.sh | 7 | Rejects PlanMode entry |
| `Write\|Edit` | check-active-task.sh | 293 | Validates task exists in `.tasks/active/` |
| `Bash` | check-tier0.sh | 253 | Scans for destructive commands |
| `Write\|Edit\|Bash` | check-project-boundary.sh | 188 | Blocks writes outside PROJECT_ROOT |
| `Write\|Edit\|Bash` | budget-gate.sh | 255 | Reads session transcript, blocks at critical |

### PostToolUse hooks (run after execution)

| Matcher | Script | Lines | What it does |
|---------|--------|-------|-------------|
| `*` (all) | checkpoint.sh post-tool | 310 | Token usage monitoring, warns/auto-handover |
| `Bash` | error-watchdog.sh | 107 | Detects error patterns in bash output |
| `Task\|TaskOutput` | check-dispatch.sh | 88 | Validates dispatch protocol |
| `Write` | check-fabric-new-file.sh | 142 | Detects new files needing fabric registration |
| `Write\|Edit` | commit-cadence.sh | 102 | Counts edits since last commit, warns |

**Per Write/Edit call**: 3 pre + 3 post = **6 hooks** (check-active-task + boundary + budget-gate + checkpoint + fabric-new-file + commit-cadence)
**Per Bash call**: 3 pre + 2 post = **5 hooks** (tier0 + boundary + budget-gate + checkpoint + error-watchdog)
**Per Read call**: 0 pre + 1 post = **1 hook** (checkpoint)

**Total hook script lines**: 1,745 lines of bash executing around every tool call.

## 6. Failure Modes

| Failure | What happens | Recovery |
|---------|-------------|----------|
| `fw context init` fails | Working dirs don't exist → later writes fail | Rarely fails (just mkdir) |
| LATEST.md missing | Agent has no context, guesses | No fallback — starts blind |
| Focus not set | check-active-task.sh **blocks all Write/Edit** | Must create/find a task first |
| `fw metrics` fails | Non-critical — informational only | Skip it |
| Task creation fails | **All productive work blocked** by PreToolUse hook | Must fix task system first |
| budget-gate.sh errors | Fails open (allows work) but loses protection | Silent degradation |
| check-tier0.sh false positive | **Blocks legitimate Bash commands** | Must approve or adjust |

**Critical path**: The only truly blocking failure is "no active task" — check-active-task.sh gates Write and Edit. Everything else is either informational or fails open.

## 7. LATEST.md Analysis

- **Total**: 581 lines, 27,220 bytes (~6,805 tokens)
- **Useful content**: Where We Are (5 lines), Suggested Action (1 line), Gotchas (3 lines) = ~9 lines
- **Boilerplate/status**: 86 active tasks listed individually with status, 32 human AC tasks listed with examples, 13 gaps, inception count, commit history = ~570 lines
- **Useful-to-boilerplate ratio**: ~1.5% useful, ~98.5% status dump

The handover is essentially a full project status report, not a session-continuation document. The resume hook's truncation (head -10/20/5/10) is a band-aid — the full file still gets read by the agent during the manual protocol.

## 8. CLAUDE.md vs Minimal Setup

| Setup | Tokens | Ratio |
|-------|--------|-------|
| **Minimal** (project description + key conventions) | ~500 | 1x |
| **This framework's CLAUDE.md** | ~13,414 | **27x** |

### CLAUDE.md section breakdown (approximate):

| Section | Lines | Est. tokens | Essential? |
|---------|-------|-------------|-----------|
| Core (overview, principle, directives, authority) | ~50 | 600 | Yes |
| Task system (format, lifecycle, sizing) | ~80 | 1,000 | Yes |
| Enforcement tiers | ~15 | 200 | Yes |
| Working with tasks | ~60 | 800 | Yes |
| Context integration | ~10 | 100 | Defer |
| Error escalation ladder | ~30 | 400 | Defer |
| fw CLI reference | ~40 | 500 | Defer (agent knows commands) |
| Agent descriptions (7 agents) | ~120 | 1,500 | Defer (load on demand) |
| Component Fabric | ~40 | 500 | Defer |
| Budget management | ~40 | 500 | Yes |
| Sub-agent dispatch protocol | ~100 | 1,200 | Defer (only when dispatching) |
| Agent behavioral rules | ~200 | 2,500 | Partially defer |
| Session protocols | ~30 | 400 | Yes |
| Quick reference table | ~60 | 800 | **Remove** (duplicate of above) |
| TermLink integration | ~60 | 800 | Defer |
| Auto-restart | ~15 | 200 | Defer |
| Remote session | ~15 | 200 | Defer |
| Session end protocol | ~15 | 200 | Yes |

## 9. Recommendations: Reducing Session-Start Overhead

### Immediate wins (no code changes)

1. **Remove Quick Reference table** (-800 tokens): Duplicates information already in agent/command sections. The agent has seen both — one is enough.

2. **Truncate LATEST.md to essentials** (-5,500 tokens): The handover should contain: Where We Are, Current Focus, Suggested Action, Gotchas/Blockers. Not 86 task listings. Task listings belong in `fw task list`, not in the handover.

3. **Defer agent descriptions** (-1,500 tokens): Agent docs (Git, Healing, Fabric, etc.) are reference material. Load them on demand when the agent needs to invoke that agent, not at session start.

### Medium-term (code changes)

4. **Layered CLAUDE.md** (T-316 already exists): Split into:
   - `CLAUDE.md` — core rules only (~3,000 tokens): principle, authority, task system, enforcement, budget, session protocol
   - `.claude/reference/dispatch.md` — Sub-agent protocol (loaded when dispatching)
   - `.claude/reference/agents.md` — Agent descriptions (loaded when invoking)
   - `.claude/reference/termlink.md` — TermLink details (loaded when using)
   - `.claude/reference/behavioral.md` — Full behavioral rules (loaded after session start)

5. **Compact handover format** (-5,000 tokens): Replace the full-project-status handover with a focused continuation document:
   ```
   Focus: T-XXX
   Last commit: abc123 T-XXX: description
   Next: [one sentence]
   Blockers: [none or list]
   Gotchas: [none or list]
   ```
   Full status available via `fw resume status` on demand.

6. **Lazy hook loading**: Several hooks (fabric-new-file, commit-cadence, error-watchdog, check-dispatch) only matter during active work. They could be no-ops during session startup and activated after the first commit.

### Potential savings

| Change | Tokens saved | Effort |
|--------|-------------|--------|
| Remove Quick Reference | 800 | Trivial |
| Compact handover | 5,500 | Medium |
| Defer agent docs | 1,500 | Low |
| Defer dispatch protocol | 1,200 | Low |
| Defer TermLink section | 800 | Low |
| Layered CLAUDE.md (full) | ~7,000 | High |
| **Total potential** | **~16,800** | |

This would reduce session-start overhead from **~24,700 tokens (12.4%)** to **~7,900 tokens (4.0%)** — a **68% reduction** and 8.4% more usable context per session.

## 10. Protocol Step Reduction

Current: 9 steps before work (6 + 3).

Proposed: 3 steps:
1. `fw start-session` (combines: context init + read handover + set focus + show summary)
2. `fw work-on T-XXX` (or create new task)
3. Begin work

The `fw start-session` command would be a single composite that does everything in steps 1-6 mechanically and returns a 10-line summary, instead of requiring 6 separate agent actions that each consume context.
