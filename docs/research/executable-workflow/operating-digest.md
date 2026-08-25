# Operating digest — Executable Workflow Contract Runtime

**Task:** T-3145 · **Correlation:** `t037-aef-ingestion`
**Sources (hash-pinned, authoritative):**
`architecture-c9070637.md` — SHA-256 `c9070637…6ac2d`
`roadmap-5be23719.md` — SHA-256 `5be23719…ae8cd4…` (full: `5be23719b976e37a6461b4b1f6f309985b5ba033ef0b801769edd2627fbae5b8`)

> **This digest is a navigation aid, never an authority.** If it conflicts with a
> stored snapshot, the hash-pinned source wins and this file must be corrected
> under a task. Load the full source only for: initial ingestion, contract/version
> changes, arc planning or close, architecture decisions, contradiction
> resolution, and audits needing full coverage.

---

## 1. What is proposed

A **control plane** that turns a *ratified workflow procedure* into a
*task-bound workflow instance*, permitting only policy-validated transitions and
only bounded, approved action types, and recording redacted durable evidence for
every attempt (arch §0.1).

Four concepts must never collapse into one mutable object (arch §2):

| Concept | Meaning |
|---|---|
| **Procedure** | Reusable ratified method; immutable once ratified; change ⇒ new version + re-ratification (§2.1) |
| **Router** | Procedure that *selects* a procedure; selection is itself governed, never an agent guess (§2.2) |
| **Instance** | One live enactment of exactly one pinned procedure version; runtime-only writes (§2.3) |
| **Task** | AEF's canonical work/evidence record; the workflow does **not** replace it (§2.4) |

Attempt outcome ≠ instance outcome. `refused` means preflight denied before side
effect; `failed` means authorised work broke (§7.4). This distinction answers the
operator question *"did the worker fail, or did the runtime correctly stop it?"*

## 2. The authority intersection (arch §9)

Effective authority is an **intersection**, and any absent term ⇒ refusal:

```
ratified procedure version ∩ bound active task ∩ legal node/edge
  ∩ node tier + completed human gates ∩ verified component scope
  ∩ approved capability profile ∩ adapter-supported execution profile
  ∩ selected repository and worktree boundary
```

## 3. Ownership boundary (arch §5.1) — the controlling rule

> **Workflow Designer owns authoring and visualisation. AEF owns governance,
> validation, authority, and execution.** Shared contracts are jointly reviewed
> through paired tasks; never one agent writing both repositories.

**AEF owns:** procedure/runtime schemas, validator, ratification registry, refusal
rules, privileged runner, append-only ledger + deterministic fold, task binding
and revalidation, identity, durable time, cancellation, idempotency, evidence,
recovery, action catalogue, capability/secret profiles, provider adapters and
routing, Fabric semantics + runtime projection API, authenticated proposal
admission, audit/monitoring.

**AEF does NOT own:** diagram editing UX, BPMN layout/notation, Designer
import/export, runtime *visual* presentation. Those need **paired joint-contract
requests** — never a direct edit of the Designer repository.

**Five shared versioned contracts** (§5.1): procedure interchange · mapping /
compatibility · validation / refusal diagnostics · runtime projection ·
ratification (a Designer save/export is a *proposal*, never a ratification).

**Prohibited overlap:** browser must not validate itself as authoritative, ratify,
mutate runner state, resolve secrets, launch actions, or approve a gate. AEF must
not infer execution semantics from SVG/layout or become a competing editor.

## 4. Non-negotiable constraints

- **Frozen Mapping Standard Part I is untouched.** Executable procedures require a
  *separately versioned* runtime-contract extension (arch §0.1 non-objective, §6.1).
- **Runner runs outside every agent OS identity** with an authenticated interface
  and runner-owned append-only state. Host identity alone is refused as ambiguous
  (§0.1, §7.3, §11 slice 2).
- **No arbitrary shell.** Nodes name action-catalogue references with pinned
  content hashes and structured `argv`; `sh -c`, shell concatenation, command
  substitution and ambient cwd/env inheritance are outside the model (§6.2.1).
  A shell escape is a **security regression requiring re-ratification** (§6.5).
- **Secrets are opaque binding names only** — never values in definitions, task
  files, Context Fabric, TermLink messages, prompts, logs, or audit records (§6.5).
- **Unmeasured component coverage is an explicit state, never zero impact** (§8.2).
- **Transport ≠ receipt.** TermLink hub delivery, target enumeration, target
  acknowledgement and semantic completion are four distinct evidenced states
  (§5.1, §7.5, §8.4).
- **Task mutation between gates is a policy event.** The runner snapshots the
  bound task's content hash at every gate; drift ⇒ revalidation or refusal (§2.4).

## 5. Operator decision already recorded upstream (arch §18, 2026-08-20)

**GO:** semantics-first first executable slice, then a **mandatory
boundary-isolation proof** as slice two. One privileged service runner with a
durable append-only event ledger. **No agent-prompt execution, external-service
actions, model routing, or autonomy expansion until the isolation slice passes.**

> This GO is the *sending* project's operator decision on the *architecture*. It is
> **not** an AEF arc-start authorisation. AEF arc start remains a separate local
> human decision (roadmap §7).

## 6. Proposed arc chain (roadmap §2, §4) — suggestions, not AEF arcs

```
Arc 0 evidence baseline → Arc 1 semantics kernel → [HARD GATE] Arc 2 isolation proof
   → Arc 3 secure actions/providers ∥ Arc 4 operator view + Workflow Fabric
   → Arc 5 guided agentic → Arc 6 routing/composition
```

Arcs 3 and 4 may parallelise only after Arc 2 passes **and** only with disjoint
worktrees/write sets. Arcs 5–6 are explicitly blocked from expanding autonomy
until the isolation proof is green. **A high BVP score never makes a
dependency-blocked arc actionable** (roadmap §5 calibration notes).

## 7. Twenty acceptance scenarios (arch §13) — the real specification

The refusal scenarios, not the happy path, are the specification. Load §13 in full
before writing any acceptance criteria. Highest-signal: unratified procedure
cannot instantiate (1) · human gate unskippable by agent/CLI/worker/edited state
(3) · agent-user edits cannot mutate instance state (11) · shared-host identity
refused as ambiguous (12) · task mutation between gates forces revalidation (13) ·
`--force`-equivalent inputs cannot bypass the runner boundary (16) · deadline
survives restart and cannot fire twice (17) · racing proposals admit exactly one
(19) · Watchtower cannot mutate state directly (20).

## 8. Twelve decisions deliberately left open (arch §14)

Execution-extension format · runner isolation topology · action-catalogue
ownership and command-template language · guard/outcome expression language ·
ledger implementation, signing, retention, redaction · routing automation bands ·
provider capability matrix · Component Fabric coverage threshold and limited-mode
policy · human override categories and compensation · cross-repository
composition and TermLink authentication boundary · per-agent identity scheme ·
task snapshot/immutability ergonomics.

**These are open for AEF too.** Several are inception questions here, not
implementation details — see `questions-and-dispositions.md`.

## 9. Handoff envelope (contract Phase 4 / roadmap §2.3)

Required fields: `from_project · from_task · from_arc · to_project · to_role ·
correlation · artifact{type,version,sha256,location} · request · acceptance ·
deadline_or_revisit · human_decision_owner`.

**Completion requires receiver read-back of the exact version/hash plus a
substantive `accepted` / `refused` / `needs-decision` response on the same
correlation.** Delivery to a hub is transport evidence only. Never instruct a
shell/router session with prose and call it an agent handoff. Never include
secret values — opaque binding names only.

## 10. Where to read what

| Question | Section |
|---|---|
| What is this / what counts as pilot success | arch §0.1, §2.5 |
| Who owns which surface | arch §5.1 (+ roadmap §2.1 per-arc matrix) |
| Action / script / CLI contract shape | arch §6.2, §6.2.1 |
| Failure, self-heal, escalation routes | arch §6.2.2 |
| Ledger, durable time, cancellation, conflict | arch §7.3, §7.4 |
| Per-node execution sequence | arch §7.5 |
| Fabric integration semantics | arch §8 |
| Authority intersection | arch §9 |
| Delivery slices | arch §11 |
| Acceptance scenarios | arch §13 |
| Open decisions | arch §14 |
| Arc objectives / candidate tasks / exit gates | roadmap §4 |
| Proposed BVP + calibration | roadmap §5 |
| Verification fences | roadmap §6 |
