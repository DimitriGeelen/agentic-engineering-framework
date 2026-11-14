# Executable Workflow Contract Runtime

**Status:** working architecture dossier — exploration, not implementation authorisation  
**Governance container:** T-027  
**Reviewed:** 2026-08-20 (Claude/AEF review incorporated under T-031)

## 0. Terminology and shorthand

Formal names are used on first reference. Any shorthand below is editorial
convenience only: it does not create, rename, ratify, or imply an existing AEF
or Workflow Designer capability.

| Term used here | Formal meaning and boundary |
|---|---|
| **AEF** | The **Agentic Engineering Framework** and its observed governed-work primitives. |
| **Mapping Standard** | The `AEF BPMN ⇄ task/inception-YAML Mapping Standard — v1.1`. Its **Part I — Frozen (v1)** is ratified/stable; Part II is provisional. |
| **frozen mapping** | Only the Mapping Standard's Part I. It does **not** mean the Workflow Designer, BPMN, the whole standard, or this runtime proposal is frozen. |
| **Designer** | The Workflow Designer reference implementation, unless a different conformant editor is expressly named. |
| **TermLink** | Agent-to-agent transport/co-ordination. Delivery to its hub is not proof of target receipt, understanding, authority, or action. |
| **runtime**, **runner**, **Workflow Fabric**, **procedure**, **router**, **workflow instance** | Proposed architecture vocabulary in this dossier, not shipped AEF primitives, except where a source is explicitly cited as an observed implementation. |

## 0.1 Definition, objective, and boundary

**Definition.** The **Executable Workflow Contract Runtime** is a proposed,
AEF-integrated control plane that turns a ratified workflow procedure into a
task-bound workflow instance. It coordinates human and agent work by allowing
only policy-validated transitions, executing only bounded approved action
types, materialising and validating the delivery artefacts between steps, and
recording redacted, durable evidence for every attempt and decision.

**Objective.** Prove, in one deterministic single-project pilot, that an
operator and an agent can advance a task-bound procedure through a human gate
and a bounded local action while the runtime independently:

1. refuses an unratified procedure, illegal transition, missing prerequisite,
   out-of-scope component/worktree, or forbidden capability;
2. preserves AEF task and human-decision authority rather than replacing it;
3. produces an inspectable, redacted record explaining what ran, under which
   procedure version, task binding, authority, inputs, executor, and outcome;
4. resumes lawfully after interruption without duplicating a completed action.

The broader product objective is to make the application-delivery method
itself executable and visible: use case/user story → technical description →
architecture decision/design → pseudocode/design contract → implementation →
verification/review/release evidence. Those are typed, versioned contract
objects and gates in a workflow—not merely labels beside agent prompts.

**Success criterion.** The pilot demonstrates both legal progress and each
specified refusal with reproducible evidence. A successful command alone is
not success; bypassing a control must be demonstrably impossible at the runner
boundary. The pilot runner must therefore execute outside the agent's OS
identity through an authenticated interface with runner-owned append-only
state. The operator still owns the choice between same-host user isolation and
a separate host/container.

**Non-objective.** This is not a general-purpose distributed scheduler, an
unrestricted agent shell, a replacement task system, a secret store, or an
attempt to make the Workflow Designer browser execute work. It also does not
alter the Mapping Standard's frozen Part I; a runtime contract is a separately
versioned extension.

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

The workflow does not replace AEF tasks. The procedure is the method; the task remains the canonical work/evidence record for acceptance criteria, BVP, approval, lifecycle, and completed-task history. A task binds to an instance; the task and instance refer to each other by stable IDs. Because task files and executable verification blocks are mutable by the working agent, the runner snapshots the bound task's content hash at every gate. Mutation between consumed gates is a policy event that requires revalidation or refusal.

### 2.5 Worked mechanism: pilot execution, evidence, and refusal

This is an illustrative **proposed** mechanism—not a claim that a runtime or
file format has already been shipped. It shows what must happen in practice and
what evidence would prove the pilot is real.

#### Scenario: verify a governed change

An operator owns AEF task `T-123`. The task requires a known test suite after a
change in one declared component. The router proposes the ratified procedure
`verification-gate@1.0`; the operator accepts that binding. The runner creates
instance `wi-0142`, pinning the procedure content hash, task ID, repository,
selected worktree, component scope, and allowed capability profile.

```text
1. Human gate: the task owner authorises verification for T-123.
2. Runner preflight: independently checks ratification, current task state,
   gate outcome, selected worktree, component scope, test-command allowlist,
   and capability profile.
3. Bounded execution: runner resolves the pre-approved test-suite reference
   and invokes it once inside the selected worktree.
4. Evidence capture: runner records the attempt identity, procedure/task
   hashes, policy decision, typed inputs, executor identity, timestamps,
   redacted output reference, exit outcome, and resulting instance state.
5. Human gate: the owner reviews the evidence and accepts or rejects it.
6. Task handoff: the evidence is attached/referenced from T-123; the task's
   own governed lifecycle remains the authority for any completion decision.
```

**Evidence of success** is not merely a zero exit code. The pilot passes only
if we can reproduce and inspect all of the following:

| Claim to prove | Required evidence |
|---|---|
| Legal execution occurred | Immutable instance/attempt record links the ratified procedure hash, task binding, allowed command reference, selected worktree, executor, inputs, and successful result. |
| Human authority held | The attempt cannot start before the recorded human-gate decision; task completion remains a separate governed task action. |
| Runner enforced the boundary | A direct agent/browser request cannot alter instance state or launch the action except through runner preflight. |
| Continuity is safe | After interruption, resume sees the prior completed attempt and does not invoke it a second time. |
| Evidence is usable | The operator can view a redacted trace and explain why the instance advanced. |

**Evidence of correct refusal** is equally required. The same pilot must show a
runner refusal—with no side effect and a durable refusal record—when an agent
tries to skip the human gate, use an unratified procedure, substitute a command,
select a different worktree/component scope, omit a required input, or request
a capability absent from the profile.

#### Scenario: later feature delivery

After the deterministic pilot is proven, a richer `feature-delivery` procedure
could make the collaboration method visible:

```text
operator frames outcome and constraints
  → agent performs bounded read-only impact analysis
  → operator approves an implementation option
  → agent makes a scoped change under a declared write capability
  → runner invokes deterministic verification
  → operator reviews evidence and makes the next task decision
```

The workflow makes the handoffs visible; the runtime enforces them. The agent
cannot broaden its scope, select a new procedure, self-approve, self-complete a
task, or treat a TermLink message as approval. Those actions require their own
policy route or a human decision.

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
| Mapping Standard v1.1 (Part I — Frozen) | Portable diagram to proposed task graph; semantic/presentational distinction | Intentionally stops before execution |
| AEF tasks and inception | Canonical work, review, criteria, human decisions | No task-bound instance machine |
| Context Fabric | Working/project/episodic memory, decisions, learnings, handovers | Not yet selected/materialised by executable node contract |
| Component Fabric | Code topology, dependency, blast radius, drift | Per-project coverage can be incomplete/unmeasured |
| BVP/change impact | Value and cost evidence; structural impact when measured | Not yet routing or runtime policy |
| TermLink | Cross-agent transport/co-ordination | Transport does not prove semantic job receipt or authorise execution |
| Provider adapters | Provider-specific launch/capability handling | No shared workflow action envelope |
| Watchtower | Operator visibility/review | No instance command/approval surface |

The earlier Workflow Process Layer proposal anticipated guided/strict modes, typed I/O, call-with-return, human touchpoints, component links, gated instance advance, and a future strict runner. Its formal disposition correctly records those as open. This dossier extends that thinking; it does not claim the open pieces already exist or silently alter the Mapping Standard's frozen Part I.

### 5.1 AEF and Workflow Designer ownership contract

The **Workflow Designer owns authoring and visualisation; AEF owns governance,
validation, authority, and execution**. This boundary is architectural, not a
temporary team convention. Neither side may silently absorb the other's
authority.

| Surface | AEF responsibility | Workflow Designer responsibility |
|---|---|---|
| Tasks, inception, approvals, BVP, and gates | Canonical owner and enforcer | Display/reference only; submit proposals through governed interfaces |
| Procedure/runtime semantics | Own canonical schemas, invariants, validation, refusal, ratification, and compatibility policy | Author conforming definitions and present validation results |
| Diagram/BPMN authoring | Supply semantic constraints and stable contract requirements | Own editing UX, layout, lanes, visual notation, import/export, and lossless round trips |
| Diagram → procedure mapping | Validate semantic output and preserve frozen Mapping Standard boundaries | Own compilation/export from visual representation to the versioned interchange contract |
| Runner, ledger, actions, identity, secrets | Sole authority for execution, isolation, event admission, capability/secret resolution, and evidence | Reference opaque profiles and render state; no execution credential or direct ledger write path |
| Context, Component, and Workflow Fabrics | Own canonical/derived records, version projection, and governed query semantics | Visualise and link records without cloning mutable truth |
| Runtime/operator interaction | Own authenticated proposal API and admission/refusal decision | Own interaction design; submit typed proposals and render the read-only projection |
| Provider adapters and model routing | Own capability manifests, qualified selection, refusal, and audit evidence | Expose declarative preferences only; never claim provider equivalence |

#### Shared versioned contracts

The two systems collaborate only through explicit versioned contracts:

1. **Procedure interchange contract:** stable procedure/node/edge IDs, typed
   I/O, action/profile references, human gates, and content hash.
2. **Mapping/compatibility contract:** which Designer/BPMN version produces
   which runtime-contract version, including lossless round-trip and migration
   rules.
3. **Validation/refusal contract:** structured diagnostics with stable codes,
   affected element IDs, failed predicates, severity, and lawful remediation.
4. **Runtime projection contract:** read-only instance/attempt/evidence state
   plus authenticated operator proposal types.
5. **Ratification contract:** an authored definition remains a proposal until
   AEF records the human decision; a Designer save/export never ratifies or
   executes it.

#### Collaboration and communication sequence

```text
Designer authors/exports proposed definition + content hash
  → AEF validates against exact contract version
  → AEF returns structured accepted/refused diagnostics
  → Designer presents correction or operator-ratification request
  → human ratifies through AEF authority
  → AEF binds task and executes through the runner
  → AEF emits versioned read-only runtime projection
  → Designer visualises state and submits typed operator proposals
```

Cross-agent coordination uses a named correlation/thread, immutable artifact
hashes, and TermLink transport. Hub delivery is not collaboration completion:
the receiver must read back the artifact/hash and return a substantive accepted,
refused, or needs-decision response. Changes to any shared contract require a
joint compatibility review and human-owned ratification; each implementation
remains governed in its own project.

#### Prohibited overlap

- Designer/browser code must not validate itself as authoritative, ratify a
  procedure, mutate runner state, resolve secrets, launch actions, or approve a
  gate.
- AEF/runtime code must not infer execution semantics from SVG/layout, become a
  competing diagram editor, or rewrite visual intent without a versioned
  diagnostic/migration response.
- Neither agent may edit the other project's files directly. It sends a
  versioned proposal; the receiving project evaluates and implements it under
  its own tasks and gates.

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

#### 6.2.1 Script and CLI invocation: registered action contracts

Scripts and CLI procedures are not incidental implementation detail; they are
the primary deterministic execution path. A workflow node names an
**action-catalogue reference**, never a free-form shell string. The catalogue is
versioned, validated, project-scoped, and approved alongside the procedure.

```yaml
# Illustrative contract, not a shipped file format
action: project.verified_test_suite
kind: script                         # `script` or `command`
implementation:
  path: tools/run-verified-tests      # repo-relative, allowlisted path
  content_hash: sha256:<pinned-hash>
  interpreter: /usr/bin/env bash      # policy-approved interpreter reference
invocation:
  argv: ["--component", "${component_id}"] # structured arguments, not shell
  cwd: selected_worktree
  environment: [CI=true]              # declared non-secret values only
inputs:
  component_id: { type: component_ref, required: true }
outputs:
  test_report: { type: evidence_ref, required: true }
controls:
  capability_profile: project-test-runner
  timeout_seconds: 900
  idempotency: run_once_per_instance_node_input_hash
  retry: none
  output_redaction_profile: test-output-v1
```

The runner resolves that reference only after node preflight. It verifies the
selected project/worktree, catalogue/procedure versions, implementation hash,
capability profile, typed inputs, allowed environment names, and idempotency
state. It invokes the resolved executable with structured `argv` semantics;
`sh -c`, shell concatenation, command substitution, ambient current-directory
inheritance, and unbounded inherited environment are outside the initial model.

`script` means an approved repository-relative implementation with a pinned
content hash and approved interpreter. `command` means an approved, structured
CLI invocation with a known executable identity/version policy; it is not “any
command the agent can formulate.” A procedure can also invoke another ratified
workflow through `call workflow`, but that is a typed instance-to-instance
contract—not a CLI shortcut around routing or authority.

Success requires the declared output/evidence validation as well as an allowed
exit outcome. The attempt record retains the action reference and resolved
version/hash, canonical argv with sensitive values redacted, cwd/worktree,
policy result, start/end times, executor identity, and output evidence
reference. This lets an operator later answer exactly which script or CLI
procedure ran, with what permitted inputs, and why the runtime allowed it.

#### 6.2.2 Failure, self-healing, and escalation are declared routes

Every executable node declares its failure routes as part of its contract. A
script/CLI failure never leaves an agent to improvise a recovery from ambient
permissions. The runner classifies the result and follows one declared route:

```yaml
# Illustrative continuation of the action contract
failure_routes:
  transient_failure:
    self_heal:
      action_ref: project.clean_test_artifacts  # separately registered action
      max_attempts: 1
      only_if: failure_class == transient_test_environment
    retry_original: once
  deterministic_failure:
    route_to: agent-diagnose-failure
  policy_refusal:
    route_to: operator-resolve-policy
  timeout_or_unknown_side_effect:
    route_to: operator-reconcile-attempt
```

**Self-healing** is not an agent's general permission to repair anything. It is
a separately catalogued, policy-approved remediation action with the same or
narrower project/worktree/component/capability scope, a fixed attempt budget,
an idempotency rule, and a post-remediation verification. It may run only after
a classifier matches its declared predicate. The remediation itself creates an
attempt record; only then may the original action retry.

**Agent escalation** is a bounded diagnostic handoff. The runner may create an
`agent-diagnose-failure` action envelope containing the failed attempt's
redacted evidence, declared scope, allowed read capabilities, and the exact
question to answer. The agent can classify, inspect, and propose a recovery;
it cannot execute an undeclared command, broaden scope, or approve its own
proposal. A recovery requiring a new script/CLI action, write capability,
changed procedure, changed task scope, or unclear side effect routes to the
operator/human gate.

**Human escalation** is mandatory for policy refusals, missing authority,
secrets/capability failures, exhausted retry/self-heal budgets, ambiguous
external side effects, divergent evidence, or any failure class the procedure
does not explicitly handle. The routed evidence bundle contains the procedure
and action hashes, attempt history, classifier result, redacted output,
proposed recovery (if any), and the decision requested.

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

The procedure requests stable profile references. The runtime resolves them against project policy and provider support on every attempt, not only at ratification. It refuses unavailable, excessive, or drifted profiles. The resolved provider, model, policy/profile versions, budgets, executor identity, and material configuration are recorded in an attempt record; credentials are never recorded. Ambiguous authorization failures must be disambiguated before selecting a recovery route.

### 6.5 Secrets and external access

Workflow definitions, task files, Context Fabric, TermLink messages, and audit records contain only opaque secret-binding references, never secret values. A runtime adapter resolves a binding at the permitted execution boundary and returns a constrained capability handle. It must not expose a copyable secret to a diagram, prompt, log, or chat transcript.

Output-redaction profiles are validated against known secret shapes before an
action type is admitted. Structured argv and typed output are invariants; a
shell escape or free-form execution path is a security regression requiring
re-ratification.

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

#### 6.6.1 The delivery chain is an executable collaboration contract

The workflow is the visible, executable agreement for how an application moves
from intent to trusted change. Each stage has a typed artefact contract, a
producer, a validator/gate, a permitted execution profile, and a lawful next
step. The chain is not a fixed waterfall: edges may route a rejected design
back to the story, an implementation failure back to pseudocode, or a changed
requirement back to an operator decision. What matters is that the loop is
explicit, typed, and evidenced.

| Stage | Contract object produced or revised | Typical executor | Required gate/evidence before advance |
|---|---|---|---|
| Discover | use case, user story, acceptance criteria, constraints | operator with agent assistance | operator confirms problem/outcome and scope |
| Specify | technical description, affected-component hypothesis, non-functional needs | agent analysis or architect/operator | typed inputs complete; impact uncertainty visible |
| Design | architecture decision, interfaces, data/error/security design | operator/architect, agent proposal | named decision owner accepts or returns for revision |
| Plan | pseudocode, change plan, test/verification plan | agent under read-only profile | plan is reviewable and bound to approved design/scope |
| Implement | scoped change set and implementation evidence | agent under declared write profile or human | scope/capability preflight; change provenance recorded |
| Verify | test reports, review findings, operational checks | registered script/CLI plus reviewer | declared verification and evidence validations pass |
| Decide/release | acceptance decision, release evidence, learning/handover | operator plus bounded integrations | human/governed release decision where policy requires |

An artefact carries at minimum: stable ID, type/schema version, content or
content reference/hash, status (`draft`, `proposed`, `accepted`, `rejected`,
`superseded`), producer and action-attempt provenance, declared inputs, and
validation/decision references. A node cannot simply claim it produced a
“design” or “code”; the runner checks that its declared artefact contract is
present and valid before an outgoing edge may be satisfied.

#### 6.6.2 Executor and model preference are policy inputs, not promises

Workflow authors may state an execution **preference** at every agentic or
automated stage: preferred agent role, model family/capability class, provider,
skills/tools/MCPs, budget/latency range, and required context/artifact access.
The preference remains declarative. At execution the runner resolves it through
the execution and capability profiles against live project policy and provider
support.

```yaml
# Illustrative node preference, not a provider grant or shipped format
node: draft-technical-description
execution_preference:
  agent_role: architecture-analyst
  model_capability: strong-reasoning
  provider_preference: [openrouter, local]
  skills: [component-impact-analysis]
  tools: [component_fabric_read]
  budget: { max_cost: low, max_duration_minutes: 10 }
fallback: operator_choose_or_refuse
```

The attempt record distinguishes the requested preference from the resolved
executor/model/provider and profile version. If no eligible executor satisfies
the hard requirements, the runtime refuses or routes to the declared human
choice; it does not silently substitute an unqualified model, expand tools, or
weaken a required gate. This lets the visual workflow show both the intended
collaboration method and the honest, provider-specific execution actually used.

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

Every transition is an immutable envelope in the runner-owned append-only event
ledger: per-agent authenticated identity, timestamps, source/target state,
node/edge, reason, bound-task content hash, materialised input/output references,
correlation IDs, and the prior accepted ledger position/hash. Host identity
alone is insufficient when agents are co-resident. Current state is a
deterministic fold of accepted envelopes; a cached projection may exist, but it
is never recovery or audit authority. Exactly one privileged service runner
validates and admits envelopes and re-verifies policy at execution time.
Operations are idempotent so retries, lost responses, or duplicate TermLink
messages cannot create duplicate effects.

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

Time is durable runtime input, not process memory. Every timeout, retry window,
wait-event deadline, routing deadline, lease, and TTL is recorded as an
absolute deadline event when admitted. After restart the runner folds the
ledger and evaluates overdue deadlines against its declared wall-clock source;
it never resets elapsed time. Duplicate timer evaluation is idempotent.

For the first pilot, cancellation takes effect at the attempt boundary. An
in-flight registered script runs to completion or its recorded timeout; the
runner records cancellation intent and refuses subsequent attempts or state
advancement except the declared reconciliation/compensation path.
Provider-specific mid-flight signalling is deferred until its side-effect and
acknowledgement semantics are explicitly designed.

Concurrent proposals use compare-and-append semantics against the last accepted
ledger position. If an agent transition races a human-gate outcome,
cancellation, or another transition, exactly one envelope is admitted and each
loser receives an immutable stale-position/conflict refusal record.

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

Wait-event correlation is runner-owned and keyed by instance ID. Hub delivery,
target enumeration, target acknowledgement, and semantic completion are
distinct evidenced states. Missing target enumeration surfaces to the operator
rather than leaving an instance silently waiting.

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

Its default version projection includes the `ratified-latest` procedure version
plus every historical version bound to a live instance. Other versions remain
queryable as historical records but do not silently participate in the default
component → step → procedure join.

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

Watchtower is an authenticated client of the runner, never a state-machine
writer or browser-side authority. Pause, resume, approval, cancellation, and
override interactions submit typed envelope proposals under the authenticated
operator identity. The runner independently admits or refuses them, and
Watchtower renders the resulting ledger projection read-only.

## 11. Incremental delivery path

### Immediate: design work

1. Complete and review this dossier against actual AEF and Designer evidence.
2. Reconcile frozen mapping v1.1 with the proposed execution extension.
3. Specify action vocabulary, routing rules, refusal matrix, and invariants.
4. Decide source-of-truth/versioning boundaries and create a worked application procedure plus a routing procedure.

### First executable slice: semantics-first, guided and deterministic

1. Validator plus immutable ratified-procedure registry.
2. One privileged service runner with an authenticated local interface and durable append-only event ledger; this slice may share the operator's OS identity but never an agent identity.
3. One task bound to one instance with task-content snapshots at both gates.
4. Human gate, one hash-pinned registered script, typed I/O, evidence, durable deadlines, attempt-boundary cancellation, and compare-and-append conflict refusal.
5. Component preflight with visible measured/unmeasured policy.
6. Per-agent authenticated attempt identity; host identity alone is refused as ambiguous.
7. Refusal tests for unratified procedure, skipped gate, wrong worktree, invalid input, excessive capability, policy drift, identity ambiguity, task mutation, duplicate/stale transition, concurrent gate/agent proposals, and deadline replay after restart.
8. Kill-mid-attempt resume without duplicate execution or timer reset.

### Mandatory second slice: boundary-isolation proof

1. Run the privileged service runner outside every agent OS identity and expose only the authenticated proposal interface.
2. Prove an agent user cannot edit ledger/state, launch registered actions, forge operator proposals, or bypass refusal through environment/force inputs.
3. Re-run the semantics/refusal suite across the isolated boundary and retain adversarial evidence.
4. Block agent-prompt nodes, external services, model routing, and any autonomy expansion until this slice passes.

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
- Durable time authority and restart-safe deadline evaluation.
- Cancellation intent, attempt-boundary semantics, and later provider-specific signalling.
- Concurrent envelope ordering and stale-position refusal.
- Procedure-version migration for active instances.
- Event correlation and message authenticity.
- Meaningful outcome evidence beyond a command exit code.
- Prompt nondeterminism and model/provider substitution.
- Capability-policy drift after procedure ratification.
- Audit observability, privacy, redaction, retention, and secret safety.
- Limited-mode behaviour when Fabric coverage or context is incomplete.
- Cross-repository composition and TermLink identity/authorisation.
- Per-agent identity and continuity across hub/service restart.
- Task mutation and executable-verification drift between runtime gates.
- Runner-owned event subscriptions when delivery and target enumeration diverge.

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
11. Agent-user edits cannot mutate instance state or launch a registered action.
12. A request carrying only shared host identity is refused as ambiguous.
13. Bound-task mutation between gates records hash drift and requires revalidation or refusal.
14. A reply delivered to the hub but never enumerated by the target becomes operator-visible and cannot deadlock the instance.
15. Ratification-to-attempt policy or capability drift follows a dedicated refusal route with versioned evidence.
16. Environment flags and `--force`-equivalent inputs cannot bypass the runner boundary.
17. A recorded deadline survives runner restart and cannot fire twice or reset its budget.
18. Cancellation during an in-flight pilot attempt prevents later advancement and routes only through declared reconciliation.
19. Racing agent and human-gate proposals admit exactly one envelope and preserve a refusal for the loser.
20. Watchtower cannot mutate state directly; every operator interaction is an authenticated proposal admitted or refused by the runner.

## 14. Decisions deliberately left open

1. Execution-extension format and compatibility/versioning mechanism.
2. Post-pilot runner isolation topology: same-host separate service user versus separate host/container. Out-of-agent-identity isolation is mandatory in slice two before autonomy expands.
3. Action-catalogue ownership and command-template language.
4. Constrained guard/outcome expression language.
5. Append-only event-ledger implementation, signing mechanism, retention, and redaction policy.
6. Routing automation bands and configuration authority.
7. Initial provider-adapter capability matrix.
8. Component Fabric coverage threshold and limited-mode policy.
9. Human override categories and compensation requirements.
10. Cross-repository composition and TermLink authentication boundary.
11. Per-agent identity scheme: independent keys versus runner-issued attempt credentials.
12. Workflow-bound task snapshot/immutability ergonomics and operator review policy.

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

## 17. Claude review dispositions

Source: `docs/reports/T-027-claude-aef-review-response.md`, reviewing dossier
SHA-256 `71465a3db6676f04f3dd120f68ddd25b4241cc86707f61c2cf0c3669b177b82f`.

| Finding | Disposition | Architecture effect |
|---|---|---|
| Runner trust boundary deferred | **Accept** | Out-of-agent-identity runner, authenticated interface, and runner-owned append-only state are pilot prerequisites; exact topology remains operator-owned. |
| Host-grade rather than per-agent identity | **Accept** | Per-agent authenticated attempt identity and ambiguity refusal added; credential scheme remains operator-owned. |
| Mutable task binding | **Accept with refinement** | Snapshot task content at each gate and treat mutation as policy drift; full task immutability remains an ergonomics decision. |
| Session-owned wait-event correlation | **Accept** | Runner-owned instance subscriptions and explicit delivery/enumeration/acknowledgement states added. |
| Ratification-to-attempt policy drift | **Accept** | Per-attempt resolution, version evidence, disambiguated authorization, and a dedicated refusal route added. |
| Structured actions/redaction invariant | **Accept** | Redaction-profile validation and shell-escape re-ratification requirement added. |

The review changes the first pilot from guided execution in the current trust
domain to a genuine enforcement-boundary proof. It does not decide the three
operator-owned implementation choices identified by Claude.

## 18. Z.ai review dispositions and operator decision

Source: `docs/reports/T-027-zai-review-response.md`, reviewing dossier SHA-256
`15f1469e8a9ae38a8800449a87401b78b17aa698f719f9205deb1a7b5fcb9b14`.

| Finding | Disposition | Architecture effect |
|---|---|---|
| Review-version drift | **Accept; corrected** | Protocol and dossier are pinned to the same current revision; future synthesis records each reviewed revision explicitly. |
| Control plane lacks deployment identity | **Accept with operator choice** | Exactly one privileged service runner admits envelopes and re-verifies policy; control-plane logic is not a second authority service. |
| Missing durable time authority | **Accept** | Absolute deadline events survive restart and are evaluated idempotently. |
| In-flight cancellation undefined | **Accept** | Pilot cancellation takes effect at the attempt boundary; provider signalling is deferred. |
| Watchtower authority contradiction | **Accept** | Watchtower is an authenticated proposal client and read-only projection, never a direct writer. |
| Workflow Fabric version ambiguity | **Accept** | Default joins project `ratified-latest` plus versions bound to live instances. |
| Ledger-native competing shape | **Accept as evolution constraint** | The service runner owns an append-only event ledger and deterministic fold, preserving a path toward smaller admission/executor components without requiring that decomposition in the pilot. |

### 2026-08-20 operator-owned decision

**GO:** use a **semantics-first** first executable slice, followed by a
**mandatory boundary-isolation proof** as slice two. Use one privileged service
runner with a durable append-only event ledger. No agent-prompt execution,
external-service actions, model routing, or autonomy expansion is permitted
until the isolation slice passes. This selects development order, not a
permanent weakening of the trust boundary.
