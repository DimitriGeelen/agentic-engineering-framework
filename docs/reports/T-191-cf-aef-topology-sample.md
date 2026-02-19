---
title: "Component Fabric — AEF Budget Management Subsystem Topology"
task: T-191
date: 2026-02-19
status: complete
phase: "Phase 1b — Manual Topology Mapping"
tags: [component-fabric, topology, budget-management, hooks, subsystem-analysis]
predecessor: docs/reports/T-191-cf-research-landscape.md
---

# Component Fabric — AEF Budget Management Subsystem Topology

> **Task:** T-191 | **Date:** 2026-02-19 | **Phase:** 1b (Manual Topology Mapping)
> **Principle:** "The thinking trail IS the artifact"

## Objective

Manually map the AEF budget management subsystem as a concrete proof-of-concept for what Component Fabric would need to capture. This is the first "living example" — every relationship documented here was discovered by reading source code, and every relationship is real. The exercise reveals what topology information matters, what's easy to discover, and what's invisible without manual tracing.

## Subsystem Overview

The **budget management subsystem** monitors context window usage during a Claude Code session and enforces escalating responses (warn → urgent → block → auto-handover → auto-restart). It spans 11 scripts, 12+ shared files, 5 Claude Code hook types, and 2 git hooks.

**Why this subsystem for the proof-of-concept:**
- It's the most interconnected subsystem in AEF (touches every tool call)
- It has all five dependency layers from the research landscape (§2)
- It has critical soft coupling (shared file formats with no import statements)
- A bug here has cascading consequences (23 handover commits in one session)
- It spans CLI, hooks, wrapper scripts, and data files — diverse component types

---

## Component Inventory

### C-001: budget-gate.sh
- **Type:** Script (PreToolUse hook — PRIMARY enforcement)
- **Location:** `agents/context/budget-gate.sh` (242 lines)
- **Purpose:** Block tool execution when context tokens exceed critical threshold
- **Interfaces:**
  - **Input:** stdin JSON from Claude Code (tool_name, tool_input.command, tool_input.file_path)
  - **Output:** exit 0 (allow), exit 2 (block) + stderr message
- **Reads:** `.context/working/.budget-status` (cached), JSONL transcript (slow path)
- **Writes:** `.context/working/.budget-status`, `.context/working/.budget-gate-counter`
- **Classification logic:** Distinguishes "allowed" ops (git commit, fw handover, reads, wrap-up writes) from "blocked" ops (feature code, general Bash)
- **Performance:** <100ms target. Fast path (cached status <90s) vs slow path (JSONL scan every 5th call)
- **Created by:** T-138 (hybrid enforcement architecture)

### C-002: checkpoint.sh
- **Type:** Script (PostToolUse hook — FALLBACK warnings + auto-handover)
- **Location:** `agents/context/checkpoint.sh` (269 lines)
- **Purpose:** Warn about context usage, auto-trigger handover at critical, detect compaction
- **Interfaces:**
  - **Subcommands:** `post-tool`, `reset`, `status`
  - `post-tool` — increment counter, check tokens every 5 calls, warn/auto-handover
  - `reset` — clear counter, prev-tokens, restart signal
  - `status` — display current usage
- **Reads:** `.context/working/.tool-counter`, `.context/working/.prev-token-reading`, `.context/working/.handover-cooldown`, JSONL transcript
- **Writes:** `.context/working/.tool-counter`, `.context/working/.prev-token-reading`, `.context/working/.handover-cooldown`, `.context/working/.handover-in-progress` (lock), `.context/working/.restart-requested`
- **Calls:** `agents/handover/handover.sh --commit` (at critical, with re-entry + cooldown guards)
- **Thresholds:** 120K warn, 150K urgent, 170K critical (same as budget-gate.sh — **soft coupling**)
- **Created by:** P-009, updated by T-136 (auto-handover), T-186 (restart signal)

### C-003: claude-fw
- **Type:** Wrapper script (auto-restart loop)
- **Location:** `bin/claude-fw` (122 lines)
- **Purpose:** Run `claude`, detect restart signals, auto-restart with `claude -c`
- **Interfaces:**
  - **Flags:** `--no-restart` (disable auto-restart)
  - **Passthrough:** All other args forwarded to `claude`
- **Reads:** `.context/working/.restart-requested`
- **Safety:** MAX_RESTARTS=5, 5-minute TTL on signals, 3-second cancel window
- **Loop:** `claude [args]` → exit → check signal → `sleep 3` → `claude -c` → repeat
- **Created by:** T-179 (auto-restart), T-187 (wrapper)

### C-004: pre-compact.sh
- **Type:** Script (PreCompact hook)
- **Location:** `agents/context/pre-compact.sh` (42 lines)
- **Purpose:** Save structured context before lossy compaction
- **Interfaces:**
  - Fires on `/compact` command (manual only — auto-compaction disabled per D-027)
- **Calls:** `agents/handover/handover.sh` (--commit or --no-commit with 5-minute dedup)
- **Writes:** `.context/working/.compact-log` (append-only)
- **Resets:** `.context/working/.budget-gate-counter` → 0, removes `.context/working/.budget-status`
- **Created by:** T-111, updated T-175 (D-028), T-177

### C-005: post-compact-resume.sh
- **Type:** Script (SessionStart hook — matchers: "compact", "resume")
- **Location:** `agents/context/post-compact-resume.sh` (101 lines)
- **Purpose:** Reinject structured context into fresh session after compaction/resume
- **Reads:** `.context/handovers/LATEST.md` (sections: Where We Are, Work in Progress, Suggested Action, Gotchas), `.context/working/focus.yaml`, all `.tasks/active/*.md`, git state
- **Output:** JSON `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}`
- **Created by:** T-111, T-188 (auto-restart support)

### C-006: check-active-task.sh
- **Type:** Script (PreToolUse hook on Write|Edit — Tier 1 enforcement)
- **Location:** `agents/context/check-active-task.sh` (92 lines)
- **Purpose:** Block file modifications when no active task is focused
- **Reads:** stdin JSON (file_path), `.context/working/focus.yaml`, task files in `.tasks/active/`
- **Exempt paths:** `.context/`, `.tasks/`, `.claude/`, `.git/`
- **Output:** exit 0 (allow) or exit 2 (block) + guidance message
- **Bonus:** Inception awareness — warns (but doesn't block) when focused task is inception without decision
- **Created by:** P-002 (Structural Enforcement)

### C-007: check-tier0.sh
- **Type:** Script (PreToolUse hook on Bash — Tier 0 enforcement)
- **Location:** `agents/context/check-tier0.sh` (211 lines)
- **Purpose:** Detect and block destructive commands unless human-approved
- **Reads:** stdin JSON (command), `.context/working/.tier0-approval`
- **Writes:** `.context/working/.tier0-approval.pending`, `.context/bypass-log.yaml`
- **Pattern matching:** Two-phase — fast bash grep pre-filter (<5ms for safe commands), then Python regex for suspicious ones
- **Approval flow:** `fw tier0 approve` writes approval hash → hook reads & consumes → logs to bypass-log
- **Patterns detected:** force push, hard reset, git clean, checkout ., branch -D, rm -rf /, DROP TABLE, docker system prune, kubectl delete namespace
- **Created by:** Spec 011-EnforcementConfig.md

### C-008: error-watchdog.sh
- **Type:** Script (PostToolUse hook on Bash — advisory)
- **Location:** `agents/context/error-watchdog.sh` (108 lines)
- **Purpose:** Detect Bash errors and inject investigation reminder
- **Reads:** stdin JSON (tool_name, tool_response.exitCode, stderr, stdout)
- **Output:** JSON additionalContext when errors detected, empty otherwise
- **Detection:** Critical exit codes (126, 127, 137, 139) + pattern matching (Traceback, FATAL, Permission denied, etc.)
- **Cannot block:** PostToolUse hooks are advisory (always exit 0)
- **Created by:** T-118 (Silent Error Bypass Remediation)

### C-009: handover.sh
- **Type:** Agent script (session handover generator)
- **Location:** `agents/handover/handover.sh` (544 lines)
- **Purpose:** Create forward-looking context document for session continuity
- **Interfaces:**
  - **Flags:** `--commit`, `--no-commit`, `--checkpoint`, `--session ID`, `--task T-XXX`
  - Normal mode: full handover with TODO sections
  - Checkpoint mode: lightweight mid-session snapshot (doesn't replace LATEST.md)
- **Reads:** all `.tasks/active/*.md`, `.tasks/completed/*.md` (recent), `.context/episodic/`, `focus.yaml`, `gaps.yaml`, `inbox.yaml`, git log
- **Writes:** `.context/handovers/S-YYYY-MMDD-HHMM.md`, `.context/handovers/LATEST.md`
- **Calls:** `agents/git/git.sh commit` (when --commit), `agents/task-create/create-task.sh` (auto-create handover task)
- **Gates:** Episodic completeness check (warns if completed tasks lack enriched episodics)
- **Called by:** checkpoint.sh (auto-handover at critical), pre-compact.sh (before /compact)

### C-010: commit-msg hook
- **Type:** Git hook
- **Location:** `.git/hooks/commit-msg` (~80 lines, installed by git.sh)
- **Purpose:** Enforce task reference in commit messages + inception gate
- **Reads:** commit message file ($1), `.tasks/active/T-XXX-*.md`
- **Task check:** Requires `T-[0-9]+` pattern in message (allows merge/rebase commits)
- **Inception gate:** After 2 commits on an inception task without `GO|NO-GO|DEFER` decision, blocks further commits
- **Bypass:** `git commit --no-verify`

### C-011: post-commit hook
- **Type:** Git hook
- **Location:** `.git/hooks/post-commit` (~35 lines, installed by git.sh)
- **Purpose:** Bypass detection + counter reset + staleness check
- **Reads:** commit message (HEAD), `.context/handovers/LATEST.md`
- **Writes:** `.context/working/.tool-counter` → 0
- **Warns:** Missing task reference (bypass), stale handover (>60 min with >3 TODOs)

---

## Shared Data Files

These are the **soft coupling points** — files that connect components without import statements. A format change in any of these files breaks readers silently.

| File | Format | Writers | Readers | Purpose |
|------|--------|---------|---------|---------|
| `.budget-status` | JSON `{level, tokens, timestamp, source}` | C-001, C-002 | C-001 | Cached budget level (ok/warn/urgent/critical) |
| `.budget-gate-counter` | Plain integer | C-001 | C-001, C-004 | Gate invocation count (for recheck interval) |
| `.tool-counter` | Plain integer | C-002, C-011 | C-002 | Tool calls since last commit |
| `.prev-token-reading` | Plain integer | C-002 | C-002 | Previous token count (for compaction detection) |
| `.restart-requested` | JSON `{timestamp, session_id, reason, tokens}` | C-002 | C-003 | Auto-restart signal |
| `.handover-in-progress` | Flag file ("1") | C-002 | C-002 | Re-entry lock for auto-handover |
| `.handover-cooldown` | Unix timestamp | C-002 | C-002 | Cooldown timer (10 min) after auto-handover |
| `.compact-log` | Append-only text lines | C-004 | (audit) | Compaction event log |
| `focus.yaml` | YAML `{current_task, priorities, blockers, ...}` | context.sh | C-005, C-006 | Current task focus |
| `session.yaml` | YAML `{session_id, start_time, ...}` | context.sh | C-002 | Session metadata |
| `.tier0-approval` | `HASH TIMESTAMP` text | fw tier0 | C-007 | One-time approval token |
| `.tier0-approval.pending` | `HASH TIMESTAMP PENDING` text | C-007 | fw tier0 | Pending command for approval |
| `LATEST.md` | Markdown with YAML frontmatter | C-009 | C-005, C-011 | Last handover document |
| `bypass-log.yaml` | YAML `{bypasses: [{timestamp, tier, risk, ...}]}` | C-007, git.sh | audit | Tier 0 approval audit trail |
| JSONL transcript | JSON lines (Claude Code internal) | Claude Code | C-001, C-002 | Token usage data |

---

## Dependency Map

### By Dependency Layer (from research landscape §2)

**Lexical (direct code references):**
- C-002 → C-009: `"$FRAMEWORK_ROOT/agents/handover/handover.sh" --commit`
- C-004 → C-009: `"$FRAMEWORK_ROOT/agents/handover/handover.sh" --commit`
- C-009 → git.sh: `"$GIT_AGENT" commit -m "..."`
- C-004 → C-002: `"$FRAMEWORK_ROOT/agents/context/checkpoint.sh" reset`

**Semantic (shared patterns/conventions):**
- C-001 and C-002: Identical token thresholds (120K/150K/170K) — **duplicated constants, not shared**
- C-001 and C-002: Both use same Python JSONL parsing pattern (tail -c 2MB | python3)
- All hooks: Same `FRAMEWORK_ROOT` / `PROJECT_ROOT` resolution pattern
- All hooks: Same stdin JSON parsing pattern (python3 -c "import json; ...")

**Operational (runtime invocation chain):**
- Claude Code → PreToolUse → [C-006, C-007, C-001] (in order, for Write/Edit/Bash)
- Claude Code → PostToolUse → [C-002, C-008] (for all tools / Bash)
- Claude Code → PreCompact → C-004
- Claude Code → SessionStart → C-005
- C-002 → C-009 (auto-handover trigger)
- C-003 → Claude Code → C-005 (auto-restart → resume)

**Cross-cutting (shared infrastructure):**
- Git hooks (C-010, C-011) installed by `agents/git/git.sh install-hooks`
- Claude Code hooks configured in `.claude/settings.json`
- All scripts depend on Python3 for JSON/YAML parsing
- All scripts use `set -uo pipefail` error handling

**Soft coupling (shared file formats, no imports):**
- `.budget-status` JSON: C-001 writes → C-001 reads (self-coupling with caching)
- `.restart-requested` JSON: C-002 writes → C-003 reads (cross-component, **format change = silent break**)
- `.tool-counter` integer: C-002 writes → C-011 resets → C-002 reads
- `focus.yaml` YAML: context.sh writes → C-005 reads, C-006 reads
- `LATEST.md` markdown: C-009 writes → C-005 parses sections, C-011 checks staleness
- JSONL transcript: Claude Code writes → C-001 parses, C-002 parses (**external soft coupling**)

---

## Interaction Flows

### Flow 1: Normal Tool Call (happy path)

```
Agent calls Write/Edit/Bash
  │
  ├─→ PreToolUse: check-active-task.sh (C-006)
  │     └─ Reads focus.yaml → task exists? → allow / BLOCK
  │
  ├─→ PreToolUse: check-tier0.sh (C-007) [Bash only]
  │     └─ Keyword scan → pattern match → allow / BLOCK
  │
  ├─→ PreToolUse: budget-gate.sh (C-001)
  │     ├─ Fast path: read .budget-status (if <90s old)
  │     │    └─ ok → allow | warn → allow+note | urgent → allow+warning | critical → BLOCK (unless wrap-up)
  │     └─ Slow path (every 5th call): read JSONL transcript → update .budget-status
  │
  ├─ [Tool executes]
  │
  ├─→ PostToolUse: checkpoint.sh post-tool (C-002)
  │     ├─ Increment .tool-counter
  │     ├─ Every 5th call: read transcript → warn_by_tokens()
  │     └─ If critical: auto-handover (with cooldown + lock guards)
  │
  └─→ PostToolUse: error-watchdog.sh (C-008) [Bash only]
        └─ Check exit code → inject investigation context
```

### Flow 2: Auto-Handover at Critical Budget

```
checkpoint.sh detects tokens ≥ 170K
  │
  ├─ Check re-entry lock (.handover-in-progress) → skip if locked
  ├─ Check cooldown (.handover-cooldown) → skip if <600s since last
  │
  ├─ Set lock file
  ├─ Set cooldown timestamp
  │
  ├─→ handover.sh --commit (C-009)
  │     ├─ Gather state (tasks, git, episodics, gaps)
  │     ├─ Write S-YYYY-MMDD-HHMM.md + LATEST.md
  │     └─ git.sh commit (via commit-msg hook C-010 → post-commit hook C-011)
  │
  ├─ Write .restart-requested signal
  │    {"timestamp": "...", "session_id": "...", "reason": "critical_budget_auto_handover", "tokens": N}
  │
  └─ Remove lock file

  [Session continues with wrap-up work, budget-gate allows only git/handover]
  [Session ends naturally or agent exits]

claude-fw wrapper (C-003) detects exit:
  │
  ├─ Check .restart-requested exists + fresh (<5 min)
  ├─ Display: "Auto-restart #N (session: S-..., tokens: N)"
  ├─ rm .restart-requested
  ├─ sleep 3 (cancel window)
  │
  └─→ claude -c (continue session)
        └─→ SessionStart:resume hook → post-compact-resume.sh (C-005)
              └─ Read LATEST.md → inject structured context → agent runs /resume
```

### Flow 3: Manual /compact Recovery

```
User types /compact
  │
  ├─→ PreCompact hook: pre-compact.sh (C-004)
  │     ├─ Dedup check: was last commit a handover <5 min ago?
  │     ├─→ handover.sh --commit (or --no-commit if dedup)
  │     ├─ Append to .compact-log
  │     └─ Reset: .budget-gate-counter → 0, rm .budget-status
  │
  ├─ [Claude Code compacts conversation — destroys working memory]
  │
  └─→ SessionStart:compact hook: post-compact-resume.sh (C-005)
        ├─ Read LATEST.md sections (Where We Are, WIP, Suggested, Gotchas)
        ├─ Read focus.yaml → current task
        ├─ Read all .tasks/active/*.md → task summary
        ├─ Read git state (branch, last commit, uncommitted count)
        └─ Output: JSON additionalContext → injected into fresh session
```

---

## Observations: What This Mapping Reveals

### 1. Soft Coupling is the Dominant Dependency Type

Of the ~25 dependencies in this subsystem, **14 are soft coupling** (shared file formats). These are invisible to any static analysis tool — you can only discover them by reading the code and tracing data flow. This validates the research landscape finding (§2): soft coupling is the most valuable and hardest dependency type to capture.

**Concrete risk:** If `.budget-status` JSON gains a new field, or if `.restart-requested` changes format, no tool will flag the inconsistency. The only protection is "the developer who changes the writer also changes the readers" — which fails when the developer is an AI agent working across sessions.

### 2. Duplicated Constants Are a Smell

`checkpoint.sh` and `budget-gate.sh` both define the same three thresholds (120K/150K/170K) independently. This is a maintenance risk — changing one without the other causes subtle behavioral inconsistency. A Component Fabric card for this subsystem would flag this as a "shared constant without shared source."

### 3. The Execution Order Matters But Is Implicit

The `.claude/settings.json` hook configuration defines execution order implicitly through array position. For PreToolUse on Write/Edit: `check-active-task.sh` runs BEFORE `budget-gate.sh`. This ordering is significant — if reversed, a budget-blocked tool call would first show the "no active task" error, which is misleading. But this ordering constraint is nowhere documented.

### 4. Recovery Paths Create Hidden Cycles

The auto-handover path creates a cycle: `checkpoint.sh → handover.sh → git.sh commit → post-commit hook → checkpoint.sh reset`. The cycle is safe (reset clears the counter, preventing re-trigger), but it's only safe because of the cooldown guard. Without the cooldown, this cycle produced **23 handover commits** (historical bug). A topology map would surface this cycle for review.

### 5. The Transcript is the Single Point of Failure

Both C-001 and C-002 depend on the Claude Code JSONL transcript for token readings. If the transcript path changes, both break independently. They use similar-but-not-identical `find_transcript()` functions. C-001 scopes to the project directory; C-002 searches all projects. This divergence is a potential bug.

### 6. Component Count vs. Conceptual Simplicity

The subsystem has 11 components, 12+ data files, and 3 interaction flows. But conceptually it does one thing: "manage the context budget." This ratio (11:1 component-to-concept) suggests the subsystem could benefit from architectural review — or it suggests that the complexity is inherent in the problem (enforcement hooks, recovery paths, edge cases). A Component Fabric doesn't judge; it makes the complexity visible.

---

## What a Component Fabric Card Would Capture

Based on this manual mapping, here's what a **minimal viable component card** needs:

```yaml
# Hypothetical component card for budget-gate.sh
id: C-001
name: budget-gate
type: script
location: agents/context/budget-gate.sh
purpose: "Block tool execution when context tokens exceed critical threshold"
container: agents/context  # C4 level 2
subsystem: budget-management

interfaces:
  input:
    - type: stdin
      format: json
      schema: "Claude Code PreToolUse JSON (tool_name, tool_input)"
  output:
    - type: exit-code
      values: [0, 2]  # allow, block

dependencies:
  reads:
    - path: .context/working/.budget-status
      format: json
      fields: [level, tokens, timestamp, source]
      coupling: soft
    - path: "~/.claude/projects/*//*.jsonl"
      format: jsonl
      coupling: soft-external
  writes:
    - path: .context/working/.budget-status
      format: json
    - path: .context/working/.budget-gate-counter
      format: plain-integer

shared_constants:
  TOKEN_WARN: 120000
  TOKEN_URGENT: 150000
  TOKEN_CRITICAL: 170000
  # NOTE: duplicated in C-002 (checkpoint.sh)

created_by: T-138
last_verified: 2026-02-19
```

### Key Schema Decisions Surfaced

1. **`coupling: soft`** — Must distinguish import-based from file-format-based dependencies
2. **`shared_constants`** — Need a way to flag duplicated values across components
3. **`subsystem`** — Components cluster into subsystems; this is a natural grouping level
4. **`interfaces`** — stdin/stdout/exit-code for scripts; HTTP for web routes; function signatures for libraries
5. **`format` on dependencies** — The file format IS the interface contract for soft coupling
6. **`created_by`** — Task traceability links (already have this in git, but makes it queryable)

---

## Mapping Effort Assessment

| Metric | Value |
|--------|-------|
| Time to manually map | ~45 minutes of reading + ~30 minutes of writing |
| Components discovered | 11 |
| Soft coupling points | 14 |
| Hidden risks surfaced | 5 (duplicated constants, implicit ordering, recovery cycle, transcript divergence, format fragility) |
| Lines of source code read | ~1,700 |

**Would auto-generation have found these?** Static analysis (AST/grep) would find lexical dependencies (source/exec statements). Git co-change analysis might find semantic dependencies. But soft coupling (shared file formats) and operational dependencies (hook execution order) require understanding what the code DOES, not just what it REFERENCES. This is the gap Component Fabric must fill — and it suggests that auto-generation can handle maybe 40% of the topology, with human/AI review needed for the remaining 60%.

---

## Cross-References

- **Predecessor:** [T-191 Research Landscape](T-191-cf-research-landscape.md) — five dependency layers, C4 model, component manifests
- **Genesis:** [T-191 Genesis Discussion](T-191-cf-genesis-discussion.md) — problem statement, design principles
- **Task:** `.tasks/active/T-191-component-fabric--structural-topology-sy.md`

---

## Next: Phase 1c

With this concrete sample mapped, Phase 1c should research UI component documentation patterns — the web UI (`web/`) is a different beast from CLI scripts, with templates, routes, JavaScript event handlers, and API endpoints that need their own card format.
