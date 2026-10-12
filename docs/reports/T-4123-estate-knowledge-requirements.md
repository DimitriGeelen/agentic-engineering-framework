---
title: "Estate knowledge platform — requirements (role chain step 1: requirements collector)"
task: T-4123
version: 0.1
date: 2026-10-12
status: collecting
---

# Estate knowledge platform — requirements

## 0 Version history

| Version | Date | Change | Task |
|---|---|---|---|
| 0.1 | 2026-10-12 | Skeleton; operator's framing captured; five stakeholder consults sent | T-4123 |

## 1 Why this document exists

ring20 operates a shared knowledge store for the estate (Qdrant 1.19.2, cluster mode, JWT RBAC, `_manifest`
collection, backups with a tested restore; ring20 T-2346). Nothing can write to it yet. The pipe (T-4091) was
about to be designed, but the operator stopped it there: first establish **what the platform is for and what it
must do**, then build the pipe.

Method: the ring20 **design role chain** (ring20-manager's T-2222 answer to AEF, 2026-10-04), step 1,
**requirements collector**: answers, glossary, R-n requirements with acceptance criteria, conflicts. Interactive
steps run in the orchestrator's session with the operator. Later chain steps (threat modeler, security floor and
phasing, architect, evidence, pseudo-code, external panel, planner) follow only after a GO.

## 2 Scope areas named by the operator (2026-10-12)

| Area | Operator's words (paraphrased) | Notes |
|---|---|---|
| A Content | what knowledge goes in, from where | today's per-project corpus: learnings, decisions, patterns, episodic summaries, completed-task summaries |
| B Curation | "pruning, collapsing, combining" | today only per project: `fw consolidate` (duplicates/stale), `fw promote` (learning → practice), `fw harvest` (project → framework, by hand) |
| C Retrieval | "then we also need to think about the retrieval" | how an agent asks, what comes back, ranking, cross-project scope, trust |
| D Fabric solution finder | "I'm working with this and this — which other applications already have elements, solutions or practices that would help us" | component fabric (`.fabric/`) across projects |
| E Model selection | default model, configurable, selectable from what Ollama has | arc-001 C3 (model manifest), P6; no model change on .107 before P1a/P1 |
| F Push interface | T-4091 | plumbing; designed after this is decided |
| G Error resolution | "store errors across projects with their resolutions, or even not if they do not have resolutions, then we can store the amount of times this happens" | overlap check: per-project healing patterns (`fw healing`, FP-n) and concerns (G-n); a host-level error service (skills `errors_*`, `/error-patterns`); arc-001 C1 telemetry is search telemetry, not errors. Proposed split: occurrences are telemetry (stay local / error service); the error class with its resolution status and occurrence count is knowledge (store) |

## 3 Facts established so far

- Embedding model: `nomic-embed-text-v2-moe` (768 dims) fixed in `web/config.py:64`, overridable only by env
  `FW_EMBEDDING_MODEL`; not in `fw config`, not in Watchtower, no Ollama listing, no guard against mixing.
- Embedding host: per install, default `localhost:11434`; silent failover between hosts is arc-001 finding F-7.
- arc-001 (T-4017, GO 2026-10-11): C3 model manifest, C12 tenant/project tags and search interface, search kept
  separate from storage, all to fit the central store; benchmark (C2) gates model changes.
- Collection naming already proposed by dimitri-mint-dev / ring20: `<tenant>__<scope>__<model-slug>-<dims>`
  behind an alias; payload fields tenant, project, item_type, content_hash, source_path, model_id, model_digest.

## 4 Stakeholder consultation

Five agents, each a user or operator of the platform, get the same brief plus one question specific to them.
Answers are stored unedited in section 7 and synthesised into sections 5, 6 and 6.1.

| Stakeholder | Why them | Sent | Answer |
|---|---|---|---|
| dimitri-mint-dev | pilot tenant; arc-001 author; owns requirements A9.7 | 2026-10-12 | 2026-10-12 → `T-4123-inputs/01-dimitri-mint-dev.txt`, area G: `01b-dimitri-mint-dev-G.txt` |
| proxmox-ring20-management (ring20-manager) | operates the platform; author of the role chain | 2026-10-12 | — |
| 832-Workflow-designer | designer corpus; heavy fabric user | 2026-10-12 | acked (their T-1141), answer within the day |
| 010-termlink | cross-project transport; a different codebase (Rust) | 2026-10-12 | acked, answer within a day (host incident) |
| 1409-sprind | German-language project; own focus-anchor practice | 2026-10-12 | — |

055-agentic-fleet-cockpit was the intended fifth stakeholder; its receiver rejected the send twice with HTTP 401
after the host reboot (filed as T-4124). 1409 was asked instead; 055 can be added once its receiver accepts.

Per-stakeholder questions: dimitri-mint-dev — what verification convinces you, which A9.7 items are hard;
ring20-manager — operating constraints, plus the full requirements-collector and _common role cards;
832 — fabric search useful vs noise, is the designer corpus knowledge; 010 — non-Python and remote hosts,
which TermLink learnings others should find; 1409 — non-English knowledge, practices others should find.

## 5 Glossary (draft)

| Term | Meaning |
|---|---|
| Estate | all projects and hosts the operator runs |
| Tenant | top-level owner partition in the store (e.g. `estate`) |
| Item | one stored unit of knowledge (a learning, decision, pattern, summary, fabric card …) |
| Prune | remove an item that is stale, wrong or superseded, everywhere it was pushed |
| Collapse | merge items that say the same thing into one, keeping every source |
| Combine | synthesise related items (possibly across projects) into a higher-order item, e.g. a practice |

## 6 Requirements (R-n) — to be collected

(empty until the consultation and the operator dialogue fill it)

## 6.1 Conflicts — to be collected

## 7 Unedited answers

### 7.0 Brief as sent

Verbatim in `docs/reports/T-4123-inputs/00-brief-as-sent.txt`; `{TO}` and `{SPECIFIC}` were filled per recipient
(section 4). Answers will be stored unedited beside it, one file per stakeholder.

## Dialogue Log

- **2026-10-12, operator:** stop designing the pipe (T-4091); first think about what the platform is.
  Everyone uses the same model because the framework configures it, and the same GPU Ollama — is that right?
  → Agent checked: model yes (fixed default, env-overridable), host no (per install, default localhost); same
  name does not guarantee the same model digest.
- **Operator:** make the model selectable from what Ollama offers, with a default, configurable. → Agent agreed;
  fits arc-001 C3 (scope area E).
- **Operator:** knowledge-building practices: building, pruning, bundling; then "pruning, collapsing,
  combining" explicitly. → scope area B.
- **Operator:** the component fabric as a cross-project solution finder ("what do other applications already
  have that would help us"). → scope area D.
- **Operator:** "then we also need to think about the retrieval." → scope area C.
- **Operator:** "first think about what it is"; use the role-based format from ring20-manager; then "go talk with
  5 different agents externally to get input, design input." → this document, role chain step 1, five
  stakeholder consults.
- **Operator:** another category, error resolution: errors across projects with their resolutions, or without
  when there is none, plus how often each happens; "a little more telemetry, I don't know if I start overlapping."
  → Agent checked existing pieces (healing FP-n, concerns, host error service, arc-001 C1 is search telemetry)
  and proposed the event/knowledge split; unresolved classes seen in several projects flagged as a priority
  signal. Added as scope area G and IW-6; follow-up question sent to the stakeholders.
