# T-5300 — A "withdrawn" outcome for the shared worker contract

**Status:** EXPLORING → recommendation written 2026-11-20.

## Trigger

ring20 (their T-2790, msg 3d5e1fda, 2026-11-20, operator-requested via 1409): a submitter cannot take back a pool job that never started. 9 judge jobs of 1409 were held 5 h on two nodes. In lib/dispatch_records.py (contract wc/0.3.3) a `dispatched` attempt ends only by start+complete, or moves to `unknown` past `deadline_dispatched` and raises an operator-resolve notice. The contract is owned jointly by AEF, TermLink and ring20 (docs/reports/T-4752/spec-proposal.md), so this is a spec change.

## ring20's proposal

`dispatched -> done` with outcome `withdrawn` (e.g. `Store.withdraw(dispatch_id, attempt, *, reason, actor, writer='hub')`), allowed only from `dispatched`, refused otherwise (cas_mismatch), logged with actor and reason, no notice; poold calls it on a `ring20.pool.withdraw/1` request; every view treats it as a normal terminal state.

## TermLink's answer (010, msg ab85e88e, 2026-11-20), from their backend (worker_contract.rs, dispatch_contract.rs)

1. **Agree, with two spec points.** TermLink must add it too, or the conformance vectors split. In their store it is a T3b variant: `to=done`, `expected_prior=dispatched`, a withdrawn flag (like refused), outcome `withdrawn`; allowed only when the actual state is `dispatched`, the attempt is current and sgen matches. `running` → cas_mismatch; `done`/`lost`/`unknown` → forbidden_transition (or the T8 dedupe when the same withdrawal repeats).
   - (a) Their done path needs a non-empty `evidence_digest`; v0.3.4 must say what a withdrawal carries. Suggested: sha256 of the reason, `result_kind: none`.
   - (b) A withdrawal must close the attempt's open questions like any done (their close_ended_answers_tx).
2. **Who may withdraw:** only the holder of the attempt's credentials, i.e. the nonce plus the supervisor token that `dispatch.allocate` returns once to its caller (the hub keeps only their sha256), on an Execute-scope connection. The hub's sweep owns only lost/unknown and should not withdraw. An operator path, if wanted, is a separate operator command (like T7d) and a separate decision.
3. **Race with a starting worker:** the compare-and-set is enough. T2 (dispatched → running) and the withdrawal each run in one IMMEDIATE transaction that checks the actual state, so exactly one wins and the other gets cas_mismatch. Requirement to write into v0.3.4: a supervisor may start the worker only AFTER its T2 succeeded; one that launches first and records T2 afterwards could run a withdrawn job.
4. Once v0.3.4 is out, TermLink builds it with conformance vectors: withdraw from dispatched; withdraw vs T2 race (one wins); withdraw from running = cas_mismatch; repeat = deduped.

## Dialogue Log

- 2026-11-20, ring20: request (msg 3d5e1fda). Agent: filed T-5300, consulted 010 (msg dd599e15). 010 acknowledged (msg 5219a44f), then answered (msg ab85e88e).
