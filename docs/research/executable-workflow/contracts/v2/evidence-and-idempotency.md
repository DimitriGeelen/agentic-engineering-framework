# EWCR v1 — Evidence snapshot/hash ordering and idempotency contract

**Task:** T-3387 · **Arc:** arc-019 (`ewcr-arc0-contract-evidence`) · **Freezes:** `architecture-c9070637.md` §2.5 (evidence is redacted, referenced and hashed *before* validation; accepted evidence is immutable; supersession is a new reference; "after interruption, resume sees the prior completed attempt and does not invoke it a second time"), §6.6.1 (artefact minimum and status set), §7.4 (duplicate timer evaluation is idempotent; failed attempts route only through declared retry/compensation; compare-and-append), §7.5 steps 7–10 (attempt start, dispatch with correlation + idempotency keys, validate outcome, record and advance), §13 scenarios 7, 9, 17, 18.
**Schemas referenced:** `evidence-reference.schema.json` (`content_hash`, `snapshot_ts`, `status`, `validation_refs`, `accepted_at`, `supersedes`), `attempt.schema.json` (`dispatch.idempotency_key`, `dispatch.correlation_id`, `sequence`, `output_ref`, `outcome_validated`), `transition-envelope.schema.json` (`idempotency_key`, `prior_position`, `admission`), `deadline-event.schema.json` (`evaluation_idempotency_key`, `status`, `superseded_by`), `refusal.schema.json` (`reason_code`).
**Responsible future components:** Arc 1 candidate 7 — *snapshot/hash evidence before validation and make accepted evidence immutable* (§1, §2 of this document); Arc 1 candidate 8 — *implement idempotent attempt, result, and compensation contracts* (§3). Roadmap `5be23719` §Arc 1. Nothing here is runtime; it is the contract those two components must satisfy, and the scenarios are the tests they must pass.

Scenarios are written Given / When / Then. "Refused" always means: a
`refusal.schema.json` record is appended with the named `reason_code`,
`side_effect: false`, and the instance stays at its current node.

## 1. Ordering invariant: snapshot → hash → validate → accept

Four distinct steps, in this order, each recorded as its own ledger event:

| Step | What happens | Field(s) it writes on the evidence reference | Who |
|---|---|---|---|
| 1 **snapshot** | The producer's output is redacted per policy and copied into the catalogue; the copy is what everything downstream refers to. | `content_ref`, `snapshot_ts`, `redacted` | runner (§7.5 step 9 entry) |
| 2 **hash** | `sha256` of the *snapshot* (the redacted copy, never the live output). | `content_hash` | runner, same event as step 1 |
| 3 **validate** | Each declared validator receives the reference **by hash** and returns a verdict keyed by that hash. | `validation_refs` (append) | validator under the node's profile |
| 4 **accept** | Status moves `proposed → accepted` only when every declared validator has a verdict for *this* `content_hash`. | `status`, `accepted_at` | runner |

Steps 1 and 2 are one atomic event: a reference never exists without a hash
(the schema makes `content_hash` and `snapshot_ts` required for that reason).
Steps 3 and 4 are separate events so that the ledger can prove *what* was
validated: the validation event carries the hash it validated, and the accept
event is admissible only if that hash equals the reference's `content_hash`.

**Invariant:** for any accepted reference, the ledger positions satisfy
`pos(snapshot+hash) < pos(every validation_ref) < pos(accept)`, and every
validation event cites `content_hash` verbatim. `accepted_at > snapshot_ts`
strictly.

**A hash computed after validation is a contract violation.** "After" has two
observable shapes, and both are refused:

| Observed | Why it is a violation | Refusal `reason_code` |
|---|---|---|
| A validator is invoked with, or a validation event arrives for, a reference that has no snapshot/hash yet (`content_hash` absent, or the validation cites a hash the ledger has never recorded for that `id`) | The validator ran over something the runner cannot identify; the verdict is not attributable to any evidence. | `unresolved_reference` — *detail:* "validation cites hash H for ev-X; no snapshot with hash H is recorded" |
| A proposal to set or change `content_hash` / `content_ref` / `snapshot_ts` on a reference that already has one, at any status | The snapshot is the identity of the evidence; changing it after the fact is a rewrite of a ledger fact, not a correction. | `direct_state_mutation` — *detail:* names `id`, old hash, proposed hash |
| A proposal to set `status: accepted` while some declared validator has no verdict for the current `content_hash` | The accept transition's typed input (one verdict per validator, keyed by hash) is missing. | `missing_typed_input` — *detail:* names the validator(s) without a verdict |

The three codes are drawn from the frozen enum; none is new. Arc 1 may find
`unresolved_reference` too coarse for the first row and propose a dedicated
*evidence_hash_mismatch* code — that is a `contracts/v2/` change (README fence),
not an edit to v1.

### Scenario 1.1 — validate-before-hash is refused

- **Given** node `run_script` of `wi-hsh-0001` has completed an attempt `att-hsh-001` whose worker posted raw output to the bus.
- **When** the worker (or a well-meaning adapter) invokes `validate.test-report.v1` directly on the bus blob and posts a validation event `{ev: "ev-hsh-out1", hash: "sha256:…live…"}` before the runner has snapshotted.
- **Then** the validation event is refused `unresolved_reference`; no `validation_refs` entry is written; the runner then performs snapshot+hash itself, producing `ev-hsh-out1` with `content_hash` H₁, and re-invokes the validator by hash. Only the verdict for H₁ is accepted.

### Scenario 1.2 — re-hashing after validation is refused

- **Given** `ev-0142-out3` has `content_hash` H₁, one validation event citing H₁, `status: proposed`.
- **When** any actor proposes `content_hash: H₂` for `ev-0142-out3` ("the report was regenerated").
- **Then** refused `direct_state_mutation`; `ev-0142-out3` keeps H₁; the regenerated report, if wanted, is snapshotted as a *new* reference (§2).

### Scenario 1.3 — accept without a hash-matched verdict is refused

- **Given** `ev-0142-out3` with H₁ and a validation event citing H₀ (an earlier, superseded snapshot of the same worker output, recorded under a different `id`).
- **When** the runner is asked to advance the edge that requires `ev-0142-out3` accepted.
- **Then** refused `missing_typed_input`; the instance stays at `run_script`; `recovery_requirement` = "run `validate.test-report.v1` against H₁".

## 2. Immutability and supersession

**Content is immutable from the snapshot.** `id`, `type`, `schema_version`,
`content_hash`, `content_ref`, `snapshot_ts`, `redacted`, `producer`,
`declared_inputs` are fixed at snapshot and never rewritten at *any* status —
a draft with different content is a different reference. What moves is
**status**, along the schema's set, in this order only:

```
draft → proposed → accepted → superseded
                 ↘ rejected
```

Once **accepted**, the reference is closed: `validation_refs` and `accepted_at`
are frozen too. The only admissible later events are (a) appending a
`decision_refs` entry — a pointer to a decision *about* the evidence, which
changes nothing about the evidence — and (b) the supersession transition
below. Any other write to an accepted reference, including removing a
`decision_refs` entry, is refused `direct_state_mutation`.

**Supersession is a new reference, never an edit.** To replace accepted
`ev-A`:

1. Snapshot+hash the new content as `ev-B` with `supersedes: ev-A`.
2. Validate `ev-B` by its own hash (§1 applies in full — `ev-A`'s verdicts do not carry over).
3. The accept event for `ev-B` **atomically** sets `ev-A.status: superseded`. `ev-A` keeps `content_hash`, `accepted_at`, `validation_refs` unchanged (the schema still requires `accepted_at` on a superseded reference for exactly this reason).

Rules: `supersedes` must name a reference in status `accepted`. Naming a
reference that is `draft`/`proposed`/`rejected` is refused
`unresolved_reference` (nothing accepted to supersede); naming one that is
already `superseded` is refused `stale_position` — the proposer is working
from an out-of-date view of the chain and must re-read the current head.
Chains are linear: at most one accepted-or-superseded reference names a given
`ev-A` in `supersedes`. Resolving "the current `test_report` for `wi-0142`"
returns the head of the chain; the trace (§13 #10) renders the whole chain.

### Scenario 2.1 — accepted evidence cannot be rewritten; it is superseded

- **Given** `ev-0142-out3` is `accepted` with H₁ and `accepted_at` T₁ (the committed example `examples/evidence-reference.json`).
- **When** the producing agent re-runs the tests and posts a proposal to update `ev-0142-out3` to the new report (`content_hash: H₂`).
- **Then** refused `direct_state_mutation`, `side_effect: false`. **When** the agent instead proposes `ev-0142-out4` with `supersedes: ev-0142-out3`, H₂, its own validation event citing H₂, **then** `ev-0142-out4` is accepted and in the same ledger event `ev-0142-out3.status` becomes `superseded` with H₁, T₁ and its `validation_refs` intact. The committed example `examples/evidence-reference-superseding.json` is this `ev-0142-out4`, and validates against the frozen schema.

### Scenario 2.2 — superseding a stale head is refused

- **Given** the chain `ev-A (superseded) ← ev-B (accepted)`.
- **When** an actor whose last read predates `ev-B` proposes `ev-C` with `supersedes: ev-A`.
- **Then** refused `stale_position`, `expected_position` pointing at the `ev-B` accept event; the actor re-reads and proposes `ev-C` with `supersedes: ev-B`, which is admitted.

### Scenario 2.3 — rejected evidence is immutable too

- **Given** `ev-0142-out2` is `rejected` (validator verdict negative).
- **When** the producer proposes to edit its content "to make it pass".
- **Then** refused `direct_state_mutation`; the corrected output is snapshotted as `ev-0142-out3` (a new reference with `declared_inputs` unchanged); the rejected reference stays in the trace as the record of the failed run.

## 3. Idempotency keys

The runtime offers **at-least-once delivery with at-most-once effect**. Every
externally originated message that could cause an effect carries an
idempotency key derived from *what the message means*, not from when or by
whom it was sent, so a replay, a retry, a hub redelivery (§13 #14) and a
resume after restart (§13 #9) all compute the same key. The runner keeps one
dedupe index per key kind; a lookup hit returns the **original** record and
its ledger position, and appends a `duplicate_delivery` refusal
(`side_effect: false`, `detail` naming the original id) so the duplicate is
visible, never silent. The duplicate is *not* an error for the caller — the
caller gets the answer it would have got the first time — but it is a fact
the operator can see.

| Key | Formed from (sha256 over the canonical JSON of) | Written where | A duplicate must return |
|---|---|---|---|
| **attempt** | `instance_id`, `node`, `sequence`, `procedure_content_hash`, `task_content_hash`, `typed_inputs_ref`, `policy_decision.policy_ref` | `attempt.dispatch.idempotency_key` (and the same value on the attempt-start `transition-envelope.idempotency_key`) | the existing `attempt_id` and its current `exit_outcome`; **no second dispatch** |
| **result** | `attempt_id`, `content_hash` of the delivered outcome payload | the post-attempt `transition-envelope.idempotency_key` | the ledger position at which the result was first consumed; **no second post-attempt checkpoint, no second advance** |
| **compensation** | `instance_id`, `node`, the *failed* `attempt_id` being compensated, the compensation `action_ref` declared on the node | `attempt.dispatch.idempotency_key` of the compensation attempt (compensation is itself an attempt, §6.2 `compensate`) | the existing compensation `attempt_id`; **no second corrective action** |
| **deadline evaluation** (§13 #17) | `deadline_id`, `due_at` | `deadline-event.evaluation_idempotency_key` | the existing `fired_in_envelope`; **the `on_expiry_route` is not taken twice** |

Notes on the key material:

- `sequence` is in the attempt key so that a *legitimate* retry (the node's declared retry route, which increments `sequence`) gets a new key and is a new attempt, while a redelivered dispatch of the *same* sequence collapses to the original. Retry is a decision the runner records; redelivery is transport noise.
- `task_content_hash` is in the attempt key so that a dispatch replayed after the bound task changed does **not** dedupe against the pre-change attempt; it becomes a new proposal and the pre-dispatch checkpoint (`task-lifecycle-contract.md` §3.1) judges it.
- The result key includes the payload hash so a second delivery of the *same* result is idempotent, while a delivery for the same `attempt_id` with a *different* payload is a conflict, not a duplicate: refused `stale_position` with `detail` naming both hashes. Two different results for one attempt is the class of event an operator must see immediately.
- The compensation key is derived from the failed attempt, not from wall-clock or from who asked, so a human who triggers compensation from Watchtower and a runner that triggers it from the declared route compute the same key and only one corrective action runs.
- `due_at` in the deadline key means a proposal that would change `due_at` on a pending deadline cannot be a "re-evaluation": it is a new deadline that must `supersede` the old one via a declared route with its own admission, which is how §7.4 "never resets elapsed time" is enforced.

### Scenario 3.1 — duplicate attempt dispatch does not double-run (§13 #7)

- **Given** `wi-hsh-0001` at `run_script`, attempt key K computed from the pinned hashes and `sequence: 1`; the runner has appended attempt-start `att-hsh-001` and dispatched over TermLink with `idempotency_key: K`.
- **When** the hub redelivers the dispatch (or the runner restarts and re-folds the ledger, or a caller re-sends the same proposal), presenting key K again.
- **Then** the dedupe index hits `att-hsh-001`; no second registered-script invocation occurs; the caller receives `att-hsh-001` with its current `exit_outcome`; a `duplicate_delivery` refusal is appended naming `att-hsh-001`. The attempt count for `(wi-hsh-0001, run_script, sequence 1)` is exactly one.

### Scenario 3.2 — duplicate result delivery does not double-advance (§13 #7)

- **Given** `att-hsh-001` has ended `succeeded`; the worker's result (payload hash R) was consumed at ledger position P, the post-attempt checkpoint passed, and the instance advanced `run_script → gate_out`.
- **When** the same result (same `attempt_id`, same R) is delivered again.
- **Then** result key hits P; no second checkpoint runs; the instance is still at `gate_out` (not advanced twice, not re-entered); a `duplicate_delivery` refusal is appended naming P. **When** instead a result for `att-hsh-001` arrives with payload hash R′ ≠ R, **then** refused `stale_position`, `detail` = "att-hsh-001 already consumed with R at P; received R′", and the instance state is unchanged.

### Scenario 3.3 — duplicate compensation produces one corrective action (§13 #18)

- **Given** `att-hsh-002` (retry, `sequence: 2`) ended `failed`; the node declares compensation `action_ref: compensate.registered.example.v1`; the runner has entered `compensating` and started compensation attempt `att-hsh-c01` with key C derived from (`wi-hsh-0001`, `run_script`, `att-hsh-002`, `compensate.registered.example.v1`).
- **When** an operator presses "compensate" in Watchtower for the same failure while `att-hsh-c01` is in flight, or the runner restarts mid-compensation and re-folds.
- **Then** key C hits `att-hsh-c01`; no second corrective action starts; the proposer receives `att-hsh-c01`; `duplicate_delivery` refusal appended. **When** compensation is requested for an attempt that is not in `{failed, timed_out, cancelled}` (e.g. `att-hsh-001`, `succeeded`), **then** refused `scope_mismatch`. **When** compensation is requested on a node that declares none, **then** refused `unresolved_reference`.

### Scenario 3.4 — a deadline survives restart and fires once (§13 #17)

- **Given** deadline `dl-hsh-t1` (`kind: timeout`, `due_at` D, `status: pending`) admitted in envelope E₁ for `att-hsh-001`.
- **When** the runner restarts after D, folds the ledger, and its declared clock source reads > D; then, on the next tick, evaluates again.
- **Then** the first evaluation computes key (`dl-hsh-t1`, D), finds no hit, fires: `status: fired`, `fired_in_envelope` E₂, `on_expiry_route` taken once. The second evaluation computes the same key, hits E₂, and does nothing further. **When** any actor proposes `due_at: D + 1h` on `dl-hsh-t1`, **then** refused `direct_state_mutation` — a longer budget is a new deadline `dl-hsh-t2` with `superseded_by` set on `dl-hsh-t1` through the declared extension route, and elapsed time is never reset.

## 4. Acceptance-scenario mapping (arch §13)

| # | Scenario | Section here | Component | Expected refusal / outcome |
|---|---|---|---|---|
| 7 | Duplicate remote result is idempotent and cannot double-run or double-advance | §3.1, §3.2 | Arc 1 cand 8 | attempt key → one execution; result key → one advance; conflicting payload → `stale_position` |
| 9 | Resume uses a durable, redacted execution envelope with precise provenance | §1 (redaction at snapshot), §3.1 (resume re-folds and dedupes) | cand 7 (snapshot), cand 8 (dedupe) | resume sees `att-hsh-001` via key K and does not re-invoke (§2.5 "continuity is safe") |
| 17 | A recorded deadline survives runner restart and cannot fire twice or reset its budget | §3.4 | cand 8 (with Arc 1 cand 5, durable deadlines) | evaluation key → one firing; `due_at` change → `direct_state_mutation` |
| 18 | Cancellation during an in-flight attempt … routes only through declared reconciliation | §3.3 | cand 8 (with cand 6, cancellation) | compensation only for a declared `action_ref` and only against a terminal-failed attempt; `scope_mismatch` / `unresolved_reference` otherwise |
| 10 | A completed instance renders a visual trace plus linked … evidence | §2 (chains are linear, superseded references retained) | cand 7 (data), Arc 4 (rendering) | trace shows every reference in the chain with its status; nothing is deleted |

**Explicitly out of Arc 0 scope for this contract** (owned elsewhere): 1, 2
(ratification / reference resolution — T-3385 `procedure`), 3, 5, 11, 13, 16,
20 (task binding and revalidation — T-3386), 4, 6 (script scope, component
measurement), 8, 12, 14, 15 (provider capability, identity, hub enumeration,
policy drift), 19 (racing proposals — the ledger compare-and-append contract;
this document *uses* `stale_position` but does not define admission order).

## 5. What the responsible components must expose

For the headline mechanic (operator picks an invariant → sees contract →
refusal scenario → component → executable fence):

**Arc 1 candidate 7** must ship:

1. `snapshot(content, producer, redaction_policy) → EvidenceReference` — pure over its inputs, returns `content_hash` and `snapshot_ts` in the same value; there is no API that yields a reference without a hash.
2. `validate(ref, validator_ref) → ValidationEvent{hash}` where the event carries `ref.content_hash` and the runner refuses to record an event whose `hash ≠ ref.content_hash` (`unresolved_reference`).
3. `accept(ref, validation_events) → ref'` refusing `missing_typed_input` unless every declared validator has an event for `ref.content_hash`.
4. `supersede(new_ref, old_id)` — one ledger event, `stale_position` when `old_id` is not the chain head.
5. A fixture per scenario in §1 and §2, each producing the named `reason_code` validated against `refusal.schema.json`; plus the property test: *for every accepted reference in the fixture ledger, snapshot position < every validation position < accept position.*

**Arc 1 candidate 8** must ship:

1. `attempt_key`, `result_key`, `compensation_key`, `deadline_evaluation_key` — pure functions over the field tuples in §3, pinned by tests that change each field and assert the key changes, and permute nothing-that-matters (delivery time, sender) and assert it does not.
2. A dedupe index with `lookup(kind, key) → original record + position | miss`, and the rule that a hit appends `duplicate_delivery` and never dispatches.
3. The double-dispatch test: dispatch twice with key K, count one registered-script execution (the T-3388 fixture `procedure-human-script-human.json` is the procedure to run it against).
4. The conflicting-result test: two payload hashes for one `attempt_id` → one consumed, one `stale_position`.

Until those components exist, this document is the only artefact; the fence
is `tools/ewcr-contracts-check.py` (schema side), the committed superseding
example (`examples/evidence-reference-superseding.json` validates and names
`supersedes`), and this task's Verification (every `reason_code` named above
is in the frozen enum; every scenario has Given/When/Then).
