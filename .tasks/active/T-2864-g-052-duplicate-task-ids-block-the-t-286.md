---
id: T-2864
name: "G-052 duplicate task IDs block the T-2863 GO decision commit"
description: >
  G-052 duplicate task IDs block the T-2863 GO decision commit

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [agents/task-create/update-task.sh, tests/unit/test_inception_commit_rename_paths.py, tests/unit/update_task_orphan_guard.bats, web/blueprints/inception.py]
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
created: 2026-08-08T07:23:40Z
last_update: 2026-08-08T07:42:46Z
date_finished: 2026-08-08T07:42:46Z
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
  - ts: '2026-08-08T07:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-08T07:30:13Z'
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

# T-2864: G-052 duplicate task IDs block the T-2863 GO decision commit

## Context

The operator recorded GO on T-2863 via Watchtower. The decision was written to the
task file but the commit was **refused** by the G-052 duplicate-task-ID gate, so the
GO exists on disk and not in history. Reported verbatim:

```
T-2863: Decision recorded — GO
⚠ Decision recorded but not committed: WARN: master-guard bypassed via FW_ALLOW_MASTER_COMMIT=1
ERROR: Commit blocked — duplicate task IDs in staged tree
Duplicate task IDs detected (G-052)
```

Two distinct things are visible here and only the first blocks: (a) duplicate task
IDs refuse the commit; (b) the Watchtower decide path bypassed the T-2394 master
guard via `FW_ALLOW_MASTER_COMMIT=1` — a Tier-2 bypass fired by a *human* action
through the UI, which is the T-100201 conflict surfacing on a new path. (b) is
recorded here as an observation and does not belong to this task's fix.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
<!-- AC1 originally read "duplicate task IDs identified... which file is authoritative
     and which is the stray". It assumed duplicates existed. They do not — neither in
     the worktree nor in the index. Rewritten to the question the evidence can answer,
     with the assumption change logged under ## Evolution rather than quietly dropped. -->
- [x] Duplicate state investigated: **no duplicate exists** in worktree or index —
      both `dup-task-scan.sh` modes return rc=0, and `git diff --cached` shows a
      clean `R100` rename. This is explained, not unexplained: the duplicate lived
      in the committer's **scratch** index (T-2708), never in the real one
- [x] **Defect A — root cause of the reported symptom** identified and reproduced:
      `_commit_decision` harvests `git status --porcelain` and keeps only the
      destination of a rename arrow, while the scratch index is seeded from HEAD
      where the source still exists → the committer manufactures the G-052
      violation the gate then refuses. Rename form measured, not assumed
- [x] Defect A fixed (both sides of the arrow harvested) and the docstring's
      contradicting claim about `mv` vs `git mv` corrected
- [x] Defect A pinned by tests that assert the **committed tree**; verified
      non-vacuous by reverting the fix (2 of 5 fail with
      `duplicate task ids in committed tree: {'T-9100'}`, pass again when restored)
- [x] **Defect B** identified independently of the incident: the T-1863
      post-move guard tests **disk** (`[ -e "$src" ]`) while G-052 fires on the
      **index** (`git ls-files --cached`), and the `|| mv` fallback produces exactly
      that split
- [x] Fix applied at **both** archive call sites — `_t2864_reconcile_index` stages
      the deletion alongside the addition when the source is still tracked
- [x] Regression test with a negative control proving the fallback state really is
      a G-052 violation before the fix is applied (`update_task_orphan_guard.bats`,
      9/9 green)
- [x] The T-2863 GO decision is committed and pushed — the Decision block reaches
      history rather than sitting uncommitted on disk (`92cb41d81`)
- [x] RCA states why a decision recorded through Watchtower could leave the
      repository in a decided-but-uncommitted state, and what surfaces the next one

### Human

- [ ] [REVIEW] A decision recorded through Watchtower commits cleanly — no
      "Decision recorded but not committed" warning

  **Steps:**
  1. Open the next inception awaiting a decision: `cd /opt/999-Agentic-Engineering-Framework && bin/fw review-queue`
  2. Open its Watchtower link and record GO / NO-GO / DEFER as you normally would
  3. Read the confirmation banner, then run: `cd /opt/999-Agentic-Engineering-Framework && git log --oneline -3 && git status --short .tasks/`

  **Expected:** The banner reports the decision with **no** "⚠ Decision recorded
  but not committed" line. `git log` shows a commit `T-XXXX: inception decision
  <GO|NO-GO|DEFER> (via Watchtower)`, and `git status .tasks/` shows the task file
  neither modified nor untracked — the decision is in history, not just on disk.

  **If not:** Copy the warning text verbatim. If it names G-052 again, run
  `bash agents/git/lib/dup-task-scan.sh scan-staged` and
  `git status --porcelain --untracked-files=all | grep T-XXXX` and attach both —
  the porcelain form is the diagnostic that matters.

  *Why human:* the failure only occurs on the operator-through-UI path (an agent
  cannot record an inception decision — T-1259), and the symptom is a banner line,
  not a non-zero exit. No agent-side check reaches this surface.

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

bash -n agents/task-create/update-task.sh
python3 -c "import ast; ast.parse(open('web/blueprints/inception.py').read())"
out=$(bats tests/unit/update_task_orphan_guard.bats 2>&1); echo "$out" | grep -q "^ok 9 " && ! echo "$out" | grep -q "^not ok"
python3 -m pytest tests/unit/test_inception_commit_rename_paths.py -q > /tmp/.t2864-py.out 2>&1 && grep -q "5 passed" /tmp/.t2864-py.out
grep -q 'path.split(" -> ", 1) if " -> " in path else \[path\]' web/blueprints/inception.py
bash agents/git/lib/dup-task-scan.sh scan-staged
bash agents/git/lib/dup-task-scan.sh scan-worktree
grep -q "_t2864_reconcile_index" agents/task-create/update-task.sh
test "$(grep -c '_t2864_reconcile_index "' agents/task-create/update-task.sh)" -eq 2
test -f .tasks/completed/T-2863-rework-the-inception-workflow-five-failu.md
out=$(git log --oneline -30 2>&1); echo "$out" | grep -q "T-2864: land the T-2863 GO decision commit"

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

## Recommendation

**Recommendation:** GO — accept both fixes; the remaining Human AC is a
confirmation on the one surface no agent can reach.

**Rationale:** The reported symptom has a measured mechanism, a fix, and a test
that has been shown to fail without the fix. The Watchtower committer was
manufacturing the exact G-052 violation the pre-commit gate then refused it for —
it seeds a scratch index from HEAD and kept only the destination side of a rename
arrow, while `update-task.sh` archives with `git mv`, making that arrow the normal
case rather than the "defensive edge" the comment called it. A second, independent
defect (the T-1863 post-move guard checking disk while the gate checks the index)
was found while investigating and is fixed alongside, since it produces the same
failure at the same boundary.

The residual risk is narrow and named: the fix is exercised by tests against a
temp repo, and the real path runs with hooks, on master, through a human click.
That is what the Human AC checks, and it needs one real decision to pass — not a
staged rehearsal.

**Evidence:**

- Mechanism measured, not inferred — `git status --porcelain` on a `git mv`'d task
  file returns `RM .tasks/active/T-x.md -> .tasks/completed/T-x.md`; the old parse
  kept only the right-hand side.
- `tests/unit/test_inception_commit_rename_paths.py` — 5 tests asserting the
  **committed tree** (not the return value, which is `True` even when broken
  because a temp repo has no hooks). Reverting the fix: **2 of 5 fail** with
  `AssertionError: duplicate task ids in committed tree: {'T-9100'}`; restoring it:
  5 passed.
- `tests/unit/update_task_orphan_guard.bats` — 9/9, including a negative control
  proving the `|| mv` fallback state really is a G-052 violation before the fix
  applies, and a `_load_reconcile_fn` that extracts the shipped function by `awk`
  so deleting it turns the suite red.
- P-011: **11/11 verification commands pass**, each rehearsed under
  `bash -c 'set -eo pipefail; …'` (one line was rewritten after failing that
  rehearsal with the L-387 SIGPIPE trap).
- The T-2863 GO decision itself is now in history — `92cb41d81`.
- Docstring corrected: it asserted the move was "a filesystem `mv` (not `git mv`)",
  the opposite of what `update-task.sh` has done since T-1523. That false statement
  is why the code read as correct.

**Deliberate carve-out:** a Watchtower decision can still fail to commit for other
reasons, and the operator learns this from a warning line rather than a failure.
That decided-but-uncommitted window is a hole in the sovereignty record and is
flagged for its own task rather than absorbed here.

## RCA

**Symptom:** The operator recorded GO on T-2863 through Watchtower. The decision
was written to the task file; the commit was refused by the G-052 duplicate-task-ID
pre-commit gate. Result: a decision that existed on disk and not in history — the
repository's authoritative record said the inception was still undecided.

**Why the repository looked innocent.** No duplicate task ID exists in the working
tree or the real index — `dup-task-scan.sh` returns rc=0 in both modes and
`git diff --cached` shows a clean `R100` rename. That is not evidence of no bug:
**the duplicate never lived in the real index.** The committer builds a *scratch*
index (T-2708, `GIT_INDEX_FILE` + `git read-tree HEAD`) and the duplicate existed
only there, for the lifetime of one subprocess. Looking at the real index was
looking at the wrong object — the same error this task is about.

**Root cause — defect A (the reported symptom), in `web/blueprints/inception.py`:**

`_commit_decision` seeds a scratch index from `HEAD`, then stages only the paths it
harvested from `git status --porcelain`. The harvest collapsed the rename form:

```python
if " -> " in path:   # "defensive: handle rename form if ever produced"
    path = path.split(" -> ", 1)[1]      # keeps the destination, DROPS the source
```

`update-task.sh` archives with `git mv` when the file is tracked (T-1523), so the
rename form is not a defensive edge — **it is the normal case**. Measured directly:

```
$ git status --porcelain --untracked-files=all
RM .tasks/active/T-9999-x.md -> .tasks/completed/T-9999-x.md
```

`HEAD` still contains the *active* path. Staging only the destination therefore
leaves the task id under **both** `.tasks/active/` and `.tasks/completed/` in the
very index being committed — a G-052 violation manufactured by the committer, which
the pre-commit gate then correctly refused. The comment two lines below already
stated the requirement (*"an explicit pathspec here stages the active→completed
deletion too"*); the code did not meet it, and the docstring asserted the opposite
of what `update-task.sh` does (*"a filesystem `mv` (not `git mv`)"*), so the reader
had no reason to check.

**Why structurally allowed (A):** a producer/consumer split of the L-399 class.
`update-task.sh` changed to `git mv` in T-1523; the Watchtower committer was written
against the older plain-`mv` shape and encoded that assumption in prose. Neither
side tested the join, and the failure only manifests when a *human* decides through
the UI — a path no agent test exercises, and one where the human sees a warning line
rather than a red command.

**Root cause — defect B (found while investigating A), in `update-task.sh`:** the
guard and the gate range over different populations.

- `agents/task-create/update-task.sh` archives with `git mv … || mv` — a documented
  fallback (T-1523).
- Its post-move guard (T-1863) is `[ -e "$_t1863_orig" ]` — **disk**.
- The gate it exists to protect against, `agents/git/lib/dup-task-scan.sh`, reads
  `git ls-files --cached` — **index**.

The `|| mv` fallback removes the source from disk while leaving it tracked in the
index. That state passes the guard (the file really is gone) and fails the gate (the
id really is under both paths). The guard was watching the one population where the
violation it names cannot appear — so it can only ever return green here.

**Why structurally allowed (B):** T-1863 was written from an incident whose orphan
was visible on disk, and the check was fitted to that instance rather than to the
predicate the downstream gate actually evaluates. Nothing compared the two.

**The shared class.** A, B and my own first investigation are three instances of one
error: *a true statement about the wrong population.* A checks the destination and
not the source; B checks disk while the gate checks the index; I checked the real
index while the duplicate lived in a scratch one. Same class as T-2732/L-534 and the
832 fixture finding earlier this session. The tell is always that the check comes
back green while the system stays broken.

**Prevention:**
1. **(A)** The porcelain harvest now takes **both** sides of a rename arrow, and the
   docstring's false claim about `mv` vs `git mv` is corrected in place — it was the
   reason the code read as correct.
2. **(A)** `tests/unit/test_inception_commit_rename_paths.py` — 5 tests asserting the
   **committed tree**, not the return value. This matters: the temp repo has no hooks,
   so `committed is True` passes with the bug present. Verified by reverting the fix:
   **2 of 5 fail** with `duplicate task ids in committed tree: {'T-9100'}`, and pass
   again when restored. `test_rename_form_is_actually_produced` pins the precondition,
   so if the ` -> ` form ever stops appearing the suite goes red rather than silently
   testing nothing.
3. **(B)** `_t2864_reconcile_index` stages the deletion alongside the addition whenever
   the source is still tracked after the move, at **both** archive call sites.
4. **(B)** `tests/unit/update_task_orphan_guard.bats` pins it with a **negative control**
   proving the fallback state really is a G-052 violation first. The function is
   extracted from the shipped script by `awk`, not reimplemented, so deleting it turns
   the test red.

**Sizing note (deliberate deviation).** "One bug = one task" argues for splitting A
and B. They are kept together because they are one deliverable — *the task-archival
commit boundary can no longer manufacture a G-052 false block* — reached through one
shared test surface. B was found only by investigating A. Splitting is the operator's
call; the two are separable by file and by test.

**Not prevented, and deliberately out of scope:** a decision recorded through
Watchtower can still fail to commit for any *other* reason, and the operator learns
this only from a warning line in the UI. The decided-but-uncommitted window is a
real hole in the sovereignty record — the human's decision is the one thing that
must never be lost — and it deserves its own task rather than a note here.

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

### 2026-08-08 — the incident was not the defect

- **What changed:** The task was filed to resolve duplicate task IDs. There are
  none — the state self-reconciled before it could be examined, and three
  hypotheses could not be separated on the available evidence. What the
  investigation *did* find is a guard whose predicate ranges over a different
  population than the gate it protects: disk vs index.
- **Plan impact:** AC1 assumed duplicates existed and named "which file is the
  stray". It was rewritten to the question the evidence can answer, rather than
  answered with a guess. The fix moved from "clean up duplicates" to "make the
  fallback path unable to produce the split state".
- **Triggered:** `_t2864_reconcile_index` at both archive call sites; four new bats
  cases including a negative control.

### 2026-08-08 — the real cause was in the committer, not the mover

- **What changed:** "Not reproducible" was wrong, and wrong for an instructive
  reason: I looked for the duplicate in the real index, but `_commit_decision`
  builds a **scratch** index (T-2708) and the duplicate only ever existed there. It
  harvests `git status --porcelain` and keeps only the destination of a rename
  arrow, while seeding from HEAD where the source still lives. Since `update-task.sh`
  archives with `git mv` (T-1523), the rename form is the normal case — so the
  committer manufactures the very G-052 violation the gate refuses.
- **Plan impact:** The RCA's "not reproducible" conclusion was retracted and
  replaced with a measured mechanism. The fix moved from update-task.sh (defect B,
  real but incidental) to `web/blueprints/inception.py` (defect A, the reported bug).
- **Triggered:** Both-sides rename harvest + docstring correction; five pytest cases
  asserting the committed tree, verified non-vacuous by reverting the fix. One
  deliberate out-of-scope carve-out logged in the RCA: the decided-but-uncommitted
  window is a sovereignty-record hole that needs its own task.

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

### 2026-08-08T07:23:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2864-g-052-duplicate-task-ids-block-the-t-286.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ab122424
- **Timestamp:** 2026-08-08T07:42:50Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-08T07:42:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
