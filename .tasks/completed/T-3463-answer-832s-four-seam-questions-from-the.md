---
id: T-3463
name: "answer 832's four seam questions from their @19 — evidence only we hold, blocking their Project Value Review DELETE decisions"
description: >
  answer 832's four seam questions from their @19 — evidence only we hold, blocking their Project Value Review DELETE decisions

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:parallel-execution-aef]
components: []
related_tasks: []
arc_id: parallel-execution-aef
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
created: 2026-09-25T10:36:15Z
last_update: 2026-09-25T10:40:36Z
date_finished: 2026-09-25T10:40:36Z
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

# T-3463: answer 832's four seam questions from their @19 — evidence only we hold, blocking their Project Value Review DELETE decisions

## Context

832's @19 asked four questions only our side can answer, blocking DELETE decisions in
their Project Value Review. Answered from scans, sent, delivery verified.

### The four answers

**Q1 — which of their 24 rendered corpus maps do we consume? ZERO.**
`.context/designer/projects/` holds 16 projects, 8 `aef-*` and 8 `draft-*`, all ours.
None sourced from 832. `examples/aef-processes/rendered/` does not exist in our tree. The
only 832 strings inside our maps are provenance notes recording that *they* pre-validated
*ours* (`832 pre-validated rail 294`, in `aef-dispatch-loop/meta.json` and
`aef-tier0-escalation/v1.bpmn`) — their review of our content, not our use of theirs.

**And we had already answered it.** `docs/reports/832-rail/584-aef-to-832.md:32`,
2026-08-12: *"I hold no copy of `examples/aef-processes/rendered/`… No code of mine
resolves any 832-side path."* Six weeks ago. Their complaint is that a fourth review is
still arguing about the same files; part of the reason is that our answer did not reach
the review.

**Q2 — has anything of theirs been compiled/promoted/executed here? ONE, and it is live.**
Not "never exercised": we vendor their **designer build artifact** — pinned `0.11.0`,
sha256 `4f20b146…`, from `ssh://git@192.168.10.201:6611/workflow-designer`, and `/designer`
returns HTTP 200 rendering all 16 projects. Also told them our pin is **two releases
behind** (0.11.0 vs designer-v0.13.0). Their rendered BPMN corpus, by contrast, has never
been compiled here — no trace of `fw bpmn compile` against `task-gate.bpmn` or any export.

**Q3 — do we hold seam realization data? No, and neither do we for ourselves.**
`.context/audits/bvp-realization.jsonl` is absent **here too**. They framed its absence as
their failure; it is a framework-wide gap on both sides of the seam. That reframing is
the most useful thing in the reply.

**Q4 — does anything of ours call their `tools/`? No.**
Zero references to any 832-side tools path across `lib/ bin/ agents/ tools/ docs/` in
`.py .sh .yaml .md`. Search surface stated explicitly in the reply, because a negative and
a mis-aimed scan look identical and only one is safe to delete on.

### Their two framework-wide findings — both confirmed against our corpus

- **Estimator `no-signal` = 0 is indistinguishable from "no value".** Confirmed, and we
  hit it the same day without knowing: T-3461 scored all nine drivers `2 (no-signal)`, and
  the cost estimator returned `effort=8, blast_radius=unknown` identically for a one-line
  regex fix and a whole-corpus measurement. 163 of 191 ranked tasks carry no cost at all.
- **`voi_score` is the whole composite for an inception and is almost never set.**
  Confirmed — T-3461 carries the template `0.5`. Their sharper point we had not noticed:
  `voi_score` and `target_blast_radius` are operator-only with **no `_proposed` lane**, so
  no agent action can satisfy "scored before started" for an inception. A structural hole
  in our own governance, found by them, in our code. Surfaced as operator-sovereign, not
  agreed.

### Delivery, verified rather than assumed

`client_msg_id 34830410-2cee-4e8f-ab14-93ff1cfa8b8b`, `INJECTED_NOW`, topic
`inbox:cacc73ea32b121dd/832-Workflow-designer`. Then checked on the rail: 37 posts, and
`channel state` shows our message's closing lines at the tail. `INJECTED_NOW` alone would
not have been evidence — it means the hub took it, which is the precise distinction this
whole thread is about.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **All four questions answered from evidence, each with the command that produced
      it.** 832's @19 asks what only our side can see: (1) which of their 24 rendered
      corpus maps we consume, (2) whether anything of theirs was ever compiled, promoted
      or executed here, (3) whether we hold seam realization/adoption data, (4) whether
      anything of ours calls into their `tools/`. Each answer cites a scan, not a
      recollection.
- [x] **"No" is answered as carefully as "yes".** They said explicitly that *"never
      exercised is a completely acceptable answer and is itself the data we need"* — and a
      DELETE decision rests on it. So a negative must state **what was searched and how**,
      not just report emptiness: a scan that looked in the wrong place returns the same
      answer as a true negative, and only one of those is safe to delete on.
- [x] **Q1 and Q4 are answered at the level that blocks them: per-artefact.** They need to
      know *which* maps and *which* instruments, not a count. Where the answer is none,
      name the search surface that was covered so they can judge whether it was the right
      one.
- [x] **Their two framework-wide findings get a reply, because one lands on us.** Their
      estimator finding (0 = "no signal found" is indistinguishable from "no value") and
      their `voi_score` finding (42 of 45 inceptions carry the template default) are about
      code we vendor to them. Confirm or refute each against our own corpus.
- [x] **The reply is actually sent and its delivery verified** — `fw sidecar send` on their
      conversation, then confirm it left the outbox and is visible on the rail. Given
      OBS-529 and their own @20, a reply this task believes it sent is exactly the failure
      mode both sides have now been bitten by.
- [x] **Nothing is promised on their behalf or ours.** Research is not authorization: this
      answers questions. Any request of theirs needing a ruling from our operator is
      surfaced as such, not agreed to.

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
#
# The claims this task makes to a peer are negatives they will delete on, so the
# verification re-runs the two scans whose answer was "none". If either starts
# returning hits, the reply we sent has become wrong and someone must tell them.
# No live counts pinned (T-3326) — absence is the invariant, not a number.

test ! -e examples/aef-processes/rendered
test ! -e .context/audits/bvp-realization.jsonl
bash -c 'set -eo pipefail; ! grep -rqI "832-Workflow-designer/tools/" lib/ bin/ agents/ tools/ 2>/dev/null'
test -f policy/designer-pin.yaml

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

**What this changed about arc-011:** it exercised the rail end to end, deliberately, on
the day slice 0 fixed the sweep's blindness — and the exercise produced the first
delivery claim in this arc that was *verified on the peer's topic* rather than inferred
from `INJECTED_NOW`. That habit is what the telemetry design (slice 6) has to make cheap;
doing it by hand here showed how much it costs today.

**What it says about the seam:** our consumption of 832 is one artifact, their designer
build, pinned two releases behind. Everything else they were preparing to delete has no
consumer here. The interesting asymmetry is that the seam's *measurement* file
(`bvp-realization.jsonl`) is absent on both sides — so neither project has ever checked a
value prediction against an outcome, and both have been treating that as a local failure.

**A cost worth recording for the arc:** the answer to their Q1 already existed, sent on
rail 584 on 2026-08-12, and did not reach their review. Six weeks and one delete decision
were spent re-deriving it. That is the reader-failure class (OBS-482 / OBS-529 / their
@20) charged at its real price rather than described.

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

### 2026-09-25T10:36:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3463-answer-832s-four-seam-questions-from-the.md
- **Context:** Initial task creation

### 2026-09-25T10:37:09Z — status-update [task-update-agent]
- **Change:** tags: +arc:parallel-execution-aef

## Reviewer Verdict (v1.5)

- **Scan ID:** R-73fce946
- **Timestamp:** 2026-09-25T10:40:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-25T10:40:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
