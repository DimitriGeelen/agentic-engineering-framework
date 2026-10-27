# T-4801 — Local backend for the shared worker contract: scope and sequence

Inception research artifact. The decision is the operator's.

## Question

AEF owns the shared dispatched-worker contract (wc/0.3.x) and its conformance vectors, yet it cannot run them. `tests/conformance/worker-contract/run_local.py` (T-4520) looks for `lib/dispatch_records.py` and its `conformance_adapter()`. The file does not exist, so every case reports not-implemented. ring20 passes 19 cases mechanically, and TermLink implements the contract in Rust (`crates/termlink-bus/src/worker_contract.rs`).

## Finding 1: the build is already approved; what is open is its sequence

T-4435 (GO, 2026-10-20) decided that AEF owns the contract, under conditions agreed with TermLink and ring20. Three of them bear on this question:

- **Condition 1:** first a jointly agreed transition table, plus one conformance suite run against the hub backend **and AEF's local backend**. No implementation before that.
- **Condition 3:** a local backend with the same CAS semantics, chosen at dispatch time, run against the same conformance suite.
- **Condition 4:** the record replaces only the completion authority. The evaluation ledger stays separate, and shadow mode runs before switch-over.

The GO covered "the ownership plus a spec-first first slice, not code". That first slice is done: spec v0.3.3 is agreed (TermLink agrees, and ring20 signs v0.3.1), and the vectors run mechanically against ring20. The no-implementation-before-agreement precondition is therefore met. T-4801 does not reopen whether to build. It asks in what order to build, and how far to go before the operator looks again.

## Finding 2: the spec already designs the store (§6)

- **§6.1:** the local backend implements every §3 row with the same CAS and fencing, and the same §9 suite runs against it.
- **§6.2:** one JSON file per dispatch at `.context/dispatch-records/<dispatch_id>.json`. Every write takes an exclusive `flock` on `<dispatch_id>.lock`, then reads, checks the nonce, `supervisor_gen` and the expected prior state, applies the change, writes a temp file, fsyncs it, renames it over the record, fsyncs the directory, and releases the lock. The lock times out after 10 s and fails closed (`cas_mismatch`-class).
- **§6.3:** `lost` comes from a local liveness probe (pid plus start-time identity) together with the absence of completion evidence, after the grace period G. An undecidable probe gives `unknown` (T6), never `lost`.
- **§6.4:** the backend is chosen at dispatch creation, recorded, and never switched mid-flight.
- **§6.5:** durable local evidence (exit_code, hand-back, signed completion, persisted_at) is written before any terminal write.

The adapter surface is fixed by `run_local.py` and the vectors' `ops:` list: create, allocate, start, complete, reclaim, confirm_end, sweep, probe_undecided, advance, stop, resolve, the answer ops (§5), dispatcher_lost/adopt, hold_lock, concurrent, wait, consume and inspect.

## Finding 3: what exists today

`fw termlink dispatch` already has the evidence half:
- run.sh writes `exit_code`, `close_state`, `result.jsonl` and `stderr.log` into the worker dir;
- the watchdog now escalates to SIGKILL (T-4776);
- `.context/dispatches.jsonl` and `dispatch-outcomes.jsonl` hold the evaluation ledger, which condition 4 keeps separate.

There is no per-dispatch record with CAS, no attempts or nonces, no transition table, and no sweep. None of the §3 state machine exists locally.

## Options

| Option | What it builds | What it proves | Risk |
|---|---|---|---|
| A. Store + adapter only | `lib/dispatch_records.py`: the §6.2 store, the §3 transitions, and `conformance_adapter()` with an injected clock and probe | The vectors are passable by AEF's own implementation, and they stay honest: AEF can catch its own vector mistakes before peers do | Low: nothing in fw termlink dispatch changes |
| B. A, then shadow-write | A, then `fw termlink dispatch` / run.sh also write the record in shadow, with the ledger still authoritative | The record matches reality on live workers (condition 4's shadow mode) | Medium: touches the dispatch path; it shadows, so it decides nothing |
| C. A + B + switch-over | Completion authority moves to the record | AEF's workers are contract-conformant end to end | High: changes how every dispatched worker is judged; an operator decision after shadow evidence |

## Recommendation (draft)

**GO for option A as the next slice. B is a follow-up after A is green. C is a separate operator decision after B's shadow evidence**, matching T-4435 condition 4.

A is bounded: one module plus its adapter, judged by the existing vectors. The answer-channel cases (CC-11, CC-12) and anything requiring a real worker can stay n/a or not-implemented for A. It closes the visible gap: the contract's owner can show its own implementation passing its own suite. It also gives the vectors a second independent implementation, besides ring20's adapter, to catch mistakes in them.

## Dialogue Log

- 2026-10-27: the agent proposed this exploration ("AEF owns the vectors but is the only party that can't run them"). The operator said "go ahead".
- 2026-10-27: research found T-4435's GO, which already covers a local backend under conditions 1, 3 and 4. The inception was reframed from "whether" to "which slice next".
