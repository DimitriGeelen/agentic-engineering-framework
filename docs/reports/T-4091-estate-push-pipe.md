---
title: "Estate knowledge platform — the push pipe (how projects feed the central store)"
task: T-4091
version: 0.1
date: 2026-10-13
status: exploring
---

# The push pipe

## 0 Version history

| Version | Date | Change | Task |
|---|---|---|---|
| 0.1 | 2026-10-13 | What T-4123 settled; how the local index works; pipe options; open questions | T-4091 |

## 1 What is already settled (T-4123, GO 2026-10-13)

1. **Source:** each project's own local vector index keeps running and is the feed. Start feeding now; aggregate or
   rationalise later (operator).
2. **Vectors are recomputed centrally** (operator: "not only for tampering, but maybe a different tagging"). The
   project sends text and metadata, never vectors.
3. **What goes in (pilot feed list):** completed tasks; episodic memory; project memory (learnings, decisions,
   patterns, gaps); research reports and designs; saved answers; agent docs; specifications; module capability
   cards (T-4142). **Not:** active tasks, handovers.
4. **Raw layer only** for the pilot; curation later (T-4123 IW-2 deferred).
5. **Pilot:** one project writing (this one), one reading.
6. **Platform rules (ring20, T-4123 RM P.1–P.7):** per-project write token, estate read token, `_manifest`
   registration before the first write, size budgets, nightly snapshots, the platform itself never calls Ollama,
   data class set by the operator.
7. **Requirements that bind the pipe:** R-2 secrets refused at write time by value pattern; R-3 opt-in per project
   and type; R-4 freshness ≤ 24 h; R-5 change and deletion propagate; R-12 provenance on every answer; R-16 local
   recall keeps working when the store is down; R-19 model + digest on every vector, one collection per model;
   R-25 project A cannot write project B; R-29 audit log; R-33 observed_on + framework version; R-37 no binaries
   or caches; CF-7 roles instead of hostnames (all three external models).

## 2 How the local index works today (facts)

- `web/embeddings.py` builds a sqlite-vec database per project. Table `documents(path, title, category, task_id,
  chunk_index, chunk_text)` holds every chunk's text; `vec_documents` the vectors; `file_state(path,
  content_hash, mtime, updated_at)` one hash per source file (T-3014, so a run knows what changed).
- `category` comes from `web/search_utils.py:19 categorize(path)` — the same scheme in every project.
- An hourly cron job (`index-reindex-hourly`, `fw index reindex`) keeps it current; `lib/vector_index_health.py`
  checks it.
- The embedding model is `nomic-embed-text-v2-moe` (768 dims), env-overridable only (`web/config.py:64`).

So the pipe does not need to re-read or re-chunk source files: the chunks, their category and a per-file content
hash already exist locally.

## 3 The central-recompute problem

"Recompute centrally" needs a *central embedder*: something that takes text and produces the vector with the one
pinned model. ring20's rule P.5 says the **store** never calls Ollama. So the embedder is a separate component
between the projects and the store. Where it runs and how text reaches it is the main design question.

### Options

| | Shape | For | Against |
|---|---|---|---|
| A | **Staging collection.** Projects write text-only points (no vector, or a zero vector) to a per-project staging collection with their own token. One **ingest worker** (central) reads staging, embeds with the pinned model, writes the main collection, clears staging. | Uses the store's own auth (P.1); projects need no new service; the ingest worker is the only writer of vectors | Qdrant needs a vector per point (staging must use a dummy vector or a payload-only collection); two hops |
| B | **Ingest service (HTTP).** Projects POST batches of chunks to an ingest endpoint; it redacts, embeds, writes. | One hop; one place for redaction, role mapping, manifest checks, audit log | A new service to run, secure and keep up; its own auth |
| C | **Files over an existing channel.** Projects export a JSONL batch per cycle (to the bus / a shared path); a central job ingests. | Simplest transport; easy to inspect and replay | A shared path is host infrastructure; freshness tied to the job's schedule |

**Leaning: A for the pilot** — it needs no new network service, keeps the platform's existing token model, and
the central ingest worker is a natural home for embedding, role mapping, a second secret scan and the audit log.
B is the likely end state if more than a few projects write. To be decided with the operator.

### Where the central embedder runs

It needs the pinned model. Today that is Ollama on the shared GPU host. The ingest worker can run anywhere that
reaches it (likely AEF's host or ring20's), but it is **one** process with **one** model pin, which is what makes
the vectors comparable. Load rule: batches ≤ 64, backoff, no bulk re-embedding in daytime (R-21).

## 4 One push cycle (draft)

1. After the hourly reindex, `fw estate push` (new verb) reads the local `documents` + `file_state`.
2. Filters: opted-in categories only (R-3, the pilot list above); size and type gate (R-37).
3. Redacts at write time: secret value patterns (R-2, reusing the secret-scan patterns) and hostname/IP → role
   mapping (CF-7). An item that still matches is **refused and logged**, not truncated.
4. Diffs against what the store has for this project (by `content_hash` per file / chunk id): new, changed,
   deleted (R-5).
5. Sends new and changed chunks (text + payload: tenant, project, category, item_type, source path, task id,
   content_hash, observed_on, framework version, chunk index), and deletions.
6. The central ingest worker embeds with the pinned model and writes the main collection with model + digest
   (R-19), checks `_manifest` registration (R-26), honours the per-project kill switch (R-28), writes the audit
   row (R-29).
7. Read side: `fw recall`/`fw ask` gain `--scope own|estate|both`, label cross-project hits, and fall back to
   local with "estate unavailable" (R-13, R-16).

## 5 Open questions (IW) for this inception

- **IW-1 Transport:** staging collection (A), ingest service (B) or file batches (C)?
- **IW-2 Central embedder:** where it runs, who operates it, and how it is pinned to one model + digest.
- **IW-3 Identity and change:** chunk id scheme (project + path + chunk index + content hash?) so changes and
  deletions propagate exactly.
- **IW-4 Redaction:** which secret-pattern set, and where the hostname→role map lives (one table per estate).
- **IW-5 Read side:** what `fw recall --scope estate` returns and how it ranks against local hits (R-14).
- **IW-6 Pilot proof:** which checks prove the pilot works (counts per category equal, exact-title top-1,
  deletion within one cycle, secret scan 0, wrong token refused — the DM pilot list in T-4123).

## Dialogue Log

- **2026-10-13, operator:** "ok, proceed as suggested" after the pilot feed list was settled → this inception
  started (T-4091 converted from a captured build task to an inception).
- **2026-10-13, ring20-manager (spike, measured on the estate store with throwaway collections; unedited in
  `T-4091-inputs-ring20-spike.txt`):** option A works. (1) A collection created with `vectors: {}` holds
  payload-only points — no dummy vector. (2) Per-collection JWT scoping works: a project token rw on
  `staging_<proj>` writes its staging (200) and cannot write or read main (403). Correction: an ingest token with
  read-only on staging cannot delete drained points (403), so the ingest worker needs rw on every staging
  collection (accepted: it is the trusted central component). Constraints: no wildcard in JWT collection lists
  (adding a project re-issues the ingest token); any token can list all collection names (keep names
  non-sensitive). ring20 prefers A (no extra service) and will extend its token tool for mixed lists + expiry.
  → IW-1 answered: A. Proposed names: main `estate__knowledge__nomic-embed-text-v2-moe-768` behind alias
  `estate_knowledge` (T-4123 naming convention: tenant__scope__model-dims, one collection per model, R-19);
  first staging `staging_aef`. Creation held until the operator confirms A and where the ingest worker runs (IW-2).
- **2026-10-13, operator:** "1 yes, 2a" — option A for the pilot; the ingest worker runs on the AEF host, built and
  tested by AEF. → IW-1 and IW-2 answered; recommendation GO; ring20 asked to create the collections and tokens.
