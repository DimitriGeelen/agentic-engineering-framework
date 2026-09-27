---
id: T-3505
name: "Fix two merge-blockers: audit.sh exec bit on dispatch-f21-f24, gate two tests on t3487"
description: >
  Fix two merge-blockers: audit.sh exec bit on dispatch-f21-f24, gate two tests on t3487

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/audit/audit.sh]
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
created: 2026-09-26T13:33:10Z
last_update: 2026-09-26T13:44:58Z
date_finished: 2026-09-26T13:44:58Z
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

# T-3505: Fix two merge-blockers: audit.sh exec bit on dispatch-f21-f24, gate two tests on t3487

## Context

Operator dispatch (not a pickup message): a review found four merge-queued branches
sound except two defects. Fix them on the branches via git plumbing (no worktree, no
checkout of the target branches — main checkout stays on bleeding-edge). No push, no
merge, no rebase/squash of the reviewed tips. Scope fence: only `dispatch-f21-f24`
(restore exec bit on `agents/audit/audit.sh`, mode-only, content/blob unchanged) and
`t3487-remove-bvp-arc-approval-gate` (gate two tests behind `FW_REQUIRE_ARC_CLOSE_APPROVAL=1`
instead of leaving them permanently red). `dispatch-f25` and
`t3485-bvp-quadrant-value-axis` are explicitly out of scope, as is `lib/inception.sh`.

## Acceptance Criteria

### Agent
- [x] `dispatch-f21-f24` has a new commit on top of tip `48b07d763` restoring
      `agents/audit/audit.sh` to mode `100755`, with the blob hash unchanged
      (mode-only change) and the previous tip as sole parent (no rebase/squash).
- [x] `t3487-remove-bvp-arc-approval-gate` has a new commit on top of tip `6adf45442`
      gating `test_close_refused_when_claudecode_set_no_override` and
      `test_refusal_message_includes_anchor_redirect` in
      `tests/unit/test_arc_close_agent_gate.py` to run only when
      `FW_REQUIRE_ARC_CLOSE_APPROVAL=1`, matching the file's existing idiom, with the
      previous tip as sole parent.
- [x] Both gated tests demonstrated to RUN and PASS with the switch set, and SKIP
      (not fail, not silently absent) without it — actual pytest output captured, not
      just code inspection.
- [x] No other file on either branch touched; `dispatch-f25` and
      `t3485-bvp-quadrant-value-axis` untouched; nothing pushed.

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

git ls-tree dispatch-f21-f24 -- agents/audit/audit.sh | grep -q '^100755 blob'
test "$(git ls-tree dispatch-f21-f24 -- agents/audit/audit.sh | awk '{print $3}')" = "$(git ls-tree 48b07d763 -- agents/audit/audit.sh | awk '{print $3}')"
test "$(git rev-parse dispatch-f21-f24~1)" = "48b07d763b274a6a954d0fb15b51cf3a34716abf"
test "$(git merge-base t3487-remove-bvp-arc-approval-gate 6adf45442)" = "6adf45442c831c2e6fd7ac32ea2ffb02ca79b6be"

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

**Symptom:** Two of four merge-queued branches had defects an independent review found but
did not fix: (1) `agents/audit/audit.sh` silently lost its executable bit (100755→100644) on
`dispatch-f21-f24`, which would make `fw audit` die with exit 126 since `bin/fw` execs that
file directly rather than via `bash audit.sh`; (2) two tests in
`tests/unit/test_arc_close_agent_gate.py` on `t3487-remove-bvp-arc-approval-gate` went
permanently red because they pinned a default-refusal behaviour the branch intentionally made
opt-in (`FW_REQUIRE_ARC_CLOSE_APPROVAL`), and were never updated to match.

**Root cause:** (1) Some prior editing tool/workflow rewrote `audit.sh`'s content (commit
`bd039ae3a`, fixing F-21/F-24) and dropped the executable bit as a side effect — the same
class OBS-336/T-3317 already exists for, meaning this is a repeat instance, not a new failure
mode. (2) The `t3487` branch changed `lib/arc.sh`'s gate condition but treated the test file as
out of scope for that commit, leaving assertions that pin the exact behaviour just removed.

**Why structurally allowed:** (1) Git tracks the executable bit as ordinary tree metadata;
nothing enforces it stays set across a content-only edit, and CI/test suites don't assert file
modes unless a test specifically checks for it. (2) Nothing structurally forces a behaviour
change to update the tests that pin the old behaviour in the same commit — P-011/AC gates
check the task's own declared criteria, not "did existing tests still pass," and this was
caught only by an independent review reading the diff, not by CI.

**Prevention:** (1) OBS-336/T-3317 is the named structural fix for the exec-bit class; this
task is a second instance under it, not a new gap — no new prevention filed here. (2) None
filed as a general rule beyond this fix: gating (rather than deleting or rewriting) the two
tests keeps the check alive for when the switch is restored, per the operator's explicit
reasoning in the dispatch prompt, and is the local fix rather than a general prevention
mechanism.

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

**Recommendation:** GO
**Rationale:** Both merge-blockers fixed via git plumbing, no rebase/squash, no push. Every
verification line and the pytest reproduction below is real captured output, not inference.
**Evidence:**
- `dispatch-f21-f24` new tip `a6c5c14f2`, parent `48b07d763` (unchanged). `git ls-tree` shows
  `100755 blob 9bf6eea...` — same blob hash as before, mode-only diff (`git diff --raw` on
  the two root trees showed exactly one line: the mode change on `agents/audit/audit.sh`).
- `t3487-remove-bvp-arc-approval-gate` new tip `4485f542e`, parent `6adf45442` (unchanged).
  Only `tests/unit/test_arc_close_agent_gate.py` touched (confirmed via `git diff --raw` on
  root trees, one line).
- Extracted the new tip via `git archive` (not a worktree — avoids the boundary-hook issue
  named in the prompt) to `/tmp/t3505-t3487-check` and ran the real tests:
  - `FW_REQUIRE_ARC_CLOSE_APPROVAL=1`: 7/7 pass, including both gated tests.
  - unset: 5 passed, 2 skipped (not failed) — `test_close_refused_when_claudecode_set_no_override`
    and `test_refusal_message_includes_anchor_redirect`.
- Re-measured the curated 65-file CLAUDECODE-relevant subset the T-3487 report used (grepped
  fresh on the archived tip: 59 `.bats` + 6 pytest, same file count). Curated pytest (6 files),
  `FW_NO_REEXEC=1 FW_REQUIRE_ARC_CLOSE_APPROVAL=1`: **255 passed, 3 failed** — matches the
  report's BEFORE baseline exactly (819 total pass includes 564 bats + 255 pytest), i.e. the
  delta this fix closes is exactly the 2 tests it targeted, confirmed by direct rerun rather
  than arithmetic. The 3 remaining pytest failures (`test_govd_sandbox.py`,
  `test_tier0_origin.py` ×2) are the same pre-existing, environment-dependent ones the T-3487
  report already named (assume a real `.git` directory; false here only because `git archive`
  has no `.git`, not because of this fix). Did not re-run the 59-file bats subset — it exceeded
  a 300s timeout in this environment and the change here touches zero `.bats` files, so it
  cannot move that number; not claiming a number I didn't measure.
- `dispatch-f25` and `t3485-bvp-quadrant-value-axis` tips unchanged (`671ea6c0e`, `e67d7e95b`).
  Main checkout still on `bleeding-edge`, working tree diff unrelated to this session's plumbing.
- Nothing pushed; no `--force` used anywhere.

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

### 2026-09-26T13:33:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3505-fix-two-merge-blockers-auditsh-exec-bit-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-33ab39f8
- **Timestamp:** 2026-09-26T13:45:00Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `git ls-tree dispatch-f21-f24 -- agents/audit/audit.sh | grep -q '^100755 blob'`

### 2026-09-26T13:44:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
