---
id: T-1818
name: "v2 peer-consult slice 1 framework-half — inbox.queued event subscriber + responder spawn-bridge (T-1804 cross-repo joint with TermLink T-243)"
description: >
  v2 peer-consult slice 1 framework-half — inbox.queued event subscriber + responder spawn-bridge (T-1804 cross-repo joint with TermLink T-243)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: ["arc:orchestrator-rethink", "cross-repo", "termlink", "peer-consult"]
components: []
related_tasks: ["T-1804", "T-1797"]
created: 2026-05-13T21:30:35Z
last_update: 2026-05-13T21:30:35Z
date_finished: null
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
- [ ] `fw peer subscribe` CLI verb registered in `bin/fw` and dispatched to `lib/peer.sh` (or `lib/peer.py`); `fw peer --help` lists subverbs
- [ ] `fw peer subscribe` opens a long-poll subscription to TermLink's `inbox.queued` event class (using `termlink event subscribe` or equivalent Rust-layer primitive)
- [ ] On receipt of `inbox.queued` event: parse {addressee, channel, offset}, look up addressee's responder workflow (via task_id → workflow registry mapping or a peer-consult-prompts table), spawn responder via `fw termlink dispatch` with a preamble that delivers the original inbox payload
- [ ] If addressee resolution fails (no workflow registered): log to `.context/working/peer-consult-misses.log` (one line per miss) and continue subscription — do NOT crash or stall the long-poll
- [ ] Cron registry entry created for `fw peer subscribe` (30s interval per host); registered via `bin/fw cron generate`
- [ ] Unit test `tests/unit/test_peer_subscribe.py` pins: event parsing, addressee resolution success, addressee resolution failure (logged miss), spawn invocation (mocked TermLink), and long-poll loop continuation after one event
- [ ] `## Verification` block runs all tests + `fw peer --help` + cron registry check
- [ ] Reviewer verdict PASS

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

## Updates

### 2026-05-13T21:30:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1818-v2-peer-consult-slice-1-framework-half--.md
- **Context:** Initial task creation
