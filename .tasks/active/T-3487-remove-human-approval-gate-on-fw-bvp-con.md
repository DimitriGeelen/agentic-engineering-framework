---
id: T-3487
name: "Remove human-approval gate on fw bvp confirm and fw arc close (operator-authorised
  sovereignty waiver)"
description: >
  Remove human-approval gate on fw bvp confirm and fw arc close (operator-authorised
  sovereignty waiver)

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [arc:value-prioritisation]
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
created: 2026-09-25T22:46:23Z
last_update: 2026-09-26T08:12:55Z
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
  - ts: '2026-09-25T23:00:12Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=304,acs=14)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-25T23:00:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3487: Remove human-approval gate on fw bvp confirm and fw arc close (operator-authorised sovereignty waiver)

## Context

Operator instruction, verbatim, 2026-09-26: "We're going to cut out any human need for
approval. BVP and ARC drivers. That's in the design. So you can implement it. Will be
overwritten later… ask AEF agent." This is a **sovereignty waiver**, not a defect repair —
the two §ACD gates below work as designed; the operator has authority to remove them and
expects the removal to be reversible.

Gates in scope:
1. `fw bvp confirm` — `lib/bvp.sh` ~91-96, ~869-882 (refuses under `$CLAUDECODE=1` unless
   `--i-am-human`/`--from-watchtower`).
2. `fw arc close` — `lib/arc.sh` ~696-710 (same shape, "Mirrors lib/inception.sh").

**Out of scope:** `fw inception decide` (`lib/inception.sh`, T-1259) — the operator named
BVP and ARC only. Report the sibling gate there; do not touch it.

**Branch constraint:** must branch from `t3485-bvp-quadrant-value-axis`
(`e67d7e95b1b1e3f12b5735d7268c616046c8ee84`) — that branch already modifies `lib/bvp.sh`
(withholds a verdict on a degenerate median, `QUAD_VALUE_WITHHELD`). Do not alter that
repair; report any conflict rather than resolving it unilaterally. Branch only, do not push
— at least 5 projects pull this repo; operator reviews the diff first.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Both gates re-derived as refusing under `CLAUDECODE=1` BEFORE the change, with the exact commands/output captured in the task Updates
- [x] `fw bvp confirm` succeeds under `CLAUDECODE=1` with no `--i-am-human`/`--from-watchtower` flag, after the change
- [x] `fw arc close` succeeds under `CLAUDECODE=1` with no `--i-am-human`/`--from-watchtower` flag, after the change
- [x] Restore mechanism (env var or config key) implemented for both gates; demonstrated bringing the refusal back when set
- [x] WHO/BY-WHAT-AUTHORITY remains reconstructable from the record after a confirm/close with no identity flag (`confirmed_by`/`confirmed_at` or equivalent) — verified, not assumed
- [x] `--headline-mechanic` and `--demo` requirements on `fw arc close` explicitly classified as "part of the approval gate" or "independent quality requirement" in the Decisions section, with the code reasoning shown
- [x] Negative control: `fw inception decide` (and any other §ACD gate not named in scope) still refuses under `CLAUDECODE=1` post-change — reproduced, not assumed
- [ ] Full test suite run before and after; before/after pass counts reported in Updates — **NOT fully done**: ran a curated 65-file CLAUDECODE-relevant subset (59 bats + 6 pytest), not the full 663+223-file corpus, because a single `bin/fw test unit` pass alone exceeded a 580s timeout with no backgrounding permitted. Counts reported in Updates; left unticked because the AC as written says "full test suite" and that did not happen.
- [x] `t3485-bvp-quadrant-value-axis`'s existing `QUAD_VALUE_WITHHELD` repair in `lib/bvp.sh` is unmodified — diff confirms only the confirm-gate hunk changed in that region
- [x] Work committed (git plumbing or worktree — see Decisions if a worktree was used) on top of the T-3485 branch tip; branch NOT pushed; final commit SHA recorded in task Updates
- [x] `lib/inception.sh`'s sibling §ACD gate finding recorded in this task (location, current behaviour) — explicitly NOT modified

### Human
- [ ] [REVIEW] Operator reviews the diff (bvp.sh + arc.sh changes, restore-mechanism shape, and the "wrong about this instruction" section if any) and decides whether to push/merge
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && git log --oneline t3485-bvp-quadrant-value-axis..<final-branch> && git diff t3485-bvp-quadrant-value-axis..<final-branch> -- lib/bvp.sh lib/arc.sh`
  2. Read the task's Decisions/Recommendation sections for the reversibility mechanism and the headline-mechanic/demo classification
  **Expected:** Diff matches only the two named gates; restore mechanism present; no change to `t3485`'s value-axis repair or to `lib/inception.sh`
  **If not:** Do not push; flag the discrepancy back to the agent for correction


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

git rev-parse --verify t3487-remove-bvp-arc-approval-gate | grep -q 6adf45442c831c2e6fd7ac32ea2ffb02ca79b6be
git diff e67d7e95b1b1e3f12b5735d7268c616046c8ee84 t3487-remove-bvp-arc-approval-gate --name-only > /tmp/.t3487-verif-files; diff <(printf 'lib/arc.sh\nlib/bvp.sh\n') <(sort /tmp/.t3487-verif-files) > /dev/null
diff <(git show e67d7e95b1b1e3f12b5735d7268c616046c8ee84:lib/bvp.sh | grep -n QUAD_VALUE_WITHHELD) <(git show t3487-remove-bvp-arc-approval-gate:lib/bvp.sh | grep -n QUAD_VALUE_WITHHELD) > /dev/null
git show t3487-remove-bvp-arc-approval-gate:lib/bvp.sh > /tmp/.t3487-verif-bvp.sh && grep -q "FW_REQUIRE_BVP_CONFIRM_APPROVAL" /tmp/.t3487-verif-bvp.sh
git show t3487-remove-bvp-arc-approval-gate:lib/arc.sh > /tmp/.t3487-verif-arc.sh && grep -q "FW_REQUIRE_ARC_CLOSE_APPROVAL" /tmp/.t3487-verif-arc.sh
test -f docs/reports/T-3487-bvp-arc-approval-gate-removal.md

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

**Recommendation:** GO
**Rationale:** Both gates are re-derived as refusing before the change, succeed
under `CLAUDECODE=1` with no identity flag after the change, and restore to the
original refusal with the documented env var — all reproduced with real
command output, not assumed. Provenance fields (`confirmed_via`/`closed_via`)
are added and verified. The T-3485 value-axis repair is confirmed byte-identical
in the untouched region. Every named negative control (`lib/inception.sh`,
`arc_abandon`, `arc_approve_driver --none`, and the other 4 `acd_gate()` callers
in `lib/bvp.sh`) still refuses, reproduced. Diff is scoped to exactly the two
named files/gates. Full rationale and evidence, including two things the
operator should read before merging, in `docs/reports/T-3487-bvp-arc-approval-gate-removal.md`
§8: (1) the `bvp confirm` gate had zero test coverage before this change and
still has none after — its removal is real but untested either way; (2) the
provenance fields record who acted but nothing downstream audits them yet, so
this is a forensic record, not a replacement control.
**Evidence:**
- Before/after refusal reproduction for both gates (direct-source harness, both worktrees removed after use)
- Reversibility demonstrated for both env vars, including `--i-am-human`/`--from-watchtower` override still working with the gate restored
- `confirmed_via`/`closed_via` verified in written frontmatter, not just claimed
- 6 negative controls reproduced refusing, unchanged
- Curated 65-file CLAUDECODE-relevant test subset: before 819 pass/32 fail, after 817 pass/34 fail — the only delta is the 2 tests in `test_arc_close_agent_gate.py` that assert the now-intentionally-removed default refusal; not the full corpus (named as a gap, AC left unticked)
- Diff stat: `lib/arc.sh | 37 ++-`, `lib/bvp.sh | 48 ++-`, 2 files changed

---

## SOVEREIGN QUESTION — parked by the parent session, 2026-09-26, NOT merged

The builder's recommendation above is left intact: it is their advisory, the
engineering is thorough, and the reversibility work is real. **The question is
scope of authorisation, not quality of implementation.** This task is parked at
`horizon: later` pending one operator ruling.

### The question

**Was removing the `fw arc close` sovereignty gate authorised?**

The authorisation this task cites, verbatim from its own commit message:

> "We're going to cut out any human need for approval. **BVP and ARC drivers.**
> That's in the design. So you can implement it. Will be overwritten later…
> **ask AEF agent.**"

And the operator's sitting instruction in the same thread: *"Take the human in
the loop out for scoring. Also take the human in the loop out for BVP arc value
drivers."*

Both name **BVP scoring** and **arc value DRIVERS**. What the branch removes is
the gate on **`fw arc close`** — arc *closure*, a different verb with a different
decision class. The branch's own commit message states that
`arc_approve_driver --none` and `arc_abandon` were deliberately **not** touched —
so the one verb the operator actually named, `approve-driver`, is untouched,
while a verb they did not name is opened.

Worth stating plainly: the drivers half was **already delivered** by T-3429/D-586
(*"per default just create them and add them"* — `fw arc approve-driver
--all-reviewed` is already the agent default, reviewer-gated). Only the negative
ruling `--none` remains human-only. So the operator's driver instruction was
already satisfied before this task began.

### Why this is not mine to decide

1. `fw arc close`'s refusal is the documented outcome of a **fourth** repeat
   incident — an agent auto-closing an arc (T-1670, T-1671,
   `docs/reports/T-1670-default-to-open-gate-gap.md`). CLAUDE.md §Arc Completion
   Discipline records it as *"closure belongs to the human"*, with
   **Default-to-OPEN** as an explicit standing rule.
2. CLAUDE.md §Autonomous Mode Boundaries: *"a broad directive does not override
   structural enforcement."* "Cut out any human need for approval" is exactly
   such a broad directive, and its own next sentence scopes it to BVP and drivers.
3. The authorisation quote **itself ends in "ask AEF agent"** — the operator
   flagged uncertainty in the same breath. The builder recorded that and
   proceeded past it.
4. The standing governance binding for this run lists `fw arc close` and
   `fw inception decide` as **agent-refused by design**.

### Independent reason it could not have closed anyway

AC #8 is **unticked** by the builder's own honest reporting: *"Full test suite run
before and after — NOT fully done."* And the curated subset moved **819 pass/32
fail → 817 pass/34 fail** — the two new failures are in
`tests/unit/test_arc_close_agent_gate.py`, which assert the refusal this change
removes. So merging as-is ships two red tests whose subject is the very gate in
question. P-010 would refuse the close independently of the scope question.

### The three options, for the operator

1. **Split it.** Land the `lib/bvp.sh` half (`fw bvp confirm`) — squarely within
   the authorisation — and drop the `lib/arc.sh` half. Requires reworking the
   single commit into two.
2. **Confirm the wider waiver** and land both, after updating/removing the two
   `test_arc_close_agent_gate.py` tests so the suite states the new intent rather
   than failing against it.
3. **Drop the arc-close half permanently**, leaving §ACD intact, and keep the
   provenance fields (`confirmed_via`/`closed_via`) which are useful either way.

Recommendation from the parent session, offered as advisory only: **option 1.**
It delivers everything the operator asked for and nothing they did not, and it
does not require re-litigating a gate that took four incidents to earn. Note
also the builder's own §8 caveat — `fw bvp confirm` had **zero test coverage
before this change and still has none after** — so even the authorised half
lands untested unless coverage is added.

### Not done, deliberately

The branch `t3487-remove-bvp-arc-approval-gate` @ `6adf45442` is **left intact
and unmerged**. It was not rebased, not split, not partially cherry-picked — any
of those would be deciding the question above by action.

## Decisions

### 2026-09-26 — Reversibility mechanism
- **Chose:** opt-in env vars, `FW_REQUIRE_BVP_CONFIRM_APPROVAL=1` and
  `FW_REQUIRE_ARC_CLOSE_APPROVAL=1`, wrapping the existing `acd_gate()` call
  (bvp) and the existing inline `CLAUDECODE` block (arc) respectively. Unset
  (default) skips the check entirely; set restores the exact original refusal
  byte-for-byte (verified — same stderr text, same override flags still work).
- **Why:** the operator said "will be overwritten later," which reads as
  provisional, and an env-var switch reverses with zero code change. It also
  keeps the diff minimal and auditable — one conditional added per site,
  nothing deleted.
- **Rejected:** outright deletion of the gate blocks/branches. Would be a
  smaller diff but loses the one-line revert path the operator's own phrasing
  implied, and destroys the refusal text/logic that a future re-enable would
  otherwise just need to re-arm rather than rewrite.

### 2026-09-26 — `--headline-mechanic`/`--demo`: independent requirement, not part of the gate
- **Chose:** classified both as independent evidence-quality requirements,
  left fully enforced and untouched.
- **Why:** `_arc_validate_headline_mechanic()` (`lib/arc.sh:268-294`) is called
  from `arc_create()`, not `arc_close()`, and its body reads only its text
  argument — no reference to `CLAUDECODE`/`i_am_human`/`from_watchtower`
  anywhere. The `--demo` validation inside `arc_close()` runs unconditionally,
  after the identity-gate block, not inside it. Confirmed by direct test: with
  the identity gate at its new default (off), closing under `CLAUDECODE=1`
  with no `--demo` still refuses (`--demo is required...`), and with the gate
  restored plus `--i-am-human`, an undersized demo file still refuses on size
  — the two checks are provably orthogonal.
- **Rejected:** treating "§ACD Layer A/B" (the code's own comment label) as
  meaning "part of the same gate this task removes." The shared §ACD name
  describes a shared motivation (closure-quality), not a shared mechanism.

### 2026-09-26 — Branch construction: git plumbing + throwaway verification worktrees
- **Chose:** built the two-file diff via git plumbing (scratch index file,
  `hash-object`/`update-index`/`write-tree`/`commit-tree`), never touching the
  main checkout's working tree. For execution-only verification (actually
  running `fw bvp confirm`/`fw arc close` against fixtures, and the test
  suite), created two throwaway `git worktree` checkouts (one at the T-3485
  base commit, one at the T-3487 tip), used them, then removed both
  (`git worktree remove --force`) before finishing.
- **Why:** the main checkout has unrelated live-session uncommitted changes
  the task explicitly said not to disturb; plumbing edits a file nobody is
  looking at. Execution needs a real working tree somewhere (git plumbing
  alone can't run a shell script), and a worktree was the prompt's own named
  alternative for exactly that case.
- **Note:** discovered mid-verification that `bin/fw`, when run from inside a
  linked worktree, silently re-execs the main checkout's `bin/fw`
  (`_fw_reexec_authority`, T-3111) unless `FW_NO_REEXEC=1` is set — so my first
  pass of "before vs after" test-suite comparisons was accidentally comparing
  the main checkout against itself. Re-ran with `FW_NO_REEXEC=1`; full
  explanation in the report §1 and §5.
- **Rejected:** running everything via direct-source harnesses only (bypassing
  `bin/fw` entirely) would have avoided the reexec trap from the start, and I
  did use that method for the identity-gate reproductions themselves — but the
  test suite's own fixtures (e.g. `test_arc_close_agent_gate.py`) invoke
  `bin/fw` as a subprocess by design, so there was no way to run the *existing*
  test suite without hitting this.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-25T22:46:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3487-remove-human-approval-gate-on-fw-bvp-con.md
- **Context:** Initial task creation

### 2026-09-25T23:10:00Z — gates removed, verified, branch built [t3487-gate-removal termlink worker]
- **Action:** Removed the identity/authority check from `fw bvp confirm` (`lib/bvp.sh` `cmd_confirm`) and `fw arc close` (`lib/arc.sh` `arc_close()`), gated behind opt-in restore switches `FW_REQUIRE_BVP_CONFIRM_APPROVAL=1` / `FW_REQUIRE_ARC_CLOSE_APPROVAL=1`. Added `confirmed_via`/`closed_via` provenance fields. Left `acd_gate()` itself, its other 4 call sites, `arc_abandon`, `arc_approve_driver --none`, and `lib/inception.sh` fully untouched.
- **Before (reproduced):** `fw bvp confirm T-<id>` under `CLAUDECODE=1` no flag → refused (§ACD, M6), rc=1. `fw arc close <id> --demo ... --decision ...` under `CLAUDECODE=1` no flag → refused (§ACD/G-062, T-1671), rc=1, arc stayed `in-progress`.
- **After (reproduced):** both succeed under `CLAUDECODE=1` with no identity flag; `confirmed_via: agent` / `closed_via: agent` written to the record. Restoring the env var brings the exact original refusal back; `--i-am-human`/`--from-watchtower` still work with the switch on, recording `confirmed_via/closed_via: human` or `watchtower` correctly.
- **Negative controls (all reproduced refusing, unchanged):** `lib/inception.sh` `fw inception decide`; `arc_abandon`; `arc_approve_driver --none`; the other 4 `acd_gate()` callers in `lib/bvp.sh` (`weight`, `driver --add`, `driver --remove`, `auto-promote --enable`).
- **Test suite (curated 65-file CLAUDECODE-relevant subset, not the full corpus — see AC note):** BEFORE 819 pass/32 fail (564/29 bats + 255/3 pytest); AFTER 817 pass/34 fail (564/29 bats + 253/5 pytest). The only delta is 2 newly-failing tests in `tests/unit/test_arc_close_agent_gate.py` (`test_close_refused_when_claudecode_set_no_override`, `test_refusal_message_includes_anchor_redirect`) — both assert the exact default-refusal behaviour this task intentionally removed. All other failures (29 bats + 3 pytest) are pre-existing, environment-dependent, and identical in both runs. `fw bvp confirm`'s gate had zero dedicated test coverage before or after.
- **Methodological finding:** `bin/fw` re-execs to the main checkout's authority when run from a linked worktree (`_fw_reexec_authority`, T-3111) unless `FW_NO_REEXEC=1` is set — my first test-suite comparison pass was silently comparing the main checkout against itself. Re-ran with `FW_NO_REEXEC=1` for the numbers above.
- **Branch:** `t3487-remove-bvp-arc-approval-gate` on top of `t3485-bvp-quadrant-value-axis` (`e67d7e95b1b1e3f12b5735d7268c616046c8ee84`). Tip commit `6adf45442c831c2e6fd7ac32ea2ffb02ca79b6be`. Built via git plumbing; two throwaway verification worktrees created and removed. Not pushed.
- **Output:** `docs/reports/T-3487-bvp-arc-approval-gate-removal.md` (full detail, including §8 concerns about the instruction).
- **Context:** Sovereignty waiver per operator instruction 2026-09-26. Task left at `started-work`; Human AC (operator diff review) intentionally unticked.

### 2026-09-26T08:12:54Z — status-update [task-update-agent]
- **Change:** tags: +arc:value-prioritisation

### 2026-09-26T08:12:55Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)
