---
id: T-3439
name: "EWCR seventh landing drive: procAsFit round 2 over arc-019, fed drive 6 (T-3437)
  — re-check S1 transfer, work the arc's remaining executable items (T-3438 first),
  re-disposition what moved, surface the rest"
description: >
  EWCR seventh landing drive: procAsFit round 2 over arc-019, fed drive 6 (T-3437)
  — re-check S1 transfer, work the arc's remaining executable items (T-3438 first),
  re-disposition what moved, surface the rest

status: work-completed
workflow_type: design
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
arc_id: ewcr-arc0-contract-evidence
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
created: 2026-09-22T19:27:47Z
last_update: 2026-09-22T19:45:25Z
date_finished: 2026-09-22T19:45:25Z
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
  - ts: '2026-09-22T19:29:06Z'
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
cost_estimate_proposed:
  - ts: '2026-09-22T19:30:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 3
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=3 
      (workflow:design); effort=8 (lines=299,acs=7)
    rubric_sha: e4a00f38e801
---

# T-3439: EWCR seventh landing drive: procAsFit round 2 over arc-019, fed drive 6 (T-3437) — re-check S1 transfer, work the arc's remaining executable items (T-3438 first), re-disposition what moved, surface the rest

## Context

Operator instruction, given twice on 2026-09-22 (17:15Z and 19:35Z), verbatim: "the work on
arc 019 use the procasfit prompt". The repeat after round 1 closed is the decision: arc-019 is
driven with the procAsFit mandate (`tools/prompt-sequence/02-procasfit.prompt.md`, T-3411)
round after round, each fed the previous handback, until the arc's Q1/Q2 work is exhausted or
every remaining path is a Sovereign question. Round 1 was T-3437
(`docs/reports/EWCR/drive-6-procasfit-handback.md`): fence 1 measured clear (0 Unknown of 1332
cards), 15/15 §3 rows dispositioned, D-614/D-615/D-616 recorded, OBS-476 + T-3438 filed
(`tools/ewcr-arc0-unknown-overlap.py` refuses on success, turning T-3394's verification red),
S1 = clause 2 transfer (now two artefacts, not four) named as the single question gating the
arc. This is round 2, fed by that handback.

## Acceptance Criteria

### Agent
- [x] **A1 Selection stated before execution.** Objective → arc-019 (Sovereign-selected) → task
      → quadrant for every unit, the next candidate named; BVP from the estimator only. Drive 6's
      handback is read first and treated as evidence, not a worklist.
      **Evidence:** handback §1 states both units' selection before execution, names why no second
      candidate existed, and states *which* quadrant reading is applied (within-arc) against the
      whole-repo reading it rejects — `bin/fw bvp estimate T-3438` re-run this drive, no self-estimate,
      no rescore; drive 6's handback read in full at run start and cited as evidence throughout §4/§5.
- [x] **A2 T-3438 driven to a terminal state.** The arc's one executable member at round start
      (build, real ACs, `horizon: now`) is worked through its own ACs and closed through the verb,
      or left with a recorded failure mode after at most two attempts — and T-3394's red
      verification line 4 is re-run green or its state recorded.
      **Evidence:** T-3438 closed via `bin/fw task update T-3438 --status work-completed`, 5/5 ACs,
      6/6 verification incl. the empty-directory control (exit 2 preserved); commits `8590c21c6`
      (fix) + `8fca51362` (close). T-3394's line 4 measured **rc=2 before, rc=0 after**, and its
      whole block re-run 6/6 — handback §3.
- [x] **A3 S1 re-checked and every drive-6 Sovereign item re-dispositioned.** The clause-2
      artefacts are searched for again (disk, `xfer-832-*`, `sidecar:832-Workflow-designer`, the
      832 DM rail); S1..Sn from drive 6 §6 are each marked unchanged / moved / resolved with the
      evidence; nothing is answered on the worker's authority.
      **Evidence:** handback §4 — seven surfaces re-checked (all reproduce drive 6's negative) plus
      the DM rail drive 6 did not search, which carries 832's standing position that the artefacts
      EXIST at named paths with published sha256 and the ask is AEF-owned disposition tables. A
      control proves the blind spot rather than asserting it (`termlink agent search` returns 0 for
      a phrase verbatim in the DM); registered as OBS-482. §5 re-dispositions S1–S9 with verdicts
      moved/unchanged/resolved + evidence, and adds S10. No Sovereign item answered; S1's ruling
      deliberately not taken even though a sanctioned cross-project route existed (§7 refusal 2).
- [x] **A4 Handback written** to `docs/reports/EWCR/drive-7-procasfit-handback.md` with the
      Mandate's Handback sections and a delta table against drive 6's §2 and §10, every claim
      traceable to a recorded check or a verb-gated state change.
      **Evidence:** file written (555 lines); §2 is the delta table against drive 6 §2, §9 carries
      the delta against drive 6 §10; all six Mandate handback sections present (objectives §2,
      arc state §9, Q1/Q2 remaining §9, Sovereign questions §5, gates refused §7, cost deltas §8).
      Two rank figures written from memory-of-output were re-derived against the table offset and
      corrected (178/192, 38/192) rather than left.
- [x] **A5 Sovereign boundaries respected.** No `fw arc close`, no `fw inception decide go`, no
      Human AC ticked, no arc scope change, no bypass flag; every gate refusal recorded with what
      was done instead.
      **Evidence:** handback §7 — two gate refusals recorded (check-active-task/OBS-250 on the close
      commit → re-focused on T-3439 via the verb; project-boundary T-559 on `/opt/0503*` → nothing
      done, sanctioned TermLink route deliberately declined because the fetch IS S1's decision).
      No `--force`, `--skip-*`, `--no-verify` or `FW_ALLOW_*` anywhere. T-3389 left `captured/later`;
      T-3147's Human ACs untouched; no arc verb run. Reviewer's `destructive-action` escalation on
      T-3438 reported rather than reworded away.

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

# T-3439: the round-2 handback exists, states a selection, carries the delta table and the S-list.
test -f docs/reports/EWCR/drive-7-procasfit-handback.md
grep -qi "quadrant" docs/reports/EWCR/drive-7-procasfit-handback.md
grep -q "T-3438" docs/reports/EWCR/drive-7-procasfit-handback.md
grep -q "S1" docs/reports/EWCR/drive-7-procasfit-handback.md
grep -q "Sovereign" docs/reports/EWCR/drive-7-procasfit-handback.md

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

### 2026-09-22 — the dispatch stanza was worth more than the arc's executable task

- **What changed:** The round's planned value was T-3438 (the arc's one executable member).
  Its actual value was §4: the clause-2 answer has been on the record in an AEF mailbox since
  before drive 2, and drives 2–6 reported it absent because `termlink agent search` does not
  index DM channels. Drive 6 called its six searches "independent negatives"; they shared one
  blind spot. The only reason drive 7 found it is that the dispatch stanza named "the 832 DM
  rail" as a surface to re-check by name.
- **Plan impact:** S1 is no longer "can the artefacts be obtained" — they exist, at named paths,
  with published hashes. It is now "does the operator authorise the fetch and the AEF-owned
  disposition tables". That is a sharper and more answerable question, and it is still Sovereign.
  Drive 6's "building dispositions from a bibliography line would be fabrication" was right about
  its source and wrong about the world.
- **Triggered:** OBS-482 (register first, fix second; homed per the gap-homing rule — the
  evidence-discipline half is ours, the search-coverage and unread-mailbox halves are not).
  New Sovereign question S10 (nothing re-runs a completed task's `## Verification` block),
  surfaced as an inception candidate rather than filed as a build.

### 2026-09-22 — the arc's executable queue is empty for the first time

- **What changed:** Drive 6 stopped with T-3438 filed-and-unstarted, on the Mandate's AC-scoping
  rule. Drive 7 leaves nothing: 18 of 20 members work-completed, T-3389 blocked on S1, T-3147
  human-owned with zero unticked Human ACs.
- **Plan impact:** Every remaining path in arc-019 runs through S1. A round 8 fed this handback
  would re-verify the same seven negative surfaces and write a third document saying so.
- **Triggered:** Advice in §9, not a decision — do not dispatch round 8 until S1 is ruled.

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

### 2026-09-22T19:27:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3439-ewcr-seventh-landing-drive-procasfit-rou.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0689781d
- **Timestamp:** 2026-09-22T19:45:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-project`

### 2026-09-22T19:45:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
