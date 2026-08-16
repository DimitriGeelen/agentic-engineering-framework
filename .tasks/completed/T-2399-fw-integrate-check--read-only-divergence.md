---
id: T-2399
name: "fw integrate check — read-only divergence + un-partitionable conflict-class
  preflight (T-2397 L2 slice 1, G2)"
description: >
  fw integrate check — read-only divergence + un-partitionable conflict-class preflight
  (T-2397 L2 slice 1, G2)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw, lib/integrate.py, tests/unit/t2399_integrate_check.bats]
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
created: 2026-06-14T15:53:22Z
last_update: '2026-08-16T22:25:04Z'
date_finished: 2026-06-14T15:58:44Z
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
bvp_scores_proposed:
  - ts: '2026-08-16T22:25:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2399: fw integrate check — read-only divergence + un-partitionable conflict-class preflight (T-2397 L2 slice 1, G2)

## Context

First (read-only) slice of the Layer-2 serialized-integration queue specified in
`docs/reports/T-2397-layer2-integration-queue-spec.md` — G2 of the T-2394
structural-remediation inception (GO'd via Watchtower). L1 (master-merge-only
guard, T-2396) is shipped; this is the next leg.

The recurring problem (twice in one session, 2026-06-14): a worktree branch and
master diverge, and reconciliation is manual — an agent must know, by hand, that
governance/generated files (counters, metrics-history, feedback-stream,
reviewer-overrides, LATEST audit yamls, episodics, task `.md`) must be
regenerated/unioned at the join, never `git merge`d (T-2397 §3.2, the framework's
`Cargo.lock` set). This slice encodes that taxonomy as code and makes the
divergence/FF-readiness state observable via `fw integrate check` — read-only, so
zero blast radius. The mutating verb (`fw integrate run`) is a later slice that
reuses `classify_path()`.

Conflict signal is "changed on BOTH sides of the merge-base," not "git reports a
textual conflict" — because the taxonomy's point is that governance files must be
regenerated/unioned even when they would textually merge.

## Acceptance Criteria

### Agent
- [x] `lib/integrate.py` implements `classify_path()` mapping a repo-relative path to one of the T-2397 §3.2 classes: `regenerate` (counters, LATEST audit yamls), `append-union` (metrics-history, feedback-stream), `id-union` (reviewer-overrides), `take-existing` (episodics), `field-merge` (task `.md`), or `git-merge` (default — real code/docs, needs-human)
- [x] `fw integrate check [target]` reports branch/target/merge-base/ahead-behind and a verdict; read-only (no mutation, no master-working-tree touch)
- [x] Exit codes: 0 ff-ready|clean-merge, 1 auto-resolvable (all both-sided files are governance classes), 2 needs-human (real code both-sided), 3 not-on-a-branch (HEAD=master/main), 4 usage/git-error
- [x] `fw integrate classify <path>...` emits `path<TAB>class<TAB>auto|needs-human<TAB>strategy`
- [x] `fw integrate --help` documents verbs, taxonomy, and exit codes; routed in `bin/fw` mirroring `fw write-set` (G4 sibling)
- [x] bats `t2399_integrate_check.bats` drives REAL diverged git repos for every exit path (ff-ready, clean-merge, auto-resolvable, needs-human, mixed→human-wins, not-on-branch, custom-target) + classify unit checks — 8/8
- [x] `bash -n bin/fw` clean (L-408); live smoke from this worktree returns FF-READY (master is ancestor)

### Human

_(none — all criteria are agent-verifiable: deterministic git/classification logic + bats.)_

## Verification

bash -n bin/fw
bats tests/unit/t2399_integrate_check.bats
python3 -c "import sys; sys.path.insert(0,'lib'); import integrate; assert integrate.classify_path('.context/working/feedback-stream.yaml')[0]=='append-union'; assert integrate.classify_path('lib/x.sh')[0]=='git-merge'; assert integrate.classify_path('.tasks/active/T-1-a.md')[0]=='field-merge'; print('classify_path OK')"

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

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-14T15:53:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2399-fw-integrate-check--read-only-divergence.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b1100df4
- **Timestamp:** 2026-06-14T15:58:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-14T15:58:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
