# EWCR Arc 0 — DeepSeek and Mistral per-finding dispositions (T-5135)

**Decision S1** (drive-7 handback §5), operator ruling 2026-11-14: *"Authorise both"*.
This file is leg (b): a disposition for every finding in the two external reviews, in the
style of the Claude (§17) and Z.ai (§18) tables in the architecture dossier.

## Inputs

| Document | Path | sha256 |
|---|---|---|
| DeepSeek review | `docs/research/executable-workflow/reviews/T-032-deepseek-review-response.md` | `4dae4098b2602b2794525292e1aa3053e0c486b23a67d9c3292ce80dc3a4d8a9` |
| Mistral review | `docs/research/executable-workflow/reviews/T-032-mistral-review-response.md` | `0eecb8af7be56ba045581167ef66b73fd9d2aa17fcd241f84defc0e7d17bfb0e` |
| Refusal/threat matrix | `docs/research/executable-workflow/contracts/v1/refusal-threat-matrix.md` (T-3389) | rows DS-1..3, MS-1..5 |
| Architecture dossier | `docs/research/executable-workflow/architecture-c9070637.md` | `c9070637…6ac2d` |
| Delivery roadmap | `docs/research/executable-workflow/roadmap-5be23719.md` | `5be23719…ae5b8` |

The review files have been in this repo since 2026-09-24 (T-3389, `PROVENANCE.md` beside
them); both re-hashed to 832's published values on 2026-11-14. Both reviews read dossier
`99d33712…`, an earlier version than the pinned `c9070637`. Where the pinned dossier or the
v1 contracts already answer a finding, the table says so and cites where.

## Disposition vocabulary

- **accepted** — the finding is right and changes what must be built. The owner is the
  roadmap arc candidate that builds it (see "Owners" below).
- **already handled** — the pinned dossier or a frozen v1 contract already states the rule,
  and `python3 tools/ewcr-contracts-check.py` checks it. Building it is still owed by the
  named candidate; the *design* gap the review saw is closed.
- **out of scope** — right, but not for the arc it was raised against; deferred to a
  named later arc.
- **rejected** — wrong or not applicable, with the reason.

## DeepSeek (runtime correctness lens) — 3 findings

| ID | Finding (severity, confidence) | Disposition | Reason | Owner | Refusal test / fence |
|---|---|---|---|---|---|
| DS-1 | Task-state TOCTOU: snapshots at gates but not during node execution; a task cancelled mid-script can still "complete" (**blocker**, high) | **accepted** | Correct. §13 #13 covers only "between gates", and #18 assumes the cancellation is observed. The per-attempt window is uncovered in v1. Needs the NEW scenario N-1 (matrix §5.1), which goes into `contracts/v2/` once the operator accepts it. | Arc 1 cand 3 (pre-dispatch and post-attempt task revalidation) with cand 6 (attempt-boundary cancellation) and cand 8 (attempt boundary) | Partial: `tools/ewcr-contracts-check.py` covers both gate checkpoints. Gap: the during-attempt check. DeepSeek's own disqualifier is the Arc 1 pilot test: mutate or cancel the task mid-script, and the instance must not advance. |
| DS-2 | Compensation idempotency unspecified; a retried remediation can double-alter state (important, medium) | **already handled** | `contracts/v1/evidence-and-idempotency.md` §3 sets idempotency keys, and Scenario 3.3 says a duplicate compensation produces one corrective action (§13 #18). Pinned dossier §6.2.2: a self-heal action carries "a fixed attempt budget, an idempotency rule, and a post-remediation verification". | Arc 1 cand 8 (build) | `python3 tools/ewcr-contracts-check.py`, Scenarios 3.1–3.3 |
| DS-3 | Output validated before evidence is snapshotted and redacted; evidence can be altered after validation (important, high) | **already handled** | `evidence-and-idempotency.md` §1 "Ordering invariant: snapshot → hash → validate → accept". Scenarios 1.1–1.3 refuse validate-before-hash, re-hash-after-validation, and accept-without-matched-verdict. | Arc 1 cand 7 (build) | `python3 tools/ewcr-contracts-check.py`, Scenarios 1.1–1.3 and 2.1–2.3 |

## Mistral (security and portability lens) — 5 findings

| ID | Finding (severity, confidence) | Disposition | Reason | Owner | Refusal test / fence |
|---|---|---|---|---|---|
| MS-1 | Secret-binding resolution has no refusal rules for missing, revoked or mismatched bindings; an adapter could fall back to ambient or default credentials (**blocker**, high) | **accepted** | Correct, and still open. §13 #2 and #8 are recorded as uncovered in `traceability.yaml`. Silent credential fallback leaves no refusal record, so nothing downstream can catch it. | Arc 3 cand 5/6 (provider adapters, capability manifests) | Gap. Required tests: a missing, a revoked and a profile-mismatched binding are each refused, with adapter-specific refusal evidence in the attempt record (`unresolved_reference` / `capability_unsupported`). |
| MS-2 | Adapters need not declare refusal semantics for unsupported capabilities, so behaviour diverges by provider (important, high) | **accepted** | Correct. No v1 contract defines a refusal-semantics declaration or validates one at ratification. | Arc 3 cand 5/6 | Gap. Required test: ratification refuses an adapter manifest without refusal semantics for a capability the procedure uses. |
| MS-3 | Confused deputy: a resolved secret may exceed the node's declared capability profile (important, medium) | **accepted** | Correct. No §13 scenario or existing reason code fits: `scope_mismatch` is repository/worktree scope, `capability_unsupported` is provider ability. Needs the NEW scenario N-2 (matrix §5.1) and likely a new reason code; both go into `contracts/v2/` once the operator accepts them. | Arc 3 cand 5/6 with Arc 2 (isolation boundary) | Gap, blocked on N-2. Required test: a binding whose effective privilege exceeds the profile is refused before execution, with the excess named in the refusal record. |
| MS-4 | No refusal rule when no eligible model satisfies a declared preference; silent weaker-model substitution (improvement, high) | **out of scope** for Arc 1/2, **accepted** for Arc 6 | The invariant is already stated: dossier §6.6.2 says "If no eligible executor satisfies…" and §13 #8 says "never silent substitution". But the Arc 1 pilot is single-provider and deterministic, with no model routing, so nothing in the pilot can exercise it. It belongs with the provider capability matrix (Q-13, deferred). | Arc 6 (governed routing, multi-provider), with the Arc 3 capability matrix | Gap. Required test: with no eligible model for a preference, the node is refused and routed to a human, never substituted. |
| MS-5 | No concrete refusal tests for path traversal, shell injection or environment poisoning in script/CLI actions (improvement, high) | **accepted** | The design is partly there. Pinned dossier §6.2.1 says structured `argv` only, and `sh -c`, concatenation, command substitution and unbounded inherited environment are outside the model. What is missing is positive refusal tests per malformation class. `tests/unit/tier0_scope_boundary.bats` measures today's gap: Tier 0 sees only the command string. | Arc 1 cand 1 / Arc 3 cand 1 (script contract) | Partial. Required tests: refuse a `..` path component, shell metacharacters in argv, and an environment name not declared in the contract (`command_substitution`, §13 #4, #16). |

## Summary

| Review | Findings | accepted | already handled | out of scope (deferred) | rejected |
|---|---:|---:|---:|---:|---:|
| DeepSeek | 3 | 1 | 2 | 0 | 0 |
| Mistral | 5 | 4 | 0 | 1 (Arc 6) | 0 |
| **Total** | **8** | **5** | **2** | **1** | **0** |

Both blockers (DS-1, MS-1) are **accepted**; neither is excluded.

## Owners

The owners are roadmap arc candidates (`roadmap-5be23719.md` §4), not AEF task IDs. No AEF
task exists yet for Arc 1–6 candidates. Arc 1 opens only after Arc 0 exits, and its
candidate tasks are filed then. Each accepted row names the candidate that must carry its
refusal test, so the test is a criterion of that task when it is filed.

## Operator decisions this table raises (not taken here)

1. **Accept N-1** (from DS-1) and **N-2** (from MS-3) as new acceptance scenarios. They go
   into `contracts/v2/`, since v1 is frozen. Until then, DS-1's per-attempt leg and MS-3 have
   no scenario to test against.
2. The two "human decisions required" each review lists: DeepSeek's task-state check
   frequency and compensation idempotency policy, and Mistral's refusal-vs-human-gate-vs-
   fallback choice for bindings, adapters and model routing. These belong to the arcs that
   build them (Arc 1, Arc 3) and are recorded here so they are not lost.
