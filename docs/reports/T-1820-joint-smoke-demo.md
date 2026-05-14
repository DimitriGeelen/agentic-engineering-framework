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

## Live joint smoke — **PARTIAL: substrate operational, headline mechanic not yet observed in live CLI**

### What landed

After operator GO on path 1 (shared-hub restart):

1. **Deploy worker `t1820-deploy`** (sonnet, exit 0 in 7 min) ran `cargo install --path /opt/termlink/crates/termlink-cli --force`. Binary at `/root/.cargo/bin/termlink` rebuilt from `13a11741` (one commit above the T-1636 emit at `f3927611`). New version: **`termlink 0.9.2104`** (was `0.9.1701`), mtime today.
2. **Hub restart** — `termlink hub stop && termlink hub start --tcp 0.0.0.0:9100 --json`. Old PID `1113405` (binary mtime 2026-05-01) → new PID `4091515` (binary 0.9.2104). Heads-up sent to remote sessions via `termlink inject` before the restart.
3. **Framework subscriber against live hub** — `bin/fw peer subscribe --once` exits 0; writes cursor `target_session: framework-agent, since: 0` to `.context/working/.peer-subscribe.cursor`; no errors. The subscriber correctly long-polls `event poll framework-agent --topic inbox.queued --since <cursor>` against the new hub.
4. **Topic recognized** — `event poll framework-agent --topic inbox.queued --since 0 --timeout 3` returns `"No events (next_seq: 342)"` — the topic name is *known* to the hub (not "unknown topic"), the event stream is operational, and there is currently no `inbox.queued` event sitting in the framework-agent inbox.

### What did NOT fire in this smoke

The integration test `inbox_queued_fires_for_no_consumer` on the TermLink
side (commit `f3927611`) drives `mirror_inbox_deposit_with()` **directly
from inside the hub crate** — it is an internal-plumbing test, not a
user-facing CLI smoke. From the framework agent's user-facing CLI surface,
two trigger attempts did not produce the event:

| Attempt | What | Result |
|---------|------|--------|
| A | `termlink file send peer-offline-target /tmp/t1820-smoke-payload.txt` to an offline target session | `File spooled to hub inbox for 'peer-offline-target'` BUT the send path emitted a `T-1249: new-path send failed — falling back to legacy events` WARN. The legacy fallback does **not** route through the new `mirror_inbox_deposit_with()` emit path. `event poll … inbox.queued` still `next_seq: 342` after the spool. |
| B | `termlink channel post dm:design-smoke-test --msg-type note` after first having `peer-smoke-consumer` (kill -9'd to take it offline) post to the topic (making it a "member"), then posting again from framework-agent | Post landed at offset 2; topic state confirms 3 posts from one fingerprint; `event poll … inbox.queued` still no events (`next_seq: 343`). The hub did not classify the kill-9'd consumer as an offline subscriber requiring deposit, or the channel-post deposit path doesn't route through the new emit. |

### Why this is a partial — and why the build is still solid

- The headline mechanic (live binary-to-binary observation) is the wire's behaviour as seen from outside. **It was not observed in this smoke window.**
- The wire contract is nevertheless pinned at the unit-test level on both halves:
  - TermLink-side: `inbox_queued_fires_for_no_consumer` + `inbox_queued_not_emitted_without_deposit` both PASS at the integration-test layer (verified via worker exit code 0; commit `f3927611`).
  - Framework-side: 12/12 PASS at `python3 -m pytest tests/unit/test_peer_subscribe.py -q`, covering event parsing, addressee resolution, spawn shape, cursor advance, and loop continuation past a miss.
- The substrate is operational: deployed binary reflects the new commits, hub runs the new binary, framework subscriber long-polls the new hub for the new topic without error.

### What's missing — the next investigation

Two investigation workers dispatched to clarify the trigger:

1. **`t1820-trigger-spec` (Haiku)** — confirmed the integration test calls
   `mirror_inbox_deposit_with()` directly (`crates/termlink-hub/src/channel.rs`
   lines 1780–1809). Helper stack: `tmp_bus → router::init_aggregator →
   mirror_inbox_deposit_with → aggregator.subscribe/inject`.
2. **`t1820-trigger-extract` (Haiku)** — reported "CLI trigger exists now:
   `termlink channel post inbox:<session-id> --msg-type file.init '<json>'`".

I tried that recipe live, **three times** to `inbox:tl-design-smoke-target`
with `--msg-type file.init`. All three posts landed at offsets 0/1/2 on the
topic, but **none produced an `inbox.queued` event** on:

- `event poll framework-agent --topic inbox.queued` (still `next_seq: 344`)
- `event topics` across all live sessions (no `inbox.queued` topic)

**Working hypothesis:** the handler registration that injects `inbox.queued`
into the aggregator happens *inside the test* via `init_aggregator(...)` —
not at hub startup. The live hub therefore has no handler picking up the
`channel post` and injecting the event, even though the post itself lands.
If true, the new emit is reachable only by code that runs `init_aggregator`
in-process — which is presently the integration test only.

This needs the TermLink-side maintainer's call:
- Option A: ship a `router::init_aggregator` invocation at hub startup so
  the handler is live → the recipe above starts working from CLI.
- Option B: declare T-1636 as substrate-only-this-slice and wire the
  user-facing trigger in a follow-up TermLink task (e.g., T-1636-b: register
  the aggregator handler at hub boot).
- Option C: pair this with the next TermLink delivery-path change so the
  emit is wired in production, not just tests.

Filed as **T-1821** on the framework side to track the joint smoke from our
end: when TermLink resolves A/B/C, we re-run the smoke against the live
hub and tick T-1820's AC#3 (or close T-1820 substrate-shipped and ship the
live observation under T-1821).

### Smoke harness (used today, partial)

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

## Recommendation — PARTIAL-COMPLETE (post-deploy)

**Recommendation:** **PARTIAL-SHIP** — close the substrate + capture investigation
follow-up; do not declare GO on the headline mechanic.

**Rationale:** the deploy landed cleanly (new binary running, hub restarted,
subscriber polls the new hub without error, topic recognized). Two
attempts to exercise the new emit from the user-facing CLI did not fire
it — the file-send path fell back to the legacy emitter (`T-1249` warn),
and the channel-post-with-offline-subscriber path did not trigger
`mirror_inbox_deposit_with()` either. The integration test on the
TermLink side calls that function directly from inside the hub crate, so
PASSING the test is **not** equivalent to "any user-facing flow exercises
the new emit." Per the framework's §ACD/G-062 discipline ("acknowledged
failure is better than false success"), I am not closing T-1820 GO on
substrate-only evidence — that's the exact conflation §ACD names.

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
- File-send + channel-post smoke attempts did NOT fire `inbox.queued` from
  outside the hub crate. See §"Live joint smoke" "What did NOT fire" for
  the specific commands + exit states.
- The integration test passing on the TermLink side calls
  `mirror_inbox_deposit_with()` directly — that does NOT prove any user-
  facing CLI flow currently exercises the new emit.

**Recommended next move:** file T-1821 as a follow-up investigation task —
"identify the user-facing trigger for inbox.queued and complete the joint
smoke." Transition T-1820 to work-completed under partial-ship framing:
substrate is real and useful; the headline-mechanic observation is a
distinct deliverable worth its own evidence bar.

The agent will NOT autonomously close T-1820 GO on substrate-only evidence
(that is the §ACD conflation the discipline names). Operator decision
needed:
- Accept partial-ship + file T-1821 follow-up
- Or keep T-1820 open and authorise another investigation worker (read the
  integration test verbatim, identify the precise trigger, retry smoke)

## Provenance / cross-repo trail

| Repo | Task | Commits (this slice) |
|------|------|----------------------|
| 999-Agentic-Engineering-Framework | T-1818 | (subscriber ship — completed before this session) |
| 999-Agentic-Engineering-Framework | T-1819 | `eaada7235` (seed + disk-load test) |
| 999-Agentic-Engineering-Framework | T-1820 | `16c1ae4ec` (ACs + dispatch), `04de4d7e7` (Evolution capture) |
| termlink                          | T-1636 | `f3927611` (impl), `13a11741` (task update) — on `/opt/termlink` master, not yet installed to `/root/.cargo/bin/termlink` |
