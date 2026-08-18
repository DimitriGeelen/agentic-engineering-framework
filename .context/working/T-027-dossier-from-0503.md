(no parent — not a reply)
[97] d1993c2c3ec44c94 note: T-027 REQUEST: independent AEF-grounded architecture review. You are advisory only; do not approve, modify, or dispatch work. Review the full dossier below, version SHA-256 7b51ba56329bebe50ac92295d32c71c66906afbae259f8010e33f39ed27efdd5. Focus: (1) factual fit with current AEF primitives and known gaps, (2) governance/authority/TermLink/worktree/Context+Component Fabric risks, (3) missing runtime primitives and refusal tests, (4) smallest credible pilot. Return <=1000 words using: Verdict; numbered findings with severity, dossier section, evidence/reason, concrete change; missing primitives; first pilot; human decisions. Distinguish observed AEF fact from proposed design. Full dossier follows.

--- DOSSIER START ---
# Executable Workflow Contract Runtime

**Status:** working architecture dossier — exploration, not implementation authorisation  
**Governance container:** T-027  
**Reviewed:** 2026-08-17

## 1. Origin: why this exists

This architecture is not a proposal to add an agent runner to a diagram tool.
It comes from a practical question: **how can an operator and agents develop an
application together without reducing their collaboration to an untraceable
chat history?**

The operator carries intent, product judgement, priorities, taste, exceptions,
and accountability. Agents contribute speed, exploration, implementation,
verification, and sustained execution. Neither role is a lesser form of the
other. An operator is not a gate that merely slows an agent down; an agent is
not a tool that merely waits for commands. They need a shared way to make
intent, delegation, evidence, intervention, and learning visible.

### 1.1 AEF: the accumulated operating experience

The Agentic Engineering Framework is the first foundation of that shared way of
working. It was built around lessons from governed agent work: work needs a
canonical task, important decisions and assumptions must survive sessions,
changes need structural impact awareness, human authority cannot be quietly
absorbed by an autonomous process, and a stopped or context-limited agent must
leave durable state for the next actor.

AEF therefore already provides important primitives:

- the task and inception lifecycle for governed work, acceptance criteria,
  review, BVP, and human decisions;
- Context Fabric for working, project, episodic, decision, learning, risk, and
  handover memory;
- Component Fabric for code topology, dependencies, blast radius, and drift;
- TermLink for cross-agent communication and correlated transport;
- provider adapters, continuity/handover work, worktree isolation, and
  Watchtower as operational visibility surfaces.

Those are not abstract features to be copied into a new product. They are the
hard-won substrate on which this vision must stand. They also explain the
non-negotiable constraints of this dossier: task authority, provenance,
worktree/project boundaries, redacted secrets, provider honesty, and explicit
human sovereignty.

### 1.2 Workflow Designer: making the method visible

The Workflow Designer supplied the second foundation. It makes roles, lanes,
process steps, gateways, handoffs, typed inputs/outputs, and interfaces visible
in a form that operators, architects, and agents can discuss together. Its
BPMN-plus-AEF mapping establishes a portable visual/process language and a
bridge to proposed governed work.

That work deliberately stopped before runtime execution. A map can describe a
method, propose tasks, and make a process legible, while still being unable to
say whether the next action is legal, which capability is permitted, whether a
human decision is required, or whether evidence actually justifies moving on.
That is the gap this architecture addresses.

### 1.3 The collaboration model

The desired experience is a conversation embodied in a durable map:

```text
Operator: states the outcome, supplies judgement, sets boundaries,
          approves consequential decisions, and can intervene at any moment.

Workflow: makes the agreed method, interfaces, options, and current state
          visible to both parties.

Agent:    receives a bounded next action with relevant context, permitted
          capabilities, expected evidence, and lawful escalation routes.

Runtime:  independently enforces the contract and records what actually
          happened; it does not trust an agent or browser to self-authorise.
```

This model lets the operator remain genuinely in the development loop without
having to micromanage every command. It lets an agent act with meaningful
autonomy without relying on ambient permissions or making invisible decisions.
It also creates a common visual map of the application and delivery process,
not merely a list of tasks or a transcript of exchanges.

### 1.4 The north-star: executable institutional methods

We want a workflow to be a versioned, governed, executable contract. It is not
merely a process drawing, a project plan, or an agent prompt. It is a shared
operational language through which operators and agents can develop and run an
application together.

The visual map explains the method to people. The same map gives an agent a
precise, bounded next action. A runtime independently enforces the action's
prerequisites, permissions, data contract, evidence requirements, and legal
successor. The execution becomes inspectable and resumable rather than a
sequence of opaque chats and shell commands.

~~~
Operator intent and decision
          ↓
Versioned workflow procedure ──→ governed runtime execution
          ↑                               ↓
Visual collaboration surface         evidence, state, audit, learning
~~~

The desired outcome is a visual map of an application and its delivery process
that an operator can understand, an agent can use, and a runtime can execute
safely. It should answer: what happens next, why, under which authority, with
which inputs, by which executor, using which model/capabilities, and what must
be true before the procedure advances.

The workflow is an approved contract; a separate runtime is the
policy-enforcement point. This is how AEF's governance and learning model can
become visible, navigable, and operational—not by replacing AEF, but by tying
its existing primitives into an explicit operator-agent delivery method.

## 2. The essential model

The following concepts have different responsibilities and must not collapse into one mutable “workflow” object.

| Concept | Meaning | Example |
|---|---|---|
| **Workflow procedure** | Reusable, ratified method for a class of work | feature-delivery version 2.3 |
| **Workflow router** | Procedure that selects and binds an eligible method | delivery-intake-router version 1.1 |
| **Workflow instance** | One live enactment of one pinned procedure version | instance wi-01J… for task T-123 |
| **Task** | AEF's canonical governed work/evidence record | task T-123 |
| **Action attempt** | One execution attempt of an instance node | attempt 003 |

### 2.1 Workflow procedure: the institutional method

A procedure defines a class of work: its phases, roles, legal paths, interfaces, outcomes, human gates, action contracts, and failure routes. It is the institutional method we improve over time—for example feature delivery, incident investigation, release readiness, architecture inception, or provider onboarding.

It is source-controlled, validated, versioned, and ratified. Once ratified it is immutable. A change produces a new version and requires re-ratification. This prevents a running agent from editing the procedure that limits its own authority.

### 2.2 Workflow router: choosing a method is itself a method

Procedure selection must not be an invisible agent guess. The router is its own governed procedure:

~~~
request/task/event
  → collect declared facts and context
  → identify eligible procedure versions
  → evaluate applicability, confidence, value, risk, and policy
  → explain recommendation
  → human decision or narrow pre-authorised auto-bind
  → bind the task and create an instance
~~~

The router records candidates, reasons for selection/rejection, confidence, the inputs used, and the decision actor. Ambiguous routing, Tier-0 work, unmeasured component scope, sensitive capabilities, external side effects, or high cost must escalate to a human gate. Low-risk automatic routing is an explicit policy choice earned through evidence, not a default.

### 2.3 Workflow instance: an enacted method

An instance is a live, task-bound enactment of exactly one ratified procedure version. It records the current node, transition history, materialised inputs and outputs, approvals, action attempts, resolved profiles, redacted evidence, and pause/resume state.

It is not a free-writable YAML file. A policy-enforcing runtime alone creates, transitions, pauses, resumes, compensates, or closes an instance. An agent may request a transition and provide evidence; it cannot make its own request legal.

### 2.4 Task: canonical governed work

The workflow does not replace AEF tasks. The procedure is the method; the task remains the canonical work/evidence record for acceptance criteria, BVP, approval, lifecycle, and completed-task history. A task binds to an instance; the task and instance refer to each other by stable IDs.

## 3. Why this matters

This architecture delivers more than automation:

- **Shared clarity:** the same map works for business/operator discussion, architecture review, agent instruction, and runtime visibility.
- **Repeatability:** proven methods become reusable procedures rather than institutional knowledge trapped in old conversations.
- **Safe delegation:** agents receive a bounded work envelope rather than broad ambient permissions and vague outcomes.
- **Accountability:** every transition has identity, inputs, policy basis, evidence, and an auditable reason.
- **Continuity:** a paused/restarted provider process resumes from durable workflow state and a curated context bundle, not from a fragile transcript.
- **Impact awareness:** Component Fabric can influence routing, scope, verification, and human escalation.
- **Provider freedom:** the procedure says what is required; an adapter states which provider/model can actually satisfy it.
- **Learning loop:** Context Fabric turns execution outcomes into decisions, learnings, patterns, handovers, and better procedure versions.

## 4. Architecture principles

1. **Executable, not merely descriptive.** A ratified procedure can drive a run; a visual map is not itself an authority grant.
2. **Human sovereignty remains substantive.** Ratification, sensitive routing, exceptions, and terminal policy decisions have explicit human ownership.
3. **Runtime-enforced policy.** Browser and agent actions are requests; the runtime validates and commits state independently.
4. **Declarative contracts, not arbitrary instructions.** Nodes select bounded action types and approved references. Raw unrestricted shell text is not an initial workflow primitive.
5. **Typed interfaces.** Inputs, outputs, outcome checks, and edge guards are validated. A line is a contract, not decoration.
6. **Deterministic skeleton; agentic leaves.** Sequencing, gates, retries, compensation, and evidence are deterministic. Agent reasoning is bounded by a node contract and observable outcomes.
7. **No duplicated truth.** Workflow definitions reference AEF substrates; they do not copy Context/Component/Task truth and then drift from it.
8. **Safe failure is designed.** Refusals explain the failed predicate and lawful recovery path; they are not silent stream drops or generic errors.
9. **Provider neutrality is honest.** Common intent is portable; adapters explicitly declare support and refusal, not fictional equivalence.
10. **Project and worktree isolation is non-negotiable.** Every lookup and action is scoped to the selected repository identity and worktree.
11. **Earn autonomy.** Routing and capability automation only expand after evidence-backed, reversible pilots prove the relevant controls.

## 5. Current reality and the opportunity

| Existing capability | Contribution | Gap to the executable vision |
|---|---|---|
| Workflow Designer + BPMN extensions | Visual maps, lanes, stable IDs, typed I/O, import/export | Editor/mapping surface, not runtime control plane |
| Frozen BPMN/task mapping v1.1 | Portable diagram to proposed task graph; semantic/presentational distinction | Intentionally stops before execution |
| AEF tasks and inception | Canonical work, review, criteria, human decisions | No task-bound instance machine |
| Context Fabric | Working/project/episodic memory, decisions, learnings, handovers | Not yet selected/materialised by executable node contract |
| Component Fabric | Code topology, dependency, blast radius, drift | Per-project coverage can be incomplete/unmeasured |
| BVP/change impact | Value and cost evidence; structural impact when measured | Not yet routing or runtime policy |
| TermLink | Cross-agent transport/co-ordination | Transport does not prove semantic job receipt or authorise execution |
| Provider adapters | Provider-specific launch/capability handling | No shared workflow action envelope |
| Watchtower | Operator visibility/review | No instance command/approval surface |

The earlier Workflow Process Layer proposal anticipated guided/strict modes, typed I/O, call-with-return, human touchpoints, component links, gated instance advance, and a future strict runner. Its formal disposition correctly records those as open. This dossier extends that thinking; it does not claim the open pieces already exist or silently alter frozen mapping v1.1.

## 6. End-state architecture

~~~
Authoring / operator plane
  Designer • procedure catalogue • visual live-instance view • review
                              │ validated, versioned definitions
Governance control plane
  validator • ratification registry • router • policy decision
  task binding • profile resolver • audit/evidence writer
                              │ approved action envelopes only
Runtime data plane
  instance state machine • dispatcher • provider adapters • workers
  human-gate notifier • wait/event listener • retry/compensation
                              │ scoped/redacted reads and writes
AEF substrates
  Tasks • Context Fabric • Component Fabric • BVP • TermLink • Watchtower
  project/worktree boundary • secret and capability providers
~~~

The control plane decides and enforces policy. The data plane performs bounded work. A worker must not replace validation, mutate a ratified definition, or approve its own escalation.

### 6.1 Definition and compilation

BPMN remains a valuable visual/interchange form. Execution should use a normalised intermediate representation compiled from semantic BPMN extension fields. The runtime must not scrape SVG, infer authority from layout, or execute browser-held state.

A future execution extension needs its own versioning and compatibility rules. It may be an explicit BPMN extension or a referenced companion manifest. The choice remains open until T-027 discovery compares validation, portability, auditing, and source-of-truth implications.

**Compatibility boundary:** frozen mapping v1.1 continues to compile a diagram
only into *proposed* governed work. It must not silently launch actions, bind a
task, ratify a definition, or change task authority. An executable procedure
therefore requires a separately versioned runtime-contract extension, explicit
human ratification, and a new validator/runner. This is a deliberate evolution
of the architecture, not a claim that the current Designer semantics already
provide execution.

Illustrative—not settled—node/edge contract:

~~~
procedure:
  id: feature-delivery
  version: 2.3.0
  status: ratified
  content_hash: sha256:...

node:
  uid: implement_change
  kind: agent_prompt
  outcome: changed_components_verified
  inputs: [approved_design, task_id, component_scope]
  outputs: [change_set, test_report]
  action_ref: prompt.implement_change.v4
  execution_profile_ref: implementation.standard.v2
  capability_profile_ref: repository.write_test.v1
  context_selectors: [decision:architecture, learning:relevant]
  timeout: PT30M
  retry: { max_attempts: 1 }

edge:
  from: implement_change
  to: review_change
  required_outputs: [change_set, test_report]
  guard: output.test_report.status == "passed"
~~~

The guard language must be constrained, typed, deterministic, and auditable; it must never be arbitrary code.

### 6.2 Bounded action vocabulary

| Node type | Purpose | Initial runtime boundary |
|---|---|---|
| human gate | Explicit operator choice/approval | Cannot auto-advance without mapped decision |
| script | Registered deterministic project script | Action-catalogue reference, typed args, project cwd |
| command | Bounded approved command template | No arbitrary shell interpolation |
| agent prompt | Bounded agent work/reasoning | Versioned prompt, resolved profiles, outcome checks |
| service | Approved external integration | Typed connector, redaction, idempotency/retry policy |
| call workflow | Invoke sub-procedure and await result | Explicit I/O map and cycle detection |
| wait event | Pause for timer/message/external fact | Bound event/correlation source and timeout |
| gateway | Legal branch decision | Declared conditions or human decision only |
| compensate | Declared corrective action | Explicitly bounded and separately authorised |

Start with a human gate and one registered deterministic script. Agent prompts, commands, services, and composition come later, after the state and authority boundary is proven.

### 6.3 Edges as interfaces

Each edge carries more than sequence order:

- legal predecessor and successor;
- named typed output-to-input mapping;
- outcome guard and required evidence;
- authority handoff/eligible actor type;
- retry, compensation, escalation, or terminal error route;
- instance/task/action correlation data.

This gives the “lines between diamonds” the contract semantics the vision requires.

### 6.4 Execution profiles and capability profiles

| Profile | Question answered | Examples |
|---|---|---|
| **Execution profile** | Who/what can execute this action? | agent role, provider adapter, eligible model class, budget, retry behaviour |
| **Capability profile** | What may that executor access? | skills, tools, MCPs, repository scope, opaque secret-binding names |

The procedure requests stable profile references. The runtime resolves them against project policy and provider support. It can refuse an action when the requested profile is unavailable or excessive. The resolved provider, model, profile versions, budgets, and material configuration are recorded in an attempt record; credentials are never recorded.

### 6.5 Secrets and external access

Workflow definitions, task files, Context Fabric, TermLink messages, and audit records contain only opaque secret-binding references, never secret values. A runtime adapter resolves a binding at the permitted execution boundary and returns a constrained capability handle. It must not expose a copyable secret to a diagram, prompt, log, or chat transcript.

### 6.6 Delivery artefacts are contract objects

The workflow must make the progression from idea to working application
explicit. User stories, technical descriptions, architecture decisions,
pseudocode, implementation changes, tests, reviews, and release evidence are
typed artefacts, not only prose inside node labels.

```text
user need / use case
  → user story + acceptance criteria
  → technical description + architecture decision
  → pseudocode / design contract
  → implementation change set
  → tests, review, and operational evidence
```

An edge declares which artefacts become inputs to the next stage and which are
produced or revised. A delivery procedure may require a human decision between
architecture and implementation, or let an agent produce a pseudocode proposal
that remains subject to review. The runtime records references, versions,
provenance, and validation status; it does not pretend that generated prose,
code, or tests are approved merely because they exist.

## 7. Runtime mechanics

### 7.1 Procedure lifecycle

~~~
draft → validate → proposed → human ratification → ratified
                                               │
                                   deprecate → successor version
~~~

Validation covers schema, graph integrity, typed I/O, reachable termination, action/profile reference resolution, human-gate mapping, component references, and policy constraints. Ratified definitions are immutable and content-hashed.

### 7.2 Routing and binding lifecycle

~~~
intake/event → candidates → eligibility/policy checks → recommendation
  → human decision or pre-authorised selection → bind task → create instance
~~~

Routing considers declared intent, task type, ownership, BVP, tier, component measurement/impact, required capabilities, provider support, and operator policy. It always produces an explanation. A routing rule never creates a task, ratifies a procedure, or bypasses a human gate.

### 7.3 Instance state machine

~~~
created → preflighted → ready → running → waiting ─┐
                         │       │                 │ resume
                         │       └→ paused ────────┘
                         │       └→ failed → compensating → failed|completed
                         └→ cancelled
running → completed
~~~

Every transition is append-only: identity, timestamps, source/target state, node/edge, reason, references to materialised inputs/outputs, and correlation IDs. A fast live projection may exist, but the append-only transition/audit record is recovery and audit authority. Operations are idempotent so a retry, lost response, or duplicate TermLink message cannot create duplicate effects.

### 7.4 Attempt outcomes and recovery semantics

An action attempt and a workflow instance have separate outcomes. The attempt
may be `succeeded`, `failed`, `timed_out`, `cancelled`, or `refused`. A refusal
means preflight or policy denied execution before side effect; it leaves the
instance at its current node with a recorded recovery requirement. A failed
attempt follows the node's declared retry, compensation, escalation, or
terminal-failure route. Only a legal transition changes the instance state.

This distinction makes an important operator question answerable: “did the
worker fail while doing authorised work, or did the runtime correctly prevent
an unsafe action from starting?” It also prevents a retry loop from treating a
missing approval or capability as a transient technical error.

### 7.5 Per-node sequence

1. Load the bound procedure version; verify ratification and content hash.
2. Verify current instance node and incoming-edge legality.
3. Resolve and type-check inputs.
4. Resolve Component Fabric scope/impact; treat missing coverage as unmeasured, never zero impact.
5. Materialise a redacted Context Fabric bundle from declared selectors.
6. Resolve execution/capability profiles via policy and provider adapter.
7. Append immutable action-attempt start with the resolved envelope.
8. Dispatch the bounded action locally or over TermLink with correlation and idempotency keys.
9. Validate declared outcome and evidence—not merely process exit status.
10. Record result and advance only through a legal satisfied edge.

### 7.6 Pause, resume, and continuity

Long-running agent work is normal. A pause records current node, inputs, context-snapshot references, latest attempt, unresolved checks, and exact resume condition. Provider session continuation is adapter-specific; instance continuity is provider-neutral. A resumed agent receives a durable fresh envelope rather than relying on an unbounded historic transcript.

## 8. How the AEF fabrics fit

### 8.1 Context Fabric: temporal and governance memory

Context Fabric tells the runtime what was decided, learned, assumed, happened, and remains active over time. Procedures use selectors/references for decisions, risks, assumptions, patterns, learnings, handovers, and episodic history.

The workflow must not duplicate mutable Context Fabric content. At execution, the runtime materialises a redacted, versioned snapshot and records its provenance. Successful/failed work may append new decision, learning, pattern, handover, or episodic references through the existing governed mechanism.

### 8.2 Component Fabric: spatial code topology

Component Fabric tells the runtime what code exists, how it relates, and what may be affected. Technical nodes may declare component IDs or a resolvable scope query. The runtime uses it for blast-radius preflight, verification selection, agent scope boundaries, post-action drift checks, and process-impact queries.

Component scope is agent-inferred but human-confirmed where policy requires. Insufficient coverage is an explicit operational state; the router or runtime must route it to policy, not quietly classify it as cheap or safe.

### 8.3 Workflow Fabric: the process-topology join

A future Workflow Fabric can be a derived, queryable graph of procedure/step/lane entities and flow, call, handoff, component, context, and inferred-dataflow relationships. It must not become a third hand-maintained copy of the other fabrics.

It enables the valuable cross-domain query:

~~~
changed component → affected technical steps → affected procedures
→ dependent procedures → affected human touchpoints
~~~

### 8.4 Other AEF primitives

- **Tasks:** work/evidence authority and instance binding.
- **BVP:** routing/sequencing input based on value, effort, tier, and measured structural impact; never self-approval.
- **TermLink:** correlated remote action transport. Transport delivery and semantic worker receipt are distinct, both evidenced states.
- **Watchtower:** operator surface for live state, approvals, refusals, evidence, pause/resume, and exceptional override—not a second state machine.

## 9. Authority, safety, and isolation

The effective authority of an action is an intersection:

~~~
ratified procedure version
  ∩ bound active task
  ∩ legal current node and edge
  ∩ node tier and completed human gates
  ∩ declared/verified component scope
  ∩ approved capability profile
  ∩ provider-adapter-supported execution profile
  ∩ selected repository and worktree boundary
~~~

If a term is absent or fails, execution is refused with the failed predicate, non-sensitive evidence, and lawful recovery route.

Each instance carries repository identity, common Git-directory identity, selected worktree, and execution root. It may access only approved same-project paths. Existing same-repository read capability does not justify cross-project access or host-wide discovery. The agent can propose a transition; the runtime validates and commits it. Human override is explicit, reasoned, scoped, and audited.

## 10. Operator and agent views

The same procedure should render in distinct lenses:

- **Business:** outcomes, roles, decision points, high-level status.
- **Logical:** interfaces, branch conditions, handoffs, sub-procedure calls.
- **Technical:** actions, scopes, profiles, evidence checks, Component/Context references.
- **Runtime:** live current node, attempts, elapsed time, pauses, refusals, approvals, outputs, and audit links.

The agent receives only the current node's material envelope: goal, completion criteria, task/procedure IDs, typed inputs, output locations, verified component scope, curated/redacted context, allowed skills/tools/MCPs, worktree scope, budget/continuity expectation, and legal success/failure/escalation routes.

## 11. Incremental delivery path

### Immediate: design work

1. Complete and review this dossier against actual AEF and Designer evidence.
2. Reconcile frozen mapping v1.1 with the proposed execution extension.
3. Specify action vocabulary, routing rules, refusal matrix, and invariants.
4. Decide source-of-truth/versioning boundaries and create a worked application procedure plus a routing procedure.

### First executable slice: guided, deterministic, single project

1. Validator plus immutable ratified-procedure registry.
2. One task bound to one instance with gated transitions.
3. Human gate, one registered script, typed I/O, evidence, and audit.
4. Component preflight with visible measured/unmeasured policy.
5. Tests proving refusal of unratified procedure, skipped gate, wrong worktree, invalid input, excessive capability, and duplicate transition.

### Intermediate: guided agentic execution

1. Versioned agent-prompt nodes and provider adapters.
2. Context selectors/snapshots and durable pause/resume.
3. Call-workflow, handoffs, Workflow Fabric derived index, and impact query.
4. Routing explanation/confidence and only narrow proven auto-binding.

### End state: composable multi-provider procedures

Procedures compose through explicit contracts and governed handoffs. Multiple providers serve eligible actions under one policy model while declaring their limits. Operators see procedure health, bottlenecks, human workload, impact, failed transitions, and learning feedback. This is an evidence-led evolution, not a single large build.

## 12. Hard problems that require explicit design

- Idempotency and duplicate message/result handling.
- Compensation for non-reversible external actions.
- Parallel branches, write-set conflicts, joins, deadlocks, and timeouts.
- Procedure-version migration for active instances.
- Event correlation and message authenticity.
- Meaningful outcome evidence beyond a command exit code.
- Prompt nondeterminism and model/provider substitution.
- Capability-policy drift after procedure ratification.
- Audit observability, privacy, redaction, retention, and secret safety.
- Limited-mode behaviour when Fabric coverage or context is incomplete.
- Cross-repository composition and TermLink identity/authorisation.

## 13. Initial acceptance scenarios

1. A proposed/unratified procedure cannot create an executable instance.
2. Unresolved action/profile references are refused before dispatch with a useful drift/refusal record.
3. A human gate cannot be skipped by agent, CLI, worker, or edited state.
4. A registered script receives typed permitted arguments and cannot execute from another repository/worktree.
5. Missing typed input prevents advancement even if a worker claims success.
6. Unmeasured component scope follows visible policy, never zero-impact logic.
7. Duplicate remote result is idempotent and cannot double-run or double-advance.
8. Unsupported provider capability causes governed refusal or human reroute, never silent substitution.
9. Resume uses a durable, redacted execution envelope with precise provenance.
10. A completed instance renders a visual trace plus linked task, evidence, decisions, component facts, and learnings.

## 14. Decisions deliberately left open

1. Execution-extension format and compatibility/versioning mechanism.
2. Runtime host/process and permission boundary.
3. Action-catalogue ownership and command-template language.
4. Constrained guard/outcome expression language.
5. Instance event-log/store and retention/redaction policy.
6. Routing automation bands and configuration authority.
7. Initial provider-adapter capability matrix.
8. Component Fabric coverage threshold and limited-mode policy.
9. Human override categories and compensation requirements.
10. Cross-repository composition and TermLink authentication boundary.

## 15. Grounding record

This dossier separates observed current capabilities from proposed design.

- [T-027](/opt/0503-codex-cli-playground/.tasks/active/T-027-evaluate-executable-workflow-contract-ru.md) — governing inception, assumptions, questions, and criteria.
- /opt/832-Workflow-designer/docs/standards/aef-bpmn-mapping-v1.md — frozen diagram-to-proposed-task mapping, semantic/presentational split, stable IDs.
- /opt/832-Workflow-designer/docs/aef-designer-integration-protocol.md and docs/designer/user-guide.md — Designer integration boundary and current I/O/handoff affordances.
- /opt/832-Workflow-designer/docs/proposals/aef-workflow-process-layer-2026-07-02/DISPOSITION-2026-07-28.md — guided execution, Workflow Fabric, component linkage, and strict runner are open rather than shipped.
- /opt/832-Workflow-designer/docs/proposals/aef-workflow-process-layer-2026-07-02/INSTRUCTIONS-workflow-process-layer-2026-07-02.md — prior detailed proposal for typed contracts, touchpoints, calls, gated transitions, and ratification; design input, not implemented fact.
- /opt/999-Agentic-Engineering-Framework/agents/context/AGENT.md and docs/articles/deep-dives/09-context-fabric.md — Context Fabric.
- /opt/999-Agentic-Engineering-Framework/docs/articles/deep-dives/07-component-fabric.md — Component Fabric.
- Local T-024/T-025/T-026 records — worktree isolation, continuity, and provider-adapter constraints discovered in this project.

## 16. Three-pass review record

| Pass | Review question | Result |
|---|---|---|
| 1 — conversation coverage | Does this capture visual executable-contract vision, interfaces/lines, procedure/router/instance distinction, operator/agent collaboration, agent/model/capability/secret needs, delivery artefacts, and value? | Pass: added explicit user-story → architecture → pseudocode → code/test artefact contract. |
| 2 — AEF grounding and safety | Does it distinguish current evidence from future design and preserve task authority, human sovereignty, Context/Component Fabric truth, provider honesty, and worktree isolation? | Pass: verified all cited sources; added explicit frozen-v1 compatibility boundary and separate-ratification requirement. |
| 3 — coherence and delivery | Are definition, routing, task binding, instance, runtime, profile, action, evidence, and transition boundaries coherent and incrementally testable? | Pass: added distinct action-attempt outcomes and refusal/recovery semantics; first deterministic slice remains bounded and testable. |
--- DOSSIER END ---
