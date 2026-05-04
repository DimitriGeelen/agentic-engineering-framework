---
id: T-1716
name: "Filing-time --recommendation gate on fw inception start (T-1715 implementation)"
description: >
  Filing-time --recommendation gate on fw inception start (T-1715 implementation)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:orchestrator-rethink, T-679-family, structural-gate, T-1715-implementation]
components: []
related_tasks: [T-679, T-1259, T-1260, T-1715, T-1668, T-1671]
created: 2026-05-04T10:47:53Z
last_update: 2026-05-04T10:47:53Z
date_finished: null
---

# T-1716: Filing-time --recommendation gate on fw inception start (T-1715 implementation)

## Context

Implements the GO decision on T-1715 (meta-RCA on agent files inception
artefacts without `## Recommendation` block). T-1715 was decided GO at
2026-05-04T09:56:18Z via Watchtower; this build task puts the structural
fix on the active board.

**T-1715 Recommendation summary:** add `--recommendation` /
`--rationale` flag pair to `fw inception start` (and `fw work-on
--type inception` plumb-through), mirroring T-1668's
`--headline-mechanic` gate at `fw arc create`. Filing-time enforcement
of the T-679 rule, symmetric to T-1259/T-1260's decide-time gate.

**Plus the post-decision sweep amendments (Paths 5–8):**
- Path 5 — manual sweep (executed 2026-05-04 in this session: T-1710 +
  T-1713 retrofitted).
- Path 6 — `fw audit` detective for template-only Recommendation
  bodies on active inceptions.
- Path 7 — Watchtower visual marker for "no recommendation" badge.
- Path 8 — retroactive retrofit on structural shipment (this task
  must sweep existing `active/` inceptions, not just gate new filings).

See `docs/reports/T-1715-meta-rca-inception-recommendation-decay.md`
and the Recommendation block of `.tasks/completed/T-1715-*.md` for
full rationale + risk acknowledged.

## Plan

Three deliverable streams. Each lands separately so partial progress is
useful.

### Stream A — filing-time gate (Path 1, ~50 LOC)

1. Add `--recommendation GO|NO-GO|DEFER` and `--rationale "..."` flags
   to `lib/inception.sh do_inception_start`.
2. Refuse filing without both flags under `$CLAUDECODE=1` (mirror of
   T-1259/T-1671 pattern — agent gets pointed to write Recommendation
   first).
3. On valid filing, write the Recommendation block directly into the
   task file (replacing the template comment block).
4. Plumb-through from `bin/fw work-on --type inception` so the
   one-step entry point gets the same gate.
5. Override flag `--i-am-human` for test/script contexts (mirror of
   T-1671 closure gate).

### Stream B — audit detective (Path 6, ~30 LOC)

1. Extend `agents/audit/audit.sh` with a `check_inception_recommendation_present`
   function: scans active inceptions, flags any whose `## Recommendation`
   body matches the template-comment pattern (`<!-- REQUIRED before fw
   inception decide`).
2. Emit WARN with mitigation "Add real Recommendation: GO/NO-GO/DEFER
   block (use `fw inception start --recommendation X --rationale ...`
   for new filings)".

### Stream C — retroactive sweep (Path 8, one-shot script)

1. `lib/inception.sh do_inception_sweep` — enumerates `.tasks/active/T-*.md`
   for inceptions with template-only Recommendation; for each, generates
   a DEFER stub Recommendation with rationale "captured pre-gate, no
   exploration done; promotion criterion: re-surface when [hand-edit]".
2. Operator review required before commit — does NOT auto-mutate; emits
   diff and asks for `--apply`.

## Acceptance Criteria

### Agent
- [x] **A1** `fw inception start "name"` without `--recommendation` /
  `--rationale` exits non-zero under `$CLAUDECODE=1` and prints the
  required-flag message.
- [x] **A2** `fw inception start "name" --recommendation GO --rationale "..."`
  succeeds and the resulting task file has a real Recommendation block
  (not the template-comment placeholder).
- [x] **A3** `fw work-on "name" --type inception` plumbs through Stream
  A's gate (no template-only Recommendation can ship via the one-step
  entry point either).
- [x] **A4** Override flag `--i-am-human` allows scripted/test filing
  without the gate, and is logged via `log_gate_bypass`.
- [x] **A5** `fw audit` (Stream B) emits WARN for any active inception
  with template-only Recommendation body.
- [ ] **A6** `fw inception sweep` (Stream C) lists all such inceptions
  and produces a diff; `--apply` mutates files; without `--apply` it
  is read-only.
- [x] **A7** Bats coverage: ≥1 test per AC, written and passing.
- [ ] **A8** Sweep amendment self-check: after this task ships, `fw
  audit` reports zero active inceptions with template-only
  Recommendation bodies.

### Human
- [ ] [REVIEW] Confirm filing-time gate UX is not too noisy (review
  one fresh `fw inception start` invocation; the error message should
  be actionable, not punitive).
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception start "test sample"`
  2. Observe the error message
  3. Try the suggested syntax: `bin/fw inception start "test sample" --recommendation DEFER --rationale "smoke test"`
  4. Verify the resulting task file in `.tasks/active/` has the Recommendation block populated
  **Expected:** Error message includes both flag names + an example invocation. Task file has real Recommendation, not template comment.
  **If not:** Note the missing/confusing element; agent reworks the message.

## Verification

bats tests/unit/inception_start_recommendation_gate.bats
CLAUDECODE=1 bin/fw inception start "verify-gate-fires" 2>&1 | grep -qE "recommendation.*required|--recommendation"

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-04T10:47:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1716-filing-time---recommendation-gate-on-fw-.md
- **Context:** Initial task creation
