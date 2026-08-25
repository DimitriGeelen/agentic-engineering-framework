# Executable Workflow Runtime — Research and Delivery Roadmap

**Governance container:** T-034  
**Architecture source:** `docs/architecture/executable-workflow-contract-runtime.md`  
**Decision source:** PD-001 / T-033  
**Intended recipient:** AEF agent / `/opt/999-Agentic-Engineering-Framework` research workflow  
**Status:** advisory research handoff; no local arc/task creation or implementation authority

> Scope boundary: every arc name and candidate task below is a **suggestion for
> the AEF agent to evaluate and include in its research/architecture work**.
> They are not arcs or tasks to register in `0503-codex-cli-playground`.

## 1. Does this decomposition make sense?

Yes. The dossier and four independent reviews are now specific enough to move
from one large architecture proposal to outcome-oriented delivery arcs. The
decomposition is useful because it separates three things that must not be
collapsed:

1. **Value priority:** what would create the most business/framework value.
2. **Safe execution order:** what prerequisites must pass before later work is
   lawful or credible.
3. **Human authority:** BVP confirmation, arc start/close, architecture changes,
   and autonomy expansion remain operator decisions.

The main caution is that the Component Fabric currently reports **0 components
and 0 edges**. Therefore this roadmap can map architecture dependencies and
verification fences, but it cannot claim a code-level blast radius. Arc 0 must
establish that evidence before implementation tasks are considered fully
decomposed.

## 2. Governing delivery logic

```text
Arc 0 — evidence baseline and contract freeze
  ↓
Arc 1 — semantics-first runtime kernel
  ↓ hard gate
Arc 2 — boundary-isolation proof
  ├──────────────┐
  ↓              ↓
Arc 3 — secure action/provider substrate
  ↓              Arc 4 — operator view + Workflow Fabric
  └──────┬───────┘
         ↓
Arc 5 — guided agentic execution
         ↓
Arc 6 — routing, composition, and multi-provider operation
```

Arcs 3 and 4 may proceed in parallel only after Arc 2 passes and only with
disjoint worktrees/write sets. Arc 5 and Arc 6 are explicitly blocked from
expanding autonomy until the isolation proof is green.

### 2.1 AEF/Designer operational split

The authoritative ownership boundary is
`executable-workflow-contract-runtime.md` §5.1. The matrix below applies it to
the suggested AEF roadmap. “Joint” means versioned proposal/review and a human
decision—not shared direct writes across repositories.

| Arc | AEF agent owns | Workflow Designer agent owns | Required joint handoff |
|---|---|---|---|
| 0 Contract baseline | Runtime schemas, invariants, refusal matrix, task/evidence contracts, AEF topology | Inventory visual/mapping schema, stable IDs, import/export and round-trip constraints | Agree version matrix, canonical IDs, diagnostic shape, and worked procedure fixture |
| 1 Semantics kernel | Registry, ledger/fold, task binding, time, cancellation, conflict, evidence, idempotency | Read fixture/projection prototypes only; no execution code | Designer proves it can render the canonical fixture without inventing semantics |
| 2 Isolation proof | Service identity, authenticated API, runner-owned state, adversarial tests | Prove browser/editor cannot reach execution/secret/ledger authority | Joint attack/interaction review; human GO before broader integration |
| 3 Secure actions/providers | Action catalogue, secrets, capability profiles, adapters, model refusal | Author declarative profile references and render structured refusals | Contract tests for missing/unsupported/mismatched profiles and diagnostics |
| 4 Operator/Fabric | Projection API, authenticated proposal admission, Fabric queries/version semantics | Runtime visualisation, operator interaction UX, diagram↔Fabric navigation | End-to-end gate/pause/cancel/refusal flows with read-back receipts |
| 5 Guided agentic | Prompt action, context envelope, continuity, TermLink state, outcome validation | Author/visualise agent nodes, scopes, outcomes, and handoffs | Round-trip one guided procedure and verify exact semantic preservation |
| 6 Routing/composition | Router, binding authority, calls, parallelism, migration, provider conformance | Visual routing explanations, sub-procedure composition, migration presentation | Multi-provider/composed demo plus compatibility and human-decision evidence |

### 2.2 Task ownership labels for the AEF research agent

When the AEF agent converts these suggestions into its own governed tasks, it
should classify each candidate as:

- **AEF:** runtime, governance, task/approval authority, schemas, validator,
  runner, ledger, identity, secrets, adapters, Fabric semantics, projection API.
- **Designer:** BPMN/diagram authoring, visual notation, editing UX,
  import/export, semantic round trip, diagnostic and runtime presentation.
- **Joint-contract:** interchange, stable IDs, version compatibility,
  diagnostic schema, projection/proposal API, fixtures, and integration tests.

Joint-contract work should be split into paired tasks—one in each owning
project—with the same contract version/hash and a named integration fence. It
must never be represented as one worker writing both repositories.

### 2.3 Required communication envelope

Every AEF↔Designer handoff should carry:

1. source project, task/arc, sender identity, and intended receiver;
2. contract/artifact type, version, content hash, and compatibility range;
3. requested action: review, implement, validate, decide, or acknowledge;
4. acceptance/refusal schema and evidence location;
5. correlation/thread ID, deadline, and human decision owner when applicable.

Completion requires receiver read-back of the version/hash plus a substantive
accepted/refused/needs-decision response. TermLink post or file transfer alone
is transport evidence, not collaboration completion.

## 3. BVP method and authority boundary

Scores below are **estimator proposals**, on the project rubric's 0–5 scale.
They are not confirmed scores and do not start, approve, or reorder arcs.

| ID | Driver | Weight | Why relevant here |
|---|---|---:|---|
| D1 | Antifragility | 9 | Refusal, recovery, restart, and adversarial failures become standing protection. |
| D2 | Reliability | 7 | Deterministic transitions, evidence, observability, and no silent fallback. |
| D3 | Usability | 5 | Operator legibility, actionable refusals, visual traces, and understandable routing. |
| D4 | Portability | 3 | Provider-neutral contracts, adapters, and environment-independent semantics. |
| F-RECALL | Recall Leverage | 6 | Durable ledger/fabric evidence prevents rediscovery and lost operating knowledge. |
| F-AUTONOMY | Autonomy / Unattended Operation | 4 | Rewards autonomy only where mechanical gates make it at least as safe. |
| F3 | Prompt Quality | 7 | Relevant when prompts become versioned executable contract objects. |
| F1 | Context Fabric | 7 | Relevant to curated execution envelopes, continuity, and governed memory. |
| F2 | Component Fabric | 6 | Relevant to scope, impact, verification selection, and Workflow Fabric joins. |

Suggested arc-scoped drivers are proposals only. The operator may approve at
most three per arc through the governed `fw arc approve-driver` mechanism.

## 4. Arc breakdown

### Arc 0 — Contract evidence and implementation baseline

**Objective:** turn the approved architecture and review findings into a frozen,
traceable implementation baseline with sufficient topology to decompose code
safely.

**Observable outcome:** an operator can select any pilot invariant or review
finding and trace it to a versioned contract, threat/refusal scenario,
responsible future component, and executable verification fence.

**Candidate tasks:**

1. Register/enrich the relevant Component Fabric baseline and validate edges.
2. Freeze v1 schemas for procedure, instance, transition envelope, attempt,
   evidence reference, refusal, and deadline events.
3. Build the consolidated refusal/threat matrix from Claude, Z.ai, DeepSeek,
   and Mistral findings.
4. Define the pilot task lifecycle and task-state revalidation contract.
5. Specify evidence snapshot/hash ordering and compensation-idempotency rules.
6. Produce a worked human-gate → registered-script → human-gate procedure.

**Exit gate:** topology is non-empty and validated; every blocker finding has a
contract disposition and testable scenario; no unresolved source-of-truth
ambiguity enters Arc 1.

**Suggested scoped driver:** `contract-evidence-completeness` (weight proposal
5; retire when every pilot invariant has source, owner, and verification).

### Arc 1 — Semantics-first runtime kernel

**Objective:** prove deterministic workflow semantics without yet claiming the
final isolation boundary.

**Observable outcome:** one governed task runs through a ratified procedure and
registered script; restart, duplicate delivery, cancellation intent, task
mutation, timer expiry, and concurrent proposals produce deterministic state or
immutable refusal evidence.

**Candidate tasks:**

1. Implement immutable procedure registry and validator.
2. Implement append-only event ledger and deterministic fold/projection.
3. Implement task binding plus pre-dispatch and post-attempt task revalidation.
4. Implement compare-and-append conflict handling and stale-position refusal.
5. Implement durable deadlines and restart-safe timer evaluation.
6. Implement attempt-boundary cancellation and reconciliation route.
7. Snapshot/hash evidence before validation and make accepted evidence immutable.
8. Implement idempotent attempt, result, and compensation contracts.
9. Run the complete semantics/refusal/restart pilot suite.

**Exit gate:** no duplicate effect/advance; canceled or mutated task cannot
silently complete; timers survive restart; racing proposals admit exactly one;
evidence cannot change after validation.

**Suggested scoped driver:** `semantic-integrity` (weight proposal 6; retire
when the semantics/refusal suite is green under crash and concurrency tests).

### Arc 2 — Mandatory boundary-isolation proof

**Objective:** make bypass impossible at the runner boundary before any agentic
or provider autonomy is enabled.

**Observable outcome:** an adversarial agent identity cannot edit ledger/state,
launch an action, forge an operator decision, inherit ambient authority, or
bypass refusal through environment/force inputs.

**Candidate tasks:**

1. Package one privileged supervised runner service outside agent identities.
2. Define and implement the authenticated typed proposal interface.
3. Move ledger, registry, and execution authority under runner ownership.
4. Implement per-agent/attempt and operator identity verification.
5. Add adversarial filesystem, process, credential, replay, and force-flag tests.
6. Re-run all Arc 1 semantics across the isolated boundary.
7. Produce wire-level isolation evidence and operational recovery procedure.

**Exit gate:** every bypass scenario is mechanically refused and recorded;
service restart preserves authority and state; human GO is required before Arc
3/4 start and before any autonomy expansion.

**Suggested scoped driver:** `authority-non-bypassability` (weight proposal 6;
retire only when the adversarial proof is repeatably green).

### Arc 3 — Secure action and provider substrate

**Objective:** safely broaden the deterministic runner from one script to typed
actions, secret bindings, and provider adapters without silent substitution.

**Observable outcome:** every action/provider attempt either runs under an
exact declared profile or returns a specific immutable refusal; no ambient
credential, weaker model, broader secret, or free-form shell fallback exists.

**Candidate tasks:**

1. Implement versioned action catalogue and structured argv invocation.
2. Add traversal, shell-metacharacter, cwd, environment, and size refusal tests.
3. Define opaque secret-binding states: missing, revoked, excessive, mismatched,
   expired, and unavailable.
4. Validate resolved secret scope against the capability profile and prevent
   confused-deputy use.
5. Define provider-adapter capability/refusal manifests and ratification checks.
6. Implement qualified model routing with explicit declared fallback or human
   reroute—never silent substitution.
7. Add redaction-profile validation and side-effect reconciliation evidence.

**Exit gate:** the Mistral refusal matrix passes; no secret/model/provider
fallback occurs without an explicitly ratified route.

**Suggested scoped driver:** `least-authority-fidelity` (weight proposal 6;
retire when action, secret, and provider profiles are mechanically congruent).

### Arc 4 — Operator control and Workflow Fabric projection

**Objective:** make the runtime understandable and operable without granting
the browser direct execution authority.

**Observable outcome:** Watchtower renders a live read-only ledger projection;
operator interactions submit authenticated proposals; users can trace runtime
state to tasks, evidence, components, procedure versions, and refusals.

**Candidate tasks:**

1. Implement read-only runtime projection API and visual trace.
2. Implement authenticated Watchtower proposal flows for gate, pause, resume,
   cancel, and override.
3. Render actionable refusal/recovery explanations and evidence links.
4. Build Workflow Fabric projection using `ratified-latest` plus versions bound
   to live instances.
5. Join procedure steps to Component and Context Fabric references.
6. Add impact queries and explicit measured/unmeasured topology states.
7. Verify browser/editor has no shell, credential, ledger, or action authority.

**Exit gate:** UI mutation attempts cannot bypass the proposal interface; every
displayed state is reproducible from governed records; version projections are
unambiguous.

**Suggested scoped driver:** `operator-legibility` (weight proposal 5; retire
when operators can diagnose and lawfully recover every pilot refusal).

### Arc 5 — Guided agentic execution

**Objective:** introduce bounded agent work while preserving all semantics,
authority, evidence, and provider honesty proven earlier.

**Observable outcome:** a versioned agent-prompt node receives a minimal
curated execution envelope, returns typed immutable evidence, survives pause or
provider-session loss, and cannot broaden its scope or approve itself.

**Candidate tasks:**

1. Define versioned prompt/action contract and outcome validator.
2. Implement Context Fabric selectors, redaction, and provenance snapshots.
3. Implement provider-neutral pause/resume envelope and adapter continuation.
4. Bind TermLink correlation to target enumeration, delivery, acknowledgement,
   semantic completion, timeout, and operator-visible failure.
5. Implement agent diagnostic/self-healing actions with narrower capabilities
   and explicit idempotency budgets.
6. Add prompt-injection, scope-escalation, stale-task, and provider-loss tests.
7. Demonstrate one guided delivery chain from specification to verified change.

**Exit gate:** agentic execution cannot escape the ratified action/profile/task
boundary; continuation does not depend on an unbounded transcript; all failure
states have lawful routes.

**Suggested scoped driver:** `bounded-agent-outcome-quality` (weight proposal 5;
retire when prompt nodes reliably produce typed verified outcomes across two
eligible providers).

### Arc 6 — Governed routing, composition, and multi-provider operation

**Objective:** scale from one guided procedure to explainable routing and
composable procedures without weakening authority or recovery.

**Observable outcome:** an intake produces eligible procedure candidates and an
explanation; a human or pre-authorized low-risk policy binds one; composed and
parallel procedures remain versioned, scoped, recoverable, and observable
across provider differences.

**Candidate tasks:**

1. Define router eligibility, explanation, confidence, deadline, and escalation
   contracts.
2. Implement human selection first; add only narrowly proven pre-authorized
   auto-binding bands later.
3. Implement call-workflow typed I/O, cycle detection, and failure propagation.
4. Implement parallel branch write sets, joins, deadlock detection, and
   compensation ordering.
5. Define active-instance procedure migration and compatibility rules.
6. Add multi-provider conformance/refusal suite and substitution evidence.
7. Design cross-repository composition as a separately authorized boundary.
8. Demonstrate routing and composed execution with complete operator trace.

**Exit gate:** routing is explainable and bounded; composition cannot bypass
task/human authority; provider divergence yields refusal rather than semantic
drift; auto-binding remains human-approved policy.

**Suggested scoped driver:** `governed-composability` (weight proposal 5; retire
when routing/composition scales without adding an authority bypass class).

## 5. Proposed BVP scores by arc

These are deliberately coarse and evidence-based. Cost/risk and dependency
gates must be shown alongside value; a high score does not make a blocked arc
actionable.

| Arc | D1 | D2 | D3 | D4 | Recall | Autonomy | Prompt | Context | Component | Confidence | Dependency state |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| 0 Baseline | 3 | 4 | 2 | 2 | 3 | 0 | 1 | 2 | 5 | high | actionable first |
| 1 Semantics kernel | 5 | 5 | 2 | 3 | 3 | 2 | 0 | 2 | 2 | high | after Arc 0 |
| 2 Isolation proof | 5 | 5 | 2 | 3 | 2 | 1 | 0 | 0 | 1 | high | after Arc 1; hard gate |
| 3 Secure providers | 4 | 5 | 3 | 5 | 2 | 2 | 2 | 1 | 2 | medium | after Arc 2 |
| 4 Operator/Fabric | 3 | 4 | 5 | 3 | 4 | 1 | 1 | 4 | 5 | medium | after Arc 2 |
| 5 Guided agentic | 4 | 5 | 4 | 5 | 4 | 4 | 5 | 5 | 3 | medium | after Arcs 3+4 |
| 6 Routing/composition | 5 | 5 | 4 | 5 | 4 | 5 | 4 | 4 | 4 | low-medium | after Arc 5 |

### Counterarguments and calibration notes

- Arcs 5–6 score highly because they create new collaboration/autonomy modes,
  but they also carry the largest cost and uncertainty. Their scores must not
  bypass their predecessor gates.
- Arc 2's F-AUTONOMY score is intentionally low: it adds safety capacity rather
  than immediately reducing human checkpoints. Inflating it would double-count
  future autonomy value.
- Arc 4's Component Fabric score assumes a real topology baseline from Arc 0.
  If Fabric remains empty, lower that score and block its impact-query tasks.
- D1/D2 scores of 5 are reserved for structural failure-class protections, not
  ordinary tests. If implementation lands as local checks rather than runner
  invariants, reduce them to 3.

## 6. Verification fences and ownership

| Fence | Required before | Evidence owner |
|---|---|---|
| Component Fabric non-empty, enriched, validated | implementation decomposition | Arc 0 task owner; operator reviews uncertainty |
| Contract/refusal matrix complete | Arc 1 | architecture task owner |
| Semantics/crash/concurrency suite green | Arc 2 | runtime test owner |
| Adversarial isolation suite green | Arcs 3–4 and all autonomy | security test owner + human GO |
| Secret/provider refusal suite green | Arc 5 | adapter/security owner |
| Watchtower authority test green | Arc 5 | UI/runtime integration owner |
| Agentic injection/scope/continuity suite green | Arc 6 | agent-runtime test owner + human GO |
| Routing/composition conformance demo | arc close/release | integration owner + human close decision |

## 7. Recommended AEF-agent handoff

Send this document and its cited review artefacts to the AEF agent as research
input. The AEF agent should first validate whether the proposed Arc 0 belongs in
the AEF repository and whether its Component Fabric/topology supports the stated
boundaries. Only after its own governed workflow and operator approval should it
create a draft arc or tasks in the **AEF project**.

Do not create any of these suggested arcs or candidate tasks in
`0503-codex-cli-playground`. Do not bulk-create all later AEF tasks: their write
sets and acceptance criteria depend on the AEF agent's topology, contracts, and
evidence. The AEF agent should refine one next arc at each exit gate.

## 8. Evidence consulted

- Approved architecture and PD-001 in
  `docs/architecture/executable-workflow-contract-runtime.md`.
- Claude review: runner identity, task binding, wait correlation, policy drift.
- Z.ai review: durable time, cancellation, deployment identity, Workflow Fabric
  version projection, ledger-native alternative, pilot ordering.
- DeepSeek review: task TOCTOU, compensation idempotency, immutable evidence
  ordering.
- Mistral review: secret-binding refusals, confused deputy, provider/model
  divergence, command-boundary refusal tests.
- `policy/value-drivers.yaml` and `policy/bvp-scoring-rubric.md`.
- `fw fabric stats`: 0 components, 0 edges (impact-map limitation).
- Architecture §5.1 ownership/collaboration contract for the AEF and Workflow
  Designer agents.
