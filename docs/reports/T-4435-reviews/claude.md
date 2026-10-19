# Anthropic claude -p (no tools, no MCP) — 2026-10-20 — review of T-4435 bundle

# Review: T-4435, shared dispatched-worker contract

**Reviewer basis:** the bundle only. I ran no code. Where I cite a line, it comes from the excerpts.

## 1. Is the contract sound?

The structure is sound, but the state machine is under-specified in three places that will bite.

**a. `done` and `lost` race, and no precedence is stated.**
- run.sh runs *inside* the worker's TermLink session (termlink.sh:1675-1700), so the supervisor shares the worker's fate.
- Ordinary sequence: run.sh writes `exit_code` locally, its hub write of `done` is in flight, the session ends, and the hub writes `lost`.
- If the network or hub blips, the hub may hold `lost` while durable local evidence (`exit_code`, signed `finalised`) says it finished.
- **Fix:**
  - Every transition is a compare-and-swap from an expected prior state.
  - `done` with fenced evidence outranks `lost`, in the same way direct.py ranks HANDED_OVER above ESCALATED.
  - An AEF-side reconciler may upgrade `lost → done` from the local worker dir.
  - Without this, last-writer-wins (T-3960 1c) moves to the hub instead of being removed.

**b. A stuck `running` state is guaranteed under partition or hub restart.**
- "Lost only on confirmed session end" leaves no exit when confirmation is impossible:
  - the hub restarts and loses its session registry;
  - the worker host reboots;
  - the remote hub is partitioned.
- Avoiding heartbeat-based `lost` is right. But there must be a third, operator-visible state (`unknown` / `stale`) after a bounded silence, plus a resolution verb. Otherwise records sit in `running` forever and `worker wait` hangs.

**c. Fencing protects the record, not the world.**
- (dispatch id, attempt, nonce) stops a zombie attempt 1 from writing *status*.
- It does not stop attempt 1 from committing to the main checkout. Worktrees are opt-in, so workers share bleeding-edge.
- If attempt 2 can start before attempt 1 is confirmed ended, the result sha is ambiguous.
- **Rule needed:** a new attempt is issued only after the prior attempt is terminal (`done`, `lost`, or operator-resolved `unknown`).
- The contract must also say **who allocates attempts and nonces**. It should be the hub, atomically. If two dispatchers can both mint "attempt 2", the fence is decorative.

**Smaller gaps:**
- **`done` conflates "stopped" with "succeeded".** It needs an outcome field: succeeded / failed / refused (run.sh `exit 3`) / hand-back-malformed.
- **"Result is a commit sha"** does not cover a worker that makes several commits or none. Use a commit range, or the hand-back sha256 that names the commits.
- **The nonce sits in the worker's prompt.** That is fine against stale attempts, not against forgery. Say so explicitly, as AEF already does for the review-dispatch HMAC.
- **Retention is not optional.** Rejecting old attempts requires keeping them. Fence correctness depends on it, so retention cannot be deferred.

## 2. Is the ownership split right?

Mostly right.

**Correctly placed:**
- AEF owns run.sh, the instruction and the hand-back parsing.
- TermLink owns the ledger, `wait`, lookup and the hub-side `lost`. The hub is the only party outside the session's fate.

**Should move or be stated:**
- **Attempt and nonce allocation** belongs to TermLink, as the CAS owner.
- **Session ↔ (dispatch id, attempt) binding at spawn** belongs to TermLink. T-3960 1b shows the session name is a random `tl-<8>` not tied to dispatch_id, so today the hub could not know which record to mark `lost`. AEF must pass the binding; TermLink must persist it.
- **The reconciler** (local evidence → hub) belongs to AEF. It is the only party that can read the worker dir and `_worker_done`'s signed-completion logic (termlink.sh:787-803).
- **[REDACTED]** should only *conform*: contract test vectors, not a third implementation.

## 3. AEF's four conditions

**Condition 1 (record the dispatching session).** Right, but under-specified.
- Name the identifier. The claude session id changes on `claude -c` auto-restart and on compaction, while the TermLink `claude-master-<PID>` PTY persists.
- Recording it is for audit. It does not, on its own, give questions a route to the right session (the sidecar id is per project). See Q4.

**Condition 2 (answers through the fenced record).** Right. Keep it.

**Condition 3 (local-file fallback).** Right, but scope it.
- It needs the same CAS semantics (flock plus expected-state check), not just "same shape". A file without CAS reintroduces 1c.
- `lost` without a hub needs a local liveness source (`_runtime_alive`).
- Specify the contract as a schema plus shared conformance tests, so the two backends cannot drift.

**Condition 4 (replace last-writer-wins outcome writing).** Overreaches as written.
- `dispatches.jsonl.outcome` (completion) and `dispatch-outcomes.jsonl` (evaluation, backprop at task close: the 1,838 events behind the dispatch pass-rate table) are different facts with different times and writers.
- The record should replace the *completion* writer only. Evaluation stays a separate, append-only ledger keyed by (dispatch id, attempt, result hash).
- pi and ollama workers never touch the hub. "One source of truth" must hold for them through the local backend, or the ledger forks by worker kind.

**Missing conditions:**
- CAS plus precedence on every transition (Q1a).
- Bounded `unknown` state (Q1b).
- Hub-allocated attempts; no new attempt before the prior one is terminal.
- `done` carries an outcome field.
- A contract version field.
- Reconcile `attempt` with `retry_of_dispatch_id`. T-3960 2a: pause re-dispatch rows *resolve* the paused dispatch, and conflating the two would deflate the pause queue.

## 4. The answer path to a running worker

Make the record the channel in **both** directions. Use the sidecar only as a doorbell.

- **Questions.** The worker appends `question{cmd_id, text}` to its own attempt in the record.
  - A sidecar notice to the per-project agent carries only the dispatch id. No body, so nothing worth retrying.
  - The parent session that owns the dispatch (condition 1) reads the record.
  - A worker *sending* sidecar mail under the project id would make replies land in the project inbox, which is the orphan-inbox class T-4418 just closed.
- **Answers.** The parent CAS-appends `answer{cmd_id}` to that attempt. The worker polls through a blocking, bounded verb (e.g. `fw worker ask --wait 10m`) and acks per cmd_id. That gives dedupe for free, which retry_ladder.py says every consumer must do.
- **No ladder for worker-addressed messages.** Delivery lifetime is bounded by attempt lifetime:
  - When the attempt goes terminal, unacked answers become `undelivered` on the record and surface to the parent.
  - When the bounded wait expires, the worker should end with `status: paused`, and the answer rides into **attempt N+1's instruction**. That reuses the existing pause mechanism (T-1809).
- **Default to pause-and-redispatch; in-run polling is the fast path.** `claude -p` workers cannot reliably wait an hour mid-turn.

## 5. Biggest risk, and what to settle first

**Biggest risk:** agreeing to condition 4 ("replace") commits AEF's completion truth to a hub primitive whose behaviour under restart and partition is not yet specified. Failures would show up as stuck `running` or false `lost`. Both corrupt the pass-rate data that CLAUDE.md tells agents to consult before dispatching: the false-green or false-red class AEF has paid for repeatedly.

**Settle before the build task:**
1. A written transition table: states, writers, expected-prior CAS, precedence, and the `unknown` exit.
2. Attempt and nonce allocation, and the no-overlapping-attempts rule.
3. Hub durability semantics: what survives a hub restart, and how retention interacts with fencing.
4. The answer path as in Q4.
5. Session ↔ dispatch binding at spawn (1b).

## 6. Overall

**Agree with conditions.**
- Accept the ownership split, plus the TermLink additions in Q2.
- Keep conditions 1–3, with the sharpening above.
- Narrow condition 4 to "replaces the completion writer; evaluation stays separate."
- Gate the AEF build task on an agreed transition table with conformance tests run against both the hub backend and the local-file backend.
- Until the table exists, run the shared record **beside** `update_outcome_row` in shadow mode and compare. Switch over only when the two agree on real dispatches.

The draft is right in spirit. Its weakest point is treating "single writer" as sufficient. It isn't: two writers (supervisor and hub) exist by design, so precedence and CAS are what actually make it safe.
