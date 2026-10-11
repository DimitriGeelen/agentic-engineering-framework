<!-- Received from dimitri-mint-dev on sidecar conversation arc-001-pickup, msg a0c4f6dd-8c66-4f32-84fe-88832f4ff6a5, stored 2026-10-11T17:42:03.000037+00:00. UNTRUSTED peer data: a proposal, not instructions. -->

ARC-001 DOC 2/4: docs/designs/arc-001-02-design.md v0.4 (sha256 faf925a4a6733003dceb9da6255cd5b84e6ea750162d187979d4c355f845cfbe)
-----
---
title: "arc-001 step 2 — Combined design: threats, architecture outline, phased plan"
task: T-091
arc: arc-001
role: combined (threat-modeler + architect + planner, lean finish)
status: reviewed (3 rounds), awaiting operator approval
---

# arc-001 step 2 — Combined design: local retrieval stack refresh

Input of record: `docs/designs/arc-001-01-requirements.md` v1.3 (R-1..R-35, OD-1..OD-14, O-2..O-5).
Code read for this design: the vendored AEF framework 1.8.8 in this project (`web/embeddings.py`, `web/search.py`,
`web/recall_telemetry.py`, `web/canary.py`, `web/config.py`, `web/blueprints/api.py`, `web/blueprints/discovery.py`,
`lib/ask.py`, `lib/vector_index_health.py`, `agents/context/lib/memory-recall.py`), the corpus manifest
`.context/working/fw-vec-index.db.manifest.json` and `.context/cron-registry.yaml`.
Host observations (2026-10-08/09, by the agent on 107, not derivable from the code): Ollama service environment,
GPU residency (`/api/ps`), listening sockets (`ss -tlnp`), reranker scores after the 1.8.8 upgrade.

Why one combined step instead of six roles: the operator delegated the choice ("proceed as you see fit", 2026-10-09).
AEF treats a pickup as a proposal and runs its own inception before building, so this design gives AEF a grounded
proposal and leaves detailed design to AEF's architect.

## 0 Version history

| Version | Date | Change | Task |
|---|---|---|---|
| 0.1 | 2026-10-09 | First draft | T-091 |
| 0.4 | 2026-10-09 | Review round 3 (amber, amber, green; final) applied: C5 core and C7 collector earlier, AC-19.1 split, P1c needs the R-20 window, cloud fallback OFF until OD-15, Watchtower ask GET, untelemetered paths, health pause for age/lag/cron, P5 switch protections, backfill at upgrade, traceability and D-5 text; not re-reviewed (round cap) | T-091 |
| 0.3 | 2026-10-09 | Review round 2 (amber, amber, green) applied: phase ordering (P1a, P1c, tooling vs operational ACs), F-9/F-10 query-text paths, `fw ask` consumer degradation, recall consumer arm, GPU baseline first, client-list re-validation, touchpoints mapped, OD-15 pending | T-091 |
| 0.2 | 2026-10-09 | Review round 1 (amber, amber, green) applied: K-1..K-13; consumer path map; findings F-4..F-8; C12, C13; P0 order; AC placement; operator touchpoints; OD-13/OD-14 | T-091 |

## 1 Current state — what AEF already has (1.8.8)

### 1.1 Consumers and their code paths

| Consumer | Code path | Fusion | Reranker |
|---|---|---|---|
| `fw ask`, MCP `ask` | `lib/ask.py` → `rag_retrieve`, then a local chat model; on an Ollama connection error a cloud fallback to `claude-via-litellm` (F-10); prompt captured by `resolver.capture_dispatch` when a workflow resolves (F-9) | own dense KNN + Tantivy BM25, RRF K=60 | yes (`rerank()` at the end of `_rag_retrieve`) |
| Watchtower ask (`/api/v1/ask`) | `web/blueprints/api.py` → `web.ask` and the LLM manager → `rag_retrieve` | as above | yes |
| `fw recall` (agent recall, the operator's first priority, A1) | `agents/context/lib/memory-recall.py`: `hybrid_search` with a widened pool, filtered to Project Memory, hits mapped back to knowledge items, a YAML keyword fallback, and open tasks appended by keyword | `search` (dense) + Tantivy BM25, RRF K=60 | **no** |
| Watchtower search page | `web/blueprints/discovery.py` / `api.py` | mode-dependent: BM25 only, dense only, or `hybrid_search` | no |
| `/recall`, `/query-knowledge` | old knowledge Qdrant (to be retired, R-26) | — | — |

(MCP `ask` is assumed to reach `lib/ask.py`; AEF to confirm.) Watchtower search is a `GET` with the query in the URL
(`/api/v1/search?q=…`), so request logs can hold query text (F-9).

### 1.2 Components today

| Area | Exists today | Gap against the requirements |
|---|---|---|
| Keyword search | Tantivy BM25 (`web/search.py`): index at the fixed path `/tmp/fw-search-index`, shared by every project on the host; `en_stem` tokenizer only; file-level documents; rebuilt from the live tree when older than 60 s | Not per project, not multilingual, not chunk-level, not reproducible (R-15 as worded in v1.3; AC-5.1); mixes projects (F-4) |
| Fusion | RRF in `hybrid_search` and separately in `_rag_retrieve` | Not measured; not gated per store (R-15); `fw recall` has no reranker (F-5) |
| Reranker | Fixed in 1.8.8 (T-3953): graded yes/no log-odds, WARNING per failed pair; uses `OLLAMA_HOST` (the chat client), not the embed hosts. Verified here: 0.9993 vs 0.0 | Silent paths remain: `_rerank_available()` false → RRF order returned with no flag; a failed pair scores 0.5 among real scores; no telemetry flag; no doctor check (R-8) |
| Telemetry | `web/recall_telemetry.py`: one row per query (ts, surface, query_hash, n_hits, top_score, latency_ms, outcome); file mode 0644 | Missing caller, store, language, score spread, reranker state, degradation (R-1). **Miss/unavailable rows carry query text** (F-1; temporary exception OD-14) |
| Index health | `lib/vector_index_health.py`: index, manifest, import, age, lag, canary top hit, cron, token; usage as WARN; wired into doctor, audit, handover | Framework index only; no recall@5 trend (R-9); age check would FAIL while a store is held at a snapshot (C6 must account for it) |
| Model identity | Corpus manifest records `model`, `embedding_dim`, chunk settings | No digest, licence, placement, candidate/active, approvals; no writer refusal (R-10..R-13) |
| Rebuild | `build_index` builds in a scratch copy and replaces the old index (`os.replace`, old index not kept); disk and lock guards; `reindex_incremental`; **`index-reindex-hourly` cron** in every seeded project | No verify-then-switch against a manifest; no snapshot kept; no rollback; no morning report (R-22..R-24); hourly cron is daytime bulk work (R-18) and could write with the old model around a switch (F-6) |
| Placement | `FW_EMBED_HOST` / `FW_EMBED_BULK_HOST`; automatic failover between them (`_fallback_host`, WARN log only) | Failover can embed with a different model or on CPU without notice (R-11, R-17; F-7); no per-model metrics (R-20) |
| Evaluation | None upstream | Harness, benchmark format, gates (R-3, R-5, R-6) |
| Approvals | Human-AC tick provenance via Watchtower | Not applied to deciding records; Watchtower listens on `0.0.0.0:3014` with `FW_SECRET_KEY` empty by default (F-8); agents run as root on 107 (R-34, O-5) |

Host observations: Ollama on 107 listens on `0.0.0.0:11434`, `OLLAMA_MAX_LOADED_MODELS=3`, `OLLAMA_NUM_PARALLEL=3`,
`OLLAMA_KEEP_ALIVE=5m`; Voxtype's gemma4 (3.3 GB) and the embedder (0.6 GB) were co-resident on a 16 GB GPU.
Agents push to OneDev with its `admin` account (credentials in `/root/.git-credentials`).

### 1.3 Findings for AEF

F-1 **Query text on miss rows** (`recall_telemetry.py`, AEF T-3019). Conflicts with R-32. AEF will add a per-project
switch under T-3967. Until then this project keeps telemetry (OD-14): text stays local, the file is git-ignored, and
`query` fields are purged when the switch lands.
F-2 **Two fusion paths** (`hybrid_search`, `_rag_retrieve`); the benchmark measures each path a consumer uses.
F-3 **Ollama open on the LAN** (`0.0.0.0`): R-21/R-35's known-clients rule needs a firewall or proxy.
F-4 **Shared, English-only keyword index in `/tmp`**: results can mix projects and change every minute.
F-5 **`fw recall` is never reranked**, although agent recall is the operator's first priority (A1).
F-6 **Hourly reindex cron** does bulk embedding by day and is unaware of manifests and night runs.
F-7 **Silent embed failover** between hosts can mix models or fall back to CPU without notice.
F-8 **Watchtower on `0.0.0.0` with an empty secret key**: approval and search endpoints are reachable from the LAN.
F-9 **Query text kept outside telemetry**: `resolver.capture_dispatch` writes the rendered `fw ask` prompt (with the
query) to a `prompt.txt` blob when a workflow resolves; Watchtower's GET search and GET ask (`/api/v1/ask`, `/api/v1/ask/stream` accept `?q=`) put the query in request
logs. Both conflict with R-32.
F-10 **Cloud fallback in `fw ask`**: on an Ollama connection error the query and the retrieved chunks go to
`claude-via-litellm`, an external model. Allowed or not is operator decision OD-15 (proposal: allowed for
framework stores, which hold no email, as A6.2 allows; never for email stores; always visible in the answer and
telemetry).

## 2 Threats (per security requirement)

| Req | Threat | Design response | Residual |
|---|---|---|---|
| R-8 | Reranker unavailable, partially failing or constant; search still "succeeds" | Every rerank call returns a status: ok / partial (n failed pairs) / unavailable / constant; any non-ok sets telemetry `reranker=degraded` and logs WARN; doctor runs a probe pair and fails when the model is absent or the pair is not separated; the observed degraded state from the last 24 h is shown by doctor | A varied but wrong score is caught only by the benchmark and canaries |
| R-11, R-12 | A writer, a failover host or a re-pulled digest writes or queries with a different model | Before any write and on every query path, the code checks model, digest (Ollama `/api/show`) and dimension **on the host actually used**, again after any failover; mismatch refuses the write and marks the query degraded | — |
| R-7, R-34 | An agent forges an approval (agents run as root on 107; same commands, same Watchtower) | Deciding records are signed with an **operator key held off 107** (OD-13): preferred a FIDO2 hardware key (signature needs a touch), alternative a key on the operator's phone. 107 keeps only the public key; consumers verify the signature over the record's hash, never the channel | Until the operator chooses and enrols a key (P1 entry condition), R-34 is not met; a phone-held key is weaker than hardware |
| R-35, F-8 | A LAN host reaches Watchtower approval endpoints, Ollama or Qdrant; a key is sniffed off plain HTTP | Watchtower bound to localhost or behind authentication with a non-empty secret; Ollama firewall to known clients; Qdrant API keys plus TLS or a Qdrant-side allow-list; OneDev: agents get their own non-admin account (local task) | Keys on 107 are readable by root agents; signing (R-34) covers approvals, not data access |
| R-4, R-14, R-32 | Email or query text reaches an external model or a log | Every embed/rerank route, including failover, is validated against the configured local estate (AC-14.1); Penelope evaluation local only; reports by query id; telemetry without text once F-1 lands; dispatch capture stores a hash or is off for retrieval prompts (F-9); Watchtower search via POST or query-stripped logs; cloud fallback per OD-15 and never for email stores; rejected drafts deleted | Temporary local miss text (OD-14) |
| R-18, R-19 | Bulk work or a bigger model evicts gemma4; dictation lags | A baseline and an approved stop threshold exist before the first GPU-affecting stage (P1a), including the P1 harness and rerank workloads; night window; the hourly cron throttled by day and paused during night runs; signal: a proxy in front of 11434 that sees in-flight interactive requests, or a periodic gemma4 latency probe; pre-stage baselines for gemma4 and the chat models | `MAX_LOADED_MODELS=3` can still evict under unusual load; telemetry and the probe show it |
| R-22, R-24 | A night run fails half-way; the hourly cron writes during a switch | Night runner takes the index lock and pauses the cron; build beside or snapshot first (today's `os.replace` does not keep the old index, so retention is new work); verify; previous index serves on failure; automatic revert after failed post-switch checks; crontab overlap check before scheduling | A failure in the revert itself; morning report and doctor show it |
| R-25 | A model is removed while a store or rollback window still needs it | Removal eligibility check over every manifest entry (active, candidate, retained) and every open rollback window, run before an approved removal executes | — |
| R-26 | The clean-up deletes Penelope data | Named collections only, snapshot each, compare Penelope point counts before and after; keys in place first (P0 order) | — |

## 3 Architecture outline (components)

Owner in brackets: AEF = framework upstream; 050 = Penelope owner; here = dimitri-mint-dev with the operator.

C1 **Telemetry extension** [AEF] — rows gain caller, store, language (local detector), score spread, reranker state,
degradation; per-project switch for miss-row text (F-1); purge tool for existing `query` fields; file mode 0600.
Rows also for paths that write none today: Watchtower search in keyword mode, and `fw recall`'s YAML keyword
fallback and open-task search (R-1 says every search). Retention scope beyond telemetry: dispatch capture of retrieval prompts (F-9), Watchtower request logs, harness and
canary outputs; AC-32.1's marker test runs with workflow capture enabled. Serves R-1, R-32.
C2 **Benchmark store and harness** [AEF] — per store: a draft area for candidates (deleted after pruning, R-32) and
versioned frozen sets (approved queries only; ids, judged relevant chunks, language, type) frozen by an
operator-signed record. Harness CLI runs, for each consumer path in §1.1, the arms dense-only, keyword-only, fused
(pre-rerank, capturing recall@20/@50) and fused+rerank; it pins a keyword-index snapshot per run so AC-5.1 holds;
reports by query id. For `fw recall` it also runs a consumer-level arm over the command's real output (knowledge
items, YAML fallback, appended tasks), with relevant items defined as knowledge items. Serves R-2, R-3, R-5, R-6,
R-15.
C3 **Model manifest** [AEF schema; each owner keeps its entries] — per store an `active` and optional `candidate`
entry (model, digest, dimension, prefixes, licence, source, placement) plus signed approval references. Writers and
readers resolve models only through it; an env override (`FW_EMBEDDING_MODEL` / `FW_RERANKER_MODEL`) is accepted
only when it matches an operator-signed entry, otherwise refused (AC-29.1). Endpoint validation against the local
estate on every route including failover. Serves R-10..R-14, R-29.
C4 **Reranker and search health** [AEF] — rerank status (§2 R-8), doctor probe and 24 h degraded view; canary runs
daily with a recall@5 trend in `vector_index_health`. Serves R-8, R-9.
C5 **Signed deciding records** [AEF; core (sign, verify, hash binding) in P1a, the rest in P1] — manifest changes, Gate 2, freezes, parameters, placement, licence exceptions,
manual rollbacks and removals are records signed with the operator's off-host key (OD-13) and bound to their hash;
verification uses only the public key on 107. Includes the operator touchpoint list (§5.2). Serves R-7, R-31, R-33,
R-34.
C6 **Night runner** [AEF] — takes the index lock and pauses the hourly cron; build beside or snapshot then rebuild;
verify; promote the approved candidate; post-switch checks; automatic revert; snapshot retention for 7 days (the
health age check treats a held snapshot as intended, not stale); removal eligibility check; crontab overlap check;
morning report. Pause and throttle states (C6, C7) are written where `vector_index_health` reads them, so doctor
reports an intended pause instead of an age, lag or cron FAIL. Serves R-22..R-25.
C7 **GPU guard and placement metrics** [AEF] — day-time throttle for the hourly cron and other bulk work; signal from
a proxy on 11434 (also serves F-3) or a gemma4 latency probe; pre-stage baselines for gemma4 and chat models;
per-model request rate, latency (GPU/CPU), VRAM/RAM, CPU cores, load/unload events over the 14-day window; failover
to CPU off unless enabled, loud when used. Its baseline and stop rule (gemma4 and chat latency, run-to-run variation)
are delivered first, in P1a, before any GPU-affecting stage; its per-model metrics collector ships in P1, so the
R-20 window runs during P1b. Serves R-17..R-20.
C8 **Estate hardening** [here] — in order: client inventory (R-21), Qdrant API keys and TLS or allow-list, Ollama
firewall to the inventory, Watchtower bound to localhost or authenticated with a secret, agents' own OneDev account
instead of `admin`. Serves R-21, R-35, F-3, F-8.
C9 **Retirement of the old knowledge collections and `/sync`** [here] — after C8's keys; snapshot and drop seven
collections, repoint `/recall` and `/query-knowledge`, retire `/sync` and its keys. Serves R-26.
C10 **Penelope adoption** [050] — telemetry rows, manifest entry, writer refusal, sparse vectors, local evaluation, own
benchmark. Serves R-1, R-4, R-11, R-15 for Penelope.
C11 **Open WebUI** [here] — embedder setting from the manifest; feasibility of telemetry, tags, writer refusal and
digest pinning (O-2).
C12 **Item tags and search interface** [AEF] — every item an AEF writer stores carries tenant, project, model and
digest; existing items backfilled by a metadata migration run at `fw upgrade` (no re-embedding needed); consumers reach search through one interface independent of
the storage backend. Serves R-11 (per-item identity), R-30.
C13 **Keyword index and degradation** [AEF] — a per-project, multilingual, chunk-level keyword index (for example sqlite
FTS5 beside the vectors) replacing the shared `/tmp` Tantivy index for these paths; degradation ladder when the
embedder is down (keyword-only, which today's `_rag_retrieve` cannot do because it embeds first) and when the
reranker is down. Covers `fw ask` as a consumer: with Ollama down it returns keyword results and a degraded notice
instead of raising. Until the operator decides OD-15, the cloud fallback is OFF by default (today an Ollama outage
would otherwise route every `fw ask` to the external model once retrieval survives); when allowed, an externally
answered response says so in the answer and in telemetry. Serves R-15, R-16.

## 4 Phased plan

A phase is done when its acceptance criteria are met and the operator is told. "Tooling" criteria prove a mechanism
on fixtures; "operational" criteria need real data (a frozen benchmark, approved parameters) and sit in the phase
where that data exists.

| Phase | Owner | Content | Entry condition | Phase acceptance criteria |
|---|---|---|---|---|
| P0 Estate | here | C8 in order (inventory → Qdrant keys/TLS → Ollama firewall → Watchtower → OneDev account), then C9 | — | AC-21.1, AC-35.1, AC-35.2, AC-26.1 |
| P1a Signing and GPU baseline | AEF tooling, here | C5 core (sign, verify, hash binding); C7 baseline and stop rule; measure gemma4 and chat run-to-run variation; operator signs the stop threshold (R-33) | operator key enrolled (OD-13, O-5) | AC-34.1..34.3 on the threshold record; stop on an injected slowdown with the cause logged (AC-19.1 first half) |
| P1 Measure | AEF | C1 (incl. F-9 scope and the untelemetered paths), C4, C2 (draft area, harness, freeze records, recall arm), C5 (rest), C7 metrics collector | P1a | AC-1.1 (one query per consumer path in §1.1), AC-1.2, AC-32.1 (capture enabled, incl. Watchtower ask), AC-8.1, AC-8.2, AC-9.1, AC-5.1, AC-5.2, AC-27.1 (second AEF project); AC-33.1 on a fixture (citation mechanism) |
| P1b Benchmark and window | here (operator time) | Drafts (~150), operator prunes, rejected drafts deleted; 14 days of telemetry; freeze; R-20 metrics window (collector from P1) in parallel | P1 (incl. the collector) | AC-2.1, AC-3.1, AC-3.2, AC-32.2, AC-20.1 |
| P1c Parameters | evidence, operator | Propose R-33 values from P1b measurements (latency p95 limit from the harness and the R-20 window, canary tolerance, hybrid margin); operator signs them | P1b complete, incl. the 14-day R-20 window | parameter record signed (input to AC-33.1) |
| P2 Identity and search | AEF | C3, C12, C13, C7 (rest) | P1 (build may start); closes after P1c | tooling: AC-10.1, AC-11.1, AC-12.1, AC-13.1, AC-14.1, AC-15.2, AC-16.1, AC-17.1, AC-17.2, AC-29.1, AC-30.1, AC-31.1; operational: AC-15.1, AC-18.1. C13's cloud fallback ships OFF unless OD-15 is decided |
| P3 First switch | AEF tooling, here | C6; candidate (e.g. qwen3-embedding) through Gate 1 and Gate 2 on this project's framework index | P2 closed, P0's client list re-validated (≤30 days, WV) | AC-6.1, AC-7.1, AC-10.2, AC-19.1 (full: cause in the morning report), AC-22.1, AC-23.1, AC-24.1, AC-24.2, AC-14.2, AC-30.1 for items rebuilt here, AC-33.1 (on the real Gate 1 report) |
| P4 Penelope | 050 | C10 with its own benchmark, drafted locally | P0 (Qdrant keys), P3 + 7 days without rollback, client list re-validated | AC-4.1, AC-4.2, AC-14.1 for Penelope's routes, and P1-P3 criteria applicable to that store |
| P5 Open WebUI | here | C11; smoke benchmark (OD-9 allowance); Gate 1, Gate 2, night-run verification and rollback as for other stores, within O-2's feasibility | P4 + 7 days without rollback, client list re-validated | AC-28.1, AC-6.1, AC-7.1, AC-10.1 for its entry, AC-22.1, AC-24.1 (or O-2's recorded exemption) |
| P6 Upstream default | AEF | Default model change after a second corpus | P3; client list re-validated | AC-29.2 |
| any removal | AEF tooling, operator | C6 eligibility check, signed record | window passed; client list re-validated (AC-21.1) | AC-25.1 |

Not in this arc: the central knowledge server (T-090), which builds on C2, C3 and C12.

## 5 Pickup scope and operator touchpoints

### 5.1 Scope fence

AEF builds C1-C7, C12, C13 (framework code, schema, CLI), each shippable through `fw upgrade` and demonstrated in a
second AEF project (AC-27.1). AEF does not build C8, C9, C11 (this project with the operator) or C10 (050). AEF does
not choose the model; the first switch (P3) runs in this project under its operator's gates. AEF's default (P6) is
AEF's own decision.

### 5.2 Operator touchpoints (AC-31.1)

Approvals (each maps to R-31's list; each is a record signed with the operator's off-host key):
1. Query-set pruning and freeze per store — R-3 (P1b, P4, P5).
2. Manifest changes — R-10; each is the record of one of items 3-6 or 8, never separate.
3. Model switch, Gate 2 side-by-side confirmation — R-7 (P3, P4, P5).
4. Placement per model — R-17 (when proposed).
5. Parameter values — R-33 (P1a stop threshold, P1c the rest).
6. Non-open licence — R-13 (when proposed).
7. Manual rollback within 7 days of a switch — R-24 (optional).
8. Model removal — R-25 (when proposed).
Non-approval duties: enrol the signing key once before P1a (OD-13); read the morning report after each night run.
AEF's default change (R-29, P6) is AEF's operator's decision.

## 6 Open items

O-2 Open WebUI feasibility (telemetry, tags, writer refusal, digest pinning). (AEF architect / here)
O-3 Qdrant dual-index form: separate collection vs named vectors. (050 / AEF architect)
O-4 First values for every R-33 parameter, from P1b and P2 measurements. (evidence, operator)
O-5 Signing mechanism and device: FIDO2 hardware key (preferred) or phone-held key; enrolment and recovery when the
key is lost. (AEF architect with the operator; P1 entry condition)
O-6 Miss-row query text switch and purge (F-1). (AEF T-3967)
O-7 Interactive-load signal for C7: proxy on 11434 vs gemma4 latency probe. (AEF architect)
O-8 Cloud fallback in `fw ask` (F-10): DECIDED by the operator as OD-15 (2026-10-10): allowed for framework stores,
never for email stores, always marked external in the answer and telemetry. C13 ships it ON for framework stores only.

## 7 Traceability (requirement → component → phase)

| Req | Component | Phase | Req | Component | Phase |
|---|---|---|---|---|---|
| R-1 | C1 | P1 | R-19 | C7 | P1a (baseline, stop), P3 |
| R-2 | C2 | P1b | R-20 | C7 | P1 (collector), P1b |
| R-3 | C2 | P1b | R-21 | C8 | P0, P3, P6 |
| R-4 | C10, C2 | P4 | R-22 | C6 | P3 |
| R-5 | C2 | P1 | R-23 | C6 | P3 |
| R-6 | C2 | P3 | R-24 | C6 | P3 |
| R-7 | C5 | P3 | R-25 | C6, C5 | any removal |
| R-8 | C4 | P1 | R-26 | C9 | P0 |
| R-9 | C4 | P1 | R-27 | C1-C7, C12, C13 | P1 (AC-27.1) |
| R-10 | C3 | P2 | R-28 | plan | P3-P5 |
| R-11 | C3, C12 | P2 | R-29 | C3 | P2, P6 |
| R-12 | C3 | P2 | R-30 | C12 | P2 |
| R-13 | C3 | P2 | R-31 | C5, §5.2 | P2 |
| R-14 | C3, C8 | P0, P2, P3 | R-32 | C1, C2 | P1, P1b |
| R-15 | C13, C2 | P2 | R-33 | C5, C2 | P1a, P1c, P3 |
| R-16 | C13 | P2 | R-34 | C5 | P1a, P1 |
| R-17 | C7, C3 | P2 | R-35 | C8 | P0 |
| R-18 | C7 | P2 | | | |

## 8 Drawings

**Drawing D-4 — components and owners**

```mermaid
flowchart LR
  subgraph AEF["AEF framework (fw upgrade to every project)"]
    C1["C1 Telemetry<br/>no query text"]
    C2["C2 Benchmark + harness"]
    C3["C3 Model manifest<br/>active / candidate"]
    C4["C4 Reranker + canary health"]
    C5["C5 Signed deciding records"]
    C6["C6 Night runner"]
    C7["C7 GPU guard + metrics"]
    C12["C12 Item tags + search interface"]
    C13["C13 Keyword index + degradation"]
    S["Search paths<br/>rag_retrieve, hybrid_search"]
  end
  subgraph HERE["dimitri-mint-dev with operator"]
    C8["C8 Estate hardening"]
    C9["C9 Retire old collections + /sync"]
    C11["C11 Open WebUI"]
  end
  subgraph P050["050 Penelope"]
    C10["C10 Penelope adoption"]
  end
  KEY["Operator signing key<br/>off host 107"]
  S --> C1
  C2 --> S
  C3 --> S
  C4 --> S
  C13 --> S
  C12 --> S
  C6 --> C3
  C6 --> C7
  C5 --> C3
  C5 --> C2
  KEY -->|signs| C5
  C8 --> C9
  C10 -.->|reuses| C2
  C10 -.->|reuses| C3
  C11 -.->|reads| C3
```

Textual equivalent of D-4:
1. AEF builds C1-C7, C12 and C13 around the existing search paths; every project gets them through `fw upgrade`.
2. The harness (C2), manifest (C3), health (C4), keyword index and degradation (C13) and item tags (C12) shape search;
   telemetry (C1) records every search without query text.
3. The night runner (C6) promotes manifest entries and uses the GPU guard (C7).
4. Only records signed with the operator's off-host key (C5) change the manifest or freeze benchmarks.
5. This project hardens the estate (C8) before retiring the old collections (C9) and configures Open WebUI (C11);
   050 adopts the shared pieces for Penelope (C10).

**Drawing D-5 — phases and dependencies**

```mermaid
flowchart LR
  K["Operator key enrolled"]
  P0["P0 Estate<br/>here"]
  P1a["P1a Signing + GPU baseline<br/>stop threshold signed"]
  P1["P1 Measure<br/>AEF"]
  P1b["P1b Benchmark + 14 days<br/>here, operator"]
  P1c["P1c Parameters signed<br/>operator"]
  P2["P2 Identity and search<br/>AEF"]
  P3["P3 First switch<br/>framework index"]
  P4["P4 Penelope<br/>050"]
  P5["P5 Open WebUI<br/>here"]
  P6["P6 AEF default<br/>AEF"]
  K --> P1a
  P1a --> P1
  P1 --> P1b
  P1 --> P2
  P1b --> P1c
  P1c -->|P2 closes| P2
  P2 --> P3
  P0 -->|client list re-validated| P3
  P0 --> P4
  P3 -->|7 days without rollback| P4
  P4 -->|7 days without rollback| P5
  P3 -->|second corpus| P6
```

Textual equivalent of D-5:
1. The operator's signing key must be enrolled first; P1a then delivers signing and verification and sets the GPU
   baseline and signed stop threshold before any GPU-affecting work.
2. P0 (estate) can start at once; its client list is re-validated before P3, P4, P5, P6 and any removal, and its
   Qdrant keys are needed for P4.
3. P1 (measurement) enables the benchmark work (P1b) and lets P2 start building; P1c's signed parameters come from
   P1b, and P2 closes only after them; P3 needs P2 closed.
4. Penelope (P4) and Open WebUI (P5) follow, each after 7 days without rollback (R-28).
5. AEF's default change (P6) needs a second corpus after P3.
