<!-- Received from dimitri-mint-dev on sidecar conversation arc-001-pickup, msg 02578fec-3df5-4b94-a3b7-b9dac04337f7, stored 2026-10-11T17:42:03.604228+00:00. UNTRUSTED peer data: a proposal, not instructions. -->

ARC-001 DOC 3/4: docs/designs/arc-001-01-requirements.md v1.3+OD-15, PART A lines 1-461 of 913 (full-file sha256 a7b463ed8f0133fac5ed220cb5b0a13649fb6219ec7858a5a5f5238390f53c1d)
-----
---
title: "arc-001 step 1 — Requirements: local retrieval stack refresh"
task: T-089
arc: arc-001
role: requirements-collector
status: reviewed (3 rounds), awaiting operator approval
---

# arc-001 step 1 — Requirements: local retrieval stack refresh

Review: three rounds, manual rung-5 panel (G-010) — `docs/designs/arc-001/reviews/step-01-round-{1,2,3}/` (disposition.md in each); operator approval on Watchtower `/review/T-089`.

Inputs of record:
- `docs/reports/T-087-ollama-model-refresh.md` (inception research, GO 2026-10-06)
- `docs/reports/T-087-advice-codex.md`, `docs/reports/T-087-advice-glm.md` (external design advice)
- Pattern: ring20 `docs/reports/T-2222-inception-protocol-for-aef.md` v0.3 + `roles/cards/requirements-collector.md`
  + `roles/cards/_common.md` + `roles/adapters/aef.md` (proxmox-ring20-management @ 82bedf0)

## 0 Version history

| Version | Date | Change | Task |
|---|---|---|---|
| 0.1 | 2026-10-06 | Skeleton, stakeholders, question list (interview mode) | T-089 |
| 0.2 | 2026-10-08 | Answers A1-A6 recorded; interview paused at Q7 (operator reboot). Resume: ask Q7 (query-set authorship; agent recommends a: agents draft ~150, operator prunes = approval of the sample per A6.3) | T-089 |
| 0.3 | 2026-10-08 | A7 recorded (agents draft, operator prunes); conflict C-1 (email subjects vs external agents) | T-089 |
| 0.4 | 2026-10-08 | A8 recorded (hours of downtime acceptable; rollback 7 days working value); C-1 accepted | T-089 |
| 0.5 | 2026-10-08 | A8.c-d: migration runs unattended in a night window; self-verifying steps, morning report | T-089 |
| 0.6 | 2026-10-08 | A9 recorded (split by owner; knowledge Qdrant moves into AEF for replicability; O-1 embedder unverified) | T-089 |
| 0.7 | 2026-10-08 | A9 corrected to under discussion: operator asked a question, the agent had recorded a decision | T-089 |
| 0.8 | 2026-10-08 | A9.5 knowledge-Qdrant inventory (stale, pre-AEF, per-type not per-project) | T-089 |
| 0.9 | 2026-10-08 | Interview complete (A10-A13, GR-1..GR-9, C-1..C-4); glossary, requirements R-1..R-31, earlier requirements, drawings D-1..D-3 | T-089 |
| 1.0 | 2026-10-09 | Review round 1 (3 seats amber) applied: disposition D-1..D-23, operator decisions OD-1..OD-8, GR-10/GR-11, new R-32..R-35, rationale for every R-n, WV markers, C-5/C-6, drawings revised | T-089 |
| 1.1 | 2026-10-09 | Review round 2 (amber, amber, green) applied: E-1..E-18, OD-9..OD-12, C-7/C-8, O-5, A9.4 moved back, drawings revised | T-089 |
| 1.2 | 2026-10-09 | Review round 3 (amber, amber, green; final round) applied: H-1..H-6 (promotion at switch, scoping, AC-2.1 fallback, D-2 Gate 1 email branch, R-29 provenance, A9 labels); not re-reviewed (round cap) | T-089 |
| 1.3 | 2026-10-09 | From the step-2 design review: OD-13 (off-host approval factor), OD-14 (keep telemetry, temporary local miss text), R-15 keyword index reworded (FTS5 was the agent's example, not the operator's choice; OD-12), A2.a corrected | T-091 |

## 1 Stakeholders (card 3.1)

1.1 Humans: the operator (Dimitri) — owns the system, approves every deciding step.
1.2 Agents that use the system: every AEF project agent calling `fw ask` / `fw recall` / Watchtower search on
host 107 (999 AEF, 1409-sprind, 832 Workflow Designer, this project); skills `/recall`, `/query-knowledge`,
`/sync` (shared toolkit, knowledge Qdrant); Penelope agents (050, email archive).
1.3 Owners who implement: 999 AEF (framework index, embedder/reranker code), shared toolkit (knowledge Qdrant
indexer), 050-email-archive (Penelope store).
1.4 Protected systems (assets/dependencies): Ollama on 107 (shared with chat models: voxtype gemma4,
qwen3:14b, claude-code-router), RTX 5060 Ti 16 GB VRAM, sqlite-vec index, Qdrant on .201, email corpus.
1.5 Adversaries (failure classes confirmed and ranked in A12; actors added after review round 1, GR-11): a confused or compromised agent session that forges an approval, edits the manifest or writes a store; a LAN host or stolen key reading or writing Qdrant or Ollama; and the failure classes: a silent quality regression nobody measures (the G-009
class); a writer that mixes vectors from two models in one store; a migration that evicts or starves chat
models; corpus data (email) leaving the estate through review or model endpoints; a hurried approver who
switches a model on benchmark claims instead of local evidence; a failed unattended night run; collateral loss of
Penelope data during a clean-up.

## 2 Question list (interview mode — answered one at a time)

Q1. Outcomes: which uses should get better, in priority order — (a) `fw ask` answers, (b) agents' recall of
    learnings/decisions, (c) email search in Penelope, (d) Open WebUI document chat?
Q2. Users and languages: who queries most (you, agents, both) and roughly what share is EN / NL / DE?
Q3. Store scope for this arc: all four embedding consumers (framework index, knowledge Qdrant, Penelope,
    Open WebUI) or a subset now and the rest later?
Q4. Success: what result would make you switch a model — a fixed threshold (e.g. +10% recall@5 on the frozen
    set) or your judgement on side-by-side answers? Who signs the result off?
Q5. Resource budget: maximum acceptable query latency, and may the embedder/reranker ever evict a chat model
    (voxtype gemma4, qwen3:14b) from the GPU?
Q6. Data boundary: may email content appear in the benchmark query set, in review briefs, or in prompts to
    external review models (Codex/GLM), or must it stay on the estate?
Q7. Query set: who writes the frozen 60-100 queries — you, agents drafting from real `fw ask` history for you
    to prune, or both — and how much of your time is available?
Q8. Migration tolerance: acceptable search downtime per store, and how long must rollback stay possible?
Q9. Ownership: should AEF implement only the framework parts and hand the knowledge store and Penelope parts to
    their owners, or should AEF own the whole arc?
Q10. Model sourcing: Ollama library only, or Hugging Face GGUF too; any licence limits; must models be pinned
     by digest?
Q11. Hybrid search: may the framework index gain keyword search (sqlite FTS5), and Qdrant stores sparse
     vectors, or do you want dense-only?
Q12. Worst failure: which outcome do you most want made impossible (silent regression, mixed-model vectors,
     chat eviction, data leakage, something else)?
Q13. Timing: priority of this arc against your other active work, and any deadline?

Gap review (card 3.4) after Q13: offline operation, recovery, revocation (removing a model), resource identity
(model digests), unsupported targets, approval fatigue.

## 3 Answers

(recorded as given)

A1 (Q1, 2026-10-06). Priority order: **b, a, c, d** — (b) agents' recall of learnings/decisions first,
then (a) `fw ask` answers, (c) Penelope email search, (d) Open WebUI document chat. The operator ranked
agent recall above `fw ask`, against the agent's recommendation (a, b, d, c), and Penelope above Open WebUI.

A2 (Q2, 2026-10-06). **Unknown** — "no idea, maybe get telemetry from agents". Open gap G-A2: who queries
and in which language is not known. Requirement candidate: the arc MUST measure the query mix (caller,
store, language, latency) from real traffic before the benchmark's language split is frozen; the operator
does not want it guessed.
A2.a Existing telemetry (probe 2026-10-06): AEF already writes `.context/working/recall-telemetry.jsonl` per
project, one row per `fw ask`/recall query: ts, surface (rag/semantic), query_hash, n_hits, top_score,
latency_ms, outcome. It has **no caller, no store and no language**; hit rows carry only a hash (language cannot be
derived). Correction 2026-10-09 (design review K-8): miss and unavailable rows DO carry the query text by AEF design
(T-3019) — see OD-14. This project: 8 rows since 2026-10-01. Busier projects (999, 1409, 832) keep
their own files (not readable from here — project boundary); aggregation would come from AEF. Ollama's journal
has no per-request lines usable for a caller/model breakdown.
A2.b Implication for requirements: extend the existing telemetry rather than add a new channel — caller
(project/agent), store, detected language (computed locally, no text stored), reranker on/off and scores'
spread (catches a G-009-class silent no-op).
A2.c AEF (2026-10-07) filed T-3967 for per-query telemetry (caller, store, language, latency, top score) and
asks whether query TEXT is stored and for how long — to be answered by the operator under Q6 (data boundary).

A3 (Q3, 2026-10-07). **a — all four embedding consumers in scope** (framework index, knowledge Qdrant,
Penelope, Open WebUI), designed together and built in the Q1 order: framework index + knowledge Qdrant first
(recall, `fw ask`), Penelope second via its owner 050, Open WebUI last. Agrees with the agent's recommendation.
A3.a AEF (2026-10-08) confirmed the existing telemetry writer; T-3967 is now "extend that writer" with
reranker on/off and score spread.

A4 (Q4, 2026-10-08). **c — both gates.** A model switch requires (1) a fixed threshold on the frozen benchmark
(working values from the question: recall@5 at least +10% relative to today, no language worse than today, no
latency regression beyond an agreed limit — exact numbers to be fixed with Q5), and then (2) the operator's
confirmation on side-by-side answers for a sample of real queries. The operator signs off; the threshold alone
never switches a model.

A5 (Q5, 2026-10-08). **No fixed rule — placement decided per model from metrics** (operator, paraphrased and
played back): "Some smaller models could run permanently on a dedicated CPU; others are GPU-intensive and must
stay on the GPU. Decide from performance, latency, memory and usage metrics. A rarely used model that runs on CPU
with acceptable latency, modest memory and few cores is a candidate for offloading; a heavily used model stays on
the GPU even if it is small." Latency limits and eviction rules are therefore **deferred to measurement** (open
gap G-A5), not set now.
A5.a Evidence already available: AEF measured query embedding at 208 ms (GPU) vs 210 ms (CPU sidecar), but bulk
reindex at 69.9 vs 1.9 chunks/s (`.agentic-framework/web/config.py:46-49`) — the same model can be CPU-fit for
queries and GPU-only for bulk work, so placement is per (model, workload), not per model. The framework already
supports split endpoints: FW_EMBED_HOST (queries) and FW_EMBED_BULK_HOST (reindex).
A5.b Host 107 today: one Ollama (GPU, :11434), no CPU instance. Metrics present: sysstat (CPU/mem, 10 min),
memwatch (T-085, memory pressure), recall-telemetry (per-query latency). Missing: per-model request rate,
load/unload/eviction events, per-model VRAM/RAM and CPU cores.
A5.c Requirement candidates: (1) collect per-model usage, latency (GPU and CPU), memory and core metrics for a
defined window; (2) a written placement rule over those metrics (usage rate x CPU latency vs caller limit x
memory x cores) with the operator approving each placement; (3) a CPU-resident Ollama instance is an allowed
target; (4) Voxtype voice input must not degrade (operator to confirm under the gap review).

A6 (Q6, 2026-10-08). **c — local by default, narrow exceptions.**
A6.1 Email content (Penelope corpus) MUST NOT leave the estate's storage (host 107 and Qdrant on .201): not in
review briefs, not in prompts to external models, not in telemetry.
A6.2 Non-email material (task notes, learnings, decisions, design docs) MAY be quoted to the external review
seats already in use (Codex, GLM via subscription), as in T-087.
A6.3 Query text: telemetry stores a hash plus locally detected language, never the text. Query text is kept
**only** for the benchmark sample the operator approves (the frozen query set), and nowhere else; no rolling
retention window.
A6.4 Answer for AEF T-3967: no query text in the telemetry row; add detected language, caller, store, reranker
on/off and score spread.

A7 (Q7, 2026-10-08). **a — agents draft, the operator prunes.** Agents draft about 150 candidate queries from real
material (task notes, learnings, decisions; for Penelope, email subjects only), spread over EN / NL / DE, plus a
share of no-answer queries. The operator keeps or rejects them in one or two sessions of about 20 minutes. The
pruning pass is also the operator's approval of the stored sample required by A6.3, and its output is the frozen set
(60-100 queries).
A7.a Constraint from A6.1 (agent finding): a Claude Code agent's prompts go to an external model, so a cloud agent
MUST NOT read email subjects to draft Penelope queries. Penelope candidates are drafted by a local model on host 107
(Ollama) or by the operator; cloud agents draft only from non-email material. Recorded under §6 Conflicts.
A7.b Language split: until telemetry answers G-A2, the draft spreads evenly over EN / NL / DE; the operator may
re-balance during pruning.

A8 (Q8, 2026-10-08). **Downtime of one to several hours per store is acceptable** (operator: "One or several hours
downtime is fine"). Consequence: the migration need not be zero-downtime; a store may be rebuilt in place during a
window, provided the window is announced and rollback is possible.
A8.a Rollback window: not stated by the operator. Working value **7 days** (keep the old index or a snapshot of it
until 7 days after the switch), to be confirmed in the gap review (recovery).
A8.b Agent note: a side-by-side build remains the cheaper route for the framework index (~9K chunks, minutes) and is
needed anyway for the A4 side-by-side comparison; downtime tolerance matters mainly for Penelope (~175K vectors).
A8.c (operator, 2026-10-08, follow-up): "Let's assume we do the work in the night and it can continue uninterrupted."
Migration and reindex work runs in a night window and may run for hours without interruption.
A8.d Consequences (agent, for the requirements): (1) nobody watches the run, so each step MUST verify itself (vector
count, model id and dimension per store, a canary query set) and MUST leave the old index usable if verification
fails; (2) the run MUST write a morning report the operator can read in a few minutes; (3) at night the GPU is free of
interactive chat load, so bulk embedding can use the GPU (A5.a: 69.9 vs 1.9 chunks/s) without the eviction concern of
A5; (4) the night jobs must not overlap other scheduled night work on 107 (crontab check at design time).

A9 (Q9, 2026-10-08). **Decided in A9.8 after discussion** (first recorded as under discussion). Operator (question, not a ruling): "things need to be
replicatable to projects. For Penelope I understand. But the Qdrant — I'm not sure why it would go to the shared
toolkit, because I don't know that. I would think it naturally sits with the AEF agent." The agent first recorded
this as a decision (19e748e) and corrected it at the operator's request; the operator asked for reflection and
rationale before a decision.
A9.1 Settled so far: replicability to projects is a requirement; Penelope with its owner 050 is understood.
A9.2 Open: owner (and future) of the knowledge Qdrant — options and rationale are in the dialogue; decision pending (closed in A9.8).
A9.3 Open: Open WebUI (not yet discussed; closed by GR-7).
A9.4 Agent finding: the knowledge Qdrant is filled today by `/opt/claude-shared-toolkit/.../index_qdrant.py`, called by the
user-level commands `/sync`, `/recall`, `/query-knowledge` (not part of AEF, no owning project). Moving it into AEF
replaces that script; the commands must then call AEF. The `/query-knowledge` command text says semantic search needs
"OpenAI API (via OpenRouter)", while the T-087 probe found local `mxbai-embed-large` vectors: which embedder the script
really calls is unverified (outside this project's boundary) and matters for A6 (non-email only, so allowed, but it
must be known). Open item O-1.
A9.5 Operator follow-up: "We need deeper analysis of the current implementation. I thought I have a Qdrant for every
project individually. How is it for other projects?" Inventory: `docs/reports/T-089-knowledge-qdrant-inventory.md`.
Short answer: every AEF project has its own sqlite-vec index; the shared Qdrant's knowledge collections are a stale
(Dec 2025 - Jan 2026) store of pre-AEF Ring20 projects with unverified model provenance; no current AEF project
writes to it. Decision on its future pending.
A9.6 Operator (2026-10-08, discussion continues): "We certainly want to keep it in projects, but I want to have an
option, a configurable option, for other users than me also ... to have a central server that holds, of course,
project information. But it will be good to think about what and how and where is value."
Settled by this: (1) the per-project index stays the default and must work on its own; (2) a central knowledge
server is wanted as an **optional, configurable** feature, usable by other users (not only the operator).
Still open at the time (closed in A9.7-A9.8): what goes central, how (push vs federated query), where the value is, multi-user scope. Agent analysis
in the dialogue of 2026-10-08; the old Qdrant knowledge collections are not the design basis (A9.5).
A9.7 (2026-10-08) Who the "other users" are: **c — both.** First ship a configurable AEF feature: each user or
organisation may run its own central knowledge server (single tenant per server, off unless configured). The data
model carries tenant (user/organisation) and project tags from the start, so a shared team server with several
tenants, logins and cross-machine access can be added later without rebuilding. Agent analysis behind the options
(value: cross-project lessons, onboarding, cross-project patterns, low-resource machines; content: curated
learnings/decisions/patterns/episodic summaries, opt-in per project and type, never email; mechanism leaning: push
with server-side embedding, content hash, deletion propagation, monitored sync) is input to the design steps, not
yet a requirement.
A9.8 (2026-10-08) Q9 closed: **a.** (1) arc-001 does not build the central server; it only keeps it possible: one
shared model manifest, tenant and project tags on every stored item, search separated from storage. (2) The central
server gets its own inception after arc-001's benchmark and manifest exist (captured as parked inception T-090). (3) The old
Qdrant knowledge collections (learnings, decisions, tasks, architecture, designs, errors, skills) are snapshotted and
then dropped; `/recall` and `/query-knowledge` are pointed at `fw recall` / `fw ask`. Penelope's `email_archive`,
`email_archive_prod` and `profile_professional` are not touched. A9.3 (Open WebUI) moves to the gap review.

A10 (Q10, 2026-10-08). **a — Ollama library and Hugging Face GGUF, open licences, pinned by digest.**
A10.1 Sources: the Ollama library and Hugging Face GGUF (pulled through Ollama as `hf.co/...`).
A10.2 Licences: Apache-2.0, MIT or a comparable licence that permits commercial use; any other licence needs the
operator's explicit approval per model (relevant because other users may run the feature, A9.7).
A10.3 Pinning: every model in the manifest is pinned by digest; a re-pull that changes the digest is a model change
and goes through the A4 gates, never silently.

A11 (Q11, 2026-10-08). **a — hybrid everywhere it fits, each part gated by the benchmark.**
A11.1 Framework index: a keyword index (sqlite FTS5) beside the vectors, results fused (e.g. reciprocal rank fusion).
A11.2 Qdrant stores (Penelope; the future central server, T-090): sparse vectors beside dense ones.
A11.3 Each hybrid part is enabled only where it beats dense-only on the frozen benchmark (A4 gate 1); otherwise it
stays off. Motivation: exact identifiers (T-xxx, G-xxx, file names, error strings, invoice numbers, names) are weak
for dense search.

A12 (Q12, 2026-10-08). Operator accepted ("ok") the agent's ranking of failures to make impossible, worst first:
1. **Silent quality regression** (G-009 class: reranker scored every candidate 0.5 for weeks, unseen).
2. **Mixed-model vectors** in one store (destroys stored data; signs already in the old knowledge Qdrant, A9.5).
3. **Data leakage** of email or private content to external models or services (A6).
4. **Failed unattended night migration** without working rollback (A8.c-d).
5. **Chat-model eviction** from the GPU (lower since bulk work runs at night, A8.d).
The strongest structural safeguard goes to #1, then #2.

A13 (Q13, 2026-10-08). **b — important, alongside other work, no deadline.** The design chain proceeds steadily;
no date pressure is put on the benchmark gates (A4).

GR (gap review, card 3.4, 2026-10-08). The agent proposed defaults GR-1..GR-8; the operator amended GR-5 and
accepted the rest.
GR-1 Offline / degraded: if Ollama, the reranker or Qdrant is down, search degrades step by step (no reranker ->
keyword-only -> clear error), never silently; every degradation is logged in telemetry.
GR-2 Recovery: the old index (or a snapshot) is kept for **7 days** after each switch (confirms A8.a).
GR-3 Revocation: a model is removed only when no store uses it and its rollback window has passed; removal is an
operator-approved manifest change, never an automatic cleanup.
GR-4 Resource identity: as A10.3 — digest pins in the manifest; every stored item records model and digest.
GR-5 (amended by the operator) Unsupported targets and compute: no cloud embedding or rerank APIs for any store (A6).
Operator: "GPU at all times is of course preferred. CPU fallback should really only be optional and should be loud,
with the remark that it can be significantly slower." So: GPU is the default for every model and workload; CPU
fallback is opt-in, and when used it warns loudly (log, telemetry, user-visible notice) that it may be significantly
slower.
GR-6 Approval fatigue: the operator approves only at deciding points — query-set pruning (A7), model switch (A4),
placement per model (A5), non-open licences (A10.2). Everything else is automatic and reported in the morning report.
GR-7 Open WebUI: configured on 107 from this project, last in order (A3); its embedder setting follows the shared
model manifest (closes A9.3).
GR-8 Voxtype: its latency must not regress at any stage; it is monitored and a regression stops the stage (confirms
A5.c(4)).
GR-8a Operator question (2026-10-08): "What does Voxtype voice input have to do with vector databases?" Answer:
functionally nothing; they share the one Ollama server and GPU on 107 (voxtype-review sends every dictation to
`gemma4:latest` on localhost:11434, config `~/.config/voxtype-review/config.toml`; at the time gemma4 held 3.3 GB and
the embedder 0.6 GB of 8.8/16 GB VRAM). Larger embedders, a reranker and night reindexing can make Ollama evict gemma4
and delay dictation. Proposed rewording: other users of Ollama/GPU on 107 (Voxtype's gemma4, chat models such as
qwen3:14b) must not get slower because of this arc; measured before/after each stage; a regression stops the stage;
Voxtype is the reference user. Confirmed by the operator ("ok", 2026-10-08).
GR-9 Operator (2026-10-08): "Vectorization and chunking is important, but not time critical." Workload classes on the
shared GPU, highest priority first: (1) interactive models (Voxtype, chat); (2) query-time embedding and reranking
(an agent waits, but the work is small); (3) bulk chunking and embedding (indexing, reindex, migration) — background:
runs at night or when idle, may be throttled or paused, and yields to classes 1 and 2. Indexing freshness is measured
in hours, not seconds.
GR-10 Credential custody (card 3.4; skipped in round 1, review D-1; operator OD-1, 2026-10-09): Qdrant stores get
API keys (read keys for search, write keys only for the night run and the store owner), kept in the secret store
and never in tasks, logs, briefs or telemetry; the OpenAI/OpenRouter keys used by `/sync` are retired with it; Ollama
on 107 stays on the LAN but accepts only clients on the known-clients list.
GR-11 Compromised or confused agent session (card 3.4; operator OD-2): agents may only propose; manifest changes,
Gate 2 confirmations, benchmark freezes, placement decisions, parameter approvals, licence exceptions, manual
rollbacks and model removals need operator provenance (Watchtower action or operator-run command); writes to AEF
stores go only through the AEF writer that checks the manifest (Penelope and Open WebUI: R-11, O-2).

OD (operator decisions on review round 1, 2026-10-09; operator answered "ok" to all eight recommendations;
disposition `docs/designs/arc-001/reviews/step-01-round-1/disposition.md`):
OD-1 credential custody as GR-10. OD-2 operator provenance as GR-11. OD-3 rollback: by the operator or automatically
by the night run when post-switch checks fail; it restores the previously approved model without re-running the
gates and is always reported. OD-4 "a regression stops the stage" = slower than the pre-stage baseline beyond the
measured run-to-run variation. OD-5 agent-proposed numbers accepted as working values (WV): 14-day measurement
windows, per store ≥5 identifier and ≥5 no-answer queries, 7 days between stores, client list ≤30 days old, +10%
recall@5; changeable only by operator approval. OD-6 drafting and pruning may start with an even split; the set is
frozen only after ≥14 days of telemetry, re-weighted to the measured mix. OD-7 one benchmark per store (framework
60-100, Penelope 40-60, Open WebUI ~20), ≥10 queries per language per store. OD-8 do not commit the vendored
.agentic-framework/ to enable the framework review path; run the panel manually until AEF T-4010.
OD-9..OD-12 (review round 2, 2026-10-09). OD-12 operator: "yes" — the agent may settle small details itself,
recording each and telling the operator; decisions that change what the operator approves, what may switch
automatically or where data goes always go to the operator. OD-9 (agent, under OD-12): the Open WebUI benchmark is a
smoke set of about 20 queries over the languages that occur, exempt from the per-language minimum; Gate 2 still
applies. OD-10: "no language worse" is strict — no language's recall@5 may be lower than the current model's, not
even by one query (A4 wording; the operator was offered strict or one query of slack, answered only the OD-12
question, and strict was applied as the recommended default; open to change). OD-11 (agent, under OD-12): canaries
run daily and the morning report is readable in under 5 minutes, both working values.
OD-13 (design review, 2026-10-09). Operator: "1a — I have wanted to be able to do this for a long time." Approvals
(R-34) use a second factor only the operator holds, off host 107 (agents run as root there, so no on-host secret can
separate operator from agent). Mechanism still to be chosen with the operator (O-5).
OD-14 (2026-10-09). Operator: "keep telemetry running, certainly." Until AEF ships the per-project switch (T-3967),
miss rows may hold query text locally on 107; the file is git-ignored (never pushed) and its `query` fields are purged
when the switch lands. A temporary, local exception to R-32, chosen by the operator.
OD-15 (2026-10-10). Operator: "yes, it may." When Ollama is down, `fw ask` MAY fall back to the external model
(`claude-via-litellm`) for framework stores, which hold no email (consistent with A6.2); NEVER for email stores; an
externally answered response says so in the answer and in telemetry.

## 4 Glossary

G.1 **Store** — one vector collection or index that serves search: the framework index of one project
(`.context/working/fw-vec-index.db`), Penelope's `email_archive`, Open WebUI's document index, later the central
server (T-090).
G.2 **Consumer** — anything that searches a store: `fw ask`, `fw recall`, Watchtower search, the MCP `ask`, the
`/recall` and `/query-knowledge` commands, Penelope agents, Open WebUI.
G.3 **Embedder** — the model that turns text into a dense vector, for documents (indexing) and queries.
G.4 **Reranker** — the model that re-scores the top candidates of a search for relevance to the query.
G.5 **Model manifest** — one artifact with one entry per store, recording the embedder and reranker in use: name, digest, dimensions,
query/document prefixes, licence, placement. The single source of truth for which model a store uses.
G.6 **Digest** — the content hash Ollama reports for a pulled model; identifies the exact weights.
G.7 **Frozen benchmark** — a versioned, operator-approved set of queries for one store (sizes in R-3) with judged
relevant items; frozen
means its hash is recorded and it does not change between the runs it compares.
G.8 **Gate 1 / Gate 2** — the two conditions for a model switch: Gate 1 the benchmark threshold, Gate 2 the
operator's confirmation on side-by-side answers (A4).
G.9 **Hybrid search** — keyword search (FTS5 or sparse vectors) and dense search run together and their result lists
fused (for example reciprocal rank fusion).
G.10 **Dual index** — the new index built beside the old one, so the switch is a configuration change and the old
index stays available for rollback.
G.11 **Switch** — the moment a store starts serving queries from the new index/model.
G.12 **Rollback window** — the 7 days after a switch during which the old index is kept and can be restored.
G.13 **Night run** — unattended migration or reindex work in a night window, self-verifying.
G.14 **Morning report** — the night run's short written result for the operator.
G.15 **Placement** — where a model runs for one workload: GPU (default) or CPU (operator-approved exception).
G.16 **Workload class** — (1) interactive models, (2) query-time embedding/reranking, (3) bulk indexing (GR-9).
G.17 **Telemetry row** — one record per query in `recall-telemetry.jsonl`; never contains query text.
G.18 **Canary queries** — a small fixed query set with known top hits, run on a schedule to detect regressions.
G.19 **Silent regression** — search quality drops while every component reports success (G-009 class).
G.20 **Tenant** — the user or organisation that owns stored items; carried on every item for T-090.
G.21 **Operator provenance** — proof that a record was made by the operator: a Watchtower action or an
operator-run command, recorded with time and identity (R-34).
G.22 **Working value (WV)** — a number the agent proposed and the operator accepted (OD-5); changeable only by an
approved parameter record (R-33).
G.23 **Local estate** — the hosts configured as local for a deployment; here host 107 and Qdrant on .201.
G.24 **Rollback** — restoring a store's previously approved model and index within the rollback window, without
re-running the gates (R-24).
G.25 **Automatic revert** — the night run's only manifest write: back to the immediately previous
operator-approved entry, within the rollback window (R-10, R-24).

## 5 Requirements

Columns per requirement: statement (RFC 2119) | type | source | rationale | priority | verification | acceptance
criteria (AC). Priority: P1 needed for the first model switch, P2 needed before a later stage, P3 desirable.
Requirements stating what MUST be impossible name the adversary (§1.5, ranked in A12).
Numbers marked **(WV)** are working values accepted by the operator (OD-5); they may be changed only by an
operator-approved parameter record (R-33). "Local estate" means the hosts configured as local for a deployment;
for this deployment: host 107 and Qdrant on .201 (D-13).

### 5.1 Measurement

**R-1 Query telemetry.** Every search through an AEF consumer MUST write one telemetry row with timestamp, caller
(project/agent), store, surface, query hash, locally detected language, hit count, top score, score spread, reranker
on/off, latency and degradation level. The row MUST NOT contain query text. Penelope (050) SHOULD write equivalent
rows; whether Open WebUI can is an open item for the architect (§5.8). Adversary for the prohibition: data leakage
(A12 #3).
Type: functional. Source: A2, A6.3-A6.4, GR-1 (AEF T-3967). Rationale: the query mix is unknown (G-A2) and silent
regressions are the top risk. Priority: P1. Verification: test.
AC-1.1 Given a `fw ask` query, when it completes, then exactly one new row exists with every listed field non-empty.
AC-1.2 Given a query containing a unique marker string, when it completes, then the marker appears in no telemetry
row (the row schema has no free-text field besides enumerated values and the hash).

**R-2 Query-mix basis before freezing.** Candidate drafting and pruning MAY start with an even EN/NL/DE split. A
benchmark MUST NOT be frozen until at least 14 days (WV) of R-1 telemetry exist; at freezing, its language split MUST
follow the measured mix, and the operator MAY re-balance during pruning.
Type: operational. Source: A2, A7.b, OD-6. Rationale: the operator does not want the mix guessed (A2), but drafting
need not wait. Priority: P1. Verification: inspection.
A store whose consumers write no telemetry (Penelope until 050 adds it, possibly Open WebUI, O-2) MAY be frozen
on an operator-approved split instead, recorded as such.
AC-2.1 The frozen benchmark's metadata names either the telemetry window (start and end dates, ≥14 days) and the
split it produced, or, for a store without telemetry, the operator-approved split and its approval record.

**R-3 Frozen benchmark per store.** Each store MUST have its own frozen benchmark before its model switch: framework
index 60-100 queries, Penelope 40-60, each with at least 10 queries per language and at least 5 exact-identifier and
5 no-answer queries (WV); Open WebUI a smoke set of about 20 queries over the languages that occur, exempt from the
per-language minimum (OD-9); each query with judged relevant items. Agents (or
the local model for email, R-4) draft about 150 candidates for the framework index; the operator prunes; freezing is
an operator-provenance action (R-34).
Type: functional. Source: A7, A6.3, OD-7, T-087 §7.4. Rationale: one shared set leaves too few queries per language
per store to judge "no language worse". Priority: P1 (framework), P2 (others). Verification: inspection.
AC-3.1 Each frozen set meets its size, per-language (framework, Penelope), identifier and no-answer minimums.
AC-3.2 Its hash and the operator's freeze record are stored; any edit produces a new version.

**R-4 Email work stays on the estate.** Every task that handles email-store content — drafting benchmark
candidates (from email subjects only), judging relevance, preparing Gate 2 side-by-side answers, harness reports and
canary output for Penelope — MUST be done by a model on the local estate or by the operator. Impossible: email text in
any prompt to an external model. Adversary: data leakage through an external agent (A12 #3).
Type: security invariant. Source: A6.1, A7, A7.a, C-1. Rationale: every evaluation path touches email text, not only
drafting (review D-2). Priority: P1. Verification: inspection of each run record.
AC-4.1 Each Penelope drafting, judging, Gate 2 and harness run record names a local-estate endpoint or the operator
as author, and its outputs are stored only on the estate and delivered only to the operator (no agent session with an
external model reads them); a test with a marker email confirms the marker reaches no external request.
AC-4.2 Penelope candidates are derived from subjects only: the drafting input record lists subject fields only.

**R-5 Benchmark harness.** A harness MUST compute, per store and per language: pre-rerank recall@20 and @50,
post-rerank recall@5, MRR and nDCG@10, with a keyword-only (BM25) baseline, and latency p50/p95 measured while the
interactive models are loaded. Identical inputs MUST give identical metrics. Reports reference queries by id, never by
text. It is delivered upstream in AEF.
Type: functional. Source: A4, A9.1, T-087 §7.4. Rationale: AEF has no evaluation harness; every gate depends on one.
Priority: P1. Verification: test.
AC-5.1 Two runs on the same index, model digest and benchmark version give identical quality metrics.
AC-5.2 The report lists every metric per language plus the BM25 baseline and contains no query text.

### 5.2 Switching models

**R-6 Gate 1 — benchmark threshold.** A candidate model MUST NOT be switched in unless, against the current model on
the store's frozen benchmark: recall@5 is at least 10% (WV) higher, relative; no language's recall@5 is lower at all (strict,
OD-10); and latency p95 is within the limit set under R-33.
Type: quality. Source: A4, OD-5, OD-10. Rationale: a measured, pre-agreed bar stops switches made on vendor claims.
Priority: P1. Verification: test (harness output).
AC-6.1 Given a candidate failing any of the three conditions, when the switch is requested, then it is refused with
the failing condition named.

**R-7 Gate 2 — operator confirmation.** After Gate 1, the operator MUST confirm the switch on side-by-side answers for
a sample of queries drawn from the frozen benchmark or typed by the operator at review time and not stored (R-32); Gate 1 alone never switches a model. Impossible: a switch without an operator-provenance
confirmation (R-34). Adversaries: a hurried approver switching on benchmark claims; an agent session forging the
confirmation (§1.5).
Type: security invariant. Source: A4, OD-2. Rationale: the operator signs off, not the threshold (A4).
Priority: P1. Verification: test + inspection.
AC-7.1 Given a switch record whose confirmation lacks operator provenance, when the switch runs, then it is refused.

**R-8 Reranker cannot fail silently.** Impossible: a reranker that errors or returns the same score for every
candidate while search reports success. Such a state MUST raise a WARN in the log, mark telemetry `reranker=degraded`
and fail `fw doctor`. Adversary: silent regression (A12 #1, G-009).
Type: security invariant. Source: A12, G-009, T-087 §7. Rationale: this exact failure went unseen for weeks.
Priority: P1. Verification: test.
AC-8.1 Given a reranker that returns HTTP 400, when a query runs, then telemetry shows `reranker=degraded`, a WARN is
logged and `fw doctor` exits non-zero.
AC-8.2 Given 10 candidates all scored identically, then the same three signals occur.

**R-9 Daily canaries.** Each store MUST run its canary queries daily (WV, OD-11); a canary whose expected document is no longer
the top hit, or a recall@5 drop beyond the tolerance set under R-33 against the last accepted run, MUST alert.
Type: operational. Source: A12 #1, AEF consult (canary stays top hit). Rationale: catches regressions between
benchmark runs. Priority: P1. Verification: test.
AC-9.1 Given an index with a canary document removed, when the canary run executes, then an alert is raised.

### 5.3 Model identity and authority

**R-10 One model manifest.** There MUST be one model manifest artifact with one entry per store (G.5); consumers and
writers MUST read the model from it, not from their own defaults. Open WebUI's embedder setting MUST follow its entry.
Each entry names the active model and, during a build, the candidate. Changes to the manifest require operator
provenance (R-34), with two narrow cases for the night run: the night run MAY revert an entry to the immediately previous
operator-approved entry within its rollback window (automatic revert, G.25), logged and reported (R-23). The
promotion of an entry's candidate to active at the switch is authorised by the operator's Gate 2 approval of that
exact candidate (R-7, R-34); the night run only executes it, after verification passes. The night run MAY make no
other manifest change.
Type: interface. Source: A10, A9.8, GR-7, C-4, OD-2. Rationale: one place to see and control which model each store
uses. Priority: P1. Verification: inspection + test.
AC-10.1 For every store, the manifest has an entry naming model, digest, dimensions, prefixes, licence, placement.
AC-10.2 Given the night run attempts any manifest change other than executing an approved promotion of the exact
approved candidate or an automatic revert, then it is refused.
