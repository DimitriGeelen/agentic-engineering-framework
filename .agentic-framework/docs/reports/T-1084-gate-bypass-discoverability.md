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

## Second Incident — T-418 (/opt/025-WokrshopDesigner), 2026-04-11

A second session hit the same class of issue while trying to decide an inception task. Three new gates surfaced:

**Gate #12 — Inception review-marker gate (BROKEN)**
- Mechanism: `fw inception decide T-XXX` refuses to run unless `.context/working/.reviewed-T-XXX` marker exists
- Marker is created as a **side effect** of `fw task review T-XXX` (via `lib/review.sh:136`)
- Error message: `ERROR: Task review required before decision` — does NOT name the bypass
- Agent had to read source code (`lib/review.sh`, search for `reviewed-T`) to discover `fw task review` creates the marker
- **Fix:** Error should print `To unblock: cd /opt/... && bin/fw task review T-XXX`

**Gate #13 — Tier 0 on `fw inception decide` (GOOD, but misleading)**
- Mechanism: `check-tier0.sh` matches `fw\s.*inception\s.*decide` in destructive patterns (line 53)
- Error message: "INCEPTION DECISION: GO/NO-GO decisions require human authority..."
- This correctly blocks the agent from deciding, but the error message doesn't mention the `fw task review` prerequisite that the human will ALSO need
- When the human then runs `fw inception decide` themselves, they hit the separate review-marker gate (#12) and get a second confusing error
- **Fix:** Tier 0 message for inception decisions should include BOTH prerequisites: human authority + review marker

**UX issue #1 — Watchtower rationale textarea truncates at 500 chars**
- Location: `web/blueprints/inception.py:187`
- Problem: The inception form pre-fills the rationale textarea from the Recommendation section, but truncates at 500 chars with no expand affordance. The user saw "..." mid-word and reported "text is cut off!!!"
- Impact: Agents writing thorough recommendations (tables, evidence, reframings) must manually trim to ≤500 chars or the form shows truncated content. Fidelity loss between the Recommendation section (full markdown) and the decision form (truncated plain text).
- **NOT a gate bug** — form UX bug that interacts with the governance workflow
- **Fix options:** (a) remove truncation, (b) show "recommendation preview + [read full]" instead of pre-filling a textarea, (c) show a summary of the FIRST LINE only with a link to the Recommendation section rendered as markdown

**Coupling issue — Invisible marker lifecycle**
- `fw task review T-XXX` looks like a "print URL and QR code" command
- But it ALSO creates the review marker as an undocumented side effect
- The connection is not surfaced in either command's help or error output
- **Root cause:** side-effecting CLI commands that don't announce their side effects. If `fw task review` said "Created review marker .context/working/.reviewed-T-418 — this unblocks fw inception decide" in its output, the agent/user would understand the flow

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

**GO (reinforced after T-418 incident)** — Now **5 gates confirmed broken** (#6, #7, #8, #12, #13-partial), 1 partial (#10), plus one Watchtower UX bug and one invisible-side-effect coupling issue. The second incident on a different project confirms this is a pattern, not a one-off. Fix is still mostly mechanical.

**Updated scope:**
1. Fix the 3 original git hooks (T-1085/T-1086/T-1087 per earlier proposal)
2. Fix review-marker gate error message (#12) — add to same fix pass
3. Fix Tier 0 inception-decide message (#13) — add review-marker prerequisite
4. Project boundary gate — add TermLink workaround mention (#10)
5. Watchtower: remove 500-char truncation OR switch to "summary + link" pattern
6. `fw task review`: print marker creation as visible side effect
7. Bump hook VERSION, propagate to 11 consumers

**Pattern observation:** Gates 1-5 (Python scripts, PreToolUse hooks, update-task) are all GOOD. Gates 6-8, 12-13 (git hooks, inception flow) are all BROKEN. The divide is workflow: **gates written by agents working in-context** know what to print; **gates written during infrastructure setup** often use template language ("Emergency bypass (human only)") that sounds authoritative but wasn't tested end-to-end. This suggests a secondary preventive action: a test harness that fires each gate and captures the error output, human-reviews for clarity.

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
