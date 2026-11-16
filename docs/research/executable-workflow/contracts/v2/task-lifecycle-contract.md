# EWCR v1 — Pilot task lifecycle and task-state revalidation contract

**Task:** T-3386 · **Arc:** arc-019 (`ewcr-arc0-contract-evidence`) · **Freezes:** `architecture-c9070637.md` §2.4 (task remains the canonical work/evidence record; task and instance refer by stable IDs; runner snapshots the bound task's content hash at every gate; mutation between consumed gates is a policy event), §7.2 (binding lifecycle), §7.5 steps 1–2 and 9–10 (per-node sequence), §13 scenarios 3, 5, 11, 13, 16, 18, 20.
**Schemas referenced:** `instance.schema.json` (`task_binding`), `transition-envelope.schema.json` (`bound_task_content_hash`), `attempt.schema.json` (`task_content_hash`), `refusal.schema.json` (`reason_code`).
**Responsible future component:** Arc 1 candidate 3 — *task binding plus pre-dispatch and post-attempt task revalidation* (roadmap `5be23719` §Arc 1). Nothing here is runtime; it is the contract that component must satisfy.

## 1. Bindable task states

AEF's task lifecycle (CLAUDE.md §Task Lifecycle, map `aef-task-lifecycle`):
`captured → started-work ↔ issues → work-completed`, with **partial-complete**
(= `work-completed` still in `active/`, `owner: human`, unchecked Human ACs).

| AEF task state | Instance may be **created** against it | Instance may **advance** while task is in it | Rationale |
|---|---|---|---|
| `captured` | **no** | n/a | Nothing gets done without a *started* task. Binding a captured task would let the runtime start work the framework has not admitted (§2.4: task lifecycle stays the authority). |
| `started-work` | **yes** | yes | The only state in which governed work is legal. |
| `issues` | no | **no** — instance goes `waiting` with `resume_condition: task.status == started-work` | A task in `issues` is in the healing loop; the runtime must not advance a method over a task the framework has flagged. Existing binding is *kept*, not invalidated. |
| `work-completed` (archived, in `completed/`) | no | **no** — refusal | Completion is a separate governed task action (§2.5 step 6). An instance still open against a completed task is an inconsistency the runtime surfaces; it never "finishes" the instance to match. |
| partial-complete | no | **no** — same as `issues` (waiting) | Human ACs outstanding = a human gate outside the procedure. Advancing would skip it (§13 #3 by another door). |

An instance binds to **exactly one** task; a task may have **at most one open**
instance (`state ∉ {completed, cancelled}`). A second binding proposal is refused
`duplicate_delivery` if it carries the same idempotency key, else
`scope_mismatch` with `detail` naming the open instance.

## 2. Transitions that invalidate a binding

The binding record (`instance.task_binding`) pins `task_id`,
`task_content_hash`, `repository`, `worktree`, `component_scope`. It is
**invalidated** — every later proposal is refused until a human re-binds —
when any of the following is observed at a checkpoint:

| Observed change | Refusal `reason_code` | §13 |
|---|---|---|
| `task_id` no longer resolves in `active/` (deleted, renamed, archived) | `scope_mismatch` | 13 |
| `owner` changed away from the binding-time owner | `task_hash_drift` | 13 |
| Task moved to `completed/` while instance open | `scope_mismatch` | 13 |
| `repository` or `worktree` differs from the pinned value | `scope_mismatch` | 4, 13 |

The binding is **kept but the instance waits** (not a refusal — a legal
transition to `waiting`) on: `status` → `issues`; `status` → `work-completed`
while Human ACs remain (partial-complete).

The binding is **revalidated, not invalidated** (checkpoint decides) on:
content-hash drift with `task_id`, `owner`, `status` unchanged — see §3.

## 3. The two revalidation checkpoints

Both checkpoints compare the **same five fields**, read from the task file on
disk at checkpoint time, against the binding. Hash drift alone is *not*
automatically fatal: a task file legitimately changes as ACs are ticked and
Updates are appended. What is fatal is drift in the fields that carry authority.

| Field | Compared how | On mismatch |
|---|---|---|
| `id` | exact | `scope_mismatch` |
| `status` | exact against the state table in §1 | `waiting` (issues / partial) or refusal (`scope_mismatch`) |
| `owner` | exact | `task_hash_drift` — ownership is authority |
| **AC digest** — sha256 over the `## Acceptance Criteria` section with checkbox marks *removed* | exact | `task_hash_drift` — the *criteria* changed under the instance (ticks are allowed to change, wording is not) |
| `last_update` | monotonic (≥ binding-time value) | `task_hash_drift` — a rewind means the file was replaced, not edited |
| whole-file `task_content_hash` | recorded, not compared | written into the envelope / attempt for audit (§2.4) |

### 3.1 Pre-dispatch checkpoint (§7.5 steps 1–2, before step 7)

Runs after the procedure's ratification/content-hash check and before the
attempt-start envelope is appended. Order matters: a refusal here is
`side_effect: false` by construction because nothing has been dispatched.

```
read task file → compare 5 fields → 
  all match           → append attempt-start envelope with task_content_hash
  status ∈ waiting-set → propose instance → waiting (legal transition), no attempt
  any authority field → refusal record, instance stays at current node,
                         recovery_requirement = "human re-bind or revert task file"
```

### 3.2 Post-attempt checkpoint (§7.5 steps 9–10, before the edge is satisfied)

Runs when the attempt result arrives and **before** the instance may advance
through the outgoing edge. The attempt's own outcome is already recorded
(`attempt.exit_outcome`); this checkpoint decides whether the *instance* may
consume it.

```
read task file → compare 5 fields against the binding →
  all match           → outcome validation (§7.5 step 9) → advance (step 10)
  authority drift     → refusal task_hash_drift; attempt stays succeeded;
                         instance does NOT advance; recovery = re-bind, then
                         the same attempt result may be consumed once (idempotent)
  status = cancelled-intent recorded meanwhile
                      → refusal cancellation_in_effect; only the declared
                         reconciliation route is admissible (§7.4)
```

A worker claiming success (§13 #5) is irrelevant to this checkpoint: it checks
the task, and step 9 separately checks declared outputs. Both must pass.

## 4. Acceptance-scenario mapping (arch §13)

| # | Scenario | Checkpoint | Expected refusal / outcome |
|---|---|---|---|
| 3 | Human gate cannot be skipped by … edited state | pre-dispatch | ticking a Human AC in the task file does not satisfy a procedure human gate; the gate needs an admitted envelope with `actor.kind: human`. Edited state → `human_gate_skipped` |
| 5 | Missing typed input prevents advancement even if a worker claims success | post-attempt | `missing_typed_input` from step 9 — this contract adds nothing, records it as in-scope for the same component |
| 11 | Agent-user edits cannot mutate instance state or launch a registered action | both | task-file edits are *read* by the checkpoints, never *executed*; an edit that changes authority fields yields `task_hash_drift`, never a transition |
| 13 | Bound-task mutation between gates records hash drift and requires revalidation or refusal | both | the core scenario: AC-digest / owner / last_update drift → `task_hash_drift` with `detail` naming the field |
| 16 | Environment flags and `--force`-equivalents cannot bypass the runner boundary | pre-dispatch | a task closed with `--force` still reads `work-completed` → `scope_mismatch`; no env var is read by either checkpoint → `bypass_input` if one is presented as an input |
| 18 | Cancellation during an in-flight attempt prevents later advancement | post-attempt | `cancellation_in_effect` |
| 20 | Watchtower cannot mutate state directly | both | a `toggle-ac` POST changes the task file's tick marks only — excluded from the AC digest by design, so it neither advances nor breaks a binding; a human-gate decision still needs its own envelope |

**Explicitly out of Arc 0 scope for this contract** (owned by other Arc 0/1
contracts): 1, 2 (procedure ratification / reference resolution — T-3385
`procedure`), 4 (worktree scope — pinned here, enforced by the script
contract), 6 (component measurement — fence 1), 7, 17, 19 (idempotency,
deadlines, compare-and-append — T-3387 and the ledger contract), 8, 9, 10, 12,
14, 15 (provider, resume envelope, trace rendering, identity, hub enumeration,
policy drift).

## 5. What the responsible component must expose

For the headline mechanic (operator picks an invariant → sees contract →
refusal scenario → component → executable fence), Arc 1 candidate 3 must ship:

1. `revalidate(binding, task_file) → ok | waiting(reason) | refusal(reason_code, field)` — pure, no I/O beyond reading the file, so it is unit-testable against committed task fixtures.
2. The AC-digest function, with the tick-mark normalisation pinned by a test that ticks a box and asserts the digest is unchanged, then edits AC wording and asserts it changed.
3. One fixture per row of §4 producing the named `reason_code`, validated against `refusal.schema.json`.

Until that component exists, this document is the only artefact; the fence is
`tools/ewcr-contracts-check.py` (schema side) plus this task's Verification
(every `reason_code` named above is in the frozen enum — a contract naming a
code the schema does not know is a contract nothing can honour).
