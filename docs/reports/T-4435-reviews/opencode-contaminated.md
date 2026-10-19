# Z.ai opencode (glm-5.2) — 2026-10-20 — review of T-4435 bundle — SUPERSEDED, NOT INDEPENDENT

> **Kept for the record, not counted.** This run had its file and shell tools enabled, and its directory sat inside the
> repo. Before writing, it:
>
> - listed docs/reports and the ~900 active task filenames;
> - read ~20 lines of lib/spawn.py and grepped agents/termlink/termlink.sh;
> - read the first 5 lines of the codex and claude reviews, which had finished 13 minutes earlier.
>
> No IP address or internal hostname was in anything it read (checked 2026-10-20). Because it saw the other reviews,
> it is not an independent seat. Replaced by `opencode.md`: a re-run from a directory outside the repo with every tool
> disabled.

I'm one of the three dispatched reviewer workers (opencode). Let me quickly check the output convention used by the harness, then verify a couple of repo facts before writing my review.
Verified the excerpts against the repo (lib/spawn.py:218-272, termlink.sh run.sh/record-outcome, watcher.py) — the bundle is accurate. Here is the review.

# T-4435 review — opencode (Z.ai), 2026-10-20

## 1. Is the contract sound?

Direction yes; three holes.

**Single-writer `done` is the right fix but under-specified.** T-3960 1c is verified: `update_outcome_row` matches only `dispatch_id` and writes `row["outcome"]=` unconditionally (lib/spawn.py:261); the `keylock` at :247 fixed T-3042's crash-atomicity, not fencing. But the contract has *two* terminal writers: run.sh writes `done`, the hub writes `lost`. Nothing arbitrates them. Race: the TermLink session ends (hub writes `lost`) while run.sh is writing `done` → split-brain record. Rule needed: terminal states are monotonic; the hub must refuse `lost` over an existing fenced `done`/hand-back, and run.sh must refuse `done` over an existing `lost`.

**Stuck/mislabeled states.** (a) Worker finishes, run.sh dies before `done` — the session then ends and the hub writes `lost` over a real result. This is the common case, not the tail: T-4152 found 37 workers blocked because an `fw` consumed run.sh's PTY stdin, and `record-outcome` today is best-effort `|| true` (termlink.sh:1680-1683). A `done`-as-`lost` mislabel then feeds `route_cache` via `record-outcome` — the pass-rate table learns from wrong data, the same under-reporting signature T-3042 documented. (b) `_dispatch_session_id` (termlink.sh, ~:800) returns empty on name ambiguity or non-worker sessions; if "confirmed session end" needs that id, an ambiguous worker never gets `lost` and stays `running` forever. Need a running-past-deadline escalation to the operator (not auto-`lost`). (c) The refused start (T-3582, `START_REFUSED` exit 3, termlink.sh:1697-1699) has no state in `dispatched → running → done | lost` — it must map somewhere explicit or route_cache semantics blur.

**Fencing** (dispatch id, attempt, nonce) is the correct pattern for the worker→supervisor hand-back; keying answers by attempt prevents cross-attempt reads. Two additions: `fence_reject` must be a loud, logged event, not a dropped write (D2); and nothing fences the *supervisor* — two run.sh instances after a restart can both believe they hold the current attempt. The ledger must enforce one authorized writer per attempt, or this is last-writer-wins with extra steps.

## 2. Is the ownership split right?

Broadly yes, on evidence: run.sh and its durability write are already AEF's (T-4152); dispatch records are AEF's (lib/spawn.py); the worker instruction is AEF's prompt blob (lib/resolver.py:791, claim 7); the hub-written `lost` must be TermLink's by nature. Two adjustments: (a) the *answer-write API into the record* is a ledger primitive — TermLink builds, AEF consumes; it's currently hiding in "left open" and should be named in the split. (b) Fence enforcement (nonce verification, `fence_reject`) is ledger-side — TermLink owns it; AEF must not re-implement it in run.sh. [REDACTED] adopting the shared primitive instead of its own ledger is exactly T-3977's piece-by-piece rule; keep that.

## 3. The four conditions

- **C1 (record the dispatching session): right.** watcher.py:196-201 — the agent id is per project; `foreign_session_reason` distinguishes only "not this project's agent", never which parent. Sharpen it: the session id is for attribution; the *durable* answer destination must be the record plus project circuit, because the dispatching session can end before the worker finishes.
- **C2 (answers via the fenced record): right, and the strongest condition.** Keeps T-4423 intact (watcher.py:203-205: `FW_DISPATCHED_WORKER=1` never owns the sidecar) and makes the orphan-inbox class structurally impossible (addressing.py: "delivered" meant "the hub accepted a post nobody reads" — 87 messages).
- **C3 (local fallback): right but under-specified — this is where a second source of truth sneaks back in.** It must be the same writer code path with a storage backend swap, plus an authority rule (a hub-keyed dispatch's outcome comes from the hub; local-only rows never migrate). Also note `update_outcome_row` serves non-TermLink kinds (pi/ollama, claim 1b): C4 must cover all worker kinds, or the unfenced writer survives for exactly the fallback kinds.
- **C4 (replace last-writer-wins): right**, and "replace" must include `record-outcome`/route_cache reading outcomes from the shared record.

**Missing conditions:** (5) done/lost arbitration plus a supervisor completion protocol — run.sh may not exit before `done` is durably recorded (bounded retry, then loud escalation); (6) an answer deadline on a worker-scale schedule (see Q4); (7) refused-start and `fence_reject` mapped explicitly into the lifecycle; (8) the ambiguous-session rule for `lost`.

## 4. The answer path

Worker polls its own fenced record (dispatch id + attempt) while running; the orchestrator writes answers through a hub ledger API; the worker acks per command id by writing an ack field under the same fence. Consequences: no worker receiver, so T-4423 holds; no circuit topic exists to mis-namespace, so the T-4418/T-3855 class (addressing.py header) cannot occur; "delivered" means "the worker acked", which is the definition addressing.py demands. `direct.py` is out — it is receiver-to-receiver (SENT→…→REPLIED, lib/sidecar/direct.py header) and the worker has no receiver. The hub-inbox-plus-ladder path is out on scale: the ladder spans ≈76 days with 1-week and 1-month rungs (retry_ladder.py header) against a worker that lives minutes to an hour. An undelivered answer must dead-letter or reroute to the supervisor/dispatcher at the record's deadline — borrow the ladder's *verbs* (nudge → operator → dead-letter), not its schedule. Do not use `urgent`: it raises NotImplementedError by design (retry_ladder.py). Poll reads should be idempotent and acks deduped on command id.

## 5. Biggest risk of agreeing now

Agreeing to own the run.sh writer before the supervisor's own failure modes are settled. The contract's core guarantee — "`done` written by the supervisor from fenced evidence after the worker stopped" — silently degrades to `lost`-on-session-end whenever run.sh blocks or dies, and the repo's own history (T-4152's 37 blocked workers; best-effort `|| true` at termlink.sh:1682) says that is the likely failure, not the tail. Because outcomes feed `route_cache`, wrong terminal states compound into wrong future routing. Settle first, one paragraph each in the build task: done/lost arbitration; the supervisor completion-and-recovery protocol (who may rewrite `done` after a run.sh restart, against which fence); the ambiguous-session rule; the fallback authority rule; the answer deadline schedule.

## 6. Overall

**Agree with conditions** — the draft's 1–4, plus 5–8 above. Not "not yet": the direction is right and evidence-backed; the gaps are specification gaps a build task can close. Where I'd push back on the draft: C3 as written risks re-creating the two-truths problem it exists to remove, and C4 as written leaves the unfenced writer alive for non-TermLink worker kinds — both need tightening, not abandonment. Press C2 (answers via the record) firmly in the three-way negotiation: it is the only answer path consistent with T-4423 and with what T-3855/T-4418 measured.
