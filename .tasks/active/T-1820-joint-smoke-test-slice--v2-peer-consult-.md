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
- [x] T-1636 build landed in /opt/termlink: cross-repo commit(s) reference T-1636, event class constant defined in events.rs, emit call inserted in deliver_pending, integration test added and passing (≤50 LOC total diff). **Evidence (worker exit 2026-05-13T23:36Z, code 0):** 3 files / 50 LOC (within budget); commits `f3927611` (impl) + `13a11741` (task update); architecture — emit lands inside `mirror_inbox_deposit_with` (no-consumer branch) via new `aggregator().inject()`; integration tests `inbox_queued_fires_for_no_consumer` + `inbox_queued_not_emitted_without_deposit` both pass; release build clean; zero deviations from the 5 locked constraints. Full report at `docs/reports/T-1820-joint-smoke-demo.md` §Worker report.
- [ ] Live joint smoke executed: framework spawns a tagged TermLink consumer session, posts a DM into a `dm:design-*` channel addressed to that session, runs `fw peer subscribe --once`, observes (a) `inbox.queued` event polled, (b) addressee resolved to `design-consult` workflow, (c) responder spawn invoked. Captured as console transcript + cursor state. **PARTIAL after deploy:** binary `termlink 0.9.2104` now live on hub PID 4091515; framework subscriber polls cleanly (cursor written, exit 0, topic recognized — `next_seq: 342`); two user-facing CLI trigger attempts (file send to offline target; channel post with kill-9'd member) did NOT fire `inbox.queued`. The integration test on the TermLink side calls `mirror_inbox_deposit_with()` directly from inside the hub crate — passing the test does NOT prove any user-facing CLI flow currently exercises the new emit. Recommended split: file T-1821 follow-up for trigger investigation; T-1820 partial-ships substrate.
- [-] Demo artefact written to `docs/reports/T-1820-joint-smoke-demo.md` containing: dispatch envelope, T-1636 build commit hashes, smoke transcript (timestamps + events seen + responder dispatch line), cursor advance evidence. **Partial:** dispatch envelope, commit hashes, worker report, coord transcript, harness plan, and Recommendation (HOLD pending operator deploy) all landed. Live smoke transcript + cursor advance fill in once operator picks a deploy path.
- [x] No regression in framework-side peer tests: `python3 -m pytest tests/unit/test_peer_subscribe.py` 12/12 PASS.

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

### 2026-05-14 — worker landed, live smoke hit deploy boundary

- **What changed:** Build worker `t1636-build` exited code 0 at 23:36Z, ~22min wall (well inside the 90min budget); 3 files / 50 LOC / 2 tests; commits `f3927611` (impl) + `13a11741` (task update) on `/opt/termlink` master. Live joint smoke (AC#3) requires the new emitter to actually fire, which needs the rebuilt `termlink` binary deployed and the hub restarted to pick it up. Deployed binary at `/root/.cargo/bin/termlink` is mtime 2026-05-01 / v0.9.1701 — predates today's commits. Hub PID 1113405 has been running since 2026-05-05 on `0.0.0.0:9100` and is shared infrastructure (TCP-reachable from remote machines + carrying active worker sessions on this host). Restarting it terminates every TermLink session for every consumer on the host.
- **Plan impact:** Agent intentionally stopped at the deploy boundary per CLAUDE.md §"Executing actions with care" — a daemon restart with that blast radius needs human consent. T-1820 status stays `started-work`; AC#2 ticked (build), AC#5 ticked (no regression), AC#3 unticked (deploy-blocked), AC#4 partial (artefact landed, live transcript pending). Surfacing to operator via `fw task review T-1820` with two deploy options enumerated: (1) restart shared hub (one-time interrupt), (2) side-by-side hub on spare port (lower blast radius, more steps).
- **Triggered:** No new sub-task — the post-deploy execution path is documented in the demo artefact's Recommendation section and the agent will resume on operator decision.

### 2026-05-14 — post-deploy: substrate live, headline mechanic not observed in CLI smoke

- **What changed:** Operator chose path 1 (shared-hub restart). Sequence executed: heads-up via `termlink inject` → dispatch worker `t1820-deploy` ran `cargo install --path /opt/termlink/crates/termlink-cli --force` (exit 0, ~7min) → new binary `termlink 0.9.2104` at `/root/.cargo/bin/termlink`, mtime today → `termlink hub stop && termlink hub start --tcp 0.0.0.0:9100 --json` (old PID 1113405 → new PID 4091515) → `bin/fw peer subscribe --once` against the live hub: exit 0, cursor written (`target_session: framework-agent, since: 0`), no errors → `event poll … --topic inbox.queued` returns `No events (next_seq: 342)` (topic recognized, no events fired). Two attempts to trigger the new emit from the CLI surface: (A) `termlink file send` to an offline target — file spooled, but with `T-1249: new-path send failed — falling back to legacy events` WARN, no event fired; (B) `channel post` to `dm:design-smoke-test` after kill-9'ing a member session — post landed at offset 2, no event fired. Trigger-spec dispatch worker `t1820-trigger-spec` (Haiku) confirmed the integration test calls `mirror_inbox_deposit_with()` **directly from inside the hub crate** — passing the test does NOT prove any user-facing CLI flow currently exercises the new emit.
- **Plan impact:** PARTIAL-SHIP. Substrate is real and useful (deployment landed, hub runs new binary, subscriber polls the new hub for the new topic without error). Headline mechanic (live binary-to-binary observation) NOT yet demonstrated. Per §ACD/G-062 ("acknowledged failure better than false success"), agent does NOT close T-1820 GO on substrate-only evidence. Surfacing PARTIAL-SHIP with two options to the operator: (1) accept substrate + file T-1821 follow-up for trigger investigation, OR (2) keep T-1820 open and authorise another worker to extract the exact trigger spec and retry smoke. Agent's call: option (1) — bundling investigation into T-1820 conflates two scopes.
- **Triggered:** Candidate follow-up — T-1821-joint-smoke-trigger-investigation (not yet filed; awaiting operator decision on which path to take).

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

- **Recommendation:** **PARTIAL-SHIP** — close T-1820 as substrate-shipped + file
  T-1821 follow-up for headline-mechanic trigger investigation. Agent will NOT
  autonomously close T-1820 GO; surfacing the partial-ship framing to the
  operator for explicit accept-or-reject (per §ACD discipline).
- **Rationale:** post-deploy state — deploy landed cleanly (binary `termlink 0.9.2104`
  active on hub PID 4091515, mtime today, framework subscriber polls the new hub
  without error, `inbox.queued` topic recognized by `event poll`). Two user-facing
  CLI trigger attempts (`file send` to offline target → fell back to legacy events
  per `T-1249` warn; `channel post` to a topic with kill-9'd "member" → did not
  fire) did NOT produce the new emit. The TermLink-side integration test passes
  because it calls `mirror_inbox_deposit_with()` directly from inside the hub
  crate — passing the test does NOT prove any CLI flow exercises the new emit
  live. Substrate is real and useful; the headline-mechanic observation is a
  distinct deliverable that deserves its own evidence bar (T-1821). Per
  §ACD/G-062 ("acknowledged failure better than false success"), I am refusing
  to close GO on substrate-only evidence.
- **Evidence (green — what landed):**
  - Worker `t1636-build` exit 0 at 23:36Z (~22min); 3 files / 50 LOC / 2 tests; commits `f3927611` + `13a11741` on `/opt/termlink` master.
  - Worker `t1820-deploy` exit 0 (~7min); `cargo install` succeeded; new binary `termlink 0.9.2104` (was 0.9.1701), mtime today.
  - Hub restarted: PID 1113405 → PID 4091515; new binary active.
  - `bin/fw peer subscribe --once` against live hub: exit 0, cursor written, no errors.
  - `event poll framework-agent --topic inbox.queued`: topic recognized (`next_seq: 342`, no error).
  - Framework peer tests: 12/12 PASS.
  - Demo artefact: `docs/reports/T-1820-joint-smoke-demo.md` (worker report, deploy log, two trigger attempts with exit states, why partial, recommended next move).
  - Reviewer: Overall PASS / Needs Human yes (cross-project-blast Layer-1 is the cross-repo human-review signal).
- **Evidence (red — what did NOT land):**
  - No live `inbox.queued` event observed from outside the hub crate during this session.
  - User-facing trigger path for the new emit is not yet identified (likely needs to read the integration test verbatim).

**Operator choice (please pick one in the Watchtower review):**

1. **Accept partial-ship** — close T-1820 as substrate-shipped, file T-1821 ("identify user-facing trigger for inbox.queued and complete the joint smoke") as a follow-up build task. Cleanest scope separation; lets T-1820 land while the trigger investigation gets its own evidence bar.
2. **Keep T-1820 open** — authorise another investigation worker to extract the exact integration-test setup from `crates/termlink-hub/src/channel.rs` (lines 1780–1809 per trigger-spec worker) and retry the smoke against the precise precondition. ~10-15 min of agent + token cost.

On your decision the agent either (1) files T-1821 + transitions T-1820 to work-completed with the partial framing on record, or (2) dispatches the investigation worker and re-attempts the smoke.

## Updates

### 2026-05-13T23:05:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1820-joint-smoke-test-slice--v2-peer-consult-.md
- **Context:** Initial task creation

### 2026-05-13T23:12:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-a64145bc
- **Timestamp:** 2026-05-14T05:29:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-repo`

- **Suppressed:** 1 (by override)
  - mock-only-integration @ AC vs Verification cross-check
