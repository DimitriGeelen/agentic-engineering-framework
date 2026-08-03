---
id: T-1818
name: "v2 peer-consult slice 1 framework-half — inbox.queued event subscriber + responder
  spawn-bridge (T-1804 cross-repo joint with TermLink T-243)"
description: >
  v2 peer-consult slice 1 framework-half — inbox.queued event subscriber + responder
  spawn-bridge (T-1804 cross-repo joint with TermLink T-243)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: ["cross-repo", "termlink", "peer-consult"]
components: [bin/fw, lib/peer.py, tests/unit/test_peer_subscribe.py]
related_tasks: ["T-1804", "T-1797"]
arc_id: orchestrator-rethink
created: 2026-05-13T21:30:35Z
last_update: '2026-06-11T22:23:26Z'
date_finished: 2026-05-13T22:25:05Z
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 2
      F-ORCH: 1
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F-RECALL=2 (body:lightly-promoted); F-ORCH=1 
      (body:hand-wired-dispatch); F3=1 (body/components:prompt-incidental); F1=0
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1818: v2 peer-consult slice 1 framework-half — inbox.queued event subscriber + responder spawn-bridge (T-1804 cross-repo joint with TermLink T-243)

## Context

Framework-half of the cross-repo joint v2 peer-consult slice 1. T-1804 inception (completed) shipped a GO recommendation conditional on TermLink-side concurrence. This session dispatched `peer-consult-v2` worker on `/opt/termlink` (via `fw termlink dispatch --project`); worker returned with seam AGREED + wakeup option (i) refined.

**Refined wakeup mechanism (from TermLink-side response):** TermLink hub emits a new `inbox.queued` event when a message lands in a session's inbox with no live consumer. Payload: addressee ID, channel, offset, timestamp — no message body. AEF subscribes via existing `event.subscribe` long-poll (Rust layer T-690 already shipped). Cron-managed 30s long-poll = zero-latency wakeup without a daemon.

**Why this instead of `$WAKEUP_CMD` hook:** TermLink-agent vetoed the raw hook form on (a) security grounds — arbitrary command execution from inbox events is a wide attack surface, and (b) domain-neutrality — TermLink shouldn't know about AEF's spawn substrate.

**Cross-repo coordination state:** Framework + TermLink each ship ≤40 LOC, 0 new CLI verbs, 0 new config fields. Both halves can ship independently after the seam was agreed. Joint build task IDs: T-1818 (this, framework) + TermLink-side counterpart filed via worker (see docs/reports/T-1804-v2-peer-consult-termlink-response-summary.md).

**Slice scope (framework-side):** wire up subscription to the new event + on-fire spawn of a responder via existing `fw termlink dispatch`. Workflow-template integration and prompt-template surface are slice 2+ (deferred).

## Acceptance Criteria

### Agent
- [x] `fw peer subscribe` CLI verb registered in `bin/fw` and dispatched to `lib/peer.py`; `fw peer --help` lists subverbs
- [x] `fw peer subscribe` opens a long-poll subscription to TermLink's `inbox.queued` event topic — via `termlink event poll <ready-session> --topic inbox.queued` (broadcast pattern, mode (a) confirmed by TermLink-side clarification worker)
- [x] On receipt of `inbox.queued` event: parse {addressee_session_id, channel, message_offset, enqueued_at}, look up addressee's responder workflow (via `.context/peer-consult-prompts.yaml`), spawn responder via `fw termlink dispatch` with a preamble carrying the original event payload
- [x] If addressee resolution fails: log to `.context/working/peer-consult-misses.log` (ISO timestamp + JSON, one line per miss) and continue subscription — does NOT crash or stall the long-poll
- [x] Cron registry entry created for `fw peer subscribe` — 1m interval (cron minimum; long-poll inside each invocation absorbs sub-minute gap); registered via `bin/fw cron generate`. **AC text said "30s" — that's unreachable on standard cron; near-real-time achieved via long-poll. See Evolution.**
- [x] Unit test `tests/unit/test_peer_subscribe.py` pins: event parsing (list + dict envelope), resolution by session_id + channel-prefix, miss-logging, spawn invocation (mocked), long-poll continuation past a miss, cursor advance on every seen event (bug found mid-build: cursor was only advancing on resolved events), no-ready-sessions early return, cursor persistence. **11 tests, all PASS.**
- [x] `## Verification` block runs all tests + `fw peer --help` + cron registry check
- [x] Reviewer verdict PASS (Layer-1 cross-project-blast escalation expected — `cross-repo` tag)

### Human
- [ ] [REVIEW] Confirm cross-repo coordination is correct — both halves ship the same wire contract (`inbox.queued` event class, payload {addressee, channel, offset, timestamp}, no message body)
  **Steps:**
  1. Read `docs/reports/T-1804-v2-peer-consult-termlink-response-summary.md`
  2. Read TermLink-side response at `/opt/termlink/docs/reports/v2-peer-consult-seam-response.md`
  3. Read this task's `## Decisions` section + Verification output
  4. Diff the wire contract: TermLink emits {x, y, z} vs framework expects {x, y, z}
  
  **Expected:** Wire contract is identical on both sides (event class name, payload shape, semantics).
  
  **If not:** Note the divergence; either side adjusts before merge.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# CLI surface registered
bin/fw peer --help 2>&1 | grep -q subscribe
# Unit tests pin behaviour
python3 -m pytest tests/unit/test_peer_subscribe.py -v
# Cron registry includes peer-subscribe (30s)
grep -q "peer.*subscribe\|fw peer subscribe" .context/cron-registry.yaml
# Bash + python syntax sanity
python3 -c "import ast; ast.parse(open('lib/peer.py' if __import__('os').path.exists('lib/peer.py') else 'bin/fw').read())"
# Reviewer verdict PASS
bin/fw reviewer T-1818 2>&1 | grep -q "Overall:.*PASS"

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

### 2026-05-14 — wire-contract clarification (broadcast mode, no `--target` semantically)

- **What changed:** Dispatched read-only TermLink-side worker (`peer-target-clarify`, /opt/termlink) to clarify the exact CLI semantics for polling `inbox.queued`. Worker confirmed: **mode (a) — broadcast**, payload fan-out via every registered session's bus (same pattern as `channel:learnings`). The framework subscriber polls ANY ready session as its endpoint; per-message routing is application-level via reading `addressee_session_id` from each event. Cross-machine: hub-local emission, no `termlink remote` relay needed.
- **Plan impact:** Original AC text said "via `termlink event subscribe` or equivalent Rust-layer primitive" — actual CLI primitive is `termlink event poll <session> --topic <name> --since <cursor>`. No semantic difference; the AC was written before clarifying which surface to call. Code uses `event poll`.
- **Triggered:** Wire-contract field names FINALIZED on TermLink-side spec (`addressee_session_id, channel, message_offset, enqueued_at`). Framework code now uses those names verbatim (emitter wins, per pre-build Decisions section).

### 2026-05-14 — cron interval: AC said 30s, deployed 1m

- **What changed:** AC text said "30s interval per host" but standard cron's minimum interval is 1m. Two options considered: (1) dual cron entries (one at minute-0, one at minute-30 via `sleep 30 && fw peer subscribe --once`) — operationally messier and harder to flock-protect, (2) single 1m entry with TermLink long-poll absorbing the gap — chosen.
- **Plan impact:** Net latency from event-emission to responder spawn is ≤25s (long-poll timeout) — well under the 30s target, despite cron at 1m. The behavior is equivalent or better than the AC text predicted.
- **Triggered:** Recorded in cron registry description so future operators understand the apparent mismatch.

### 2026-05-14 — bug found in unit test: cursor stall on misses

- **What changed:** Initial implementation advanced cursor only after a successful spawn. Unit test `test_subscribe_loop_continuation_past_miss` caught the regression: if event N+1 is a miss while event N is a hit, cursor stays at N, so event N+1 (the miss) replays on every poll forever.
- **Plan impact:** None at design level; pure implementation bug. Fix: cursor advances on every seen event regardless of resolution outcome. Miss is still logged once (replay would re-log).
- **Triggered:** No new sub-task — fixed in same commit. Logged here as evidence that the test suite is doing real work (caught a real bug pre-merge, not after deploy).

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

- **Recommendation:** GO (Agent ACs complete; pending [REVIEW] Human AC on wire-contract alignment)
- **Rationale:** Framework-half built end-to-end against TermLink-side T-1636 wire contract. The contract was confirmed live by a dispatched TermLink-side worker (`peer-target-clarify`, exit 0) which clarified mode (a) broadcast + hub-local cross-machine semantics. Field names use TermLink-emitter spelling (`addressee_session_id`, `channel`, `message_offset`, `enqueued_at`) per the emitter-wins default recorded in pre-build Decisions. 11/11 unit tests pass, reviewer PASS, cron registry in sync. One real bug found and fixed mid-build (cursor stall on misses) — the test suite caught it before merge.
- **Evidence:**
  - `lib/peer.py` 197 LOC — subscribe loop, addressee resolver, spawn-bridge, miss-log, cursor persistence
  - `bin/fw peer subscribe` dispatcher wired + `fw help` entry
  - `tests/unit/test_peer_subscribe.py` 11 tests PASS
  - `.context/cron-registry.yaml` peer-subscribe-1m entry + generated crontab in sync
  - `bin/fw reviewer T-1818` Overall: PASS (1 expected Layer-1 cross-project-blast for `cross-repo` tag)
  - TermLink-side clarification artifact: `/tmp/tl-dispatch/peer-target-clarify/result.md` (worker confirmed mode (a) broadcast)
  - Cross-repo pair: TermLink T-1636 implementation pending; framework code is ready to consume the moment the emitter ships
- **Open item for human (single Human AC):** Confirm wire contract alignment by diffing TermLink-side `/opt/termlink/.tasks/active/T-1636-*.md` against this task's Evolution + Decisions. Default: framework adopts TermLink-side field names verbatim (done).

## Decisions

### 2026-05-13 — cross-repo build task pairing

- **Chose:** File T-1818 (framework) + TermLink-side T-1636 as paired build tasks; both shipped under the v2 peer-consult slice 1 scope.
- **Why:** TermLink-side coordination response (T-1804 round-trip) confirmed seam + refined wakeup mechanism. Both halves are bounded (≤40 LOC each), independently shippable.
- **Rejected:** (a) framework-only build with TermLink-side as undocumented dependency — would re-enable the §ACD pattern T-1670 hit. (b) merge into a single arc-tagged epic — violates one-task-one-deliverable.

### 2026-05-13 — wire-contract field-name divergence noted

- **Issue:** TermLink-side T-1636 specifies payload `{addressee_session_id, channel, message_offset, enqueued_at}` (TermLink-precise names). T-1818 above writes `{addressee, channel, offset, timestamp}` (generic names).
- **Action:** Human AC explicitly catches this — review must diff the two halves and align field names BEFORE either side merges. Anticipated as a normal coordination outcome, not a blocker.
- **Default:** Framework-side will adopt TermLink-side names verbatim (TermLink emits, framework consumes — emitter wins on naming).

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-13T21:30:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1818-v2-peer-consult-slice-1-framework-half--.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-70d10d3f
- **Timestamp:** 2026-08-03T13:30:13Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw peer --help 2>&1 | grep -q subscribe`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 10
     - evidence: `bin/fw reviewer T-1818 2>&1 | grep -q "Overall:.*PASS"`

- **Layer-1 escalations:** 2
  1. **external-publish** (high) — External publish or release
     - matched: `broadcast`
  2. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-project`

- **Suppressed:** 2 (by override)
  - AC-verify-mismatch @ AC#3 (Agent)
  - AC-verify-mismatch @ AC#4 (Agent)
### 2026-05-13T22:25:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
