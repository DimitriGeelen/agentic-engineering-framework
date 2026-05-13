# T-1820 — Joint Smoke Demo Artefact

**Status:** build complete, live smoke deploy-blocked (awaiting operator deploy decision)
**Arc:** dispatch-safety + orchestrator-rethink (v2 peer-consult slice 1)
**Cross-repo joint:** framework T-1818/T-1819/T-1820 ↔ TermLink T-1636
**Seam:** `inbox.queued` event (T-1804 inception GO)

## Headline mechanic

TermLink hub fires `inbox.queued` when a DM lands in a session inbox with no
live consumer → framework `fw peer subscribe` polls the event → resolves the
addressee against `.context/peer-consult-prompts.yaml` → spawns a responder
worker via `fw termlink dispatch`. The cross-repo wire contract is a
4-field envelope with no message body:
`{addressee_session_id, channel, message_offset, enqueued_at}`.

This artefact captures the live joint behaviour after T-1636 ships.

## Cross-repo coordination story (dogfooded)

Before dispatching the build worker, the framework agent ran a coordination
consultation against the TermLink-side anchor to confirm authorization +
scope. This is itself an instance of the very pattern we are smoke-testing —
the framework agent asks a peer for guidance before crossing a repo boundary.
We are doing it by hand because the automated seam (T-1636) is not yet live.

### Coordination consultation (verbatim)

> **T-1636 is unstarted** (created 14h ago, marked `started-work` but zero
> implementation commits; prior session moved to handover). **Framework
> dispatch is welcome** — scope is frozen (seam locked in T-1804 inception
> GO), AEF half shipped, and implementation is pure plumbing (event const +
> one emission call + test). Documented 5 constraints: event const +
> delivery-path emit only, locked payload, ≤50 LOC diff, standard event
> emission style, integration test pinning no-consumer fire / live-consumer
> no-fire semantics.

Source: `/tmp/tl-dispatch/t1636-coord/result.md` (Haiku, ~60s consultation).

The five locked constraints became the build worker's non-negotiable
preamble (see Dispatch Envelope below).

## Framework-half (shipped before build dispatch)

| Task | Artefact | What landed |
|------|----------|-------------|
| T-1818 | `lib/peer.py` | subscriber + resolver + spawn_responder (12 unit tests pinning event parsing, addressee resolution, spawn shape, cursor advance) |
| T-1819 | `.context/peer-consult-prompts.yaml` | runtime addressee→workflow map (4 entries: design-consult `dm:design-`, escalation-triage `dm:escalate-`, prompt-triage `dm:triage-`, dm-fallback `dm:`) + disk-load test pinning the shipped seed |
| T-1820 | this document | joint smoke harness + demo |

Pre-build smoke (mock emitter): `python3 -m pytest tests/unit/test_peer_subscribe.py -q` → 12/12 PASS.

## Dispatch envelope (T-1636 build worker)

```json
{
  "name": "t1636-build",
  "project": "/opt/termlink",
  "timeout": 5400,
  "task": "T-1820",
  "task_type": "build",
  "model": "sonnet",
  "model_used": "sonnet",
  "fallback_used": false,
  "resolution_source": "explicit",
  "started": "2026-05-13T23:14:33Z",
  "status": "running"
}
```

CLI form:

```
bin/fw termlink dispatch \
  --project /opt/termlink \
  --task T-1820 \
  --timeout 5400 \
  --model sonnet \
  --name t1636-build \
  --prompt "<5-constraint preamble>"
```

**Timeout lesson:** the first dispatch used the 600s default
`TERMLINK_WORKER_TIMEOUT` and was killed mid-read (211KB into result.jsonl).
A Rust build + test + commit needs ~30-90min; the watchdog would have killed
the worker every time at the default. Redispatched with explicit
`--timeout 5400` + `--model sonnet`. Captured as Evolution entry in T-1820.

**Follow-up candidate (not filed):** workflow-driven timeout — the v1 build
workflow could declare `expected_duration: 90m` so the dispatcher sizes the
watchdog from task-type rather than from a one-size-fits-all default.

## Worker report

**Exit:** code 0 at 2026-05-13T23:36Z (~22min wall, well inside the 90min budget).

**3 files changed, 50 LOC diff (48+2)** — within the locked ≤50 LOC budget:

| File | Change |
|------|--------|
| `termlink-protocol/src/events.rs` | Added `inbox_topic::QUEUED` const + `InboxQueued` struct |
| `termlink-hub/src/aggregator.rs` | Added `EventAggregator::inject()` for hub-originated events |
| `termlink-hub/src/channel.rs` | Wired emit in `mirror_inbox_deposit_with` + 2 unit tests |

**Architecture:** the emit lands inside `mirror_inbox_deposit_with` — the
function called exclusively when a message is spooled for an offline
session (no live consumer). On a successful `bus.post`, it calls
`aggregator().inject()` which surfaces the event via `event.subscribe`
long-poll. Cross-machine guarantee is intrinsic: the function runs on the
recipient's hub.

**Integration tests added:**
- `inbox_queued_fires_for_no_consumer` — no-consumer path emits the event
- `inbox_queued_not_emitted_without_deposit` — live-consumer path does NOT emit (delivered directly, no enqueue)

Both pass. Release build clean.

**Deviations from constraints:** none. Standard event emission style matched
(read 2 existing emit sites for the `inject`/`record` pattern). Locked
payload preserved verbatim.

**Commit trail (on /opt/termlink master, per worker report):**
- `f3927611` — implementation (events.rs + aggregator.rs + channel.rs + 2 tests)
- `13a11741` — task update (AC ticks + Recommendation, status left `started-work` for TermLink-side human review)

## Live joint smoke — **DEPLOY-BLOCKED**

**Current state of deployed `termlink` binary:** `/root/.cargo/bin/termlink`
mtime **2026-05-01 23:21**, version `0.9.1701`. T-1636 commits landed on
`/opt/termlink` master today (2026-05-13). The deployed binary therefore
does **not** contain the new `inbox_topic::QUEUED` emit. A live binary-to-
binary smoke against this hub would not observe the event.

**Hub state:** PID 1113405, running on `0.0.0.0:9100` since 2026-05-05.
This hub is shared infrastructure — restarting it would terminate every
TermLink session on this host (worker dispatches, peer agents on remote
machines connected via TCP, etc.). Per CLAUDE.md §"Executing actions with
care", that blast radius requires human consent rather than autonomous
action. The agent has therefore stopped at the deploy boundary and is
surfacing the decision to the human.

**Two operator-decision paths exist (Watchtower review will offer both):**

1. **Restart the shared hub** with the rebuilt binary — simplest path,
   one-time interruption. Sequence:
   ```
   cd /opt/termlink && cargo install --path crates/termlink-cli
   termlink hub stop && termlink hub start --tcp 0.0.0.0:9100 --json &
   ```
   Then re-run the harness below.

2. **Side-by-side hub on a non-prod port** — leaves the main hub running.
   Requires the framework subscriber to be pointed at the side hub for the
   smoke window. More steps, no service interruption.

### Smoke harness (to run after the operator chooses a deploy path)

1. **Spawn a tagged TermLink consumer session**
   ```
   termlink spawn --name peer-smoke-consumer --backend background --shell \
     --wait --tags "task:T-1820,role:peer-smoke-consumer"
   ```

2. **Post a DM into a `dm:design-*` channel addressed to that session**
   (the channel prefix should resolve via `peer-consult-prompts.yaml` to
   `workflows/design-dialogue.yaml` per the seed map.) Use
   `termlink channel post` with addressee header set to the spawned session's id.

3. **Run framework subscriber once**
   ```
   bin/fw peer subscribe --once
   ```

4. **Observe**:
   - `inbox.queued` event polled (visible in subscribe stdout)
   - Addressee resolved to `design-consult` workflow + name
   - Responder spawn invoked — `fw termlink dispatch --name peer-design-consult --prompt <...>`
   - Cursor advanced (`.context/working/peer-cursor.yaml` updated to highest seen `message_offset`)

5. **Negative path (single subscribe pass)**: post a second DM to a
   `dm:unknown-channel` not in the seed map → expect cursor advances, miss
   logged to `.context/working/peer-misses.jsonl`, no spawn invoked.

Transcript will be pasted verbatim into this section, timestamps included.

## Verification (P-011 gate)

```
test -f docs/reports/T-1820-joint-smoke-demo.md
grep -q "T-1636" docs/reports/T-1820-joint-smoke-demo.md
python3 -m pytest tests/unit/test_peer_subscribe.py -q
bin/fw reviewer T-1820 2>&1 | grep -q "Overall:.*PASS"
```

## Recommendation — PARTIAL-COMPLETE

**Recommendation:** **HOLD** — wait for operator deploy decision, then run smoke and re-decide.

**Rationale:** five of six closure conditions are already green; the sixth
(live binary-to-binary observation) is a deploy boundary the agent
intentionally did not cross autonomously because restarting the shared hub
on `0.0.0.0:9100` would terminate every TermLink session on the host. The
honest framework-aligned move is to surface the deploy choice to the
human rather than close on a partial smoke.

**Evidence (green):**
- T-1636 implementation landed on `/opt/termlink` master — commits
  `f3927611` (impl) + `13a11741` (task update); 3 files, 50 LOC (within
  budget); 2 integration tests pin both no-consumer-fires and
  live-consumer-no-fires semantics.
- Framework peer subscriber + resolver shipped (T-1818) and tested
  (12/12 PASS at `python3 -m pytest tests/unit/test_peer_subscribe.py`).
- Prompts seed map shipped (T-1819, `.context/peer-consult-prompts.yaml`),
  with a disk-load test pinning the contract against deletion.
- Cross-repo wire shape (4-field envelope, no body) is identical on both
  halves of the seam — guaranteed by paired unit tests + the locked-payload
  constraint.
- Coordination consultation captured (`/tmp/tl-dispatch/t1636-coord/result.md`);
  authorisation + scope confirmed by the TermLink-side peer before dispatch.
- Reviewer verdict: Overall PASS (needs_human=yes is the correct cross-repo
  signal); 90-day TTL override OV-22a57a31 documents the integration evidence
  rationale.

**Evidence (red):**
- Deployed `termlink` binary at `/root/.cargo/bin/termlink` mtime 2026-05-01,
  version 0.9.1701 — predates today's T-1636 commits. The new emit code is
  not running on the live hub.
- Live `fw peer subscribe --once` against the live hub would observe
  **zero** `inbox.queued` events because the deployed binary doesn't fire
  them yet. Running it now produces non-evidence — false-success risk per
  §ACD discipline.

**Deploy choice for the operator (Watchtower review surfaces both):**
1. **Shared-hub restart** — `cargo install --path /opt/termlink/crates/termlink-cli`
   + `termlink hub stop && termlink hub start --tcp 0.0.0.0:9100 --json`.
   Shortest path; one-time TermLink interruption.
2. **Side-by-side hub on a spare port** — leaves prod hub running; framework
   subscriber points at the side hub for the smoke window. Lower blast
   radius, more steps.

**Post-deploy plan (the agent will execute upon operator decision):**
1. Verify `termlink --version` reflects the new binary.
2. Run the harness above (consumer spawn → DM post → `fw peer subscribe --once`).
3. Paste the live transcript into the “Live joint smoke” section above.
4. Run all 6 Verification commands; tick remaining ACs.
5. Re-issue the Recommendation as GO.
6. Transition T-1820 to work-completed.

## Provenance / cross-repo trail

| Repo | Task | Commits (this slice) |
|------|------|----------------------|
| 999-Agentic-Engineering-Framework | T-1818 | (subscriber ship — completed before this session) |
| 999-Agentic-Engineering-Framework | T-1819 | `eaada7235` (seed + disk-load test) |
| 999-Agentic-Engineering-Framework | T-1820 | `16c1ae4ec` (ACs + dispatch), `04de4d7e7` (Evolution capture) |
| termlink                          | T-1636 | `f3927611` (impl), `13a11741` (task update) — on `/opt/termlink` master, not yet installed to `/root/.cargo/bin/termlink` |
