---
id: T-2827
name: "fw init bootstrap commit has an EMPTY tree — worktree isolation still yields
  an empty worktree (OBS-178)"
description: >
  T-2821's --allow-empty bootstrap gives a resolvable HEAD but a zero-file tree, so
  git worktree add checks out nothing. Fix the tree, not just the ref.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/init.sh]
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
created: 2026-08-06T13:18:27Z
last_update: 2026-08-06T15:09:02Z
date_finished: 2026-08-06T15:09:02Z
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
  - ts: '2026-08-06T13:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-06T13:30:12Z'
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

# T-2827: fw init bootstrap commit has an EMPTY tree — worktree isolation still yields an empty worktree (OBS-178)

## Context

**OBS-178, measured live in T-2826 against published bytes `7b143ad5e`.**

T-2821 gave a fresh project a resolvable HEAD via an `--allow-empty` bootstrap commit. The
HEAD resolves — but its **tree contains zero files**, so `git worktree add` checks out
nothing and yields a worktree holding only `.git`. The user-visible failure is identical to
OBS-175 (a background agent isolates into an empty worktree); only the mechanism changed,
from orphan-inference to empty-tree checkout.

Window measured at both ends: empty at bootstrap HEAD; correct (10 entries, `CLAUDE.md` +
`.tasks/` present) after the first **content** commit. `fw init` leaves its scaffolding
uncommitted, so nothing closes the window automatically — and the window is exactly the
onboarding window in which a background agent would first be dispatched.

**T-2821's "empty commit only" was deliberate**, and its stated reasons are real
(`lib/init.sh:524-528`): an empty commit makes no decision about which framework files get
tracked, and does not pre-empt onboarding task T-003 ("First governed commit"). Any fix
must either honour those reasons or explicitly supersede them with a recorded decision —
not silently `git add -A`.

## Acceptance Criteria

### Agent
- [x] The tracking question is settled from evidence, not assumption: what `fw init`
      actually creates, what its `.gitignore` already excludes, and what onboarding T-003
      asks the operator to do — recorded in `## Decisions` before the code changes.
      → 9 top-level entries / 2353 files, **no `.gitignore` written**, all framework-owned.
- [x] `fw init` on an empty dir leaves a HEAD whose **tree is non-empty** and contains the
      governance scaffolding a background agent needs (`CLAUDE.md`, `.tasks/`, `.claude/`).
      → `TREE_FILES=2729`, `TREE_ONBOARDING_TASKS=5`, `DIRTY_AFTER_INIT=0`.
- [x] `git worktree add` immediately after `fw init` (no intervening commit) yields a
      **populated** worktree — the OBS-178 failure, measured the same way T-2826 measured it.
      → `WT_ENTRIES=9`, `WT_CLAUDEMD=yes`, `WT_FW_EXECUTABLE=yes`, `WT_ACTIVE_TASKS=5`.
      Was 1 entry / no CLAUDE.md before the fix.
- [x] The bootstrap commit still passes the project's own hooks with **no `--no-verify`**
      (commit-msg task-ref, T-1844 secret-scan, T-1845 large-file, T-1863 dup-task-id) —
      T-2821's hard rule, which a non-empty diff now actually exercises rather than
      trivially satisfying. → `INIT_RC=0` with 2729 staged files; bats test 5 green.
- [x] Existing-project and re-init paths remain no-ops (guard on unborn HEAD preserved).
      → bats tests 7 + 8 green; `tests/unit/upgrade_fresh_machine_simulation.bats` **11/11**
      (CLAUDE.md §Consumer-Facing Command Hygiene hard rule).
- [x] `tests/unit/init_head_bootstrap.bats` extended to assert **tree non-emptiness**, not
      just HEAD resolvability — the proxy/thing divergence that let OBS-178 ship green —
      and mutation-checked (revert the fix ⇒ the new assertion goes red).
      → 8/8 green. Mutation (staging step neutralised): **tests 2, 3, 6 go red**; 1, 4, 5, 7, 8
      survive. Test 1 (*"HEAD resolves"*) surviving is the correct signature — it is the
      proxy assertion, and its staying green on a broken tree is exactly the F4 gap.

## Second defect found while fixing (placement)

The staging change alone was not sufficient. The bootstrap sat ~150 lines after hook
install, so it committed an **intermediate** state: it captured the `.fw-init-incomplete`
sentinel that init then *deletes*, and ran before the enforcement baseline and before all
five onboarding tasks were seeded. Measured leftovers: 4 dirty entries including
`?? .tasks/active/` — a worktree cut from that commit had `.tasks/` but **no tasks in it**,
the populated-looking-but-broken state this fix exists to prevent.

Moved to the end of `do_init`, immediately after the marker clear. This is the **same
argument T-2727 already made** for post-init validation: the verdict — here, the tree — must
describe what the user is actually left with, not a state that no longer exists by the time
init returns. Result: `DIRTY_AFTER_INIT=0`, sentinel absent from the tree, 5 onboarding
tasks present.

**Process note:** the first move landed the block in the *wrong* place — a `python3` splice
matched the **first** `rm -f "$_init_incomplete_marker"` (the preflight-failure branch) rather
than the last. `bash -n` passed, because the result was syntactically valid and semantically
wrong. Caught by re-reading the placement rather than trusting the syntax check — the same
class as the false-green family this task belongs to.

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

# Syntax (L-408 — this task spliced blocks with python3; bash -n is necessary not sufficient)
bash -n lib/init.sh

# The staging step exists — this IS the fix (mutation-checked: removing it reds tests 2,3,6)
grep -q 'git -C "$target_dir" add -A' lib/init.sh

# The bootstrap runs AFTER the marker clear, not in the preflight-failure branch.
# Guards the placement defect: a python3 splice matched the FIRST marker-clear and
# bash -n passed on the wrong result.
python3 -c "import sys; s=open('lib/init.sh').read(); sys.exit(0 if s.rindex('rm -f \"\$_init_incomplete_marker\"') < s.index('--- Bootstrap commit: give the project a resolvable HEAD') else 1)"

# Suite green, with the guard L-387/T-2738 requires (pass marker AND no failures)
out=$(bats tests/unit/init_head_bootstrap.bats 2>&1); echo "$out" | grep -q '^ok 8 ' && ! echo "$out" | grep -q '^not ok'

# CLAUDE.md hard rule: any fw init change keeps the consumer-facing simulation green
out=$(bats tests/unit/upgrade_fresh_machine_simulation.bats 2>&1); echo "$out" | grep -q '^ok 11 ' && ! echo "$out" | grep -q '^not ok'

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
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

**Symptom:** `fw init` reports success and leaves a resolvable HEAD, but a background agent
isolating into a worktree immediately afterwards lands in a directory containing only
`.git` — no `CLAUDE.md`, no `fw`, no tasks. Every Write/Edit then fails, deadlocking the
first background session before it can write its own task file.

**Root cause:** the bootstrap commit was `--allow-empty`, so HEAD pointed at a **zero-file
tree**. `git worktree add` faithfully checked out that empty tree. Compounding it, the
commit ran ~150 lines before the end of `do_init`, so even once populated it would have
captured an intermediate state — the `.fw-init-incomplete` sentinel init later deletes, and
none of the five onboarding tasks.

**Why structurally allowed:** T-2821 fixed the *ref* and its tests asserted the *ref*.
`git rev-parse HEAD` succeeding was adopted as the definition of "worktree isolation works"
because that is the check Claude Code's preflight performs. But the preflight is not the
requirement — it is one necessary condition of it. The property the real use needs is
"HEAD has content", and **resolvability was a proxy that diverged from the thing** (T-1828 /
T-2735 class). The suite's worktree test asserted `status 0`, not-orphan, and HEAD ≠ zeros —
all three of which are true of an empty tree. It passed on the broken state and still does:
in the mutation run, test 1 survives while 2, 3 and 6 go red. That surviving green is the
defect's signature, not noise.

The deeper enabler is that the fix was authored against the *narrative* of OBS-175
("worktree add refuses on unborn HEAD") rather than its *mechanism*. T-2822 F7 had already
falsified that narrative — `git worktree add` returns **RC=0** and yields an empty worktree —
so the failure mode was emptiness all along. The fix removed the unborn HEAD and left the
emptiness, because emptiness was never what it was aimed at.

**Prevention (distinct from the fix):**
1. `tests/unit/init_head_bootstrap.bats` now asserts the **tree**, not just the ref —
   `ls-tree` non-empty, and the worktree must actually contain `CLAUDE.md`, `.tasks/`,
   `.claude/` and `.agentic-framework/`. Mutation-checked: neutralising the staging step
   reds exactly those assertions.
2. A **runtime** guard: when the staged count is 0, init now prints an explicit OBS-178
   warning naming the consequence, so the failure is legible at the point it is created
   rather than at the point a background agent deadlocks.
3. A verification line pins the **placement** (bootstrap must follow the last marker-clear),
   because the first attempt at moving it silently landed in the preflight-failure branch
   and `bash -n` passed.

**Escalation level:** C (tooling) for the fix; B (technique) for the authoring lesson —
*when a fix targets a reported mechanism, verify the mechanism report first.* T-2822 F7 had
already corrected it and the correction did not propagate into T-2821's test design.

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

### 2026-08-06 — what the bootstrap commit tracks

**Evidence gathered first (AC1):**
- `fw init` creates **9 top-level entries / 2353 files**: `.agentic-framework/`, `.claude/`,
  `.context/`, `.framework.yaml`, `.mcp.json`, `.tasks/`, `.termlink-task`, `CLAUDE.md`,
  `policy/`. `.agentic-framework/` (the vendored CLI) is the bulk.
- `fw init` writes **no `.gitignore`** — so there is no pre-existing encoded tracking
  decision to respect or violate. The question is genuinely open.
- All 9 entries are **framework-owned**. None is operator project content.
- T-2826 LEG6 already proved empirically that staging all 2353 and committing **passes the
  project's own hooks with no `--no-verify`** (`LEG6_COMMIT_RC=0`).

- **Chose:** the bootstrap commit stages everything `fw init` created (`git add -A`) and
  commits it, falling back to `--allow-empty` only if there is genuinely nothing staged.
- **Why:**
  1. **A partially-populated worktree is a worse false-green than an empty one.** A
     background agent needs `CLAUDE.md`, `.claude/`, `.tasks/`, `.context/`, *and*
     `.agentic-framework/` (without the vendored CLI, `fw` does not exist in the worktree
     and no governance runs at all). Committing a curated subset yields a worktree that
     looks populated and is still broken — the T-2726 unwitnessable class.
  2. **This is not a decision about the operator's content.** All 9 entries are files the
     framework itself just wrote. The framework tracking what the framework created leaves
     the operator's content decision entirely intact.
  3. **It makes "freshly initialised" a valid git state.** That property is precisely what
     worktree isolation requires; leaving 2353 files uncommitted means a fresh project is
     git-valid in name (HEAD resolves) but not in substance (tree empty) — the exact
     proxy/thing gap that produced OBS-178.
  4. Tracking the vendored `.agentic-framework/` is the **established pattern**, not a new
     one (D-377 total isolation; this repo tracks its own).
- **Rejected — keep `--allow-empty` and fix at the worktree layer.** The framework does not
  control Claude Code's `EnterWorktree` preflight, so there is no layer there to fix.
- **Rejected — commit a curated governance subset.** See reason 1: yields a functional-looking
  but non-functional worktree.
- **Supersedes** T-2821's stated "empty commit only" rationale (`lib/init.sh:524-528`). That
  reasoning was sound about *tracking neutrality* but was not weighed against the deadlock
  it left open, because the deadlock was believed fixed. It was not (OBS-178).

**Interaction with T-2822 (recorded, not resolved here):** committing `.tasks/` and
`.context/` means every worktree forks governance state — which is exactly what T-2822
identified. That is **already true** the moment those files are tracked at all, and T-2822's
GO answers it at the correct layer (*refuse writes*, since git puts the files there
regardless). This task does not change that surface; it removes a precondition failure that
sits underneath it. Noted so the two are not later mistaken for conflicting fixes.

**T-003 remains meaningful:** it asks the operator for their first governed commit of
*project content*, which this does not pre-empt — a freshly initialised project still has
no operator content in it.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-06T13:18:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2827-fw-init-bootstrap-commit-has-an-empty-tr.md
- **Context:** Initial task creation

### 2026-08-06T14:46:11Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b4418c3c
- **Timestamp:** 2026-08-06T15:17:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -f`

### 2026-08-06T15:09:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
