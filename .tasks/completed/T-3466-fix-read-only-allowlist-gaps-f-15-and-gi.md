---
id: T-3466
name: "Fix read-only allowlist gaps (F-15) and git-commit task-file dirt (F-17)"
description: >
  Fix read-only allowlist gaps (F-15) and git-commit task-file dirt (F-17)

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
created: 2026-09-25T11:24:53Z
last_update: 2026-09-25T11:39:28Z
date_finished: 2026-09-25T11:39:28Z
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
  - ts: '2026-09-25T11:30:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=288,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-25T11:30:36Z'
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

# T-3466: Fix read-only allowlist gaps (F-15) and git-commit task-file dirt (F-17)

## Context

Dispatched worker task from a consuming project (vendored at 1.6.768) fixing two
findings against the framework source directly, since the vendored copy is read-only
to the consumer. F-15: `agents/context/lib/safe-commands.sh`'s read-only allowlist
refuses `VAR=$(readonly-cmd)` and `python3 -m pytest`. F-17: `fw git commit`
(`agents/git/git.sh`) appends the task-file Updates entry AFTER creating the commit,
so the working tree is dirty the instant the commit returns.

## Acceptance Criteria

### Agent
- [x] F-15 reproduced-or-not is confirmed against this source with file:line evidence
- [x] F-15: `X=$(git status)` (command-substitution assignment wrapping an allowlisted
      read) is classified safe by `is_bash_safe_command`, while `X=$(rm -rf /tmp/x)`
      (substitution wrapping a genuine write) is still classified unsafe
- [x] F-15: `python3 -m pytest` shape evaluated against the existing script-execution
      exclusion boundary (safe-commands.sh:568-570, CLAUDE.md §Enforcement Tiers
      T-2742) — decision (widen or decline) recorded in Decisions with rationale
- [x] F-15: existing safe-commands bats suite still passes (no regression on prior
      pinned contracts)
- [x] F-17 reproduced-or-not is confirmed against this source with file:line evidence
- [x] F-17: `fw git commit -m "T-XXX: ..."` leaves a clean working tree (the Updates
      entry is written before or included in the commit, not after)

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

out=$(bash -c 'source agents/context/lib/safe-commands.sh; is_bash_safe_command "X=\$(git status)"; echo rc=$?' 2>&1); echo "$out" | grep -q "rc=0"
out=$(bash -c 'source agents/context/lib/safe-commands.sh; is_bash_safe_command "X=\$(rm -rf /tmp/x)"; echo rc=$?' 2>&1); echo "$out" | grep -q "rc=1"
out=$(bash -c 'source agents/context/lib/safe-commands.sh; is_bash_safe_command "python3 -m pytest tests/foo.py -q"; echo rc=$?' 2>&1); echo "$out" | grep -q "rc=1"
timeout 300 bats tests/unit/safe_commands*.bats > /tmp/.t3466-bats.out 2>&1; echo "$?" > /tmp/.t3466-bats.rc; grep -q "^0$" /tmp/.t3466-bats.rc && ! grep -q "^not ok" /tmp/.t3466-bats.out

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

## RCA

**F-15 — Symptom:** `is_bash_safe_command` refused two everyday read-only shapes:
`VAR=$(readonly-cmd)` (a terminal assignment from a command substitution) and
`python3 -m pytest ...` (a test runner). Both were reported as "not on the
read-only allowlist" by the active-task PreToolUse gate with no task active.

**F-15 — Root cause (VAR=$(cmd) shape):** the file's own T-2834 header comment
documents command substitution as "Deliberately NOT handled" — a general
exclusion made for the case where `$(...)` is an ARGUMENT to another command
(widening there risks admitting an outer command on the strength of an inner
one it doesn't share safety with, e.g. conflating `curl` with whatever a
substituted argument resolves to). The general exclusion also covered the
narrower, unambiguous case where the ENTIRE line is one terminal assignment —
`VAR=$(cmd)`, nothing else — where there is no outer command to conflate with.

**F-15 — Root cause (python3 -m pytest shape):** NOT a gap — this is the
`python3|python` case arm's DELIBERATE design, correctly applied. The same file
explicitly excludes `bats`, `make`, `python3 <file>` and `./script.sh` on the
stated ground (safe-commands.sh:568-570, citing CLAUDE.md §Enforcement Tiers
T-2742) that "a file's contents are not visible to a command-string scan, so
executing one is never provably read-only." `python3 -m pytest <path>` executes
arbitrary Python from whatever test files `<path>` resolves to — the identical
class. Implementing the dispatch's suggested widening would have silently
reopened a hole this codebase closed on purpose elsewhere in the same function.
Declined; see Decisions.

**F-15 — Why structurally allowed:** the allowlist is grown incident-by-incident
(this file's own history: T-2834, T-2988, T-3096, T-3222, T-3344, T-3374 are all
"measured this shape gated, widened narrowly"), so an unmeasured shape simply
stays gated until someone hits it and reports it, by design — the file's stated
failure direction is "misjudging safe as unsafe merely sends it to the task
gate" (line 107-109), i.e. the cost of a gap is friction, not a security hole.

**F-15 — Prevention:** the new terminal-assignment recognizer is additive and
delegates to the existing chain-aware entry point recursively, so future
allowlist widenings automatically extend to `VAR=$(...)`-wrapped forms too,
rather than needing their own copy of the recognizer.

**F-17 — Symptom:** `fw git commit -m "T-XXX: ..."` returned success but left
the working tree dirty immediately afterward — `git status` showed the just-
committed task file modified again, with only its `last_update:` frontmatter
timestamp changed.

**F-17 — Root cause:** `agents/git/lib/commit.sh:do_commit` ran `git commit`
first (was line 172) and only THEN called `update_task_timestamp` (was line
177 → `agents/git/lib/common.sh:52`, a `sed -i` on `last_update:`). The bump
was therefore never present in the commit it was describing; it became a
trailing, always-one-commit-behind dirty diff.

**F-17 — Why structurally allowed:** nothing checks "is the tree clean
immediately after `fw git commit` returns" as its own invariant — the
consuming project's audit checks `uncommitted-changes` generically, so a
framework-manufactured dirty diff looks identical to real uncommitted drift,
and the specific commit-then-mutate ordering was never itself under test
(the T-3090 pathspec suite tests WHICH paths land in a commit, not whether
the tree is clean immediately after).

**F-17 — Prevention:** the fix moves the write before the commit for the
common (no-pathspec, non-bypass) flow, so the tree is clean by construction
for the everyday `git add -A && git commit` path. Pathspec-scoped commits
(T-3090, handover-class callers) deliberately keep the OLD post-commit
ordering — see Decisions — so this is a partial, scope-limited prevention, not
a universal one; the corroborating sibling in the dispatch (parking-a-task
deadlock) is the same family and is explicitly out of scope here.

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

### 2026-09-25 — F-15: decline to widen `python3 -m pytest` into the allowlist
- **Chose:** do NOT add `python3 -m pytest` (or any pytest/test-runner shape) to
  `is_bash_safe_command`. Left it classified unsafe (gated).
- **Why:** `agents/context/lib/safe-commands.sh:568-570` already states, for the
  adjacent `sed|awk|...` filter category, that `bats`, `make`, `python3 <file>`
  and `./script.sh` are deliberately excluded because "a file's contents are
  not visible to a command-string scan, so executing one is never provably
  read-only" (citing CLAUDE.md §Enforcement Tiers, T-2742, the Tier 0 scope
  boundary). `python3 -m pytest <path>` imports and executes every test module
  under `<path>` — including arbitrary module-level code in test files and
  `conftest.py` — which is the identical class this file already refuses to
  admit for the sibling shapes. There is no narrower form (e.g.
  `--collect-only`) that avoids executing file content, since collection still
  imports the modules.
- **Rejected:** implementing the dispatch's suggested widening as specified.
  Rejected because it would contradict a design boundary this same file states
  explicitly and enforces for near-identical inputs a few lines away — not
  because the friction it causes isn't real (five refusals in the dispatching
  session's own transcript were cited as motivation).

### 2026-09-25 — F-15: `VAR=$(cmd)` recognizer scoped to the terminal-assignment shape only
- **Chose:** recognize and delegate ONLY when the entire (post-trim) segment
  matches `^[A-Za-z_][A-Za-z0-9_]*=\$\(.*\)[[:space:]]*$` — i.e. the whole
  statement is one assignment from a substitution, nothing else on the line.
- **Why:** the file's T-2834 header comment scoped its "deliberately not
  handled" exclusion to the general case of `$(...)` as an argument to an
  OUTER command (e.g. `curl "$(fw watchtower url)/page"`), where extracting
  and judging the substitution alone would risk admitting the outer command on
  the strength of an inner one it shares no safety property with. A terminal
  assignment has no outer command — the substitution's effect IS the entire
  line's effect — so that risk does not apply to this narrower shape.
- **Rejected:** generalizing to recognize `$(...)` anywhere on a command line.
  Rejected per the file's own stated reasoning above; doing so was not what
  either reproduction case in the dispatch needed, and it is the wider, riskier
  version of the same idea.
- **Verified:** `X=$(echo $(hostname))` (nested substitution) classifies safe —
  the prefix/suffix strip is exactly correct for a well-formed match regardless
  of nesting depth, since only the outermost `VAR=$(` / trailing `)` are
  stripped. `X=$(git status && rm -rf /tmp)` stays gated, because the
  recognizer delegates to the top-level chain-aware entry point
  (`is_bash_safe_command`), which requires every `&&`-joined clause inside the
  substitution to be independently safe.
- **Known limitation, not fixed here:** `_fw_chain_split` (the top-level
  splitter) does not track parentheses, only quotes. So a chain operator
  INSIDE a substitution on an otherwise-terminal assignment, e.g.
  `X=$(git status && echo ok)`, gets split at the top level before reaching
  the new recognizer, and the resulting fragments (`X=$(git status`, `echo
  ok)`) match nothing — the whole line stays gated. Verified this is NOT a
  regression: the identical input was already gated before this fix (tested
  against the pre-fix source via `git stash`). Fixing it would require paren-
  tracking in `_fw_chain_split` itself, a materially larger change touching the
  file's most load-bearing function, and neither of the two dispatch
  reproduction cases needs it. Left as a known gap, not silently widened.

### 2026-09-25 — F-17: pathspec-scoped commits keep the pre-fix (post-commit) ordering
- **Chose:** the pre-commit timestamp-bump-and-stage fix applies only when
  `bypass != true` AND no `--` pathspec was given (the ordinary whole-index
  `git add -A && git commit` flow). Pathspec-scoped commits (`git.sh commit -m
  "..." -- path1 path2`) fall back to the original post-commit ordering.
- **Why:** first attempt auto-appended the task file to a given pathspec so its
  bump could ride in the same commit. That broke 2 of
  `tests/unit/handover_commit_scope.bats`'s T-3090 tests, which pin "a
  pathspec-scoped commit takes EXACTLY the given paths, no more, no fewer" —
  a deliberate safety property protecting a concurrent writer's staged-but-
  uncommitted work from being absorbed (origin: commit d3d3e49db incident).
  Silently widening a caller's explicit path scope to include a file it didn't
  ask for is the same class of defect T-3090 was filed to close, just for a
  different file.
- **Rejected:** auto-injecting the task file into the pathspec array
  (implemented, then reverted after the test failures above).
- **Consequence:** F-17 is fixed for the everyday flow this finding's symptom
  describes, not universally. A pathspec-scoped commit whose message
  references an active task still leaves that task file dirty afterward,
  identically to pre-fix behaviour. This is the narrower, already-accepted
  cost of a narrower, already-deliberate caller (handover-class commits),
  not a regression.

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

### 2026-09-25T11:24:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3466-fix-read-only-allowlist-gaps-f-15-and-gi.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2383785a
- **Timestamp:** 2026-09-25T11:39:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -rf`

### 2026-09-25T11:39:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
