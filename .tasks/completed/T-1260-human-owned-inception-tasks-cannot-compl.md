---
id: T-1260
name: "Human-owned inception tasks cannot complete — 5 layered root causes (sovereignty,
  dispatch, template drift, recommendation gate, tier0 hash)"
description: >
  Inception: Human-owned inception tasks cannot complete — 5 layered root causes (sovereignty,
  dispatch, template drift, recommendation gate, tier0 hash)

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-14T23:01:08Z
last_update: '2026-06-11T22:23:44Z'
date_finished: 2026-04-18T22:43:53Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1260: Human-owned inception tasks cannot complete — 5 layered root causes (sovereignty, dispatch, template drift, recommendation gate, tier0 hash)

## Problem Statement

Cross-session report (high-priority, 2026-04-15): inception tasks with
`owner: human` cannot be completed through any available pathway. Decision is
recorded (multiple times in some cases) but status stays stuck at
`started-work`. Observed layered failure across five distinct surfaces:

| Path tried | Result |
|-----------|--------|
| `fw inception decide T-002 go` (CLI, agent-run) | Tier 0 block — requires human approval |
| `fw tier0 approve` + retry (CLI) | Retry hits Tier 0 again — hash drift or approval consumed |
| Watchtower /inception/T-XXX → click GO | Decision block written. Status does NOT transition. Error truncated to "Task Update ... F" |
| `fw task update T-XXX --status work-completed` (agent) | Sovereignty gate R-033 blocks: "Cannot complete human-owned task" |
| `fw task review T-XXX` | Dispatch script missing: `/tmp/tl-dispatch/fabric-purpose-fill/run.sh` |

Contrast: T-006 (also `owner: human`) transitioned cleanly because the decide
was run directly from the human's terminal (no agent identity, no Watchtower).

**Result:** decision recorded repeatedly (T-002 has 3+ duplicated inception-decision
blocks from multiple Watchtower clicks), status never advances.

## Assumptions

- A1: The five root causes are independent but compound — fixing any one alone leaves task completion still broken
- A2: Watchtower backend runs with agent-identity (not human-identity via session auth)
- A3: The dispatch script missing is the same class as T-007 (not-yet-diagnosed dispatch path bug)
- A4: Template drift is finite — only older inception tasks are missing `## Decision` / `## Recommendation` headers
- A5: Tier 0 hash drift is reproducible given two identical-looking invocations

## Exploration Plan

- **Spike A (20min) — Sovereignty gate asymmetry:** Trace how Watchtower `/inception/T-XXX/decide` POST reaches update-task.sh. Is there any identity signal that could bypass R-033 when the request comes from Watchtower's web session? Examine `web/blueprints/inception.py`.
- **Spike B (15min) — Dispatch script materialization:** Find every `/tmp/tl-dispatch/*/run.sh` reference in the codebase. What's supposed to write these scripts? Why did `fabric-purpose-fill/run.sh` not materialize? Link to T-007.
- **Spike C (10min) — Template completeness:** Audit `.tasks/templates/inception.md` and all template variants. Confirm every new inception has `## Decision`, `## Recommendation`, `## Updates` sections. Test: `fw task create --type inception` and grep output.
- **Spike D (5min) — Recommendation gate ordering:** The `## Recommendation required` gate fires on decide. Is the decide flow calling the gate before the recommendation-writer (Watchtower) has finished writing?
- **Spike E (20min) — Tier 0 hash drift:** Look at `lib/tier0.sh` (or equivalent) to understand hash normalisation. Test: run same command twice, compare hashes. If drift is present, identify the non-deterministic input (whitespace, timestamps, env var).
- **Spike F (10min) — Workaround validation:** Confirm the "human runs decide from own terminal" workaround actually works (proven for T-006). Document it as a stopgap until the structural fixes ship.

## Technical Constraints

- Watchtower HTTP backend is Flask (web/app.py), Python 3.12 — identity propagation via session cookie would require flask-login or equivalent wiring
- Tier 0 approve machinery: `.context/working/.tier0-approved-*` hash files (transient)
- R-033 rule lives in update-task.sh:~200 (sovereignty gate)
- Dispatch scripts under `/tmp/tl-dispatch/` — Claude TermLink integration surface, per-session ephemeral
- Data loss risk: duplicate decision blocks mean if we auto-dedupe we might lose the human's latest choice

## Scope Fence

**IN:**
- Why each of the 5 root causes fires
- Minimal intervention to unblock *immediate* human-inception-completion
- Recommendation on which root causes get own bugfix tasks vs. bundled

**OUT:**
- Rewriting the inception workflow end-to-end (would be a separate design task)
- Tier 0 approval redesign (R-033 specifically in scope, Tier 0 generally out)
- Watchtower auth overhaul (session cookies, flask-login adoption — noted as follow-up)

## Acceptance Criteria

### Agent
- [x] Spike A complete: sovereignty gate asymmetry traced — CLAUDECODE inheritance regression confirmed (T-1259 blocks Watchtower decide)
- [x] Spike B complete: dispatch script origin identified — `fabric-purpose-fill` is stale worker reference, no in-codebase definition; class L-006 again
- [x] Spike C complete: template completeness audit done — current template OK, older tasks need backfill
- [x] Spike D complete: recommendation gate ordering diagnosed — order is correct, but Decision block writer is non-idempotent (root of T-002's duplicates)
- [x] Spike E complete: Tier 0 hash drift root cause — raw command hashed without whitespace/quote normalization
- [x] Spike F complete: human-terminal workaround verified — T-006 case confirms the path works; documented
- [x] Research artifact written to `docs/reports/T-1260-human-inception-completion.md`
- [x] Recommendation with GO/NO-GO/DEFER + concrete bugfix task list for build follow-up (B1-B9 with P0/P1/P2/P3 tags)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** Five distinct failure surfaces identified across the inception-completion path. Most critical (P0) is a regression from my own T-1259 commit (`4589bc60`) — `lib/inception.sh:204` CLAUDECODE guard fires on Watchtower-driven decisions because Flask inherits `CLAUDECODE=1` from its parent Claude Code shell (`web/subprocess_utils.py:51` passes `{**os.environ, ...}`). The fix is bounded (~30 LOC for B1-B3): pass `--from-watchtower` flag from `inception.py` to `fw inception decide`, exempt that flag from the guard. P1 fixes (B4-B5) prevent the T-002 stuck-state compounding (3+ duplicate Decision blocks from repeated clicks). Workaround validated: human's own terminal (no `CLAUDECODE` env) bypasses all five surfaces — T-006 transitioned cleanly via that path.

**Evidence:**
- `web/subprocess_utils.py:51` — `env={**os.environ, ...}` inherits CLAUDECODE in subprocess
- `echo $CLAUDECODE` in current session returns `1` — every fw subprocess inherits this
- `lib/inception.sh:204` (T-1259) blocks on CLAUDECODE=1 unless `--i-am-human` passed; `web/blueprints/inception.py:411` does not pass any human-identity flag → **regression confirmed**
- `lib/inception.sh:336` comment: `--skip-sovereignty` bypasses ONLY R-033, NOT P-010 (AC gate) or P-011 (verification gate) — explains "Status does NOT transition" when Agent ACs unchecked
- `lib/inception.sh:295-318` Decision block writer appends rather than replacing → multiple clicks compound
- `agents/context/check-tier0.sh:167` hashes raw command string (no normalization) → whitespace/quote drift between retries
- `.tasks/templates/inception.md` confirmed has all three required sections; older inception tasks may need backfill (B7)
- `grep -r fabric-purpose-fill` finds zero non-task references → stale worker name, recoverable
- T-006 case validates workaround: direct human terminal bypasses CLAUDECODE+Watchtower+R-033 entirely

**Critical interim warning (until B1-B2 ship):**
> Watchtower GO/NO-GO buttons are likely broken for any session where Watchtower was started inside a Claude Code shell. Use human's own terminal:
> ```bash
> cd /path/to/project && [bin/fw|.agentic-framework/bin/fw] inception decide T-XXX go --rationale "..."
> ```

**Research artifact:** `docs/reports/T-1260-human-inception-completion.md` (full 6-spike findings, build decomposition B1-B9 with P0/P1/P2/P3 priority tags).

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Five distinct failure surfaces identified across the inception-completion path. Most critical (P0) is a regression from my own T-1259 commit (`4589bc60`) — `lib/inception.sh:204` CLAUDECODE guard fires on Watchtower-driven decisions because Flask inherits `CLAUDECODE=1` from its parent Claude Code shell (`web/subprocess_utils.py:51` passes `{os.environ, ...}`). The fix is bounded (~30 LOC for B1-B3): pass `--from-watchtower` flag from `inception.py` to `fw inception decide`, exempt that flag from the guard. P1 fixes (B4-B5) prevent the T-002 stuck-state compounding (3+ duplicate Decision blocks from repeated clicks). Workaround validated: human's own terminal (no `CLAUDECODE` env) bypasses all five surfaces — T-006 transitioned cleanly via that path.

Evidence:
- `web/subprocess_utils.py:51` — `env={os.environ, ...}` inherits CLAUDECODE in subprocess
- `echo $CLAUDECODE` in current session returns `1` — every fw subprocess inherits this
- `lib/inception.sh:204` (T-1259) blocks on CLAUDECODE=1 unless `--i-am-human` passed; `web/blueprints/inception.py:411` does not pass any human-identity flag → regression confirmed
- `lib/inception.sh:336` comment: `--skip-sovereignty` bypasses ONLY R-033, NOT P-010 (AC gate) or P-011 (verification gate) — explains "Status does NOT transition" when Agent ACs unchecked
- `lib/inception.sh:295-318` Decision block writer appends rather than replacing → multiple clicks compound
- `agents/context/check-tier0.sh:167` hashes raw command string (no normalization) → whitespace/quote drift between retries
- `.tasks/templates/inception.md` confirmed has all three required sections; older inception tasks may need backfill (B7)
- `grep -r fabric-purpose-fill` finds zero non-task references → stale worker name, recoverable
- T-006 case validates workaround: direct human terminal bypasses CLAUDECODE+Watchtower+R-033 entirely

Critical interim warning (until B1-B2 ship):
> Watchtower GO/NO-GO buttons are likely broken for any session where Watchtower was started inside a Claude Code shell. Use human's own terminal:
> ```bash
> cd /path/to/project && [bin/fw|.agentic-framework/bin/fw] inception decide T-XXX go --rationale "..."
> ```

Research artifact: `docs/reports/T-1260-human-inception-completion.md` (full 6-spike findings, build decomposition B1-B9 with P0/P1/P2/P3 priority tags).

**Date**: 2026-04-18T22:44:19Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-14T23:02:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-18T22:43:52Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Five distinct failure surfaces identified across the inception-completion path. Most critical (P0) is a regression from my own T-1259 commit (`4589bc60`) — `lib/inception.sh:204` CLAUDECODE guard fires on Watchtower-driven decisions because Flask inherits `CLAUDECODE=1` from its parent Claude Code shell (`web/subprocess_utils.py:51` passes `{os.environ, ...}`). The fix is bounded (~30 LOC for B1-B3): pass `--from-watchtower` flag from `inception.py` to `fw inception decide`, exempt that flag from the guard. P1 fixes (B4-B5) prevent the T-002 stuck-state compounding (3+ duplicate Decision blocks from repeated clicks). Workaround validated: human's own terminal (no `CLAUDECODE` env) bypasses all five surfaces — T-006 transitioned cleanly via that path.

Evidence:
- `web/subprocess_utils.py:51` — `env={os.environ, ...}` inherits CLAUDECODE in subprocess
- `echo $CLAUDECODE` in current session returns `1` — every fw subprocess inherits this
- `lib/inception.sh:204` (T-1259) blocks on CLAUDECODE=1 unless `--i-am-human` passed; `web/blueprints/inception.py:411` does not pass any human-identity flag → regression confirmed
- `lib/inception.sh:336` comment: `--skip-sovereignty` bypasses ONLY R-033, NOT P-010 (AC gate) or P-011 (verification gate) — explains "Status does NOT transition" when Agent ACs unchecked
- `lib/inception.sh:295-318` Decision block writer appends rather than replacing → multiple clicks compound
- `agents/context/check-tier0.sh:167` hashes raw command string (no normalization) → whitespace/quote drift between retries
- `.tasks/templates/inception.md` confirmed has all three required sections; older inception tasks may need backfill (B7)
- `grep -r fabric-purpose-fill` finds zero non-task references → stale worker name, recoverable
- T-006 case validates workaround: direct human terminal bypasses CLAUDECODE+Watchtower+R-033 entirely

Critical interim warning (until B1-B2 ship):
> Watchtower GO/NO-GO buttons are likely broken for any session where Watchtower was started inside a Claude Code shell. Use human's own terminal:
> ```bash
> cd /path/to/project && [bin/fw|.agentic-framework/bin/fw] inception decide T-XXX go --rationale "..."
> ```

Research artifact: `docs/reports/T-1260-human-inception-completion.md` (full 6-spike findings, build decomposition B1-B9 with P0/P1/P2/P3 priority tags).

### 2026-04-18T22:43:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-18T22:44:19Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Five distinct failure surfaces identified across the inception-completion path. Most critical (P0) is a regression from my own T-1259 commit (`4589bc60`) — `lib/inception.sh:204` CLAUDECODE guard fires on Watchtower-driven decisions because Flask inherits `CLAUDECODE=1` from its parent Claude Code shell (`web/subprocess_utils.py:51` passes `{os.environ, ...}`). The fix is bounded (~30 LOC for B1-B3): pass `--from-watchtower` flag from `inception.py` to `fw inception decide`, exempt that flag from the guard. P1 fixes (B4-B5) prevent the T-002 stuck-state compounding (3+ duplicate Decision blocks from repeated clicks). Workaround validated: human's own terminal (no `CLAUDECODE` env) bypasses all five surfaces — T-006 transitioned cleanly via that path.

Evidence:
- `web/subprocess_utils.py:51` — `env={os.environ, ...}` inherits CLAUDECODE in subprocess
- `echo $CLAUDECODE` in current session returns `1` — every fw subprocess inherits this
- `lib/inception.sh:204` (T-1259) blocks on CLAUDECODE=1 unless `--i-am-human` passed; `web/blueprints/inception.py:411` does not pass any human-identity flag → regression confirmed
- `lib/inception.sh:336` comment: `--skip-sovereignty` bypasses ONLY R-033, NOT P-010 (AC gate) or P-011 (verification gate) — explains "Status does NOT transition" when Agent ACs unchecked
- `lib/inception.sh:295-318` Decision block writer appends rather than replacing → multiple clicks compound
- `agents/context/check-tier0.sh:167` hashes raw command string (no normalization) → whitespace/quote drift between retries
- `.tasks/templates/inception.md` confirmed has all three required sections; older inception tasks may need backfill (B7)
- `grep -r fabric-purpose-fill` finds zero non-task references → stale worker name, recoverable
- T-006 case validates workaround: direct human terminal bypasses CLAUDECODE+Watchtower+R-033 entirely

Critical interim warning (until B1-B2 ship):
> Watchtower GO/NO-GO buttons are likely broken for any session where Watchtower was started inside a Claude Code shell. Use human's own terminal:
> ```bash
> cd /path/to/project && [bin/fw|.agentic-framework/bin/fw] inception decide T-XXX go --rationale "..."
> ```

Research artifact: `docs/reports/T-1260-human-inception-completion.md` (full 6-spike findings, build decomposition B1-B9 with P0/P1/P2/P3 priority tags).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fb570aa1
- **Timestamp:** 2026-06-02T14:56:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
