---
id: T-2474
name: "fw integrate run hybrid landing: auto-FF clean master worktree, report MAIN go-live"
description: >
  fw integrate run hybrid landing: auto-FF clean master worktree, report MAIN go-live

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [lib/integrate.py]
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
created: 2026-06-23T23:15:22Z
last_update: 2026-06-23T23:23:22Z
date_finished: 2026-06-23T23:23:22Z
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

# T-2474: fw integrate run hybrid landing: auto-FF clean master worktree, report MAIN go-live

## Context

`fw integrate run` (T-2471) integrates `master` into a worktree branch and pushes
`branch:master` to **origin** — but "merge-back" in a multi-worktree setup has THREE
landing zones and the tool only lands one:

1. `origin/master` — the remote (✅ handled by `--push`)
2. the local `master`-holding worktree — left behind origin (❌)
3. MAIN's running checkout — what makes the fix actually LIVE on this host, since
   governance hooks execute MAIN's `bin/fw` (❌, and MAIN is usually off-master)

Hybrid design (operator-approved, scored highest against the Four Directives —
Reliability outranks Usability, so don't silently mutate decision-zones): the two
zones are not the same kind of thing.

- **Zone 2 (master worktree)** is *mechanical* — keeping it synced to origin/master
  is always correct; auto-FF it (clean-guarded). After `git merge --no-ff master into
  branch`, `branch` strictly contains `master`, so the FF is always valid when clean.
- **Zone 3 (MAIN go-live)** is a *decision* — making a fix live changes what hooks
  execute (Tier-2-flavored). Report-only with a copy-pasteable command; never auto.

Zone-2 auto-FF fires only with `--push` (without push, FF-ing the master holder ahead
of origin would create local divergence — so push-less runs report all zones instead).

## Acceptance Criteria

### Agent
- [x] `fw integrate run --push` auto-FFs a CLEAN master-holding linked worktree to the
      integrated branch (`git merge --ff-only <branch>` in that worktree). Verified by a
      bats test: synthetic repo with master checked out in a linked worktree, clean →
      that worktree's HEAD advances to the branch HEAD after the run. (t2474 test 1)
- [x] `fw integrate run --push` does NOT touch a DIRTY master-holding worktree — its HEAD
      is unchanged and the run prints a report line telling the operator to FF it manually.
      Verified by a bats test (dirty master worktree → HEAD unchanged + report present). (t2474 test 2)
- [x] When MAIN is off-master, the run REPORTS (does not execute) a copy-pasteable go-live
      command targeting MAIN's path; MAIN's HEAD is unchanged. Verified by a bats test. (t2474 test 3)
- [x] A "landing" summary block prints each zone's final state (origin pushed / master
      worktree FF'd-or-reported / MAIN live-or-go-live-command). Grep-verified in tests. (t2474 test 4)
- [x] Zone-2 auto-FF does NOT fire without `--push` (push-less run reports all zones,
      mutates no other worktree). Verified by a bats test. (t2474 test 5)
- [x] No regression: `tests/unit/t2471_integrate_run.bats` and
      `tests/unit/t2399_integrate_check.bats` stay green; `python3 -m py_compile lib/integrate.py` passes.
      (13/13 green; py_compile OK)

### Human
- [ ] [REVIEW] Running `fw integrate run --push` to merge a real branch back feels smooth —
      the landing summary makes the three-zone state legible and the next action obvious
      (audience is the operator doing merge-back; this is the ergonomic point of the task).
      **Steps:**
      1. From a worktree branch with divergence vs master, run
         `cd <worktree> && bin/fw integrate run --push`
      2. Read the landing summary block at the end of the output.
      **Expected:** You can tell at a glance which zones landed automatically, which need
      a manual command, and the exact command to run for each — without re-deriving the
      worktree topology yourself.
      **If not:** Note which line was ambiguous or which zone's state was unclear.

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
python3 -m py_compile lib/integrate.py
bats tests/unit/t2474_integrate_run_landing.bats
bats tests/unit/t2471_integrate_run.bats
bats tests/unit/t2399_integrate_check.bats

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

### 2026-06-24 — How to land zones 2 & 3 (scored against the Four Directives)
- **Chose:** Hybrid — auto-FF the master-holding worktree (zone 2, mechanical, clean-guarded),
  report-only for MAIN go-live (zone 3, a decision that changes which hooks execute).
- **Why:** Reliability (#2) outranks Usability (#3). The two zones differ in kind: syncing
  the master worktree to origin/master is always-correct mechanics with zero sovereignty cost;
  making MAIN live is a Tier-2-flavored decision. Hybrid takes the usability win exactly where
  it's free and keeps reliability/sovereignty exactly where it's earned.
- **Rejected — Auto-land both (weighted 3.2/5):** silently mutates MAIN, a deliberate-intent
  decision-zone; same command → different result depending on other trees' runtime cleanliness
  → fails Reliability's "predictable, no silent failures". Wins Usability (5) but trades the
  higher directive for the lower.
- **Rejected — Report-only both (weighted 4.2/5):** safe and predictable but leaves zone-2's
  purely-mechanical sync as manual toil for no sovereignty benefit. Hybrid keeps its reliability
  while reclaiming that free usability.
- Scoring detail: Antifrag×4, Reliab×3, Usab×2, Port×1. Hybrid ≈4.1–4.3, dominating both.

## Recommendation

- **Recommendation:** GO
- **Rationale:** All 6 Agent ACs pass with bats evidence over a genuine multi-worktree
  fixture (real `git worktree` + FF + push to a bare origin). The hybrid was scored the
  directive-optimal of three options. One Human AC remains — a smoothness judgment that
  only you can make by running it against a real merge-back.
- **Evidence:**
  - `_land()` in `lib/integrate.py`: zone-2 auto-FF (clean+pushed only), zone-3 report-only.
  - `tests/unit/t2474_integrate_run_landing.bats` — 5/5 green (clean-FF, dirty-skip, MAIN-report,
    summary block, no-push-no-mutation).
  - Regression: `t2471_integrate_run` + `t2399_integrate_check` — 13/13 green; `py_compile` OK.
  - Live dry-run on this host confirmed FF-READY (+168/−0) and correctly refused on uncommitted
    real code (the AC2-class guard firing for real).
- **To verify the smoothness AC:** `cd <a worktree branch> && bin/fw integrate run --push` and
  read the `Landing:` block — it should tell you at a glance which zones landed and the exact
  command for any that need you.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-23T23:15:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2474-fw-integrate-run-hybrid-landing-auto-ff-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5e90bdb6
- **Timestamp:** 2026-06-23T23:23:28Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-23T23:23:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
