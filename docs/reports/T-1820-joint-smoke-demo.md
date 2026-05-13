# T-1820 — Joint Smoke Demo Artefact

**Status:** scaffolding (pre-build); build-dependent sections marked `[WORKER-FILL]`
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

## Worker report `[WORKER-FILL]`

Pending worker exit. Will be filled from `/tmp/tl-dispatch/t1636-build/result.md`:

- Files touched + LOC count (≤50 budget)
- Const + struct snippet
- Emit call snippet
- Test names + assertions
- cargo check / cargo test results
- Commit hash
- Any deviations from constraints

## Live joint smoke `[WORKER-FILL]`

Harness (planned — to be executed against the live emitter once the build lands):

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

## Recommendation `[POST-SMOKE]`

To be filled after the live smoke runs. Recommendation will be GO iff:
- T-1636 commit on `/opt/termlink` master references this task chain
- Event const + emit call landed within the ≤50 LOC budget
- Both integration scenarios (no-consumer fires, live-consumer does not) pass
- Framework `fw peer subscribe --once` observes the event end-to-end
- 12/12 framework peer tests still pass
- Reviewer agent verdict: PASS, needs_human=no

## Provenance / cross-repo trail

| Repo | Task | Commits (this slice) |
|------|------|----------------------|
| 999-Agentic-Engineering-Framework | T-1818 | (subscriber ship — completed before this session) |
| 999-Agentic-Engineering-Framework | T-1819 | `eaada7235` (seed + disk-load test) |
| 999-Agentic-Engineering-Framework | T-1820 | `16c1ae4ec` (ACs + dispatch), `04de4d7e7` (Evolution capture) |
| termlink                          | T-1636 | `[WORKER-FILL]` |
