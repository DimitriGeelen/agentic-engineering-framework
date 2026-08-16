---
id: T-3054
name: "watchtower.sh silently falls PROJECT_ROOT back to FRAMEWORK_ROOT, serving the
  wrong project"
description: >
  From T-3047 triage M-26 (ring20-dashboard P-011, 2026-06-13). bin/watchtower.sh:208
  is export PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}" with no die and no warn.
  The identity check at lib/watchtower.sh:30,:79 compares against the same fallback,
  so a misconfigured instance matches itself and passes doctor. Operator sees a fresh-install
  Setup Checklist for a project with hundreds of tasks.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [upstream-pickup, T-3047-triage]
components: []
related_tasks: [T-3047]
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
created: 2026-08-16T22:32:12Z
last_update: 2026-08-16T22:46:35Z
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
  - ts: '2026-08-16T22:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-16T22:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3054: watchtower.sh silently falls PROJECT_ROOT back to FRAMEWORK_ROOT, serving the wrong project

## Context

Filed from T-3047 triage M-26 (ring20-dashboard P-011, 2026-06-13 — unread for two
months). `bin/watchtower.sh:208` reads `export PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"`
with no die and no warning: a caller that forgets to export `PROJECT_ROOT` gets Flask
serving the framework's own `.tasks/` and `.context/`, so the operator sees a
fresh-install Setup Checklist for a project holding hundreds of tasks.

What makes it a *false green* rather than a plain bug is the second half. The identity
check that exists to catch exactly this — `lib/watchtower.sh` `_watchtower_identity_matches`
— compares the served `project_root` against `"${PROJECT_ROOT:-${FRAMEWORK_ROOT:-}}"`,
i.e. the same fallback expression. A misconfigured instance therefore matches *itself*
and passes `fw doctor`. The check cannot fail in the one situation it was written for.

This is the same shape as T-3051 and as the port-3000 class in CLAUDE.md: a guard whose
predicate is derived from the thing it is meant to validate reports green forever.

Scope fence: make the fallback observable and make the identity check independent of
it. Not in scope: changing how `PROJECT_ROOT` is discovered, or making the fallback
fatal — an intentional framework-repo-serves-itself run must keep working.

## Acceptance Criteria

### Agent
- [x] **A1** When `PROJECT_ROOT` is unset and the fallback fires, `bin/watchtower.sh`
  emits a clearly-worded warning naming both the value used and the fact that it was a
  fallback. Silent substitution is the defect; the fallback itself is not.
- [x] **A2** `_watchtower_identity_matches` no longer derives its expected value from
  the same `${PROJECT_ROOT:-$FRAMEWORK_ROOT}` expression, so a fallback-serving instance
  is *detectable* rather than self-matching.
- [x] **A3** A regression test drives the real fallback path with `PROJECT_ROOT` unset
  and asserts the warning appears. It must be observed red against the current silent
  form — a test that only proves the warning exists when the variable is set proves
  nothing.
- [x] **A4** A regression test asserts the identity check returns *non-matching* for an
  instance serving `FRAMEWORK_ROOT` while a distinct `PROJECT_ROOT` is configured — the
  case that previously self-matched.
- [x] **A5** The intentional case still works: serving the framework repo itself with
  `PROJECT_ROOT` explicitly set to `FRAMEWORK_ROOT` produces no warning and matches.

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
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# A1-A5 — the regression suite, including the silent-predecessor mutation (test 2)
out=$(bats tests/unit/t3054_watchtower_root_fallback.bats 2>&1); echo "$out" | grep -q '^ok 7 ' && ! echo "$out" | grep -q '^not ok'

# A2 — the inline fallback expression is gone from both identity sites
! grep -q 'PROJECT_ROOT:-${FRAMEWORK_ROOT:-}' lib/watchtower.sh
test "$(grep -c '_our_root=$(_watchtower_our_root)' lib/watchtower.sh)" -eq 2
grep -q 'PROJECT_ROOT="$(_watchtower_our_root)"' bin/watchtower.sh

# both scripts parse, and URL resolution still works against the live instance
bash -n bin/watchtower.sh && bash -n lib/watchtower.sh
bin/fw watchtower url > /tmp/.t3054url 2>&1 && grep -qE '^https?://' /tmp/.t3054url
curl -sf "$(bin/fw watchtower url)/" > /dev/null

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

**Symptom:** an operator running Watchtower without exporting `PROJECT_ROOT` saw a
fresh-install Setup Checklist for a project holding hundreds of tasks — Flask was
serving the framework's own empty `.tasks/` and `.context/`. Reported by
ring20-dashboard as P-011 on 2026-06-13; unread for two months.

**Root cause:** `bin/watchtower.sh:208` substituted `FRAMEWORK_ROOT` for an unset
`PROJECT_ROOT` with no warning, and `_watchtower_identity_matches` computed "our root"
with the *same* `${PROJECT_ROOT:-${FRAMEWORK_ROOT:-}}` expression. The server and its
validator therefore agreed by construction.

**Why structurally allowed:** the identity handshake (T-1803) was built to catch a
wrong-project instance, and it is the reason nobody looked again. But a predicate
derived from the value it is meant to validate cannot return false — the check passed
on every misconfigured instance, which is indistinguishable from there being no
misconfigured instances. Same class as the port-3000 false green in CLAUDE.md and as
T-3051's exec-bit gate: the failure mode is a guard that reports green rather than a
guard that is missing, so nothing ever prompts an audit.

**Prevention:** one shared resolver, `_watchtower_our_root`, is now the only place the
fallback fires, and it warns on stderr naming both the root and the fact that it was a
fallback. `tests/unit/t3054_watchtower_root_fallback.bats` exercises the unset case —
the only one that could ever have failed — and its second test runs the pre-fix
expression on the same input to prove it was silent, so the warning is pinned as
attributable to the fix. Test 7 stands up a server answering with FRAMEWORK_ROOT while
PROJECT_ROOT is set elsewhere and asserts the identity check now reports non-matching.

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

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
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

### 2026-08-16T22:32:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3054-watchtowersh-silently-falls-projectroot-.md
- **Context:** Initial task creation

### 2026-08-16T22:46:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
