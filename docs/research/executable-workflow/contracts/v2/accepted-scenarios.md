# EWCR v2 — Acceptance scenarios accepted after §13 was frozen (N-1, N-2)

**Task:** T-5179 · **New in:** contracts v2 · **Source:** T-5135
(`docs/reports/EWCR/T-5135-deepseek-mistral-dispositions.md`, rows DS-1 and MS-3) ·
**Accepted by:** the operator, 2026-11-16 ("yes" to operator decision 1 of that report).

Architecture `architecture-c9070637.md` §13 lists twenty acceptance scenarios and is not
renumbered here. The two scenarios below are additional and carry their own ids, **N-1**
and **N-2**. Their statements are the ones proposed in `refusal-threat-matrix.md` §5.1,
unchanged. A future engine must pass all twenty §13 scenarios and these two.

Each scenario has the same three parts: the situation, the required behaviour, and a
pass/fail test. This is a specification. No runtime code exists for it yet, and each
scenario names the roadmap arc candidates that must carry its test.

---

## N-1 — a task cancelled or changed during an attempt does not advance the instance

**Statement:**
> Bound-task mutation or cancellation occurring *during* an in-flight attempt — not only between gates — is detected before that attempt's result is admitted; a result whose execution began before a cancellation cannot advance the instance.

**Source finding:** DS-1 (DeepSeek, blocker, high confidence).
**Responsible components:** Arc 1 cand 3 (pre-dispatch and post-attempt task revalidation),
with cand 6 (attempt-boundary cancellation) and cand 8 (attempt boundary).

### Situation

An instance is bound to a task. The pre-dispatch checkpoint passed, the attempt-start
envelope is appended, and a registered script is running. While it runs, the bound task is
cancelled, or one of its authority fields changes (`owner`, the acceptance-criteria digest,
a `last_update` rewind, or the task leaving `active/`; see `task-lifecycle-contract.md`
§2 and §3). The script then finishes and reports success.

§13 #13 covers a change "between gates" and §13 #18 covers the effect of a cancellation
that has been observed. Neither says that the change must be observed when it happens
inside an attempt. That window is where a long-running script lives.

### Required behaviour

1. The task is re-read and compared with the binding after the attempt's result arrives
   and before the result is admitted to the instance. A comparison made before the
   attempt started does not count for this.
2. If the task was cancelled after the attempt started, the result is refused
   `cancellation_in_effect`. If an authority field changed, the result is refused
   `task_hash_drift`, and `detail` names the field. If the task no longer resolves in
   `active/`, the result is refused `scope_mismatch`.
3. The attempt keeps its own outcome (`attempt.exit_outcome` stays what the script
   returned). The instance stays at its current node and does not take the outgoing edge.
4. The refusal is a ledger entry with `side_effect: false` and `scenario_refs` containing
   `"N-1"`. After a cancellation only the declared reconciliation route is admissible
   (§7.4). After drift, a human re-binds, and the same result may then be consumed once.
5. A cancellation recorded while the attempt is in flight wins over a result that arrives
   later, however short the interval.

### Scenario N-1.a — cancellation during the attempt

- **Given** `wi-hsh-0001` at `run_script`, bound to its task; the pre-dispatch checkpoint passed and attempt `att-hsh-001` is running.
- **When** the bound task is cancelled while `att-hsh-001` is still running, and the script then returns success.
- **Then** the result is recorded on `att-hsh-001`; the proposal to advance is refused `cancellation_in_effect` with `scenario_refs` containing `"N-1"`; the instance is still at `run_script`; no envelope advancing it to `gate_out` exists in the ledger.

### Scenario N-1.b — mutation during the attempt

- **Given** the same instance and a running attempt `att-hsh-001`.
- **When** the wording of an acceptance criterion in the bound task is edited (or its `owner` is changed) while the attempt runs, and the script then returns success.
- **Then** the proposal to advance is refused `task_hash_drift`, `detail` names the changed field, `scenario_refs` contains `"N-1"`; the instance is still at `run_script`; `att-hsh-001` stays `succeeded`.

### Pass/fail test

Run both scenarios against the engine with a script that blocks until released. Cancel
(N-1.a) or mutate (N-1.b) the task while the script is blocked, then release it.

- **Pass:** in both runs the instance's `current_node` is unchanged, the ledger holds no
  admitted envelope that advances the instance after the attempt-start envelope, and it
  holds one refusal record that validates against `refusal.schema.json` with the reason
  code named above and `"N-1"` in `scenario_refs`.
- **Fail:** the instance advances in either run, or advances and is corrected afterwards,
  or no refusal record is written, or the record carries a different reason code.
- **Control:** the same run with the task left untouched advances the instance. Without
  this leg an engine that never advances would pass.

Worked refusal record: `examples/refusal-task-cancelled-during-attempt.json`.

---

## N-2 — a credential that can do more than the node's capability profile is refused

**Statement:**
> A resolved secret binding whose effective privilege exceeds the capability profile declared by the node is refused before execution, with the excess named in the refusal record.

**Source finding:** MS-3 (Mistral, important, medium confidence).
**Responsible components:** Arc 3 cand 5/6, with Arc 2 (isolation boundary).

### Situation

A procedure node declares a `capability_profile_ref`, for example a read-only profile.
The secret binding the node uses is named for that narrow purpose but resolves to a
credential that can do more, for example write or delete. Nothing in v1 compares what the
resolved credential can do with what the profile allows, so the script would run holding
more privilege than the ratified procedure granted it (a confused deputy).

### Required behaviour

1. Before the attempt-start envelope is appended and before anything is dispatched, the
   effective privilege of every resolved binding is compared with the node's declared
   capability profile.
2. If the binding carries any privilege the profile does not allow, the proposal is
   refused with `reason_code: privilege_exceeds_profile`. No attempt exists and nothing
   has run, so `side_effect` is `false`.
3. The refusal record carries `privilege_excess`: the node, its `capability_profile_ref`,
   the `binding_ref`, and `excess`, a non-empty list naming each privilege beyond the
   profile. The secret value never appears in the record.
4. `scenario_refs` contains `"N-2"`. The instance stays at its node.

### Why a new reason code

`privilege_exceeds_profile` is new in v2. `scope_mismatch` means repository or worktree
scope in this vocabulary, and `capability_unsupported` means the provider cannot do what
was asked. N-2 is the opposite case: the credential can do more than it was asked to be
able to do. Filing it under either existing code would hide the threat.

### Scenario N-2.a — binding exceeds the profile

- **Given** `wi-hsh-0001` at `run_script`; the node declares `capability.registry.read-only.v1` (allows `repo:read`); its binding `secret.registry.deploy-token.v1` resolves to a credential with `repo:read`, `repo:write` and `packages:delete`.
- **When** an agent proposes `ready → running` on `run_script`.
- **Then** the proposal is refused `privilege_exceeds_profile` before any attempt-start envelope; `privilege_excess.excess` is exactly `["repo:write", "packages:delete"]`; no attempt exists for the node; the registered script was not invoked.

### Pass/fail test

Run the scenario against the engine with a binding whose resolved credential carries at
least one privilege outside the node's profile.

- **Pass:** the script is not invoked (zero attempts for the node); the ledger holds one
  refusal record that validates against `refusal.schema.json` with
  `reason_code: privilege_exceeds_profile`, `side_effect: false`, `"N-2"` in
  `scenario_refs`, and a `privilege_excess.excess` list equal to the set of privileges
  beyond the profile.
- **Fail:** the script runs; or the refusal comes after execution began; or the record
  does not name the excess; or it names a privilege the profile allows; or it contains
  the secret value.
- **Control:** the same node with a binding whose privilege is within the profile is
  dispatched. Without this leg an engine that refuses every binding would pass.

Worked refusal record: `examples/refusal-privilege-exceeds-profile.json`.

---

## What this document does not do

It does not change architecture §13, any v1 contract, or any running code. It does not
define how a credential's effective privilege is measured, or what happens when it cannot
be measured: both belong to Arc 3 cand 5/6.
