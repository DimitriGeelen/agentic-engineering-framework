# Z.ai opencode (zai-coding-plan/glm-5.2) — 2026-10-20 — review of T-4435 bundle (isolated re-run: outside the repo, all tools disabled, bundle only)

That skill wasn't relevant to this task — this is a review, not opencode configuration. Let me inspect the scratchpad to understand the expected output format.
The skill loader is mis-triggering on this directory. Ignoring it — this task is a review, not configuration. Let me check the scratchpad files to understand the output contract.
No relevant skill for this task — proceeding with the review directly. (Note: the excerpts are my only file access in this environment; line references are to the excerpted versions.)

# T-4435 review — opencode (Z.ai), 2026-10-19

## 1. Is the contract sound?

Mostly. Three of the four legs hold; the terminal-state seam does not.

- **Single-writer `done`** — sound, and it fixes a real gap: today the `worker.done` event lives on the worker's own session and dies with it (agents/termlink/termlink.sh:1688-1689). Moving completion to a hub record is right.
- **Fencing** — correct in principle; it is the direct cure for T-3960 finding 1c (`lib/spawn.py:218-272`: match on `dispatch_id` only, unconditional `row["outcome"]=` at 261). Two gaps. (a) A fence fences the *record*, not the *effects*: a stale attempt's commits stay in the repo after `fence_reject`. The result hash must be bound to its attempt number, so verdicts name (hash, attempt) and a rejected attempt's effects have a stated disposition. (b) The nonce must be hub-minted at attempt creation and validated atomically with the `done` write — an echo-check separated from the write is a TOCTOU that reopens the race. Attempt numbers must likewise be hub-assigned; client-side numbering lets two supervisors each believe they are attempt N+1.
- **`lost` only on confirmed session end** — the conservatism is right (no false `lost` on missed heartbeat), but with no timeout it creates a stuck state: a zombie session that never ends pins the record in `running` forever. T-4152's 37 workers blocked in `n_tty_read` (termlink.sh:1683-1686) is direct evidence the never-ending-session class exists. "Not on a missed heartbeat" must not become "only with human eyes" — add a supervisor deadline or an explicit operator-adjudicated `lost`.
- **The unnamed race**: `done` (supervisor) and `lost` (hub) are *two* writers of terminal state with no precedence rule. Concrete interleaving: run.sh writes local `exit_code`, dies or partitions before the hub `done`; hub sees confirmed session end, writes `lost`. Local durable evidence says done, hub says lost, and the contract has no reconciliation. The direct-path ledger already solved this shape: state is the highest-ranked row, not the newest (lib/sidecar/direct.py:52-60). Steal it — fenced `done` (or fenced evidence submitted within a grace window) supersedes `lost`, with an idempotent `lost → done` upgrade.

## 2. Is the ownership split right?

Broadly yes: run.sh and the instruction template are already AEF's; the dispatcher session id is information only AEF holds; the ledger primitive and hub-written `lost` are TermLink's. Two amendments:

- The hand-back *schema* (commission, attempt, nonce, status, summary, findings) is contract surface, not AEF-private. AEF owns the template; the schema must be specified three-way, or [REDACTED]'s S-1 supervisor can't emit the same shape and substitutability (the whole point of the shared primitive) fails.
- Result-hash rules (commit sha / sha256 of hand-back, attempt binding, nonce check) belong in the contract and in TermLink's validator — AEF produces evidence, the hub validates it. Don't leave validation to the writer.

## 3. Are AEF's four conditions right?

1. **Record the session** — right, necessary. The agent id is per project (lib/sidecar/watcher.py:195-197); a project-level dispatcher cannot tell two parents apart. Keep.
2. **Answers via the record** — right conclusion, under-specified as written. It turns the record from an outcome ledger into a communication channel: it needs a per-attempt answers section that the lifecycle state machine ignores, plus poll semantics (interval, deadline — see Q4). The ack-per-command-id in the proposal should be the worker's poll writing a read-marker under the same fence, not a sidecar ack, since the worker has no receiver.
3. **Local fallback (D4)** — right, but two holes: the local path has no hub-written `lost`, so who marks `lost` when run.sh is killed without a confirmable session end? (Needs a local sweep.) And two fencing implementations will drift — make the record format a spec with one conformance test both backends run. T-3042's lesson (crash-atomic ≠ concurrency-safe; lib/spawn.py docstring) transfers verbatim to TermLink's primitive and should be an acceptance criterion in *their* build task.
4. **Replace, not run beside** — right; dual writers would be worse than either alone. Add the migration tail: `termlink record-outcome` route learning (termlink.sh:1677-1685) and dispatch-outcomes.jsonl readers must move onto the record, not keep reading the old log. Note finding 2a: `retry_of_dispatch_id` semantics must survive the schema change or the pause queue silently deflates.

**Missing**: the done/lost precedence rule (Q1) and the answer TTL/bounce policy (Q4) as explicit conditions.

## 4. The answer path to a running worker

The draft's answer — poll the fenced record — is the correct base, and I'd defend it firmly: the worker's only stable, correctly-namespaced address is (dispatch id, attempt). No inbox topic is ever created for the worker, so the orphan-inbox class T-4418 closed (87 messages "delivered" into a topic nobody reads; lib/sidecar/addressing.py:7-20) is excluded *by construction*, and T-4423 stays intact (the worker never owns a receiver; watcher.py:201-204 refuses `FW_DISPATCHED_WORKER=1`).

The part the draft leaves open is the failure policy, and here the ladder is actively wrong: 16 attempts doubling from 1 minute to 1 month, ~76 days (lib/retry_ladder.py:24-28), with escalation verbs — nudge, operator, deadletter — that are meaningless for a recipient that lives minutes to an hour. Re-posting to a dead worker is exactly the "noise, not reach" failure D-600's escalation class exists to prevent (retry_ladder.py:39-42). The ladder is deliberately pure (no transport knowledge), so this is caller-side policy: an answer bound for a worker rides at most the first rung or two (≤ ~10 minutes, inside the attempt's remaining lifetime), then **bounces** — to the dispatcher's circuit (a real, read topic) or dead-letter naming the dispatch id. Never escalated, never re-posted past the worker's death.

Questions the other way (worker → orchestrator) can go through the sidecar to the dispatcher's circuit, but each question must carry its return coordinates — dispatch id, attempt, nonce, and per condition 1 the dispatcher session id — in the payload, because the answer's destination is the record, not any inbox.

Polling cost is real (a worker polls a hub for its whole run); acceptable now, with the deferred notice layer as a later push *hint* while polling stays the source of truth.

## 5. Biggest risk of agreeing now

Committing the ownership split before terminal-state semantics are specified: precedence of `done` vs `lost`, zombie-session recovery, hub-assigned attempts, nonce atomicity. Two parties would then build halves that meet at an undefined seam — precisely the shape of 1c and T-3042, where each side was locally correct and the seam erased dispatches. I want those four points, plus the record schema (answers section, attempt-bound hashes), settled in the build task text before any code.

## 6. Overall

**Agree, with conditions**: the draft four (2 and 3 tightened as above), plus (5) done/lost precedence with a late-evidence upgrade path, (6) answer TTL ≤ worker lifetime with bounce-to-dispatcher instead of ladder escalation, (7) hand-back schema and hash rules owned by the contract, not by AEF's template, (8) one conformance test shared by hub and local fallback, and (9) migration of `record-outcome`/outcomes.jsonl consumers. Not "not yet": T-3977 already commits AEF to taking S-1 piece by piece, and the gaps are spec holes in a sound design, not design flaws.

(≈1,050 words)
