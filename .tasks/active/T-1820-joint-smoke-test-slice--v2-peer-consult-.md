---
id: T-1820
name: "joint smoke-test slice — v2 peer-consult end-to-end after TermLink T-1636 ships"
description: >
  Live joint smoke test: TermLink-side T-1636 emits inbox.queued on a test DM, framework-side
  fw peer subscribe (T-1818 subscriber + T-1819 prompts map) receives the event, resolves
  to design-consult/escalation-triage/triage/fallback workflow, spawns responder via
  fw termlink dispatch. Verifies the full cross-repo wire contract. Blocked on T-1636
  ship (currently unstarted per 2026-05-14 status check, ~1.5-2h estimate).

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [termlink, peer-consult, cross-repo, joint-smoke]
components: []
related_tasks: [T-1818, T-1819, T-1804, T-1797, T-1821, T-2409, T-2363, T-2918]
arc_id: orchestrator-rethink
created: 2026-05-13T23:05:51Z
last_update: 2026-09-27T14:05:59Z
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 4
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=4 
      (body:cross-machine)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 4
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=4 
      (body:cross-machine); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 4
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=4 
      (body:cross-machine); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 4
      F-RECALL: 2
      F-ORCH: 4
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=4 
      (body:cross-machine); F-RECALL=2 (body:lightly-promoted); F-ORCH=4 
      (body:rubric-routable)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 4
      F-RECALL: 2
      F-ORCH: 4
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=4 
      (body:cross-machine); F-RECALL=2 (body:lightly-promoted); F-ORCH=4 
      (body:rubric-routable); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 4
      F-RECALL: 2
      F-ORCH: 4
      F3: 1
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=4 
      (body:cross-machine); F-RECALL=2 (body:lightly-promoted); F-ORCH=4 
      (body:rubric-routable); F3=1 (body/components:prompt-incidental); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-13T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 4
      F-RECALL: 2
      F-ORCH: 4
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=4 
      (body:cross-machine); F-RECALL=2 (body:lightly-promoted); F-ORCH=4 
      (body:rubric-routable); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-07T10:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 4
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=4 
      (body:cross-machine); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-17T12:36:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=287,acs=5)
    rubric_sha: e4a00f38e801
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
- [x] Live joint smoke via the *originally scoped* mechanism (per-session `event poll` on `inbox.queued`) is conclusively retired, not merely blocked. 2026-08-11 rerun found the framework-side root cause (`lib/peer.py::poll_once` polls a per-session bus that structurally cannot see hub-aggregator-injected events, plus a `dm.queued`/`inbox.queued` topic mismatch — `docs/reports/T-1820-joint-smoke-demo.md` §"2026-08-11 — conclusive rerun"). That root cause was handed to **T-2918**, which investigated the fix directly (hub aggregator has no cursor/replay primitive at all — `crates/termlink-hub/src/aggregator.rs:192-224`, confirmed against TermLink source) and surfaced the remaining choice as a Sovereign architecture question (T-2918 `## Recommendation`: DEFER, four candidate directions). That question was independently taken up and resolved by inception **T-3396** ("Peer-consult sidecar: real always-on listener per agent session, cooperative yield-point delivery") — `status: work-completed`, `date_finished: 2026-09-20`, `target_blast_radius: 5`, listing T-1820/T-2918 in `related_tasks:` and its own `voi_score` rationale naming "unblocks T-1820/arc-003's headline mechanic" directly — followed by **T-3397** ("Resolve T-3396 open questions IW-1..IW-6"), also `status: work-completed`. The chosen direction is not merely decided but *shipped and live*: this very session is addressed via `fw sidecar inbox`/`fw sidecar send` (arc-011 sidecar substrate, T-3407), the mechanism T-3396 GO'd — observed directly, not inferred, in this round's own tool use. **Conclusion:** T-1820's AC as originally worded (smoke the poll-based mechanism) can never be satisfied because the mechanism it targeted was abandoned in favor of the sidecar architecture. This is a retirement of the AC's premise, not an agent judgment that the substitute is "good enough" — that acceptance call is scoped to the Human AC below, per the same T-954/§ACD discipline T-2918 applied to its own architecture-choice AC.
- [x] Demo artefact (`docs/reports/T-1820-joint-smoke-demo.md`) is complete as a historical record of the *investigated* mechanism: dispatch envelope, T-1636 build commit hashes (`f3927611`, `13a11741`), worker report, the 2026-05-14 through 2026-08-11 rerun trail, and the conclusive 2026-08-11 root-cause section are all present and committed (verified: `grep -c T-1636` → 11 hits; commit-hash table row present at line 409; no `WORKER-FILL`/`POST-SMOKE` placeholders remain). No further transcript is owed against the retired mechanism — see AC above. A live smoke against the *new* sidecar mechanism, if wanted, is independent scope for a new task, not a gap in this artefact.
- [x] No regression in framework-side peer tests: `python3 -m pytest tests/unit/test_peer_subscribe.py` 12/12 PASS (reconfirmed this session, 2026-09-27).

### Human
- [ ] [REVIEW] Confirm T-1820 should close as superseded-by-sidecar-architecture
      (substrate-shipped, original poll-based smoke retired) rather than stay
      open waiting for a live smoke that this task's original mechanism can
      no longer produce.
  **Steps:**
  1. Read this task's Context + the two Agent ACs above (the 2026-08-11
     conclusive-rerun citation and the T-2918 → T-3396 → T-3397 chain).
  2. Confirm T-3396 (`fw task show T-3396`) really is the GO'd architecture
     decision that superseded the poll-based mechanism this task targeted,
     and that T-3397 resolved its open implementation questions.
  3. If you agree: no action beyond ticking this box and running
     `cd /opt/999-Agentic-Engineering-Framework && bin/fw task update T-1820 --status work-completed`.
  4. If you want a *live* smoke against the new sidecar mechanism before
     closing this lineage: don't tick this box — instead note that under
     `## Decisions` below and file a new task for it (this task's own
     Verification block still targets the retired mechanism's artefact, not
     the sidecar).
  **Expected:** Agreement that the poll-based mechanism is dead and the
  sidecar mechanism (now live — this round used `fw sidecar inbox`/`send`
  itself) is its replacement, so T-1820 closes as historical record of a
  retired approach rather than lingering as apparently-still-open work.
  **If not:** Reopen with `fw task update T-1820 --horizon now` and name
  what independent scope remains (e.g. a fresh sidecar-smoke task).

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

### 2026-05-14 — investigation worker dispatched, CLI trigger still not reachable

- **What changed:** Operator chose option 2 ("keep T-1820 open + investigate"). Dispatched `t1820-trigger-extract` (Haiku, ~3min) to read `crates/termlink-hub/src/channel.rs` lines 1780–1809 verbatim. Worker reported "CLI trigger exists now: `termlink channel post inbox:<session-id> --msg-type file.init '<json>'` — no new commands needed." Tested the recipe live: **three posts** to `inbox:tl-design-smoke-target` with `--msg-type file.init`, each landed at offsets 0/1/2, **no `inbox.queued` event** fired on `framework-agent`'s stream (`next_seq` stuck at 344) and no `inbox.queued` topic appeared on any session's `event topics` list. Working hypothesis: the handler that injects `inbox.queued` into the aggregator runs inside the integration test via `init_aggregator(...)` — not at hub startup. The live hub therefore has no handler picking up the `channel post` to inject the event. T-1821 filed as the framework-side tracker for re-running the smoke once TermLink wires the aggregator handler at hub boot (or ships the user-facing trigger path).
- **Plan impact:** Investigation done; conclusion is the same as PARTIAL-SHIP. The trigger isn't reachable from the current CLI surface; T-1636 ships the substrate, not the user-facing trigger. Recommendation re-issued: accept PARTIAL-SHIP and close T-1820 substrate-shipped, picking up the live smoke under T-1821 once TermLink wires the handler.
- **Triggered:** T-1821 filed (framework-side tracker, captured/next, owner: agent, type: build). Cross-link added to this task's related_tasks if not already present.

### 2026-05-16 — rerun against fix-shipped hub 0.9.2110 ebe05294 — emit still not observable from session-poll

- **What changed:** TermLink-side agent shipped a follow-up at commit `ebe05294`, version `0.9.2110` (framework:pickup offset 18, msg-type=fix.shipped, responding to P-041). Reported fix: `handle_channel_post_with` now injects `inbox.queued` when topic starts with `inbox:` and bus.post succeeds. Reported live-smoke evidence: `channel post inbox:tl-design-smoke-target --msg-type file.init` → "hub-level event.subscribe (topic=inbox.queued) returned count=1 with addressee_session_id=tl-design-smoke-target, message_offset=4". Rerun request: "Please re-run the T-1820 joint smoke against the updated hub and confirm next_seq advances on inbox.queued."

  Rerun executed 2026-05-16T06:47Z against local hub:
  - `termlink doctor` confirms `version: termlink 0.9.2110 (ebe05294)` and `hub: running (PID 2382342)` — matches the PID + binary termlink-agent reported.
  - Spawned a fresh session `tl-design-smoke-target` (session was gone since prior smoke).
  - Three trigger attempts: `channel post inbox:tl-design-smoke-target --msg-type file.init --payload '{transfer_id:t1820-rerun-00X-2026-05-16}'` — all delivered cleanly (offsets 5/6/7 on the topic).
  - Probes after each trigger:
    - `termlink event poll tl-design-smoke-target --topic inbox.queued --since 0` → count=0, next_seq=0 (bus empty).
    - `termlink event poll framework-agent --topic inbox.queued --since 0` → count=0, next_seq=384 (no advance from 384).
    - `mcp__termlink_event_subscribe target=tl-design-smoke-target topic=inbox.queued since=0 timeout_ms=3000` → count=0.
    - `termlink event topics` across all 10 sessions → **zero sessions list `inbox.queued`** as an emitted topic.
    - `termlink channel info inbox.queued` → -32013 unknown topic (it's not a channel topic, which is expected — it's an event class).
- **Plan impact:** PARTIAL-SHIP recommendation **stands**. The fix's correctness inside the hub crate (integration test green, hub-level event.subscribe sees count=1 per termlink-agent's report) does NOT translate to anything the framework's `fw peer subscribe` can consume. Framework-side substrate (`lib/peer.py::poll_once`) calls `termlink event poll <target> --topic inbox.queued --since <cursor>` — per-session bus. The new emit appears to land somewhere session-poll cannot reach (hub-internal aggregator? a virtual aggregator session?). Headline mechanic (framework subscriber observes the event when a CLI post lands an inbox) is still not demonstrated end-to-end.
- **Triggered:** Sent structured inject reply to termlink-agent asking which session bus the emit lands on (or how to subscribe from a CLI client). Keeping T-1820 in PARTIAL-SHIP awaiting clarification or a session-targeted wiring change.

### 2026-08-11 — conclusive rerun: TermLink T-2363 confirmed shipped, real root cause found (framework-side)

- **What changed:** Dispatched a read-only TermLink worker confirming T-2363
  (the fix TermLink filed for the T-2409 investigation) shipped 2026-07-06,
  commit `7aa968811`. Re-ran the live smoke against the shared hub
  (`termlink 0.11.720`). Result: the fix is real and correct, but the smoke
  still does not observe a live event — because of a **framework-side**
  defect, not a TermLink-side one. Root cause confirmed by direct
  reproduction: `lib/peer.py::poll_once` polls a per-session event bus
  (`termlink event poll <session> --topic inbox.queued`), but `inbox.queued`
  is injected into the hub-level aggregator under a synthetic `session_id:
  "hub"` — per-session poll cannot reach it regardless of target or topic
  correctness. Confirmed live: polling both the addressee session and an
  unrelated ready session returned 0 events immediately after a proven emit,
  while `termlink event watch --hub --topic inbox.queued` captured the same
  emit instantly. Separately confirmed: the DM rail (T-2323, shipped after
  T-1819's prompts map was authored) emits under topic `dm.queued`, not
  `inbox.queued` — so `.context/peer-consult-prompts.yaml`'s `dm:design-*`
  channel-prefix routing can never fire via the topic the subscriber polls,
  even with the poll-primitive defect fixed. Full trail:
  `docs/reports/T-1820-joint-smoke-demo.md` §"2026-08-11 — conclusive rerun".
- **Plan impact:** T-1821's premise ("aggregator not wired at hub startup")
  is disproven — the aggregator was wired the whole time. **T-2918** filed
  as the precisely-scoped fix (lib/peer.py must consume the hub aggregator,
  not per-session poll; resolve the inbox.queued/dm.queued topic question).
  Registered as concern OBS-186 (three months of investigation, T-1820 →
  T-2409 → TermLink T-2363, correctly fixed real TermLink-side emit bugs but
  never re-tested whether the framework's own poll call could reach a
  hub-injected event at all). AC #2/#4 remain unticked — the live smoke, as
  literally scoped, still does not fire end-to-end; this is a definitive
  negative result with a named, fixable cause, not an open question.
- **Triggered:** T-2918 filed (build, owner: agent, horizon: now). T-1821
  updated with a superseded-premise note pointing at T-2918.

### 2026-05-14 — pickup envelope delivered to TermLink-side inbox

- **What changed:** Operator chose option 2 (hold T-1820 open until TermLink resolves the handler gap) — and asked the right question: have we filed a pickup with TermLink? Answer was no until now. Dispatched `t1820-pickup-deliver` (Haiku, ~30s) to /opt/termlink which ran `bin/fw pickup send --type bug-report --priority high --task-id T-1636 --tags cross-repo,joint-smoke,T-1820,T-1636,T-1821` with the full working-hypothesis detail (handler registered in test only via `router::init_aggregator`, three resolution paths A/B/C). Envelope `P-041-bug-report.yaml` created in /opt/termlink's `.context/pickup/inbox/`; visible on `bin/fw pickup list`. The TermLink-side maintainer (or their next agent session) will see it on routine pickup processing.
- **Plan impact:** Cross-repo signal is now formally on record in /opt/termlink, not just in our demo doc. Framework side can hold T-1820 open without needing to chase TermLink — they have the structured envelope to triage on their cadence. Closes the cross-repo coordination loop this slice can close from our side.
- **Triggered:** No new sub-task. Awaiting TermLink-side pickup processing (`fw pickup process` on /opt/termlink, or routine agent review of inbox).

### 2026-09-27 — architecture question this task deferred to T-2918 is now resolved and shipped (procAsFit round 2, T-3517)

- **What changed:** T-2918's own Sovereign architecture question (four
  candidate directions for the hub-event-observation gap, DEFER'd
  2026-09-20) was independently taken up by inception **T-3396**
  ("Peer-consult sidecar: real always-on listener per agent session,
  cooperative yield-point delivery"), which reached GO and
  `status: work-completed` the same day, naming T-1820 directly in its
  `voi_score` rationale ("unblocks T-1820/arc-003's headline mechanic").
  Follow-up **T-3397** resolved its remaining implementation questions
  (IW-1..IW-6) and is also `status: work-completed`. The chosen direction is
  not just decided but live: this session (a TermLink worker dispatched
  under T-3517) is itself addressed via the sidecar substrate
  (`fw sidecar inbox`, arc-011/T-3407) — confirmed by direct use, not by
  reading a task file. This means T-1820's original AC ("live smoke of the
  per-session `inbox.queued` poll mechanism") targets a mechanism that no
  longer exists as the sanctioned design; it was not fixed, it was replaced.
- **Plan impact:** T-1820's own 2026-08-11 PARTIAL-SHIP recommendation is
  superseded, not by this session judging the work adequate, but by a
  Sovereign decision made elsewhere (T-3396's human-gated `fw inception
  decide go`) that this session has no authority to make and is only
  reporting. The acceptance call ("is closing this lineage on
  substrate-shipped + superseded-premise correct, or is a fresh live smoke
  against the sidecar wanted first") is scoped to a new Human AC rather than
  decided here — consistent with T-2918's own precedent of reclassifying an
  architecture-adjacent AC as Human rather than self-certifying it.
- **Triggered:** No new sub-task filed. If the Human AC below is confirmed,
  this task closes as historical record of the retired mechanism; if a live
  sidecar smoke is wanted, that is named as a fresh task at confirmation
  time, not assumed here.

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

**Recommendation (updated 2026-09-27, procAsFit round 2, T-3517):** GO — close
T-1820 as superseded-by-sidecar-architecture, pending the one-line operator
confirmation in the Human AC above. This supersedes (but does not delete) the
2026-08-11 PARTIAL-SHIP recommendation below.

**Rationale:** The 2026-08-11 recommendation already established that
T-1820's substrate work is real and that the live-smoke gap was a named,
framework-side bug (T-2918), not an open question. What's new since then:
T-2918's own remaining Sovereign question (which of four architecture
directions to take) has been resolved — not by this session, but by a
human-gated inception decision (T-3396, GO, `fw inception decide`) — and the
chosen direction (a real always-on sidecar, not a poll-based subscriber) has
shipped and is live, confirmed by this session's own use of it. T-1820's
original AC targeted the poll-based mechanism specifically; that mechanism
was not fixed, it was retired. Closing T-1820 now is not "good enough,
ship it" — it is recognizing that the AC's technical premise no longer
exists to be tested, and that the actual open question (pick an
architecture) was already decided by the party authorized to decide it.

**Evidence:**
- T-3396 frontmatter: `status: work-completed`, `date_finished:
  2026-09-20T22:19:04Z`, `related_tasks: […, T-1820, …]`, `voi_score: 0.7`
  rationale naming T-1820/arc-003 directly.
- T-3397 frontmatter: `status: work-completed` (resolves T-3396 IW-1..IW-6).
- This session's own tool availability: `fw sidecar inbox` /
  `fw sidecar send` (arc-011 sidecar substrate, T-3407) — the sidecar is not
  a paper design, it is the mechanism this very dispatch is running under.
- T-2918's own DEFER rationale (`## Recommendation`, unchanged): the hub
  aggregator has no cursor/replay primitive at all — confirmed against
  TermLink source, not CLI help text — which is why a same-mechanism fix was
  never on the table; only a direction change could close this.

**If GO is confirmed:** operator ticks the Human AC above and this task
closes via `fw task update T-1820 --status work-completed`.
**If not:** operator reopens (`fw task update T-1820 --horizon now`) and
names what a fresh sidecar-based smoke task should cover.

---

**Original recommendation (2026-08-11), preserved for record:**

- **Recommendation:** **PARTIAL-SHIP** (unchanged conclusion, now on decisive
  evidence) — close T-1820 as substrate-shipped; follow-up refiled as
  **T-2918** (T-1821's premise is disproven — see 2026-08-11 Evolution
  entry). Agent will NOT autonomously close T-1820 GO; surfacing to the
  operator per §ACD discipline.
- **Rationale (updated 2026-08-11):** TermLink's T-2363 fix (filed by T-2409's
  investigation) landed 2026-07-06 and is confirmed correct — verified live by
  re-triggering the exact `remote send-file` path it fixed. The smoke still
  does not observe a live event, but the reason is now conclusively known
  and framework-owned: `lib/peer.py::poll_once` polls a per-session event
  bus, which structurally cannot see hub-aggregator-injected events
  (confirmed by side-by-side comparison — per-session poll returns 0 events,
  `event watch --hub` captures the identical emit instantly). A second,
  independent defect was also found: the DM rail emits under topic
  `dm.queued`, not the `inbox.queued` topic the subscriber polls, so the
  AC's literal `dm:design-*` scenario can never route through
  `peer-consult-prompts.yaml` even with defect #1 fixed. Both are scoped in
  **T-2918** and registered as concern **OBS-186**. Per §ACD/G-062
  ("acknowledged failure better than false success"), I am not closing
  T-1820 GO on substrate-only evidence — but this is no longer an open
  question, it's a named, fixable, framework-side bug.
- **Evidence (green — what landed):**
  - Worker `t1636-build` exit 0 at 23:36Z (~22min); 3 files / 50 LOC / 2 tests; commits `f3927611` + `13a11741` on `/opt/termlink` master.
  - Worker `t1820-deploy` exit 0 (~7min); `cargo install` succeeded; new binary `termlink 0.9.2104` (was 0.9.1701), mtime today.
  - Hub restarted: PID 1113405 → PID 4091515; new binary active.
  - `bin/fw peer subscribe --once` against live hub: exit 0, cursor written, no errors.
  - `event poll framework-agent --topic inbox.queued`: topic recognized (`next_seq: 342`, no error).
  - Framework peer tests: 12/12 PASS.
  - **(2026-08-11)** TermLink T-2363 confirmed shipped and correct (commit `7aa968811`).
  - **(2026-08-11)** Hub aggregator confirmed wired at boot (`server.rs:279`, `run_with_tcp()`), disproving the T-1821 hypothesis.
  - **(2026-08-11)** `termlink event watch --hub --topic inbox.queued` and `--topic dm.queued` both captured live emits within the same second they were triggered — proves TermLink's emit path works end-to-end for both rails.
  - Demo artefact: `docs/reports/T-1820-joint-smoke-demo.md` (worker report, deploy log, 2026-08-11 conclusive rerun with full reproduction trail and named root cause).
  - Reviewer: Overall PASS / Needs Human yes (cross-project-blast Layer-1 is the cross-repo human-review signal).
- **Evidence (red — what did NOT land):**
  - No live `inbox.queued` event observed via `fw peer subscribe` / per-session `event poll` — root cause is now named (`lib/peer.py` polls the wrong primitive; see T-2918), not unknown.
  - The AC's literal `dm:design-*` scenario cannot be reached even with the poll defect fixed, because the DM rail emits under `dm.queued`, not `inbox.queued` (also scoped in T-2918).

**Investigation outcome (option 2 executed):**

Worker `t1820-trigger-extract` read `channel.rs:1780-1809` and reported the
recipe `termlink channel post inbox:<id> --msg-type file.init '<json>'`. I
tested it three times against `inbox:tl-design-smoke-target` — every post
landed (offsets 0/1/2) but no `inbox.queued` event fired on framework-agent's
stream or appeared in any session's `event topics`. **The conclusion lines
up with PARTIAL-SHIP:** the handler that injects `inbox.queued` into the
aggregator is registered inside the integration test via
`router::init_aggregator(...)`, not at hub startup. The live hub has no
handler picking up the post.

T-1820's substrate work is real and useful (deploy landed, framework
subscriber operational against the new hub, topic recognized). The headline
mechanic requires TermLink to either (a) call `init_aggregator` at hub
startup, (b) add a CLI command that bridges the post to an in-process
aggregator subscriber, or (c) bundle this with the next delivery-path
change so the emit fires in production.

**T-1821 filed** as the framework-side tracker for the live smoke when
TermLink resolves the handler-registration gap.

**Operator decision (please pick one in the Watchtower review):**

1. **Accept PARTIAL-SHIP** — agent transitions T-1820 to work-completed
   (substrate shipped, headline mechanic deferred to T-1821 with live demo
   conditional on TermLink resolving the handler gap). Recommended.
2. **Hold T-1820 open until TermLink resolves the gap** — keep the framework-
   side task open; close it the same day TermLink ships the handler fix and
   the live smoke runs green. Higher coupling, longer-lived task; loses the
   "one task = one deliverable" discipline.

Agent's call: **option 1**. The substrate is a real ship. T-1821 captures
the next move at the right scope. Operator confirms or overrides.

## Updates

### 2026-05-13T23:05:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1820-joint-smoke-test-slice--v2-peer-consult-.md
- **Context:** Initial task creation

### 2026-05-13T23:12:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-36811a68
- **Timestamp:** 2026-08-11T12:43:25Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 17
     - evidence: `bin/fw reviewer T-1820 2>&1 | grep -q "Overall:.*PASS"`

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-repo`

### 2026-09-27T14:05:59Z — status-update [task-update-agent]
- **Change:** owner: agent → human
- **Reason:** procAsFit round 2 (T-3517): reclassifying for operator confirmation — original poll-based smoke mechanism retired, superseded by sidecar architecture (T-3396 GO, T-3397 resolved), acceptance call scoped to new Human AC per T-2918 precedent
