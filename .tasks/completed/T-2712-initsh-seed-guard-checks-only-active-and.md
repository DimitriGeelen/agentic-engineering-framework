---
id: T-2712
name: "init.sh seed guard checks only active/ and re-seeds over completed onboarding"
description: >
  lib/init.sh:469 sets has_existing_tasks by testing .tasks/active/T-*.md only, never
  .tasks/completed/. Once onboarding tasks are completed they leave active/, so a
  later fw init sees an empty active dir, concludes the project is fresh, and re-seeds
  T-001..T-005 (greenfield) or T-001..T-006 (existing-project) over IDs the project
  has already used and committed against. That is a duplicate-ID generator by construction;
  the existence of the check-active-completed-dup hook shows the class is already
  known. Consumer-facing: fires hardest on new projects.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [onboarding, consumer, task-id]
components: [lib/init.sh, tests/unit/init_seed_guard.bats]
related_tasks: [T-460, T-2709]
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
created: 2026-08-01T07:23:05Z
last_update: 2026-08-01T08:50:28Z
date_finished: 2026-08-01T08:50:28Z
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
  - ts: '2026-08-01T07:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-01T07:30:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2712: init.sh seed guard checks only active/ and re-seeds over completed onboarding

## Context

`lib/init.sh:469` decides whether a project is fresh:

```bash
if [ -d "$target_dir/.tasks/active" ] && ls "$target_dir/.tasks/active/"T-*.md >/dev/null 2>&1; then
    has_existing_tasks=true
fi
```

It looks only in `active/`. Completing a task **moves it to `completed/`**, so a project
that finished its onboarding tasks presents an empty `active/`, is judged fresh, and gets
`T-001`..`T-005` (greenfield) or `T-001`..`T-006` (existing-project) written over IDs it
has already used and committed against.

The guard's own comment says "idempotent on `--force` re-init" — that is the intent it
fails to deliver, and it fails precisely for projects that made progress.

The existence of the `check-active-completed-dup` PreToolUse hook shows this duplicate-ID
class is already known and defended elsewhere; the seeder creates it upstream of that hook.

**Fix:** the freshness test must consider every place a task ID can live — `active/`
**and** `completed/`.

## Acceptance Criteria

### Agent
- [x] `has_existing_tasks` is true when `.tasks/completed/` holds `T-*.md` and `active/` is empty — the exact state of a project that finished onboarding.
- [x] Re-running `fw init` on a project whose onboarding tasks are all completed seeds **zero** new tasks and does not recreate `T-001`.
- [x] The existing behaviours are unchanged: a genuinely empty project still seeds, and a project with tasks in `active/` still skips.
- [x] Regression test `tests/unit/init_seed_guard.bats` green, including a negative control that fails if the guard reverts to checking `active/` only.

**Evidence (live end-to-end, 2026-08-01):** `fw init` on a fresh dir seeded 5 tasks →
moved all 5 to `completed/` (simulating finished onboarding) → `fw init --force` again →
**0 tasks in `active/`**. Pre-fix that second init re-seeded all 5 over already-committed
IDs. Suite 6/6; test 4 runs the pre-fix guard against the same fixture and confirms it
reports `false`, so the fixture genuinely reproduces the defect.

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

bats tests/unit/init_seed_guard.bats
bash -n lib/init.sh

## RCA

**Symptom:** `fw init` on a project whose onboarding tasks were all completed re-seeded
`T-001`..`T-005` over IDs the project had already used and committed against.

**Root cause:** the freshness test asked "are there tasks in `active/`?" when the question
it needed to answer was "has this project ever had tasks?". Completing a task moves it to
`completed/`, so the two questions diverge exactly when a project makes progress — the
guard was most wrong about the projects that had done the most.

**Why structurally allowed:** the guard was written alongside the seeder, when `active/`
was the only directory that existed in the author's mental model of "tasks". Nothing tied
it to the lifecycle that moves files out of `active/`. And the failure is invisible at the
moment it happens: re-seeding produces valid-looking task files with plausible IDs, so
there is no error, no warning, and no output that differs from a legitimate first init.
The duplicate only surfaces later, as an ID collision, far from its cause — which is why
`check-active-completed-dup` exists to catch it downstream while the seeder kept
manufacturing it upstream.

**Prevention:** the guard now iterates the directories a task ID can occupy rather than
naming one — the same correction as T-2711 in a different file. `init_seed_guard.bats`
test 4 keeps the pre-fix predicate as a live negative control, so reverting the guard fails
the suite instead of quietly re-arming the seeder.

## Decisions

### 2026-08-01 — iterate the lifecycle directories, don't add `completed/` as a second test

- **Chose:** `for _seed_dir_probe in active completed`.
- **Why:** the question is "any task, anywhere". A second hardcoded branch would answer it
  correctly today and be wrong again the moment the lifecycle grows a directory.
- **Rejected:** `[ -d active ] && ... || [ -d completed ] && ...` — same answer now, same
  naming-not-deriving defect this session has already hit twice (T-2711, T-2710).

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

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-01T07:23:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2712-initsh-seed-guard-checks-only-active-and.md
- **Context:** Initial task creation

### 2026-08-01T08:37:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-08-01T08:39:59Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-08-01T08:47:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c8c8c8f0
- **Timestamp:** 2026-08-01T08:50:30Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `bats tests/unit/init_seed_guard.bats`

### 2026-08-01T08:50:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
