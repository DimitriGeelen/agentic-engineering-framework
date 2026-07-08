---
id: T-2121
name: "T-2091 RCA prevention follow-up: structural detector for active↔completed task-id
  collisions. Three prongs surfaced: (1) PreToolUse hook on Write|Edit to .tasks/active/T-*.md
  that checks .tasks/completed/T-NNNN-*.md and refuses if same id present (write-time
  block); (2) BVP estimator + last_update bumper worker — cross-check .tasks/completed/
  before mutating any .tasks/active/ file (prevents masking by metadata churn); (3)
  bin/fw doctor — surface untracked files in .tasks/{active,completed}/ (currently
  doctor doesn't look here, so 7-day-orphaned completion content was invisible). Filing
  as separate task per 'one bug = one task' since the cleanup (T-2091) and the prevention
  are independent."
description: >
  Promoted from observation OBS-035

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: [T-2516, T-2517]
inception_decisions:
  - id: prong-3-doctor-untracked
    text: "fw doctor WARNs on untracked T-*.md under .tasks/{active,completed}/ — closes the 7-day mask window"
    ships_in: deferred:T-2516
  - id: prong-1-dedup-hook
    text: "PreToolUse hook blocks a same-id active/completed duplicate at write time (bypass for fw task update git-mv)"
    ships_in: deferred:T-2517
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
target_blast_radius: 3
voi_score: 0.4
created: 2026-05-30T20:16:09Z
last_update: 2026-07-08T06:38:50Z
date_finished:
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
cost_estimate_proposed:
  - ts: '2026-06-05T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-10T09:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T09:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-12T10:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-05T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 4
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=4 (body:rubric-routable)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-10T09:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F1=2 
      (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:32Z'
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
  - ts: '2026-06-13T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F-AUTONOMY=2 
      (no-signal); F3=2 (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-07T10:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2121: T-2091 RCA prevention follow-up: structural detector for active↔completed task-id collisions. Three prongs surfaced: (1) PreToolUse hook on Write|Edit to .tasks/active/T-*.md that checks .tasks/completed/T-NNNN-*.md and refuses if same id present (write-time block); (2) BVP estimator + last_update bumper worker — cross-check .tasks/completed/ before mutating any .tasks/active/ file (prevents masking by metadata churn); (3) bin/fw doctor — surface untracked files in .tasks/{active,completed}/ (currently doctor doesn't look here, so 7-day-orphaned completion content was invisible). Filing as separate task per 'one bug = one task' since the cleanup (T-2091) and the prevention are independent.

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Inception decision recorded (GO / NO-GO / DEFER) on whether to ship any of the three prongs from the task body — (1) PreToolUse hook on Write|Edit refusing same-id duplicates between `.tasks/active/` and `.tasks/completed/`, (2) BVP estimator + last_update bumper cross-check before mutating `.tasks/active/` files, (3) `bin/fw doctor` surfacing untracked files in `.tasks/{active,completed}/`.
- [x] If GO: each prong filed as its own build task (per "one bug = one task") with `unlocks_inception_decision: [T-2121:<decision-id>]` traceability. If NO-GO or DEFER: rationale recorded in `## Recommendation` block citing why the T-2091 cleanup pattern is sufficient without structural prevention, or what evidence would push the next revisit toward GO.

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

**Decision**: GO

**Rationale**: The active↔completed task-id divergence class has a detection-only control
(G-052 STRUCTURE audit "No duplicate task IDs") that fires *after* the divergence
is committed and only at audit time — which is why the T-2091 origin surfaced 7
days late and at the worst moment (a pre-push gate that stranded a handover
commit). There is **no** write-time prevention and **no** early `fw doctor`
surface (verified: no dedup hook in `agents/context/`, no untracked-`.tasks/`
check in `audit.sh`/`bin/fw`). The class has **recurred** — `T-100202` is active
today — so "cleanup when it happens" is demonstrably insufficient. Prong 3 is
cheap/low-risk (read-only `git status --porcelain .tasks/`); prong 1 is moderate
(must not block the legitimate `fw task update --status work-completed` git-mv
path). Prong 2 (bumper cross-check) is deferred: once 1+3 exist the metadata-worker
masking is largely moot, so it's the lowest-marginal-value prong.

DEFER is **not** appropriate here (per the DEFER-for-evidence-not-confidence
discipline): the artifact carries complete evidence (grounded 3-prong analysis vs
the T-2091 origin + a live recurrence). The prior `DEFER` in this block was a
T-2204 auto-retrofit stub ("Auto-retrofitted by 'fw inception retrofit-rec'"),
not a graded advisory.

**Date**: 2026-07-08T07:04:18Z

## Updates

### 2026-05-30T20:16:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2121-t-2091-rca-prevention-follow-up-structur.md
- **Context:** Initial task creation

### 2026-06-10T09:17:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Recommendation

**Recommendation:** GO (prongs 1 + 3); DEFER prong 2

**Rationale:**

The active↔completed task-id divergence class has a detection-only control
(G-052 STRUCTURE audit "No duplicate task IDs") that fires *after* the divergence
is committed and only at audit time — which is why the T-2091 origin surfaced 7
days late and at the worst moment (a pre-push gate that stranded a handover
commit). There is **no** write-time prevention and **no** early `fw doctor`
surface (verified: no dedup hook in `agents/context/`, no untracked-`.tasks/`
check in `audit.sh`/`bin/fw`). The class has **recurred** — `T-100202` is active
today — so "cleanup when it happens" is demonstrably insufficient. Prong 3 is
cheap/low-risk (read-only `git status --porcelain .tasks/`); prong 1 is moderate
(must not block the legitimate `fw task update --status work-completed` git-mv
path). Prong 2 (bumper cross-check) is deferred: once 1+3 exist the metadata-worker
masking is largely moot, so it's the lowest-marginal-value prong.

DEFER is **not** appropriate here (per the DEFER-for-evidence-not-confidence
discipline): the artifact carries complete evidence (grounded 3-prong analysis vs
the T-2091 origin + a live recurrence). The prior `DEFER` in this block was a
T-2204 auto-retrofit stub ("Auto-retrofitted by 'fw inception retrofit-rec'"),
not a graded advisory.

**Evidence:**

- Research artifact: `docs/reports/T-2121-tasks-dir-divergence-prevention.md` (5-Whys origin, 3-prong analysis, cost/blast-radius).
- Recurrence: `T-100202` active — the divergence/collision class is not a one-off.
- Detection-only gap: G-052 audit check exists but fires post-commit at audit time; no write-time hook, no `fw doctor` untracked-`.tasks/` surface (verified absent in current source).
- Origin cost: T-2091 divergence masked for ~7 days by `last_update:` churn, then FAILed a pre-push audit and stranded handover commit `e1a6fd50`.

Each GO prong files as its own build task ("one bug = one task") with
`unlocks_inception_decision: [T-2121:<decision-id>]` traceability.


### 2026-06-12T10:13:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-07-08T07:04:18Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The active↔completed task-id divergence class has a detection-only control
(G-052 STRUCTURE audit "No duplicate task IDs") that fires *after* the divergence
is committed and only at audit time — which is why the T-2091 origin surfaced 7
days late and at the worst moment (a pre-push gate that stranded a handover
commit). There is **no** write-time prevention and **no** early `fw doctor`
surface (verified: no dedup hook in `agents/context/`, no untracked-`.tasks/`
check in `audit.sh`/`bin/fw`). The class has **recurred** — `T-100202` is active
today — so "cleanup when it happens" is demonstrably insufficient. Prong 3 is
cheap/low-risk (read-only `git status --porcelain .tasks/`); prong 1 is moderate
(must not block the legitimate `fw task update --status work-completed` git-mv
path). Prong 2 (bumper cross-check) is deferred: once 1+3 exist the metadata-worker
masking is largely moot, so it's the lowest-marginal-value prong.

DEFER is **not** appropriate here (per the DEFER-for-evidence-not-confidence
discipline): the artifact carries complete evidence (grounded 3-prong analysis vs
the T-2091 origin + a live recurrence). The prior `DEFER` in this block was a
T-2204 auto-retrofit stub ("Auto-retrofitted by 'fw inception retrofit-rec'"),
not a graded advisory.
