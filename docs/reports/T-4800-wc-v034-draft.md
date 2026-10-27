# T-4800 — Shared worker contract v0.3.4 (DRAFT, pending adoption)

**Status:** draft for adoption by the AEF operator, TermLink's operator (their T-3484) and ring20.
Nothing here is in force until all three adopt it; v0.3.3 stays the agreed text until then.
**Version field:** stays `wc/0.3`. This is a patch revision (§2): one clarification of an order every
implementation already uses, and one optional backend behaviour that a backend which never closes a
dispatch does not see.

**Spec:** `docs/specs/shared-worker-contract-transitions.md` (new section "Changelog v0.3.3 → v0.3.4").
**Vectors:** `tests/conformance/worker-contract/vectors.yaml` (header says v0.3.4 draft).

## Sources

- ring20: msgs 59742ea8, e93a0367, 4b03810f. Their mechanical runner on be.31 failed CC-15 and CC-19 on
  one step: ring20 closes a dispatch after a resolve-as-lost or a paused end, so its next allocate is
  refused, and the spec never offered that answer. Their T-2544 adapter derives `refused` before the
  hand-back check.
- TermLink, implementation side: msg 14d0100a. No objection to either item. Their hub never closes a
  dispatch, and `worker_contract.rs:605-628` already puts refusal ahead of the hand-back check.

## What changed

### 1. Refusal before rule 1 (§3.3 outcome derivation)

Rule 1 (hand-back missing or malformed → `handback-malformed`) now says it applies **to a worker that
ran**. Rule 2 (run.sh or supervisor refusal → `refused`) applies **even with the hand-back absent**:
a refused worker never ran, so it never owed a hand-back. The rules keep their numbers, so every
"rule N" reference (CC-16, the §3.3 backend-stop paragraph, CC-25) still holds.

Why: read literally, v0.3.3 checks rule 1 first, so a refusal with no hand-back would come out
`handback-malformed`. That contradicts the CC-16 `supervisor-refusal` and CC-21 `refused-before-start`
vectors, TermLink's code and ring20's adapter, which all give `refused`. Text change only. No vector
changes.

### 2. Dispatch closure (optional) and `fence_reject(dispatch_closed)`

- **§2:** new optional dispatch-level field `closed: {actor, reason, ts}|null`, set once and never cleared.
- **§4.7 (new):** a backend MAY close a dispatch once its last attempt is terminal (`done` or `lost`;
  an `unknown` goes through T7d first). Closing is not a transition. It appends to no attempt's history
  and changes no state, outcome or result. T5, T7b and T8 on existing attempts are unaffected. After
  closing, the only way to continue is a new dispatch that names this one in `retry_of_dispatch_id`.
- **§3.3 T1:** the precondition adds "and the dispatch is not closed". A T1 on a closed dispatch is
  `fence_reject(dispatch_closed)`.
- **§3.3 `fence_reject`:** `dispatch_closed` is added to the closed reason list. Unlike `cas_mismatch`
  it is final. A backend that never closes a dispatch never returns it.
- **§8.4:** a closed dispatch whose last attempt is `paused` is **never counted as resolved work**. It
  stays in the pause queue until a re-dispatch names it, and consumers still refuse the paused attempt
  as not finished work.
- **§9 CC-15 and CC-19:** the Then clause accepts either T1 (A2 allocated) or
  `fence_reject(dispatch_closed)` with no A2.

A hub that keeps dispatches open (TermLink) is unaffected and stays conformant without changes.

## How the vectors express it

The closed answer is accepted **only on a declared equivalent route** (the T-4793/T-4796 mechanism):

- CC-15's final allocate moves into a variant `allocate-after-resolve`, and CC-19 `next-attempt` gets
  the same treatment. Each variant carries `equivalent:` text and its allocate step carries
  `expect_equivalent: {fence_reject: dispatch_closed}`.
- New variant key `then.final_equivalent` replaces `final` on that route. `A2: null` means the attempt
  must not exist. `admissible_histories_equivalent` drops A2.
- The plain path still requires `accepted: T1`. A backend that answers `dispatch_closed` without
  declaring the route fails, and so does one that answers `cas_mismatch` on either path.
- `check_vectors.py` refuses `dispatch_closed` in a plain `expect`, so no vector can require closure
  of a hub that keeps dispatches open. It also refuses `final_equivalent` outside a variant that offers
  an equivalent.

## What a backend needs to do

- **TermLink (hub):** nothing. CC-15 and CC-19 run on the plain path as before.
- **ring20:** declare `CC-15/allocate-after-resolve` and `CC-19/next-attempt` in
  `adapter.equivalent_routes`, and return `"equivalent": "<what ran>"` in every step result of those
  two variants, as it already does for the CC-08/CC-16/CC-21 routes.
