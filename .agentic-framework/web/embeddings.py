"""sqlite-vec semantic search for Watchtower.

Embeds all YAML/Markdown knowledge files using nomic-embed-text-v2-moe (768-dim)
via Ollama, stores vectors in sqlite-vec, and provides semantic + hybrid search
(RRF fusion with Tantivy BM25).

T-245: sqlite-vec embedding layer — semantic search for project knowledge.
T-263: Upgraded from all-MiniLM-L6-v2 (384-dim) to nomic-embed-text-v2-moe (768-dim).
"""
from __future__ import annotations


import logging
import os
import re
import sqlite3
import struct
import time
from functools import lru_cache
from pathlib import Path

import ollama
import sqlite_vec

from web.canary import CANARY_CATEGORY, all_canaries, verify_canaries
from web.config import Config
from web.corpus_manifest import build_manifest, read_manifest, write_manifest
from web.embed_health import (
    RETRYABLE,
    EmbedHealth,
    EmbedUnavailable,
    classify,
    probe,
)
from web.search_utils import categorize, collect_files, extract_task_id, extract_title
from web.shared import PROJECT_ROOT

log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Configuration (T-273: config-driven, no hardcoded paths)
# ---------------------------------------------------------------------------

# Lazy Ollama client — re-created when Config.OLLAMA_HOST changes (T-395)
_ollama_client = None
_ollama_client_host = None


def _get_ollama_client() -> ollama.Client:
    """Get or create Ollama client, respecting runtime config changes."""
    global _ollama_client, _ollama_client_host
    if _ollama_client is None or _ollama_client_host != Config.OLLAMA_HOST:
        _ollama_client = ollama.Client(host=Config.OLLAMA_HOST, timeout=Config.OLLAMA_TIMEOUT)
        _ollama_client_host = Config.OLLAMA_HOST
    return _ollama_client


# Embedding client is separate from the chat client (T-3006). They may address
# different endpoints — see Config.EMBED_HOST for why.
_embed_client = None
_embed_client_host = None


def _get_embed_client() -> ollama.Client:
    """Get or create the embedding client, respecting runtime config changes."""
    global _embed_client, _embed_client_host
    if _embed_client is None or _embed_client_host != Config.EMBED_HOST:
        _embed_client = ollama.Client(host=Config.EMBED_HOST, timeout=Config.OLLAMA_TIMEOUT)
        _embed_client_host = Config.EMBED_HOST
    return _embed_client


def embed_health() -> EmbedHealth:
    """Classify the embedding path right now. Never raises."""
    return probe(_get_embed_client(), MODEL_NAME, host=Config.EMBED_HOST)

MODEL_NAME = Config.EMBEDDING_MODEL
EMBEDDING_DIM = 768
CHUNK_OVERLAP = 150  # chars of overlap between adjacent chunks (T-263)

# ── Chunk budget (T-3010, measured in T-3009) ──────────────────────────────
# The embedder truncates at a hard token ceiling and reports nothing when it
# does: the row still looks indexed while its tail is unreachable by search.
# So the chunk cap is not a tuning knob, it is a correctness bound, and it is
# derived from the ceiling rather than written down as a literal.
#
# EMBED_CONTEXT_TOKENS — measured, not from the model card. `prompt_eval_count`
#   saturates at exactly 512, and the truncation is real: two texts sharing a
#   >512-token prefix and differing only in suffix embed to cosine 1.000000000
#   (control pair: 0.502). Re-measure with `tools/measure_chunk_tokens.py`.
# CHARS_PER_TOKEN_FLOOR — the *minimum* observed ratio over the real corpus
#   (2.01 across 247 sampled chunks). The floor is what makes the cap a proof:
#   at the median ratio (3.19) a 1500-char chunk fits, but dense chunks at the
#   floor would be ~746 tokens and silently lose their tail. Using the floor
#   costs chunk count and buys "no chunk can truncate".
#
# Changing the embedding model (T-3007 step B) means re-running the measurement
# and updating EMBED_CONTEXT_TOKENS — the cap follows on its own.
EMBED_CONTEXT_TOKENS = 512
CHARS_PER_TOKEN_FLOOR = 2.0
MAX_CHUNK_CHARS = int(EMBED_CONTEXT_TOKENS * CHARS_PER_TOKEN_FLOOR)
RERANKER_MODEL = Config.RERANKER_MODEL
DB_PATH = Config.VECTOR_DB_PATH
STALE_SECONDS = 3600  # rebuild if older than 1 hour (T-395: was 120s, caused search hangs)

# Singleton state
_db = None
_db_built_at = 0.0


# ---------------------------------------------------------------------------
# Embedding via Ollama (T-263: replaces sentence-transformers)
# ---------------------------------------------------------------------------

def _embed(texts: list[str]) -> list[bytes]:
    """Embed a batch of texts, returning raw float32 bytes for sqlite-vec.

    T-3006: retries bounded transient failures and, on exhaustion, raises
    EmbedUnavailable carrying the behavioural class. Previously this re-raised
    the bare Ollama exception, which named neither the subsystem nor the remedy
    and was then discarded by the caller's `2>/dev/null`.
    """
    attempts = max(1, Config.EMBED_RETRIES + 1)
    last: EmbedHealth | None = None

    for attempt in range(attempts):
        try:
            resp = _get_embed_client().embed(model=MODEL_NAME, input=texts)
            return [struct.pack(f"{len(emb)}f", *emb) for emb in resp.embeddings]
        except Exception as exc:  # noqa: BLE001 — classified immediately below
            status, detail = classify(exc)
            last = EmbedHealth(status=status, detail=detail,
                               host=Config.EMBED_HOST, model=MODEL_NAME)
            if status not in RETRYABLE or attempt == attempts - 1:
                break
            # Linear backoff. Deliberately short: the permanent-starvation case
            # (T-3006) must fail fast rather than stall every task start.
            time.sleep(Config.EMBED_RETRY_BACKOFF * (attempt + 1))

    log.error("embedding unavailable [%s] host=%s model=%s: %s",
              last.status, last.host, last.model, last.detail)
    raise EmbedUnavailable(last)


# Query embedding cache — LRU avoids re-embedding repeated queries (T-263)
@lru_cache(maxsize=256)
def _embed_single_cached(text: str) -> bytes:
    """Embed a single text string with LRU caching."""
    return _embed([text])[0]


def _embed_single(text: str) -> bytes:
    """Embed a single text string (cached for queries)."""
    return _embed_single_cached(text)


# ---------------------------------------------------------------------------
# File collection & chunking
# ---------------------------------------------------------------------------

def _split_to_budget(text: str, budget: int) -> list[str]:
    """Split `text` into pieces of at most `budget` chars, losing nothing.

    Walks separators coarse-to-fine so cuts land on natural boundaries when the
    text has any, and ends at a hard character cut so the bound holds even for
    input with no whitespace at all — minified JS, base64, a long hash.

    T-3010: the previous code stopped at "\\n\\n" and appended whatever it was
    holding, so a paragraph bigger than the cap went in whole. That produced a
    170,873-char chunk in the real corpus, of which the embedder read ~1,600.
    The bound has to hold for *every* input shape or it is not a bound.
    """
    if len(text) <= budget:
        return [text] if text else []

    for sep in ("\n\n", "\n", ". ", " "):
        if sep not in text:
            continue
        pieces, cur = [], ""
        for part in text.split(sep):
            candidate = part if not cur else cur + sep + part
            if len(candidate) <= budget:
                cur = candidate
            else:
                if cur:
                    pieces.append(cur)
                cur = part
        if cur:
            pieces.append(cur)
        # A single part can still be over budget (one enormous line, one
        # enormous sentence); recurse so the finer separators get their turn.
        out = []
        for p in pieces:
            out.extend(_split_to_budget(p, budget) if len(p) > budget else [p])
        return out

    # No separator anywhere. Hard cut is the only way to keep the bound, and
    # keeping the bound matters more than a tidy boundary: the alternative is
    # silently handing the embedder text it will throw away.
    return [text[i:i + budget] for i in range(0, len(text), budget)]


def _chunk_content(content: str, max_chars: int | None = None,
                   reserve: int = 0) -> list[str]:
    """Split content into chunks suitable for embedding.

    Each chunk is roughly max_chars. Splits on section headings (## or ###)
    first, then on double newlines if still too long. Adjacent chunks get
    CHUNK_OVERLAP chars of overlap to preserve boundary context (T-263).
    """
    if max_chars is None:
        max_chars = MAX_CHUNK_CHARS
    # The budget governs the text that is EMBEDDED, and build_index prepends the
    # title while the overlap pass below prepends CHUNK_OVERLAP chars. Reserve
    # both here, or the cap is right in this function and wrong where it counts.
    budget = max(200, max_chars - reserve - CHUNK_OVERLAP - 4)

    # Split on markdown headings
    sections = re.split(r'\n(?=#{1,3}\s)', content)
    raw_chunks = []

    for section in sections:
        section = section.strip()
        if not section:
            continue
        raw_chunks.extend(_split_to_budget(section, budget))

    if not raw_chunks:
        # Whitespace-only input. Previously `content[:budget]`, which would have
        # silently dropped the tail had anything non-trivial ever reached here.
        return _split_to_budget(content.strip(), budget)

    # Add overlap: prepend tail of previous chunk to each subsequent chunk
    chunks = [raw_chunks[0]]
    for i in range(1, len(raw_chunks)):
        prev = raw_chunks[i - 1]
        overlap_text = prev[-CHUNK_OVERLAP:] if len(prev) > CHUNK_OVERLAP else prev
        # Find a clean word boundary for the overlap
        space_idx = overlap_text.find(" ")
        if space_idx > 0:
            overlap_text = overlap_text[space_idx + 1:]
        chunks.append(overlap_text + "\n\n" + raw_chunks[i])

    return chunks


# ---------------------------------------------------------------------------
# Database management
# ---------------------------------------------------------------------------

def _init_db() -> sqlite3.Connection:
    """Create and initialize the sqlite-vec database."""
    db = sqlite3.connect(str(DB_PATH), check_same_thread=False)
    db.enable_load_extension(True)
    sqlite_vec.load(db)
    db.enable_load_extension(False)

    db.execute("""
        CREATE TABLE IF NOT EXISTS documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT NOT NULL,
            title TEXT NOT NULL,
            category TEXT NOT NULL,
            task_id TEXT DEFAULT '',
            chunk_index INTEGER DEFAULT 0,
            chunk_text TEXT NOT NULL
        )
    """)

    # Virtual table for vector search
    db.execute(f"""
        CREATE VIRTUAL TABLE IF NOT EXISTS vec_documents USING vec0(
            id INTEGER PRIMARY KEY,
            embedding FLOAT[{EMBEDDING_DIM}]
        )
    """)

    db.commit()
    return db


def corpus_health() -> dict:
    """Manifest + canary verdict for the live index. Never raises.

    This is what slice 4's doctor/audit rail reads. It deliberately returns three
    states rather than a boolean, because the reason a rail stays silent matters:
    an index with no manifest predates this control and is *unknown*, which is not
    the same as *healthy* and not the same as *broken*. Collapsing those was how
    T-3004's outage stayed green for five months.
    """
    manifest = read_manifest(DB_PATH)
    if manifest is None:
        return {"status": "unknown", "manifest": None, "canaries": [],
                "detail": "no corpus manifest — index predates T-3011 or was "
                          "built by an older framework version"}

    results = verify_canaries(search, manifest.get("canary_token", ""))
    failed = [r for r in results if not r.ok]
    return {
        "status": "fault" if failed else "ok",
        "manifest": manifest,
        "canaries": [
            {"name": r.name, "ok": r.ok, "detail": r.detail, "top_hit": r.top_hit}
            for r in results
        ],
        "detail": "; ".join(f"{r.name}: {r.detail}" for r in failed) or "canaries green",
    }


def is_index_ready() -> bool:
    """Check if the vector index exists and has data (T-395: avoids triggering rebuild)."""
    if _db is not None and _db_built_at > 0:
        return True
    if not DB_PATH.exists() or DB_PATH.stat().st_size < 4096:
        return False
    try:
        db = sqlite3.connect(str(DB_PATH), check_same_thread=False)
        db.enable_load_extension(True)
        sqlite_vec.load(db)
        db.enable_load_extension(False)
        count = db.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
        db.close()
        return count > 0
    except Exception:
        return False


def _get_db() -> sqlite3.Connection:
    """Get the database connection, reusing existing index if available."""
    global _db, _db_built_at

    if _db is not None and (time.time() - _db_built_at) < STALE_SECONDS:
        return _db

    # Reuse existing DB file if it has data (T-395: avoid expensive full rebuild on every search)
    if DB_PATH.exists() and DB_PATH.stat().st_size > 4096:
        try:
            _db = _init_db()
            count = _db.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
            if count > 0:
                _db_built_at = time.time()
                log.info("Reusing existing vector index with %d documents", count)
                return _db
        except Exception:
            pass  # Fall through to full rebuild

    build_index()
    return _db


# ---------------------------------------------------------------------------
# Index building
# ---------------------------------------------------------------------------

def build_index() -> dict:
    """Build a fresh vector index from all framework files.

    Returns stats dict with num_docs, num_chunks, build_time_ms.
    """
    global _db, _db_built_at

    start = time.time()

    # Remove old DB
    if DB_PATH.exists():
        DB_PATH.unlink()

    db = _init_db()
    files = collect_files()

    # T-3011: the canary token identifies this build. Stored in the manifest so
    # the checker can tell "canary missing" from "canary from an older build".
    canary_token = f"FWCANARY-{int(start)}"

    # Collect all chunks with metadata
    all_chunks = []
    all_metadata = []

    for fpath in files:
        try:
            content = fpath.read_text(errors="replace")
            if not content.strip():
                continue

            rel_path = str(fpath.relative_to(PROJECT_ROOT))
            title = extract_title(fpath, content)
            category = categorize(rel_path)
            task_id = extract_task_id(fpath, content)
            # Reserve the title: it is prepended below, so it is part of what
            # the embedder actually sees and therefore part of the budget.
            chunks = _chunk_content(content, reserve=len(title) + 2)

            for i, chunk in enumerate(chunks):
                # Prepend title for better embedding context
                embed_text = f"{title}\n\n{chunk}" if i > 0 else chunk
                all_chunks.append(embed_text)
                all_metadata.append({
                    "path": rel_path,
                    "title": title,
                    "category": category,
                    "task_id": task_id,
                    "chunk_index": i,
                    "chunk_text": chunk,
                })
        except Exception:
            continue

    # T-3011: plant the canaries through the SAME chunk/embed path as real
    # content. Anything that special-cases them would make them green by
    # construction, which is the failure this control exists to detect.
    for doc in all_canaries(canary_token):
        for i, chunk in enumerate(_chunk_content(doc.text,
                                                 reserve=len(doc.title) + 2)):
            all_chunks.append(f"{doc.title}\n\n{chunk}" if i > 0 else chunk)
            all_metadata.append({
                "path": doc.path,
                "title": doc.title,
                "category": CANARY_CATEGORY,
                "task_id": "",
                "chunk_index": i,
                "chunk_text": chunk,
            })

    if not all_chunks:
        _db = db
        _db_built_at = time.time()
        return {"num_docs": 0, "num_chunks": 0, "build_time_ms": 0}

    # Batch embed all chunks (in groups to avoid Ollama timeout)
    BATCH_SIZE = 64
    embeddings = []
    for i in range(0, len(all_chunks), BATCH_SIZE):
        batch = all_chunks[i:i + BATCH_SIZE]
        log.info("Embedding batch %d/%d (%d chunks)", i // BATCH_SIZE + 1,
                 (len(all_chunks) + BATCH_SIZE - 1) // BATCH_SIZE, len(batch))
        embeddings.extend(_embed(batch))

    # Insert into database
    for idx, (meta, emb) in enumerate(zip(all_metadata, embeddings)):
        row_id = idx + 1
        db.execute(
            "INSERT INTO documents (id, path, title, category, task_id, chunk_index, chunk_text) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            (row_id, meta["path"], meta["title"], meta["category"],
             meta["task_id"], meta["chunk_index"], meta["chunk_text"]),
        )
        db.execute(
            "INSERT INTO vec_documents (id, embedding) VALUES (?, ?)",
            (row_id, emb),
        )

    db.commit()

    elapsed_ms = int((time.time() - start) * 1000)
    num_docs = len(set(m["path"] for m in all_metadata))

    _db = db
    _db_built_at = time.time()

    # T-3011: record what was built, from which commit, with which model and cap.
    # Best-effort — a manifest write failure must not fail an otherwise good
    # index, but it must be visible rather than swallowed.
    manifest_written = False
    try:
        write_manifest(DB_PATH, build_manifest(
            num_docs=num_docs,
            num_chunks=len(all_chunks),
            model=MODEL_NAME,
            embedding_dim=EMBEDDING_DIM,
            max_chunk_chars=MAX_CHUNK_CHARS,
            embed_context_tokens=EMBED_CONTEXT_TOKENS,
            canary_token=canary_token,
            started_at=start,
            project_root=PROJECT_ROOT,
        ))
        manifest_written = True
    except Exception as exc:  # noqa: BLE001
        log.warning("corpus manifest not written: %s", exc)

    return {
        "num_docs": num_docs,
        "num_chunks": len(all_chunks),
        "build_time_ms": elapsed_ms,
        "canary_token": canary_token,
        "manifest_written": manifest_written,
    }


# ---------------------------------------------------------------------------
# Cross-encoder reranking (T-269)
# ---------------------------------------------------------------------------

_RERANKER_SYSTEM = (
    "Judge whether the Document meets the requirements based on the Query "
    "and the Instruct provided. Note that the answer can only be 'yes' or 'no'."
)

_RERANKER_INSTRUCT = (
    "Given a user question about the Agentic Engineering Framework, "
    "retrieve relevant passages that answer the question"
)


def _rerank_score(query: str, document: str) -> float:
    """Score a single (query, document) pair using the cross-encoder reranker.

    Returns a relevance score between 0 and 1.
    """
    import math

    prompt = f"<Instruct>: {_RERANKER_INSTRUCT}\n<Query>: {query}\n<Document>: {document}"
    try:
        resp = _get_ollama_client().generate(
            model=RERANKER_MODEL,
            system=_RERANKER_SYSTEM,
            prompt=prompt,
            options={"temperature": 0.0, "num_predict": 1},
            raw=True,
        )
        answer = (resp.response or "").strip().lower()
        return 1.0 if "yes" in answer else 0.0
    except Exception as e:
        log.debug("Reranker error: %s", e)
        return 0.5  # neutral fallback


def _rerank_available() -> bool:
    """Check if the reranker model is installed."""
    try:
        models = [m.model for m in _get_ollama_client().list().models]
        return any(RERANKER_MODEL.lower() in m.lower() for m in models)
    except Exception:
        return False


def rerank(query: str, candidates: list[dict], top_k: int = 10) -> list[dict]:
    """Rerank candidates using cross-encoder and return top_k.

    Each candidate must have a 'chunk_text' key.
    Falls back to original order if reranker unavailable.
    """
    if not _rerank_available() or not candidates:
        return candidates[:top_k]

    scored = []
    for item in candidates:
        doc_text = item.get("chunk_text", "")[:1000]  # truncate for speed
        score = _rerank_score(query, doc_text)
        scored.append((score, item))

    # Sort by reranker score desc, then by original RRF score desc for ties
    scored.sort(key=lambda x: (x[0], x[1].get("score", 0)), reverse=True)
    return [item for _, item in scored[:top_k]]


# ---------------------------------------------------------------------------
# Search functions
# ---------------------------------------------------------------------------

def search(query: str, limit: int = 20) -> dict:
    """Semantic vector search.

    Returns:
        {
            "query": str,
            "total_hits": int,
            "results": [
                {
                    "path": str,
                    "title": str,
                    "category": str,
                    "task_id": str,
                    "score": float,
                    "snippet": str,
                }
            ]
        }
    """
    db = _get_db()
    query_vec = _embed_single(query)

    rows = db.execute("""
        SELECT v.id, v.distance, d.path, d.title, d.category, d.task_id, d.chunk_text
        FROM vec_documents v
        JOIN documents d ON d.id = v.id
        WHERE v.embedding MATCH ? AND k = ?
        ORDER BY v.distance
    """, (query_vec, limit * 3)).fetchall()

    # Deduplicate by path — keep best chunk per file
    seen_paths = {}
    results = []
    for row_id, distance, path, title, category, task_id, chunk_text in rows:
        # sqlite-vec returns L2 distance; convert to similarity score
        similarity = max(0, 1.0 - distance)
        if path in seen_paths:
            continue
        seen_paths[path] = True

        # Extract a short snippet from the chunk
        snippet = _make_snippet(chunk_text, query)

        results.append({
            "path": path,
            "title": title,
            "category": category,
            "task_id": task_id,
            "score": round(similarity, 3),
            "snippet": snippet,
        })

    return {
        "query": query,
        "total_hits": len(results),
        "results": results,
    }


def hybrid_search(query: str, limit: int = 20) -> dict:
    """Hybrid search combining Tantivy BM25 + sqlite-vec semantic via RRF.

    Reciprocal Rank Fusion (RRF): score = sum(1 / (k + rank)) across systems.
    k=60 is the standard constant.

    Returns same format as search().
    """
    from web.search import search as bm25_search

    K = 60

    # Get BM25 results
    bm25_results = bm25_search(query, limit=limit * 2)
    bm25_items = []
    for cat_items in bm25_results.get("categories", {}).values():
        bm25_items.extend(cat_items)

    # Get semantic results
    vec_results = search(query, limit=limit * 2)
    vec_items = vec_results.get("results", [])

    # Build RRF scores by path
    rrf_scores = {}
    item_data = {}

    for rank, item in enumerate(bm25_items):
        path = item["path"]
        rrf_scores[path] = rrf_scores.get(path, 0) + 1.0 / (K + rank + 1)
        if path not in item_data:
            item_data[path] = item

    for rank, item in enumerate(vec_items):
        path = item["path"]
        rrf_scores[path] = rrf_scores.get(path, 0) + 1.0 / (K + rank + 1)
        if path not in item_data:
            item_data[path] = item

    # Sort by RRF score
    sorted_paths = sorted(rrf_scores.keys(), key=lambda p: rrf_scores[p], reverse=True)

    results = []
    for path in sorted_paths[:limit]:
        item = item_data[path]
        results.append({
            "path": item.get("path", path),
            "title": item.get("title", ""),
            "category": item.get("category", ""),
            "task_id": item.get("task_id", ""),
            "score": round(rrf_scores[path], 4),
            "snippet": item.get("snippet", ""),
        })

    return {
        "query": query,
        "total_hits": len(results),
        "results": results,
    }


def rag_retrieve(query: str, limit: int = 10) -> list[dict]:
    """Retrieve full chunks for RAG context (LLM-assisted Q&A).

    Wraps hybrid_search() to return full chunk_text instead of snippets.
    Deduplicates by path (best chunk per file).

    Returns list of dicts: path, title, category, task_id, score, chunk_text.
    """
    db = _get_db()
    query_vec = _embed_single(query)

    # Get more candidates for better dedup
    rows = db.execute("""
        SELECT v.id, v.distance, d.path, d.title, d.category, d.task_id, d.chunk_text
        FROM vec_documents v
        JOIN documents d ON d.id = v.id
        WHERE v.embedding MATCH ? AND k = ?
        ORDER BY v.distance
    """, (query_vec, limit * 3)).fetchall()

    # Also get BM25 ranking for RRF fusion
    from web.search import search as bm25_search
    K = 60
    bm25_results = bm25_search(query, limit=limit * 3)
    bm25_items = []
    for cat_items in bm25_results.get("categories", {}).values():
        bm25_items.extend(cat_items)

    # Build BM25 rank by path
    bm25_rank = {}
    for rank, item in enumerate(bm25_items):
        path = item["path"]
        if path not in bm25_rank:
            bm25_rank[path] = rank

    # Build RRF-scored results with full chunk text
    rrf_scores = {}
    item_data = {}

    for rank, (row_id, distance, path, title, category, task_id, chunk_text) in enumerate(rows):
        similarity = max(0, 1.0 - distance)
        vec_rrf = 1.0 / (K + rank + 1)
        bm25_rrf = 1.0 / (K + bm25_rank[path] + 1) if path in bm25_rank else 0

        if path not in rrf_scores or (vec_rrf + bm25_rrf) > rrf_scores[path]:
            rrf_scores[path] = vec_rrf + bm25_rrf
            item_data[path] = {
                "path": path,
                "title": title,
                "category": category,
                "task_id": task_id,
                "score": round(vec_rrf + bm25_rrf, 4),
                "chunk_text": chunk_text,
            }

    # Add BM25-only results (not in vector results)
    for rank, item in enumerate(bm25_items):
        path = item["path"]
        if path not in rrf_scores:
            bm25_rrf = 1.0 / (K + rank + 1)
            rrf_scores[path] = bm25_rrf
            # BM25 results don't have chunk_text — read from DB
            row = db.execute(
                "SELECT chunk_text FROM documents WHERE path = ? ORDER BY chunk_index LIMIT 1",
                (path,)
            ).fetchone()
            item_data[path] = {
                "path": path,
                "title": item.get("title", ""),
                "category": item.get("category", ""),
                "task_id": item.get("task_id", ""),
                "score": round(bm25_rrf, 4),
                "chunk_text": row[0] if row else "",
            }

    # Sort by RRF score descending
    sorted_paths = sorted(rrf_scores.keys(), key=lambda p: rrf_scores[p], reverse=True)
    candidates = [item_data[p] for p in sorted_paths[:limit * 3]]

    # T-269: Cross-encoder reranking — rerank top candidates to final limit
    return rerank(query, candidates, top_k=limit)


def _make_snippet(chunk_text: str, query: str, max_len: int = 200) -> str:
    """Extract a relevant snippet from chunk text with basic highlighting."""
    # Find the most relevant paragraph
    query_words = set(query.lower().split())
    paragraphs = chunk_text.split("\n\n")

    best_para = paragraphs[0] if paragraphs else chunk_text
    best_score = 0

    for para in paragraphs:
        para_lower = para.lower()
        score = sum(1 for w in query_words if w in para_lower)
        if score > best_score:
            best_score = score
            best_para = para

    # Truncate
    snippet = best_para.strip()
    if len(snippet) > max_len:
        snippet = snippet[:max_len].rsplit(" ", 1)[0] + "..."

    # Highlight query words with <b> tags (matching Tantivy style)
    for word in query_words:
        if len(word) >= 3:  # skip very short words
            pattern = re.compile(re.escape(word), re.IGNORECASE)
            snippet = pattern.sub(lambda m: f"<b>{m.group()}</b>", snippet)

    return snippet


def index_stats() -> dict:
    """Return stats about the current vector index."""
    db = _get_db()
    num_chunks = db.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
    num_docs = db.execute("SELECT COUNT(DISTINCT path) FROM documents").fetchone()[0]
    return {
        "num_docs": num_docs,
        "num_chunks": num_chunks,
        "built_at": _db_built_at,
        "db_path": str(DB_PATH),
        "model": MODEL_NAME,
        "embedding_dim": EMBEDDING_DIM,
    }
