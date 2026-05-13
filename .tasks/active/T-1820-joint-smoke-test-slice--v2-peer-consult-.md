---
id: T-1820
name: "joint smoke-test slice — v2 peer-consult end-to-end after TermLink T-1636 ships"
description: >
  Live joint smoke test: TermLink-side T-1636 emits inbox.queued on a test DM, framework-side fw peer subscribe (T-1818 subscriber + T-1819 prompts map) receives the event, resolves to design-consult/escalation-triage/triage/fallback workflow, spawns responder via fw termlink dispatch. Verifies the full cross-repo wire contract. Blocked on T-1636 ship (currently unstarted per 2026-05-14 status check, ~1.5-2h estimate).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:orchestrator-rethink, termlink, peer-consult, cross-repo, joint-smoke]
components: []
related_tasks: [T-1818, T-1819, T-1804, T-1797]
created: 2026-05-13T23:05:51Z
last_update: 2026-05-13T23:12:01Z
date_finished: null
---

# T-1820: joint smoke-test slice — v2 peer-consult end-to-end after TermLink T-1636 ships

## Context

End-to-end joint smoke for v2 peer-consult slice 1: TermLink hub emits
`inbox.queued` → framework subscriber (`fw peer subscribe`) receives → resolves
addressee via `.context/peer-consult-prompts.yaml` → spawns responder via
`fw termlink dispatch`. Validates the cross-repo wire contract end-to-end.

Coordination state (2026-05-14, dispatched `t1636-coord` worker to /opt/termlink):
- TermLink T-1636 unstarted (created 14h ago, status: started-work, zero
  implementation commits). Prior session moved to handover.
- TermLink-side agent confirmed: **framework dispatch is welcome** for the
  T-1636 build. Scope is frozen per T-1804 inception GO seam.
- TermLink-side constraints for the build: (a) event const + delivery-path
  emit only, no broader changes; (b) locked payload shape per T-1804;
  (c) ≤50 LOC diff; (d) standard event emission style; (e) integration test
  pinning no-consumer-fire / live-consumer-no-fire semantics.

This task: (1) dispatch framework Claude worker to /opt/termlink under T-1636
scope per the 5 constraints; (2) verify T-1636 build landed (commits + tests);
(3) execute joint smoke: framework subscriber against live emitter, observe
event fire + addressee resolution + responder spawn; (4) capture demo artefact.

## Acceptance Criteria

### Agent
- [x] TermLink T-1636 implementation dispatched via `bin/fw termlink dispatch --project /opt/termlink --task T-1820 --timeout 5400 --model sonnet` with prompt enumerating the 5 locked constraints. Worker `t1636-build` running (started 2026-05-14T01:14:33+02:00). Initial dispatch at 10-min default timeout was killed mid-read — redispatched with 90-min timeout + sonnet for the Rust build.
- [ ] T-1636 build landed in /opt/termlink: cross-repo commit(s) reference T-1636, event class constant defined in events.rs, emit call inserted in deliver_pending, integration test added and passing (≤50 LOC total diff).
- [ ] Live joint smoke executed: framework spawns a tagged TermLink consumer session, posts a DM into a `dm:design-*` channel addressed to that session, runs `fw peer subscribe --once`, observes (a) `inbox.queued` event polled, (b) addressee resolved to `design-consult` workflow, (c) responder spawn invoked. Captured as console transcript + cursor state.
- [ ] Demo artefact written to `docs/reports/T-1820-joint-smoke-demo.md` containing: dispatch envelope, T-1636 build commit hashes, smoke transcript (timestamps + events seen + responder dispatch line), cursor advance evidence.
- [ ] No regression in framework-side peer tests: `python3 -m pytest tests/unit/test_peer_subscribe.py` 12/12 PASS.

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

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

test -f docs/reports/T-1820-joint-smoke-demo.md
grep -q "T-1636" docs/reports/T-1820-joint-smoke-demo.md
# Live-smoke evidence: demo doc must have no placeholders left (live transcript filled in)
! grep -q "WORKER-FILL\|POST-SMOKE" docs/reports/T-1820-joint-smoke-demo.md
# Cross-repo commit captured: a TermLink-side commit hash must appear in the trail
grep -qE '\| termlink +\| T-1636 +\| `[0-9a-f]{7,}`' docs/reports/T-1820-joint-smoke-demo.md
python3 -m pytest tests/unit/test_peer_subscribe.py -q
bin/fw reviewer T-1820 2>&1 | grep -q "Overall:.*PASS"

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

### 2026-05-14 — coordination consultation dogfooded the slice we're building

- **What changed:** Before dispatching the build worker, ran a coordination consultation worker (`t1636-coord`, Haiku, ~60s) to /opt/termlink asking (a) is anyone working T-1636, (b) is framework dispatch welcome, (c) what constraints. The pattern — framework agent asks TermLink-side peer for guidance before crossing the repo boundary — IS the v2 peer-consult slice we're about to smoke. We're using the manual `fw termlink dispatch` form because the automated inbox.queued seam (T-1636 itself) isn't live yet. The slice is the answer to a problem we're currently solving by hand.
- **Plan impact:** None — the coord step was already implicit. Logging it explicit captures the dogfooding moment for the demo artefact.
- **Triggered:** No new sub-task. Coord-worker result captured at `/tmp/tl-dispatch/t1636-coord/result.md`.

### 2026-05-14 — initial dispatch with 600s default timeout would have killed mid-Rust-read

- **What changed:** First dispatch defaulted to `TERMLINK_WORKER_TIMEOUT=600` (10 min). The Rust build + test + commit was estimated at ~1.5-2h. The watchdog would have killed the worker mid-read (it was already 211KB into result.jsonl when I caught it). Killed via `termlink clean` (signal failed but session unregistered) and re-dispatched with `--timeout 5400 --model sonnet`.
- **Plan impact:** None for T-1820's scope, but a learning: `--timeout` must match the estimated work time when dispatching real builds. The 600s default is for quick research / one-shot reads. Consider filing a follow-up for either (a) higher default when `task_type=build`, or (b) workflow-driven timeout (the v1 build workflow could declare `expected_duration: 90m`).
- **Triggered:** Candidate follow-up — not filed yet, pending whether this is a recurring miss or a one-off. Logged here as evidence.

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

### 2026-05-13T23:05:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1820-joint-smoke-test-slice--v2-peer-consult-.md
- **Context:** Initial task creation

### 2026-05-13T23:12:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-01856120
- **Timestamp:** 2026-05-13T23:25:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-repo`

- **Suppressed:** 1 (by override)
  - mock-only-integration @ AC vs Verification cross-check
