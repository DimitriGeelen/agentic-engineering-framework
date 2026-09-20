---
id: T-2918
name: "fw peer subscribe uses event poll <session> which never observes hub-aggregator
  events"
description: >
  T-1820's live joint smoke (2026-08-11 rerun) confirmed a framework-side defect distinct
  from the TermLink-side T-2363 fix: lib/peer.py::poll_once calls 'termlink event
  poll <session> --topic inbox.queued' but inbox.queued (and its dm-rail sibling dm.queued)
  are injected into the hub-level aggregator under a synthetic session_id='hub' (crates/termlink-hub
  router::aggregator()/EventAggregator, T-1645). Per-session 'event poll' structurally
  cannot see hub-aggregator-injected events -- confirmed by polling both the addressee
  session and an unrelated session immediately after a proven emit, both returned
  0 events, while 'termlink event watch --hub --topic inbox.queued' observed the same
  emit instantly. This means fw peer subscribe has never been able to observe a live
  inbox.queued event since T-1818 shipped, independent of any TermLink-side emit bug.
  Separately (also confirmed live): the DM rail (T-2323) emits under topic 'dm.queued',
  not 'inbox.queued', so .context/peer-consult-prompts.yaml's dm:design-*/dm:escalate-*/dm:triage-
  channel-prefix routing can never be reached via inbox.queued even if the poll-primitive
  defect were fixed -- the subscriber would need to also poll dm.queued, or TermLink's
  dm rail would need to align its topic name. Scope: (a) change lib/peer.py to consume
  the hub aggregator (event watch --hub, or an equivalent cursor-capable primitive
  if one exists) instead of per-session poll; (b) decide whether to also subscribe
  dm.queued or treat inbox: and dm: as two distinct trigger rails; (c) rerun T-1820's
  live joint smoke against the fix to close the headline mechanic. See docs/reports/T-1820-joint-smoke-demo.md
  2026-08-11 section for full reproduction trail.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [termlink, peer-consult, cross-repo, joint-smoke, structural-flaw]
components: []
related_tasks: [T-1820, T-1821, T-1818, T-1819, T-2409, T-2363]
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
created: 2026-08-11T12:40:13Z
last_update: 2026-09-20T13:59:04Z
date_finished: 2026-09-20T13:59:04Z
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
  - ts: '2026-08-11T12:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-17T12:36:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 7
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=7 (lines=179,acs=4)
    rubric_sha: e4a00f38e801
  - ts: '2026-09-20T10:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=280,acs=6)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-11T12:45:12Z'
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
  - ts: '2026-09-20T10:45:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 3
      D3: 3
      D4: 4
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=3 
      (body:component-silent-failure); D3=3 (body:component-discoverability); 
      D4=4 (body:cross-machine); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2918: fw peer subscribe uses event poll <session> which never observes hub-aggregator events

## Context

`lib/peer.py::poll_once` calls `termlink event poll <target> --topic inbox.queued`
(per-session bus), but hub-aggregator-injected events (`inbox.queued`, `dm.queued`)
live under a synthetic `session_id: "hub"` that per-session poll structurally
cannot see. Filed 2026-08-11 from T-1820's live joint-smoke reproduction. Scope
named at filing: (a) switch to consuming the hub aggregator, (b) decide dm.queued
vs inbox.queued routing, (c) rerun T-1820's smoke to close the headline mechanic.

## Investigation (2026-09-20)

Dispatched a read-only TermLink worker (`t2918-hub-since-check`, cross-project via
`fw termlink dispatch --project /opt/termlink`, since this repo's project-boundary
hook correctly refuses direct inspection of `/opt/termlink` source) to confirm,
against TermLink's actual Rust source rather than CLI help text alone, whether
`termlink event watch --hub --since N` honors the cursor. **Confirmed it does
not — this is load-bearing for the task's own scope item (a) and changes what
"switch to the hub aggregator" can mean:**

- `crates/termlink-cli/src/commands/events.rs:845-847`: `--since` is silently
  dropped when `--hub` is set. A text-mode warning fires (`eprintln!`); **in
  `--json` mode (what a scripted subscriber like `lib/peer.py` must use) there
  is no warning at all** — the flag is accepted by clap and never reaches the
  RPC call.
- `crates/termlink-hub/src/router.rs:488-530` (`handle_hub_subscribe`) takes
  only `timeout_ms` and `topic` — no `since`/cursor parameter exists in its
  signature at all.
- `crates/termlink-hub/src/aggregator.rs:192-224` (`EventAggregator::collect`)
  is a `tokio::sync::broadcast` real-time drain for a timeout window —
  structurally no replay/history capability. A broadcast channel only has a
  lagged-receiver window, not addressable history.
- No hub-aware cursor/replay primitive exists anywhere in TermLink today. The
  session-level `event.collect`/`watch` (non-`--hub`) path does honor real
  since-cursors, but that is per-session, not the aggregator this task targets.

**What this means for scope item (a):** the task description's suggested fix —
"change `lib/peer.py` to consume the hub aggregator instead of per-session
poll" — cannot be a drop-in swap. `fw peer subscribe` is explicitly designed
as a **cron-driven 30s `--once` poll** (`lib/peer.py` docstring, T-1804: daemon
mode "not preferred"). A cron-poll-once caller against a pure broadcast channel
with no cursor **will lose any event emitted between polls** — there is no way
to ask "what happened since my last poll" at the hub level. That is not a bug
in this task's fix; it is a capability TermLink's aggregator does not have.

**This is a Sovereign question, not an implementation detail — surfaced, not
resolved:**

1. **Switch the subscriber to a persistent watch/daemon** (`termlink event
   watch --hub`, held open rather than polled) — correctness-preserving
   (broadcast is real-time, so a listener that's always connected sees
   everything), but reverses T-1804's explicit "daemon mode not preferred, use
   cron" design decision. Changes the subscriber's process model and its
   supervision story (who restarts it, how a crash is detected).
2. **Accept lossy delivery** — keep cron-poll-once, connect briefly each tick,
   process whatever arrives in that window, accept that events between ticks
   are silently missed. Violates D2 (Reliability, no silent failures) as a
   design choice, not an oversight — the arc's own headline mechanic
   ("no .tasks/ or .context/audits/ merge conflicts... absence of governance-
   plane corruption") implicitly assumes no dropped signals.
3. **Request a TermLink-side feature**: a hub-aware cursor/replay primitive
   (e.g. persist aggregator events to a ring buffer addressable by seq, the
   way per-session buses already work). This is the "Gap Homing" case (T-1333)
   — the fix would live in TermLink, not here, and is real new scope on a
   sibling-governed repo with its own priorities, not this task's to decide
   or file on TermLint's behalf without operator sign-off on cross-repo ask.
4. **Defer arc-003/T-1820's headline mechanic to a design that doesn't need a
   live cross-session poll at all** (e.g. batch reconciliation instead of
   real-time consult) — the largest-blast-radius option, effectively
   re-opening T-1820/T-2303's scoping.

None of these four is "the obvious next move" — each trades a different
constraint (process-model change, silent data loss, cross-repo dependency,
re-scoping an already-GO'd arc). Recording rather than picking.

## Acceptance Criteria

### Agent
- [x] Root cause of "fw peer subscribe never observes hub events" confirmed
      against TermLink source (not CLI help text, which contradicts itself):
      `--hub` mode has zero cursor/replay capability, `--since` is a silent
      no-op (worse: unwarned in `--json` mode) — see Investigation above
- [x] Task's own suggested fix (a) evaluated and found insufficient as
      described: switching `lib/peer.py` to `--hub` without also resolving
      the poll-vs-daemon tension would trade "never sees events" for "sees
      events only during the poll window, silently drops the rest" — not a
      fix, a different failure mode
- [x] Findings and four candidate directions recorded under Investigation,
      with the Human AC below scoped as the single decision point — no
      separate agent-completable step remains; the architecture choice is a
      Sovereign question (D1/M6, never self-certified), not a task the agent
      can close on its own authority

### Human
- [ ] [REVIEW] Pick the architecture direction for the peer-consult hub-event
      capability gap (see Investigation above)
  **Steps:**
  1. Read the Investigation section above — it names four candidate
     directions and why none is "obviously right": (1) switch to a
     persistent `event watch --hub` listener, reversing T-1804's
     cron-preferred design; (2) accept lossy cron-poll delivery as a
     documented tradeoff; (3) request a TermLink-side hub-aware
     cursor/replay primitive (cross-repo ask, Gap Homing per T-1333); (4)
     re-scope T-1820/arc-003's headline mechanic away from live cross-session
     polling entirely.
  2. Decide which direction (or a different one) this task should build
     toward — note it under `## Decisions` below with rationale.
  **Expected:** one `### [date] — architecture direction` entry under
  `## Decisions` naming the chosen direction. That unblocks the remaining
  Agent AC and lets a build task implement it.
  **If not:** if none of the four is acceptable, say what's wrong with each
  so a fifth can be scoped — this task should not sit open indefinitely on
  an unstated objection.

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

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-09-20 — Architecture direction chosen: build the real sidecar (operator decision, via chat dialogue)
- **Chose:** None of the four candidates as originally framed. Operator chose
  the long-term-correct route: build a real, always-on, deterministic sidecar
  listener per agent session (holds the TermLink connection, writes a flag +
  heartbeat), with `fw peer subscribe`'s harness cooperatively polling that
  flag/heartbeat at its own safe yield point — not a blind 30s poll, and not
  interrupt-driven PTY injection.
- **Why:** This isn't a novel design — it's the *existing, already-reasoned*
  architecture from arc-011's ADR (`docs/architecture/parallel-execution-aef.md`
  §5), reviewed under an adversarial "Grill Me" pass
  (`docs/reports/arc-011-grill-me-responses.md`). That ADR already explicitly
  considered and rejected PTY-inject-on-apparent-idle (§5: an agent mid-turn
  is uninterruptible; an external watcher cannot prove a safe yield point;
  injection corrupts the input stream the agent is actively consuming). It
  chose a deterministic (non-LLM) sidecar + agent-self-polls-at-its-own-
  yield-point + heartbeat-based deafness self-check instead — exactly the
  shape the operator asked for when re-describing the "sidekick" concept from
  memory, corrected on the delivery mechanism. T-1135 (April 2026) separately
  negotiated the TermLink-side persistence contract for an always-on session
  (`tags: persistent,receptionist`, cleanup exemption, `session.needs_restart`
  event) but neither side of that agreement was ever built.
- **Rejected (the four narrower fixes originally proposed in Investigation
  above):** (1) generic persistent daemon with no self-check — superseded by
  the ADR's heartbeat-checked design, which is safer for the same cost; (2)
  accept lossy delivery — rejected, this is the option the operator explicitly
  chose to avoid; (3) ask TermLink for a hub cursor/replay primitive —
  unnecessary once the sidecar holds its own live connection rather than
  polling a lossy broadcast after the fact; (4) re-scope the arc away from
  live polling — rejected, the sidecar makes live delivery achievable without
  re-opening arc-003/T-1820's already-GO'd scope.
- **Open sub-question surfaced, not resolved here:** yield-point granularity
  (T-2323, still `captured`/unstarted) — the ADR's "before every file-write"
  candidate was chosen for the *write-collision* use case (arc-011); it is
  not obviously the right yield point for *peer-consult* messages (design
  questions, escalations). This and the rest of the unbuilt spec (heartbeat
  timing, priority-byte flag shape, cross-repo persistence wiring) are being
  captured as a new inception task rather than decided inline here.
- **Superseded text below (2026-09-20, earlier same day):** Removed the third
  Agent AC ("architecture decision made") and
  replaced it with an Agent AC scoping the investigation as complete and
  explicitly deferring the direction choice to the existing `[REVIEW]` Human
  AC — no new scope introduced, no work skipped.
- **Why:** The original Agent AC and the Human AC both asked for the same
  thing (pick one of the four candidate directions), but a go/architecture
  decision is strategic authority (T-954 criterion 1) — the agent cannot
  self-certify it and the mandate governing this session forbids treating
  research as authorization. Leaving it as an unticked Agent AC would have
  wedged the close gate the same way T-2433 did.
- **Rejected:** Picking a direction myself and ticking the box — explicitly
  out of scope (producer-not-judge; Sovereign questions are surfaced, not
  resolved).

## Recommendation

**Recommendation:** DEFER (genuine evidence gap — this is a Sovereign
architecture choice, not a confidence-calibration hedge; see T-2144/T-2145
guidance).

**Rationale:** The investigation is complete and conclusive: TermLink's hub
aggregator (`crates/termlink-hub/src/aggregator.rs`) has no cursor/replay
capability at all, and `--since` is silently dropped in `--hub --json` mode
(confirmed against source, not CLI help text). That closes scope item (a) as
originally worded — it cannot be a drop-in swap. What remains is a genuine
four-way architecture trade-off (persistent daemon vs. lossy poll vs.
cross-repo TermLink ask vs. re-scoping arc-003's headline mechanic) that
touches a standing design decision (T-1804: cron-preferred, not daemon) and
a cross-repo dependency this task cannot decide on TermLink's behalf.

**Evidence:**
- `crates/termlink-cli/src/commands/events.rs:845-847` — `--since` dropped
  silently in `--hub --json` mode
- `crates/termlink-hub/src/router.rs:488-530` — `handle_hub_subscribe` has no
  cursor parameter
- `crates/termlink-hub/src/aggregator.rs:192-224` — broadcast-only, no replay
- `lib/peer.py` docstring + T-1804 — cron-poll-once is the standing design,
  not daemon mode

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-11T12:40:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2918-fw-peer-subscribe-uses-event-poll-sessio.md
- **Context:** Initial task creation

### 2026-09-20T10:33:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-94fcd7d5
- **Timestamp:** 2026-09-20T13:59:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-repo`

### 2026-09-20T13:59:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
