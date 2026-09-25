---
id: T-3462
name: "sidecar slice 0 (OBS-529): answered_conversations() is blind to the legacy
  topic, so answered conversations never close and ride the full retry ladder into
  a silent operator queue"
description: >
  sidecar slice 0 (OBS-529): answered_conversations() is blind to the legacy topic,
  so answered conversations never close and ride the full retry ladder into a silent
  operator queue

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:parallel-execution-aef]
components: [lib/sidecar/inbox.py, lib/sidecar/retry.py]
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
created: 2026-09-25T09:50:45Z
last_update: 2026-09-25T10:16:02Z
date_finished: 2026-09-25T10:16:02Z
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
  - ts: '2026-09-25T10:00:12Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=276,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-25T10:00:35Z'
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

# T-3462: sidecar slice 0 (OBS-529): answered_conversations() is blind to the legacy topic, so answered conversations never close and ride the full retry ladder into a silent operator queue

## Context

arc-011 slice 0, authorised by the T-3461 GO (D-645). **Not part of the target
architecture** — a one-line-class fix to the architecture that runs today, taken first
because it is live and actively generating false alarms whatever we build next.

`pending()` was widened for the T-3433 circuit transition to drain `inbox:<circuit>` AND
the legacy `sidecar:<agent>` alias. `answered_conversations()` was not. The topic list was
written out separately at each call site and only one copy moved.

The consequence was not a lost message — `pending()` surfaced everything to the agent — it
was that the **sweep could not see a reply**. A peer answering on the legacy rail left the
ack row open, so every five minutes the ladder re-posted, nudged, and finally fired an
operator notice for a conversation answered days earlier. Those notices land in
`.context/inbox.yaml`: 319 pending, no renderer, notify disabled. The system generated
false alarms it could not hear.

### Before / after, live on this corpus

```
BEFORE  answered_conversations() -> set()          (empty)
AFTER   answered_conversations() -> 8 conversations
          832-T829-THREE-ASKS
          832-T830-H3-RULED
          832-T833-CTL029-AND-REVIEWER-CLOSURE     <- all three had reached rung 5
          832-BRANCH-TOPOLOGY-T805
          1409-sprind-xfer-20260922T125753Z
          T-3062-consult / T-3406-demo / T-3407-worker
```

Circuit topic: 6 envelopes, **0** foreign conversations. Legacy topic: 21 envelopes,
**8** foreign conversations. Every reply the sweep needed was on the rail it wasn't reading.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **A reply on the legacy rail closes the ack row.** `answered_conversations()` returns
      the conversations present on *every* topic the reader drains, not just the circuit
      topic. Verified live: the eight foreign conversations currently sitting on
      `sidecar:999-Agentic-Engineering-Framework` — including the three that escalated to
      rung 5 — appear in its return value, where today it returns the empty set.
- [x] **The two readers cannot drift apart again.** The fix is a single shared helper that
      both `inbox.pending()` and `retry.answered_conversations()` call, not the same topic
      list written out twice. Two copies is how this happened: `pending()` was widened for
      the T-3433 transition and the answered-check was not. A test asserts both call sites
      resolve the identical topic set.
- [x] **Nothing that was already closing stops closing.** A reply on the circuit topic
      still closes its row. This is the leg that catches a "fix" that swaps one blindness
      for another.
- [x] **The peek stays a peek.** `answered_conversations()` must not advance any inbox
      cursor or touch the seen-set — `fw sidecar inbox` owns those, and a sweep that
      consumed messages would make them invisible to the agent. Pinned, because widening
      the topic list is exactly the change that could break it.
- [x] **Tests pin the failing leg against the pre-fix code**, not just the fixed code: a
      fixture where the only reply is on the legacy rail must FAIL against the pre-fix
      `answered_conversations()` and pass after. `TEST_TEMP_DIR` in setup; no bare
      `! grep -q`; no live corpus counts pinned (T-3326).
- [x] **The DEFAULT_LIMIT=100 peek window is recorded, not silently inherited.**
      `answered_conversations()` reads from cursor 0 with a 100-message limit, so once a
      topic passes 100 messages the oldest conversations fall out of view permanently.
      Not in scope to fix here — but stated in `## Decisions` with the measured
      headroom, so the next person meets a known deferral rather than a fresh surprise.
- [x] Vendored copies synced for every touched file under `lib/`; `bin/fw vendor self
      --check` clean.

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
# No live corpus counts pinned (T-3326): the 8-conversation before/after is dated
# evidence in ## Context. The pytest file drives fixture topics only.

timeout 600 python3 -m pytest tests/unit/test_sidecar_answered_topics.py -q > /tmp/.t3462-v1.out 2>&1 && grep -q "passed" /tmp/.t3462-v1.out
timeout 900 python3 -m pytest tests/unit/test_sidecar_sweep.py tests/unit/test_sidecar_inbox.py tests/unit/test_sidecar_outbox.py tests/unit/test_sidecar_delivery.py tests/unit/test_retry_ladder.py -q > /tmp/.t3462-v2.out 2>&1 && grep -q "passed" /tmp/.t3462-v2.out
bin/fw vendor self --check

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

**Symptom:** 15 of 45 sidecar messages climbed the retry ladder to rung 4-5 over 10-12
attempts, 14 ending `escalated:operator`. Three of them were consults to 832 that 832 had
already answered days earlier. `retry.answered_conversations()` returned the empty set on
a corpus holding eight answered conversations.

**Root cause:** the list of topics a reader must consult was written out separately at two
call sites. T-3433's circuit-addressing transition widened one — `inbox.pending()`, to
drain `inbox:<circuit>` **and** the legacy `sidecar:<agent>` alias — and did not widen the
other. `answered_conversations()` kept peeking the circuit topic alone. Replies on the
legacy rail were fully visible to the agent and completely invisible to the sweep.

**Why structurally allowed:** three things had to line up, and all three did.

1. **Duplication with no shared definition.** Two hand-written copies of one list. Nothing
   forced them to move together, so a correct, careful widening of one was a silent
   breakage of the other.
2. **The failure is invisible from the surface that reports health.** `fw sidecar status`
   showed `45 delivered, 0 in flight, 0 dead-letters` throughout, because delivery
   genuinely succeeded. What broke was *closure*, which nothing counts.
3. **The escalations it manufactured were themselves silent** — `fw note` into
   `.context/inbox.yaml`, 319 pending, no Watchtower renderer, notify disabled. A false
   alarm nobody can hear is indistinguishable from no alarm, so the noise never prompted
   anyone to look.

`answered_conversations()` had **zero test coverage** before this task. The function that
closes the loop was the one function nothing exercised, which is why a transition that
touched its sibling never surfaced it.

**Prevention:** `inbox.read_topics()` is now the single definition, called by both. Adding
a topic at a call site — the shape of the original defect — is what a test now catches:
`test_pending_and_answered_resolve_the_same_topics` asserts both callers consult an
identical topic list, and `test_every_read_topic_is_actually_consulted` pins that every
topic in that list is really read, so a future third rail is covered by construction
rather than by remembering to edit this file. The legacy-rail legs were demonstrated to
FAIL against the pre-fix code (5 of 10 red) before being accepted as a guard.

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

**What this slice changed about arc-011's direction:** nothing — and that is the point of
it being slice 0. The arc's direction was set by the T-3461 GO (D-645): build toward the
T-3397 receiver-API design. This slice deliberately does **not** move toward that design;
it repairs the architecture currently running so it stops emitting false escalations while
the real work proceeds.

**What it changed about how the arc will be built:** the sweep is now trustworthy as a
measurement source. Before this, "messages that escalated" conflated *nobody answered* with
*we could not see the answer*, so any telemetry built on the ladder would have inherited
that conflation — including the escalation-precision metric proposed in
`docs/architecture/sidecar-roundtrip-and-telemetry.md`. Slice 6 now has a baseline worth
measuring against.

**A finding for the slices ahead:** the defect was duplication of a definition across two
readers, and the target architecture adds *more* readers — a receiver-side API, a flag
watcher, a readiness gate, two confirmation endpoints. Every one of them will need the
topic/address list. `read_topics()` exists now so they take it rather than restate it. If
slice 1 hand-writes an address list, it is re-introducing this bug before the fix has
aged a week.

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

**Fixed structurally, not locally.** The obvious patch is to add the legacy topic to
`answered_conversations()`. That reproduces the defect's cause — two hand-written copies of
one list — with the copies merely agreeing for now. Instead both callers now use
`inbox.read_topics()`, one definition. A future address change widens that and every reader
follows; adding a topic at a call site is the bug, and a test asserts the two call sites
resolve the identical topic set.

**The peek stays a peek, deliberately.** Widening the topic list is exactly the change that
could start consuming an agent's unread consults, because `answered_conversations()` now
touches every topic `fw sidecar inbox` owns. It still reads from cursor 0 and writes
nothing — pinned by a test that snapshots `inbox-state.json` across the call.

**DEFERRED, stated so the next person meets a known deferral rather than a surprise:
`DEFAULT_LIMIT = 100`.** `answered_conversations()` reads from cursor 0 with a 100-envelope
limit **per topic**, so once a topic passes 100 messages its oldest conversations fall out
of the peek window permanently and their rows can never close. Measured headroom today:
circuit 6, legacy 21 — roughly 79 messages of margin on the busier rail. Not fixed here
because paging changes the read pattern for every caller and belongs with the receiver-side
rework (slice 1), not bolted onto a one-line correction. If traffic grows before slice 1
lands, this bites silently and in exactly the same shape as the bug being fixed.

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

### 2026-09-25T09:50:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3462-sidecar-slice-0-obs-529-answeredconversa.md
- **Context:** Initial task creation

### 2026-09-25T09:52:40Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)

### 2026-09-25T09:53:31Z — status-update [task-update-agent]
- **Change:** tags: +arc:parallel-execution-aef

### 2026-09-25T10:10:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-666fde98
- **Timestamp:** 2026-09-25T10:16:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-25T10:16:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
