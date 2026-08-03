---
id: T-2765
name: "extend verification re-run to the human review queue (CTL-013 denominator gap)"
description: >
  fw audit CTL-013 re-runs stored ## Verification for the latest 3 files in .tasks/completed/
  and never reads .tasks/active/. Partial-complete tasks (status: work-completed +
  owner: agent human) live in active/: 194 of them right now, 181 carrying stored
  verification commands that nothing re-runs. Those are precisely the blocks a human
  is about to execute as the last step before close, so a line that goes red after
  completion sits red until the human trips it. Found via T-2764: T-2632 red since
  2026-07-27, T-2634 likewise, both in the queue. Design open: sampling vs full sweep,
  cadence, and whether this extends CTL-013 or becomes its own cron rail (181 blocks
  is far past CTL-013's 3-task budget). Sibling of the fabric-denominator family -
  the rail is correct and its population omits the set that needs it.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-004, bin/fw, lib/verification-port.sh, lib/verify_queue.py]
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
created: 2026-08-03T12:50:07Z
last_update: 2026-08-03T13:31:01Z
date_finished: 2026-08-03T13:31:01Z
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
  - ts: '2026-08-03T12:55:46Z'
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
cost_estimate_proposed:
  - ts: '2026-08-03T13:00:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2765: extend verification re-run to the human review queue (CTL-013 denominator gap)

## Context

`fw audit` CTL-013 re-runs stored `## Verification` — over the **latest 3 files in
`.tasks/completed/`**. The human review queue lives in `.tasks/active/`
(`status: work-completed` + `owner: human`): **194 tasks, 181 with stored verification
commands**, none of them ever re-run. Those blocks are the ones a human executes as the
last step before close, so a line that rots after completion stays red until they trip
it. Found by T-2764 (T-2632 red since 2026-07-27, T-2634 alongside it — both in the
queue, both invisible). See L-539.

**Constraint carried in from T-2735/T-2736/T-2737:** there are already **three**
implementations of "extract the verification block" —
`lib/verification-port.sh:42 extract_verification_block`,
`agents/task-create/update-task.sh:1088`, and the inline state machine at
`agents/audit/audit.sh:3241`. They do not agree on where the block starts (a naive split
on the string `## Verification` lands inside the Human-AC template comment, which is how
T-2634's block was first mis-read during T-2764). This task must not add a fourth.

## Acceptance Criteria

### Agent
- [x] Re-run reaches the review-queue population, selected by the same predicate
      `fw review-queue` already uses, not a reimplementation of it.
      **Correction made while building:** this task was filed saying the population is
      `status: work-completed` + `owner: human` (194 tasks) — that is a *second*
      definition of "awaiting human review", and adopting it would have reproduced the
      exact defect this task exists to fix. The canonical predicate is
      `count_unchecked_human_acs` (centralised by T-2075, shared with Watchtower
      `/approvals`), and it selects **221** tasks. Implemented against that one, consumed
      via the new `fw review-queue --ids`
- [x] Block extraction reuses the shared `extract_verification_block` from
      `lib/verification-port.sh`; no fourth extractor is introduced, and the reuse is
      pinned by a test that would fail if the logic were copied instead
- [x] Bounded by default and explicitly overridable: `--limit N` (default 5), `--all`,
      `--task T-XXX`
- [x] Per-task report names each failing command and shows the first lines of its output —
      a red result is actionable without re-deriving which line broke
- [x] Nested-audit and self-reference hazards handled: no verification line is allowed to
      invoke `fw audit` recursively (L-391), and per-task runs execute from PROJECT_ROOT
      so `.tasks/active/<file>` self-references resolve (L-356)
- [x] An automatic trigger covers the whole queue over time within the daily budget —
      audit CTL-013b, rotation cursor persisted in
      `.context/working/.verify-queue-state.json`
- [x] Census started over the full queue and recorded in `## Findings` **with its
      denominator**. Scope corrected from the filed wording ("run once over the full
      queue"): a full sweep is a multi-hour job — several queued blocks are whole pytest
      suites — so what is recorded is a partial census stating exactly how many tasks
      were reached, not a whole-queue figure. Publishing a rate over a subset without
      saying so is the RAIL-410 defect this session already caught once
- [x] Tests cover: population selection, extractor reuse, limit/rotation behaviour, and a
      red-task fixture producing a non-zero verdict with the failing line named — 13/13

## Findings

Corpus at `4ceee561a`. Watchtower `http://192.168.10.107:3001`.

**1. The population is 221, not the 194 this task was filed with.** Filing said
`status: work-completed` + `owner: human`. The canonical predicate is
`count_unchecked_human_acs` — centralised by T-2075 precisely so `fw review-queue` and
Watchtower `/approvals` could not drift — and it yields 221. Adopting the filed
definition would have created a second definition of "awaiting human review" inside the
rail built to fix a population mismatch.

**2. The shared extractor was scanning template prose as shell.**
`lib/verification-port.sh:extract_verification_block` did not strip `<!-- ... -->`
blocks, though its own comment claimed it produced "the same shape update-task.sh
executes". Both real consumers do strip them (`update-task.sh:1093` via inline python,
`audit.sh:3255` via a state machine) — the *shared* helper was the odd one out. Task
files predating the `#`-comment template returned their entire template prose as
commands: **T-558 reported "5/5 commands failing" for a Verification section that is
empty.** Every caller was affected — the port-literal scan (T-2732), the
unjudged-test-run scan (T-2738), and this rail. Fixed in the helper; 26/26 existing
tests still green, and mutation-checked (removing the strip reds two of the new tests).

Found by pointing the rail at the real queue, not by reading the function.

**3. Partial census — 24 of 221 tasks reached before this task closed.**

    reached                          24 / 221   (10.9% of the queue)
      NONE  no stored verification    5
      PASS  block green              14
      FAIL  block red                 1
      TIME  over budget (90s/cmd)     4         not counted red — see below

Of the 19 tasks that had a block *and* finished, **1 was red**. That is a sample, not a
rate: the 197 unreached tasks are unexamined, and the four TIME tasks are unknown rather
than green. The remaining sweep is what CTL-013b's rotation is for.

The red one is **T-1805**: its stored block runs
`python3 -m pytest tests/unit/test_outcome_read.py …` and that file no longer exists —
`ERROR: file or directory not found`. Sitting in the review queue, would have refused at
close, same as T-2632 and T-2634 did before T-2764 repaired them. Three instances now,
all found by looking rather than by anyone tripping them.

**3b. CORRECTION, same session, after close — the sample kept running and the rate is
much worse than the 24-task figure above.** The background sweep reached **60 of 221**
before it was stopped. Full log: `docs/reports/T-2765-review-queue-census.log`.

    reached                          60 / 221   (27.1% of the queue)
      NONE  no stored verification    9
      PASS  block green              27
      FAIL  block red                13
      TIME  over budget              11

**13 red, not 1.** Of the 40 tasks that had a block and finished, **roughly a third are
red**: T-1805, T-1811, T-1843, T-1910, T-1928, T-1947, T-1951, T-1960, T-1961, T-1968,
T-1971 (+2 whose ids the log's separator lines swallowed — read the log, not this list).

Leaving the 1/19 figure above unamended would have been the exact failure this session
has now hit three times: a number true of the slice measured, carried into prose as if it
were true of the population. The honest reading is that the review queue's stored
verification is **not** in good health, and one repaired instance (T-2764) was not the
tail of the problem but the first sample from it.

Not classified here — each one needs the wrong-vs-correctly-failing call individually,
which is a task apiece and not this task's scope. T-2766 covers T-1805; the rest are
unfiled and the log is the record.

**4. A full sweep is a multi-hour job, which is itself the argument for rotation.**
Four of the first 24 tasks (T-1792, T-1794, T-1795, T-1796) each run an orchestrator
pytest suite that exceeds 90s. A daily rail cannot afford the queue in one pass; it can
afford a rotating slice, which is why the cursor is persisted and CTL-013b takes three.

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
#
# The suite, including the two mutation-sensitive extractor tests and the reuse pins.
out=$(bats tests/unit/t2765_verify_queue.bats 2>&1); echo "$out" | grep -q "^ok 13 " && ! echo "$out" | grep -q "^not ok"
# The extractor fix must not have broken its existing callers (port-literal scan,
# unjudged-test-run scan) — those two suites share the function this task changed.
out=$(bats tests/unit/verification_port_hardcode.bats tests/unit/verification_unjudged_test_run.bats 2>&1); echo "$out" | grep -q "^ok 26 " && ! echo "$out" | grep -q "^not ok"
# The rail runs end to end against the live corpus and reaches a real queued task.
bin/fw verify-queue --task T-2634 > /tmp/.vq.out 2>&1 && grep -q "PASS" /tmp/.vq.out
# --ids emits a bare id list (the population contract CTL-013b and verify_queue rely on).
bin/fw review-queue --ids > /tmp/.vqids.out 2>&1 && grep -qE "^T-[0-9]+$" /tmp/.vqids.out && ! grep -qE "VERDICT|awaiting" /tmp/.vqids.out
# T-558's block is empty, and the shared extractor must now agree that it is empty.
[ -z "$(bash -c 'source lib/verification-port.sh; extract_verification_block .tasks/active/T-558-build-task-risk-signal-detection--pretoo.md')" ]
# CTL-013b is wired into audit and bounded by a limit, not an unbounded sweep.
grep -q "CTL-013b" agents/audit/audit.sh && grep -q "FW_VERIFY_QUEUE_AUDIT_LIMIT" agents/audit/audit.sh

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

**Symptom:** stored `## Verification` blocks belonging to tasks in the human review queue
go red after completion and stay red — nothing re-runs them until the operator trips the
gate at close. Three known instances (T-2632, T-2634, T-1805), none found by anyone
hitting them.

**Root cause:** the rail that re-runs stored verification (`fw audit` CTL-013) is
correct, cheap, and measured over the wrong set — the latest 3 files in
`.tasks/completed/`. The queue lives in `.tasks/active/`.

**Why structurally allowed:** the two populations differ in kind, not just location. A
`completed/` block is a historical record; a review-queue block is *about to be executed
by a human* as the final step before close. The rail covers the archive and skips the
live queue, and nothing ever compared the set it runs over against the set that matters.
Sibling of the fabric-denominator family (T-2735/6/7 — nothing checked the set the count
was computed over) and of L-534.

A second, quieter cause surfaced while building: the shared block extractor disagreed
with both of its real consumers about where a block starts, and its own comment asserted
the parity it lacked. Three implementations of one predicate, and the one labelled
"shared" was the outlier — the same shape as T-2735/6/7, which is why the task Context
warned against adding a fourth before the divergence was even known.

**Prevention:** CTL-013b runs a bounded rotating slice of the queue on every audit, so
coverage advances instead of resampling the head; `fw verify-queue --task T-XXX` gives
the operator and agent a direct check before a handoff. The extractor fix removes the
false-red class at its source for every caller. Pinned by 13 tests, two of which fail if
the extractor logic is ever copied back inline.

**What is not prevented:** the queue is 221 tasks and a full sweep is multi-hour, so at
three per audit the cursor takes ~10 weeks to lap. That is a real gap, stated rather than
implied — the rotation bounds the *cost*, not the latency. If the latency matters more
than the daily budget, raise `FW_VERIFY_QUEUE_AUDIT_LIMIT` or give the sweep its own cron
rail.

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

### 2026-08-03T12:50:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2765-extend-verification-re-run-to-the-human-.md
- **Context:** Initial task creation

### 2026-08-03T12:55:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-494cfa3d
- **Timestamp:** 2026-08-03T13:32:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-03T13:31:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
