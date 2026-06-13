---
id: T-2383
name: "CTL-030 FAIL: completed tasks store horizon=now + missing episodics + horizon-clear prevention"
description: >
  Two arc-012 completed tasks (T-2364/T-2365) store horizon: now triggering CTL-030 FAIL; 3 completed tasks (T-2364/T-2365/T-2351) lack episodics. Root cause: the OBS-072 git-mv bypass (files moved to completed/ without fw task update, so update-task.sh's existing horizon-null normalization never ran); T-2370 fixed status but deferred horizon. Fix the data; prevention already exists (line 1791 + tests).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [audit, governance, completion-hygiene]
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-06-13T22:48:18Z
last_update: 2026-06-13T22:48:18Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
---

# T-2383: CTL-030 FAIL: completed tasks store horizon=now + missing episodics + horizon-clear prevention

## Context

Remediation R1 from `.context/working/audit-remediation-plan-2026-06-14.md`. The full
audit (`bin/fw audit`, exit 2) emitted CTL-030 FAILs for two completed arc-012 tasks
(T-2364/T-2365) that store `horizon: now` in `.tasks/completed/` (CTL-030, T-2160,
expects null/absent there), plus episodic-gap WARNs for T-2364/T-2365/T-2351. This task
fixes the data (horizon + episodics). Investigation found the completion-time prevention
**already exists** (update-task.sh:1791, T-2163/T-2300) — the FAIL came from the OBS-072
git-mv bypass, not a missing normalization (see ## RCA). No new prevention code is warranted.

## Acceptance Criteria

### Agent
- [x] `.tasks/completed/T-2364*.md` and `T-2365*.md` no longer store `horizon: now` (set to `horizon: null`); `fw audit` CTL-030 count for them = 0
- [x] Episodic summaries exist for T-2364, T-2365, T-2351 (generated via `fw context generate-episodic`)
- [x] Confirm the completion-time prevention **already exists** (update-task.sh:1791, T-2163/T-2300 — nulls horizon on work-completed outside the move-conditional) and is **already tested** (`update_task_horizon_null_on_close.bats`, `test_update_task_horizon_null_reclose.bats`); **no new code needed** — adding any would be redundant
- [x] RCA corrected: the FAIL came from the OBS-072 **git-mv bypass** (file moved to completed/ without `fw task update`, so line 1791 never ran), which T-2370 partially fixed (status field) while explicitly deferring the sibling horizon drift — not from a missing normalization
- [x] Existing horizon/CTL-030 test suites still green; reviewer PASS (R-ddb59c42)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
#
# --- R1 verification ---
# Data fix: completed T-2364/T-2365 must not store `horizon: now`.
! grep -Eq '^horizon:[[:space:]]*now' .tasks/completed/T-2364-t-2158-s2-sessionstart-resume-reads-dire.md
! grep -Eq '^horizon:[[:space:]]*now' .tasks/completed/T-2365-t-2158-s3-run-length-cap--continuous-mod.md
# Episodics exist for the three gap tasks.
test -f .context/episodic/T-2364.yaml
test -f .context/episodic/T-2365.yaml
test -f .context/episodic/T-2351.yaml
# Prevention already exists (T-2163/T-2300) at update-task.sh — confirm the write-path line is present.
grep -q 'horizon: null' agents/task-create/update-task.sh
# Existing prevention tests still green (no new code added — these cover line 1791).
# (Exit code is the gate signal; output left visible so the gate surfaces failures.)
bats tests/unit/update_task_horizon_null_on_close.bats
bats tests/unit/test_update_task_horizon_null_reclose.bats

## RCA

**Symptom:** Two completed arc-012 tasks (T-2364/T-2365) store `horizon: now` in
`.tasks/completed/`. The CTL-030 detector (T-2160) derives the location-state ('past')
from `_location` and expects the stored `horizon` field to be null/absent for completed
tasks → CTL-030 FAIL. Three completed tasks (T-2364/T-2365/T-2351) also lack episodic
summaries.

**Root cause (CORRECTED — the plan's original RCA was wrong):** the completion-time
normalization is **not** missing. `update-task.sh:1791` (T-2163, with the T-2300 leg-gap
fix lifting it *outside* the move-conditional) already runs
`_sed_i "s/^horizon:.*/horizon: null/"` on every `--status work-completed`, and it is covered
by `tests/unit/update_task_horizon_null_on_close.bats` (4 tests) +
`tests/unit/test_update_task_horizon_null_reclose.bats`.

The real cause is the **OBS-072 git-mv bypass**: T-2364 (S2) and T-2365 (S3) were moved to
`.tasks/completed/` via raw `git mv` in their ship commits (ee76ec7c5 / 606ce7c2b) **without**
`fw task update --status work-completed`. Because update-task.sh was never invoked, *none* of
its completion-time normalization ran — status stayed drifted, horizon stayed `now`, and no
episodic was generated. T-2370 later fixed OBS-072 but only the **status** field (edited
`status:` directly in the completed file) and explicitly left the sibling horizon drift "as a
separate concern" (T-2370 RCA, line 146). CTL-030 then correctly flagged the leftover
`horizon: now`. Missing episodics are the same bypass: episodic-gen lives in update-task.sh's
completion path, which the git-mv skipped.

**Why structurally allowed:** a raw `git mv` of a task file into `completed/` cannot be
intercepted by update-task.sh (the script isn't called). arc-009 deliberately chose
*detection* (CTL-030 audit rail) + an idempotent `bin/migrate-horizon-null-completed.sh` as
the prevention model for exactly this bypass class, rather than trying to gate git itself.

**Prevention:** already in place and working — CTL-030 (T-2162) *detected* this drift (that's
how it surfaced in the audit), the write-path normalization (T-2163/T-2300) handles every
non-bypass close, and the episodic-gap check in handover flagged the missing summaries. The
durable lesson is that **partial fixes of a multi-field drift leave siblings behind**: T-2370
fixed status but not horizon/episodics. This task closes those two remaining siblings; no new
code is warranted (would duplicate line 1791 + its tests).

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-13T22:48:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2383-ctl-030-fail-completed-tasks-store-horiz.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ddb59c42
- **Timestamp:** 2026-06-13T22:58:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
