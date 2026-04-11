# T-1084: Gate Bypass Discoverability — Research Artifact

**Status:** inception (exploration phase)
**Created:** 2026-04-11
**Origin:** Real-world incident on /opt/termlink, T-908 session. Agent hit inception commit-msg gate, suggested `fw tier0 approve` as bypass, user ran it and got "No pending Tier 0 block to approve". Correct bypass was `git commit --no-verify`.

## Problem Statement

The framework has multiple independent gates that block agent actions, each with a different bypass mechanism. When a gate fires, its error message typically does NOT print the exact bypass command. The agent is expected to remember the taxonomy (which gate → which bypass) and often guesses wrong, creating friction for the user.

**Observed failure mode:**
1. Gate blocks commit
2. Agent guesses bypass (e.g., `fw tier0 approve`)
3. User runs it
4. New error ("No pending Tier 0 block")
5. Agent corrects itself
6. User runs the right command

This is a 2x round-trip for something that should be 0 round-trips — the gate's own error message should have told the user exactly what to do.

## Known Gates Inventory (audited 2026-04-11)

| # | Gate | Enforcement point | Bypass mechanism | Status |
|---|------|-------------------|------------------|--------|
| 1 | Tier 0 Bash (destructive commands) | PreToolUse `check-tier0.sh` | `fw tier0 approve` | **GOOD** — prints bypass (line 377) |
| 2 | Task-first gate (no active task) | PreToolUse `check-active-task.sh` | `fw work-on T-XXX` | **GOOD** — prints bypass (line 167-169) |
| 3 | Build readiness G-020 (placeholder ACs) | PreToolUse `check-active-task.sh` | Edit ACs or `--type inception` | **GOOD** — prints bypass (line 341-344) |
| 4 | Verification gate P-011 | `update-task.sh --status work-completed` | `--force` | **GOOD** — prints bypass (line 230-232) |
| 5 | Completion gate P-010 (unchecked ACs) | `update-task.sh --status work-completed` | `--force` | **GOOD** — prints bypass (line 104-105) |
| 6 | Inception commit-msg gate (2+ exploration commits) | `commit-msg` git hook | `git commit --no-verify` | **BROKEN** — prints misleading `fw tier0 approve` (hooks.sh:128-130) |
| 7 | Pre-push audit gate (FAIL) | `pre-push` git hook | `git push --no-verify` | **BROKEN** — same misleading `fw tier0 approve` (hooks.sh:377-379) |
| 8 | Commit-msg task-ref gate (no T-XXX) | `commit-msg` git hook | `git commit --no-verify` | **BROKEN** — same misleading `fw tier0 approve` (hooks.sh:75-79) |
| 9 | Inception research-artifact gate (C-001) | `commit-msg` git hook | `git commit --no-verify` | **GOOD** — just says `git commit --no-verify` (hooks.sh:169) |
| 10 | Project boundary (cross-project writes) | PreToolUse `check-project-boundary.sh` | No bypass — use TermLink | **PARTIAL** — says "restricted" but doesn't mention TermLink workaround |
| 11 | Budget gate (context critical) | PreToolUse `budget-gate.sh` | No bypass — wrap up | **GOOD** — lists allowed operations clearly |

## Audit Findings

**The T-908 root cause is a repeated copy-paste bug.** Three separate git-hook gates (#6, #7, #8) all print the same misleading recipe:

```
Emergency bypass (human only):
  fw tier0 approve
  git commit --no-verify
```

This recipe is wrong in both contexts:
- **Agent running `git commit --no-verify` via Bash tool:** Tier 0 PreToolUse hook fires at the Bash tool level BEFORE the git hook ever runs. So the agent does need `fw tier0 approve` — but for the Bash command, not for the commit-msg hook. The commit-msg hook itself never even executes in agent context because Tier 0 intercepts first.
- **Human running `git commit --no-verify` in their own terminal:** Tier 0 is a Claude Code PreToolUse hook, not a shell-level check. It doesn't fire. `fw tier0 approve` returns "No pending Tier 0 block to approve" and, worse, `fw tier0 approve && git commit --no-verify` fails the chain (what T-908 hit).

So the `fw tier0 approve` line in these three hooks is **useless in both contexts** and **actively harmful** (blocks the `&&` chain with exit 1).

The research artifact enforcement gate (#9) in the SAME file gets it right — just says `git commit --no-verify`. That's the pattern to copy.

## Proposed Fix (minimal)

**Scope:** 3 git hook messages in `agents/git/lib/hooks.sh` and the mirrored `.agentic-framework/` copy. Replace:
```
Emergency bypass (human only):
  fw tier0 approve
  git commit --no-verify
```
with:
```
Bypass (human in terminal): git commit --no-verify
(Agent via Claude Code: Tier 0 gate will prompt for approval on --no-verify.)
```

**Also:** Update project boundary gate (#10) to mention TermLink workaround:
```
To intentionally operate on another project: use TermLink
  fw termlink dispatch --name worker --project /opt/other --prompt '...'
```

**Out of scope for initial fix:**
- `fw gates` inventory command (nice-to-have, separate task)
- Unified `fw bypass` command (requires design, separate inception)
- Context-aware `fw tier0 approve` suggestions (separate task)

## Decision

**GO** — 3 gates confirmed broken (#6, #7, #8), 1 partial (#10). Fix is mechanical: edit 4 error messages in hooks.sh, bump hook VERSION, propagate to 11 consumer projects. Each git hook change is one bug = one task per framework rules; TermLink addition to boundary gate is separate.

## Impact Analysis

**Agent burden:** Must remember 10 gates × 4 bypass paths and map correctly. Error-prone — T-908 incident confirmed.

**User burden:** Wasted command execution, confusing error chains, trust erosion ("the agent doesn't know its own tooling").

**Framework reputation:** Governance gates are valuable, but if they're hostile to debug, users learn to bypass them wholesale rather than work with them.

## Proposed Direction

**Primary:** Every gate's block message must include the exact bypass command, copy-pasteable, with full `cd` prefix per the Copy-Pasteable Commands rule (T-609).

Template for all gate error messages:
```
======================================================
  [GATE NAME] BLOCK — [brief reason]
======================================================

  [context: what was attempted, what failed]

  To bypass:
    [exact copy-pasteable command]

  Or to resolve structurally:
    [alternative: what the agent should do instead]

  Policy: [ref]
======================================================
```

**Secondary:** `fw tier0 approve` and other bypass commands should be context-aware. When invoked without a pending block, they should look at recent gate failures (from a shared log) and suggest the likely-intended action.

**Tertiary:** A `fw gates` CLI command that lists all gates, their fire conditions, and bypass paths. For agent self-serve reference instead of memory-based guessing.

## Exploration Plan

1. **Audit each gate's current error output** — run each gate in a controlled test, capture block message, assess bypass clarity.
2. **Identify gaps** — which gates don't print their bypass command at all.
3. **Design the standard template** — pick one format, apply consistently.
4. **Scope the fix** — estimate LOC impact per gate.

## Dialogue Log

### 2026-04-11 — user reports incident
- **User showed:** Transcript from /opt/termlink T-908 session where agent suggested `fw tier0 approve` for an inception commit-msg gate block. User ran it, got "No pending Tier 0 block to approve". Agent corrected: bypass is `--no-verify`.
- **User asked:** "Can you reflect on this, is there a systemic improvement possible?"
- **Agent response:** Identified root cause (gate blocks without naming its bypass), proposed primary fix (error messages print exact bypass), secondary fix (context-aware `fw tier0 approve`), tertiary (`fw gates` inventory command).
- **User answer:** "yes" to creating inception task.

## Open Questions

- Q1: Do we want ONE unified `fw bypass` command that handles all gates, or keep the native per-gate bypasses (`--force`, `--no-verify`, etc.) but improve error messages? Native preserves the mechanism, unified hides complexity but adds indirection.
- Q2: Should the context-aware `fw tier0 approve` be a separate feature (`fw bypass suggest`), or folded into existing commands?
- Q3: Is there value in logging gate-block events to `.context/working/` so they can be queried after the fact (`fw gates log`)?

## Go/No-Go Criteria

- **GO if:** Audit confirms 3+ gates lack bypass command in their error output AND the fix is mechanical (template + targeted edits) AND no existing infra needs redesign.
- **DEFER if:** Fewer than 3 gates are affected (it's a one-off fix, not a pattern).
- **NO-GO if:** Every gate already prints its bypass and the T-908 incident was caused by agent error ignoring what was printed (in which case the fix is the agent, not the gates).

## Next Steps (if GO)

1. Create build task for error message template.
2. Create build tasks per-gate for message updates (one per gate, per "one bug = one task" rule).
3. Optional build task for `fw gates` inventory command.
4. Optional inception task for unified `fw bypass` vs per-gate — needs more design.
