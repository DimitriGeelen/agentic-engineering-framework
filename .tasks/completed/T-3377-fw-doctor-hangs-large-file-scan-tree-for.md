---
id: T-3377
name: "fw doctor hangs: large-file scan-tree forks grep+stat per file across 17k tracked
  files"
description: >
  fw doctor hangs: large-file scan-tree forks grep+stat per file across 17k tracked
  files

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/git/lib/large-file-scan.sh, tests/unit/t3377_large_file_scan.bats]
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
created: 2026-09-16T19:55:04Z
last_update: 2026-09-16T20:03:35Z
date_finished: 2026-09-16T20:03:35Z
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
  - ts: '2026-09-16T20:00:12Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=322,acs=7)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-16T20:00:26Z'
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
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3377: fw doctor hangs: large-file scan-tree forks grep+stat per file across 17k tracked files

## Context

`bin/fw doctor --quick` does not complete on this host. Measured: exit 124 at a
120s timeout, near-zero CPU in the parent (`user 0m0.002s`) because it is
blocked in a child. Partial output stops after `OK Exec-bit parity`, and the
check immediately following it (`bin/fw:1737-1752`) shells out to
`agents/git/lib/large-file-scan.sh scan-tree`. Timed standalone: exit 124 at a
60s timeout, `user 0m19.128s / sys 0m49.423s` — CPU-bound, grinding processes.

`scan_tree` (large-file-scan.sh:131-161) loops over `git ls-files` — **17,270
tracked files in this repo** — and per file runs `_lf_is_allowed`, which is
`echo "$path" | grep -qE` (line 80-84: a pipeline, so a subshell plus a `grep`
fork), then a `stat` fork, then `_lf_human_size`. That is ~35-50k process
spawns per scan, which is the measured sys time almost exactly.

**This is not a hypothetical slow path — it is the documented one.** The audit
carries its own measurements in a comment at `agents/audit/audit.sh:3300-3320`:
secret scan-tree 188s, large-file scan-tree 95s, whole `structure` section 347s.
T-3062 responded by moving both scans out of `structure` (the pre-push horizon)
into a `tree` section that only a full audit runs. That fixed the audit call
site and **left doctor's inline call site untouched** — the same
remembered-site-list-vs-enumerating-guard shape as L-533. Doctor still pays the
full 95s on every invocation, including `--quick`, whose banner claims
"project-only mode — host/network probes skipped".

Blast radius: `fw doctor` is named in `## Verification` blocks across the
corpus and in the daily cron audit, so a verb that cannot return inside a
gate's timeout degrades every close that depends on it. The audit comment
already describes this failure shape in the push path, and the description
transfers exactly: *"Pushes were not blocked — they were killed partway
through, which looks the same from the outside and reports nothing."*

## Acceptance Criteria

### Agent
- [x] `scan_tree` over the full tracked tree completes in **under 30s** (baseline: >95s documented, >60s measured here as a timeout, not a completion)
      → **0s** measured post-fix (rc=0, 15 lines). Pre-fix implementation from the pinned SHA, same tree, same run: **101s**.
- [x] Post-fix `scan_tree` output is **byte-identical** to a captured pre-fix baseline over the same tree — the change is performance-only, with no shift in which files are reported or at which threshold
      → `diff -q` of old vs new over all 17,270 tracked files: **IDENTICAL**, 15 lines each.
- [x] `bin/fw doctor --quick` completes (exit 0 or 1, not 124) within a 120s timeout and emits its large-file line
      → **27s**, rc=2, 249 lines, emits `INFO Large-file gate: 15 tracked file(s) above warn threshold`. rc=2 is a pre-existing VERSION FAIL unrelated to this change (filed OBS-426), not a timeout — the AC's bar is "returns a verdict at all".
- [x] A bats regression test pins scan_tree behaviour against a **committed fixture repo** (block threshold, warn threshold, allowlist exemption, clean tree) rather than the live corpus — per T-3326, no live-count anchors
      → `tests/unit/t3377_large_file_scan.bats`, **10/10 ok, 0 skips**. Also **10/10 against the pre-fix source** via `FW_LARGE_FILE_SCAN_SRC` — the parity control that makes these a spec both implementations meet, not a description of the new one.
- [x] The sibling `secret-scan.sh scan-tree` site is **enumerated and reported** (L-533: select by dependency, not by remembered filename) — fixed in the same pass if it shares the per-file-fork shape, or explicitly scoped out here with the reason
      → Enumerated: it does **not** share the shape. It runs `git grep` once per pattern (secret-scan.sh:225-236), so its 188s is O(patterns × tree). Scoped out with the reason and filed as **OBS-427** so nobody "fixes" it by analogy.

<!-- No ### Human section: every criterion above is deterministic (elapsed time,
     byte-identical output, exit code, fixture-based test). Nothing here touches a
     rendering surface, so P-013 does not apply. Template sanctions removal —
     "Remove this section if all criteria are agent-verifiable." Removed rather
     than left empty, per T-2420: an empty Human block between ### Agent and
     ## Verification makes Human ACs report 0/0.

     Retained template guidance for the next author:
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

# AC1 — scan_tree completes well inside the old 95s. rc 0 (clean) or 1 (blocks
# found) both count as completion; 124 is the timeout we are fixing.
start=$(date +%s); timeout 120 env PROJECT_ROOT="$PWD" agents/git/lib/large-file-scan.sh scan-tree > /tmp/.t3377-lf-new.out 2>&1; rc=$?; end=$(date +%s); test "$rc" -le 1 && test $((end - start)) -lt 30

# AC2 — semantics preserved. Diffs the NEW implementation against the PRE-FIX
# one (pinned SHA 949ed27a1, immutable) over whatever the tree currently holds.
# The invariant asserted is equality of the two implementations, NOT any
# particular file list — so this cannot rot as the corpus moves (T-3326).
git show 949ed27a1:agents/git/lib/large-file-scan.sh > /tmp/.t3377-old.sh && chmod +x /tmp/.t3377-old.sh && timeout 600 env PROJECT_ROOT="$PWD" /tmp/.t3377-old.sh scan-tree > /tmp/.t3377-lf-old.out 2>&1; diff -q /tmp/.t3377-lf-old.out /tmp/.t3377-lf-new.out

# AC3 — doctor returns at all, and actually reaches the large-file line.
timeout 120 bin/fw doctor --quick > /tmp/.t3377-doc.out 2>&1; rc=$?; test "$rc" -ne 124 && grep -q "Large-file gate" /tmp/.t3377-doc.out

# AC4 — fixture-based regression suite. Two lines: "did anything fail" and
# "did everything run" (T-3217 — a skipped bats test reports `ok`).
timeout 300 bats tests/unit/t3377_large_file_scan.bats > /tmp/.t3377-bats.out 2>&1 && ! grep -q "^not ok" /tmp/.t3377-bats.out
test "$(grep -c '# skip' /tmp/.t3377-bats.out)" -eq 0

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

**Symptom:** `bin/fw doctor --quick` never returns — exit 124 at a 120s timeout,
output stopping after `OK Exec-bit parity`. `git push` also hung (>180s), because
the pre-push hook runs `audit --section structure`. Neither surface reported a
reason; both simply failed to finish.

**Root cause:** `scan_tree` did per-file work across the whole tracked tree. For
each of 17,270 paths it ran `_lf_is_allowed` — `echo "$path" | grep -qE`, a
subshell plus a `grep` fork — and then a `stat` fork, before any size test. The
size test is the cheap discriminator and it ran last, so ~35-50k processes were
spawned to report 15 lines. Measured: user 19.128s / sys 49.423s, incomplete at
60s. Fix inverts the order: one batched `stat` pass over the file list, an awk
cut at the warn threshold, and the per-path work only on survivors. 0s measured
after, against a >60s timeout before.

**Why structurally allowed:** the cost was *known and written down*. The audit
carries the measurements in a comment (`agents/audit/audit.sh:3300-3320`:
secret 188s, large-file 95s, structure total 347s) and T-3062 acted on them — by
moving both scans out of the pre-push horizon into a daily `tree` section. That
fixed the call site T-3062 was looking at and left doctor's inline call site
(`bin/fw:1737-1752`) untouched, because the remedy was *relocation of one known
caller* rather than *reduction of the cost itself*. Consumers were selected by
the site being worked on, not enumerated by dependency on the scanner — the
L-533 shape. Anything else that calls `scan-tree` inherited the 95s silently,
and `--quick`, whose banner promises "host/network probes skipped", pays it in
full.

Two properties kept it invisible. The scan is CPU-bound but the *parent* blocks,
so `fw doctor` looks idle rather than busy. And both affected surfaces fail by
timeout: the audit comment already described this exactly — *"Pushes were not
blocked — they were killed partway through, which looks the same from the
outside and reports nothing."* That sentence was written about the push path and
was equally true of doctor, unnoticed, because nothing connected the two.

**Prevention:** distinct from the fix, three parts.
1. `tests/unit/t3377_large_file_scan.bats` pins the reporting rules against a
   fixture repo (thresholds, allowlist exemption at BOTH levels, ordering,
   missing-path skip, spaced paths), so a future rewrite for speed cannot move
   semantics unnoticed. It passes against the pre-fix source too — parity, run
   via `FW_LARGE_FILE_SCAN_SRC` — which is what makes it a spec rather than a
   description of current behaviour.
2. AC2's verification line diffs the live implementation against the pinned
   pre-fix SHA, so equality is re-checkable rather than asserted once.
3. The sibling site was enumerated rather than assumed: `secret-scan.sh`
   `scan_tree` does **not** share this defect — it runs `git grep` once per
   pattern and says so at line 225-226. Its 188s is O(patterns × tree), a
   different shape needing a different fix. Named here so the next reader does
   not "fix" it by analogy. Filed as its own observation rather than folded in.

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

### 2026-09-16T19:55:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3377-fw-doctor-hangs-large-file-scan-tree-for.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1b592359
- **Timestamp:** 2026-09-16T20:05:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-16T20:03:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
