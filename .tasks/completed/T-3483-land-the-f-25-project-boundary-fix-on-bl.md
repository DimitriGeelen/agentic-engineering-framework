---
id: T-3483
name: "land the F-25 project-boundary fix on bleeding-edge: cherry-pick, verify the
  boundary still blocks a genuinely foreign project, then push"
description: >
  land the F-25 project-boundary fix on bleeding-edge: cherry-pick, verify the boundary
  still blocks a genuinely foreign project, then push

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
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
created: 2026-09-25T21:38:17Z
last_update: 2026-09-25T21:45:26Z
date_finished: 2026-09-25T21:45:26Z
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
  - ts: '2026-09-25T21:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=351,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-25T21:45:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3483: land the F-25 project-boundary fix on bleeding-edge: cherry-pick, verify the boundary still blocks a genuinely foreign project, then push

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Context

Operator authorised the merge 2026-09-25. T-3480's fix (`671ea6c0e`) has sat on
branch `dispatch-f25` — 1 ahead, 7 behind `bleeding-edge` — because two
autonomous procAsFit rounds correctly refused to land a **security-boundary
hook** on their own authority. That refusal was the mandate working, not doubt
about the fix.

**What the fix does.** `check-project-boundary.sh` blocks commands targeting
paths outside `PROJECT_ROOT`. A sibling git worktree of *this* repo is the same
repository, not another project, but the hook could not tell. The fix consults
`git worktree list --porcelain` run **against PROJECT_ROOT**, which enumerates
only worktrees sharing PROJECT_ROOT's own `.git` — a genuinely foreign project
has its own `.git` and can never appear. It fails closed: any error (not a git
repo, git missing, timeout) yields an empty list and every prior pattern behaves
unchanged.

**Cherry-pick, not merge.** The commit touches 3 files (354 insertions, 1
deletion) and the branch is 7 behind. A cherry-pick lands exactly that change
with linear history; a merge would drag a stale branch tip along for no benefit.

**The check that actually matters is the control leg.** Round 2 verified the
suite passes. A passing suite on a permissive change does not prove the
boundary still refuses — only a live attempt at a foreign path does. That is
the criterion below, and it is the one that would catch a fix that admits too
much.

**Residual risk, accepted and recorded:** a worktree of this repo created
*inside* another project's tree (`git worktree add /opt/055-other/x`) would be
admitted. It is technically our repo, so the hook is not wrong, but it defeats
the boundary's intent. Worktrees are opt-in-only here (CLAUDE.md §Worktree
Policy), so the exposure is small. Named rather than fixed.

## Acceptance Criteria

### Agent
- [x] `671ea6c0e` cherry-picked onto `bleeding-edge`, bringing exactly its 3 files and no stale branch content
- [x] **Control leg — the boundary still BLOCKS:** a command targeting a genuinely foreign project path is still refused after the change, demonstrated live, not inferred from a green suite
- [x] The permissive half works: a path inside a real sibling worktree of this repo is admitted
- [x] `tests/integration/check_project_boundary.bats` runs, with any failure shown to be pre-existing on unmodified `bleeding-edge` rather than introduced
- [x] The enforcement baseline is refreshed if the hook's canonical hash moved (L-398), so `fw doctor` does not accumulate a silent FAIL
- [x] `bin/fw vendor self --check` clean, and the change pushed to origin


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

## Evidence

**Cherry-pick:** `1d5d2b3f6`, exactly 3 files, 354 insertions / 1 deletion.

**Control leg — twice, one of them unplanned.** While composing the negative
test, the *live* hook refused my own command for naming `/opt/055-…` — and that
refusal came from the code just cherry-picked. An accidental but genuine
demonstration that the boundary still fires post-fix. The deliberate version is
in the suite: tests 32, 33 and 34 (`foreign repo still blocked` ×2, plus
`PROJECT_ROOT not a git repo still blocks`) all pass.

**Permissive half:** tests 29–31 pass — Write, `cat` and `cd` into a sibling
worktree of this repo are admitted.

**Suite:** 33 ok / 1 not ok / **0 skips** (skips counted per T-3217 — a skipped
bats test reports `ok`).

**The single failure is pre-existing, verified rather than inherited.** Round 2
asserted this; I re-derived it. Restored the pre-fix hook from `HEAD~1`, re-ran
the suite, and `not ok 16 Bash redirect to /etc: blocked` fails there too (30 ok
pre-fix). So the fix adds three passing tests and regresses nothing. The hook
file was then restored and confirmed byte-identical to HEAD before proceeding —
a test that mutates the thing under test must put it back, and be seen to.

**Enforcement baseline:** `fw doctor` reports no enforcement line, so the
canonical hash did not move — the baseline covers `.claude/settings.json` hook
*wiring*, not hook file contents, and the wiring is unchanged. Nothing to
refresh; checked rather than assumed.

**Not fixed, recorded:** a worktree of this repo created inside another
project's tree would be admitted. Technically correct (it is our repo) but
against the boundary's intent. Worktrees are opt-in-only, so exposure is small.

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
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
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
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# The F-25 fix is on this branch. Redirect-then-grep (L-387): the pipe form
# `git log | grep -q` returns 141 under the gate's pipefail — grep matches,
# closes stdin, git takes SIGPIPE. Caught by the gate on this very task.
git log --oneline -20 > /tmp/.t3483-log.out 2>&1 && grep -q "F-25 fix" /tmp/.t3483-log.out
# Suite runs; the only failure is the pre-existing /etc one, and nothing skips.
timeout 300 bats tests/integration/check_project_boundary.bats > /tmp/.t3483.out 2>&1; test "$(grep -c '# skip' /tmp/.t3483.out)" -eq 0
grep -q "^ok 32 F-25 negative control" /tmp/.t3483.out
grep -q "^ok 33 F-25 negative control" /tmp/.t3483.out
grep -q "^ok 29 Write into sibling git worktree" /tmp/.t3483.out
test "$(grep -c '^not ok' /tmp/.t3483.out)" -eq 1
bin/fw vendor self --check

## RCA

The gate keys on "fix" in the title. This task *lands* a fix rather than making
one — T-3480 did the fixing. But there is a real root cause underneath, about
the landing, and it is worth the section.

**Symptom:** a verified fix to a **security-boundary hook** sat unmerged on
`dispatch-f25` for a day while `bleeding-edge` moved 7 commits ahead of it.

**Root cause:** dispatched workers produce changes on branches, and the
procAsFit mandate correctly forbids a worker from resolving a Sovereign question
to unblock itself. Two rounds hit that wall and did the right thing. But
**nothing routes the resulting state — "worker-produced change awaiting a
sovereign merge" — anywhere an operator would encounter it.** It surfaced only
because round 2 wrote it into a handback, and handbacks are read when someone
chooses to read them.

**Why structurally allowed:** `/approvals` is the queue for Tier-0 approvals,
inception decisions and arc closures. A branch awaiting a merge ruling is none
of those, so it has no surface. The refusal was loud to the worker and silent to
everyone else. That is the same shape as OBS-533 (a watchdog firing unread) and
OBS-535 (a finding whose qualifier lived where nobody looks): **the detection
worked and the routing did not** — the fifth instance of that class this week.

**Prevention:** none shipped here, and saying otherwise would be the false
close this session keeps finding. What *would* prevent it is a branch-awaiting-
merge surface on `/approvals`, fed by the dispatch records. Not built, not
filed as done — named so it is not mistaken for handled. What this task did
prevent is narrower and real: the landing was not taken on trust. The pre-fix
baseline was re-derived rather than inherited from round 2's claim, and the
negative control (foreign project still blocked) was run against the merged
code, because a permissive change proven only by a green suite is not proven.

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

### 2026-09-25T21:38:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3483-land-the-f-25-project-boundary-fix-on-bl.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-34007f2c
- **Timestamp:** 2026-09-25T21:45:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-25T21:45:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
