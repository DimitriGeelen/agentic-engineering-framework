"""sqlite-vec semantic search for Watchtower.

Embeds all YAML/Markdown knowledge files using nomic-embed-text-v2-moe (768-dim)
via Ollama, stores vectors in sqlite-vec, and provides semantic + hybrid search
(RRF fusion with Tantivy BM25).

T-245: sqlite-vec embedding layer — semantic search for project knowledge.
T-263: Upgraded from all-MiniLM-L6-v2 (384-dim) to nomic-embed-text-v2-moe (768-dim).
"""
from __future__ import annotations


import fcntl
import hashlib
import logging
import os
import re
import shutil
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
from web import recall_telemetry
from web.embed_health import (
    FAILOVER,
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


# Embedding clients are separate from the chat client (T-3006), and there is one
# per endpoint rather than one global (T-3016): queries and bulk reindex address
# different hosts on purpose. Keyed by host, so a runtime config change picks up
# a fresh client instead of reusing one pointed somewhere else.
_embed_clients: dict[str, ollama.Client] = {}


def _get_embed_client(host: str | None = None) -> ollama.Client:
    """Get or create the embedding client for `host` (default Config.EMBED_HOST)."""
    target = host or Config.EMBED_HOST
    client = _embed_clients.get(target)
    if client is None:
        client = ollama.Client(host=target, timeout=Config.OLLAMA_TIMEOUT)
        _embed_clients[target] = client
    return client


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

# When THIS PROCESS opened the sqlite handle. A connection-cache clock, and
# nothing more (T-3012).
#
# It was called `_db_built_at` and was read as the index's build time, which it
# never was: `_get_db()` restamps it every time it reuses the existing file, so
# it renewed itself on every process start and every TTL expiry. A five-month-old
# index therefore reported itself seconds old, and STALE_SECONDS could not fire
# while a non-empty database existed — the mechanism behind T-3004.
#
# The index's real age comes from the T-3011 corpus manifest; see
# `index_freshness()`. Do not reintroduce the old name: it asserts something
# false, and `test_the_handle_clock_is_not_named_a_build_clock` fails if it
# comes back.
_db_opened_at = 0.0


# ---------------------------------------------------------------------------
# Embedding via Ollama (T-263: replaces sentence-transformers)
# ---------------------------------------------------------------------------

# Failover bookkeeping (T-3017). A failover that leaves no trace turns an outage
# into a mystery: the subsystem keeps working, nobody learns a host died, and the
# survivor quietly becomes a single point of failure in turn. Counted here and
# reported by `embed_failover_state()` so it can be surfaced rather than inferred.
_failovers: dict[str, object] = {"count": 0, "last": None}


def embed_failover_state() -> dict:
    """What the embed path has had to route around, if anything."""
    return dict(_failovers)


def _fallback_host(target: str) -> str | None:
    """The other configured embed host, or None if there is only one.

    Returning None for a single-host install matters: without it, every failure
    would be retried twice against the same endpoint, doubling the wait on the
    permanent-starvation case T-3006 deliberately made fail fast.
    """
    alt = (Config.EMBED_BULK_HOST if target == Config.EMBED_HOST
           else Config.EMBED_HOST)
    return alt if alt and alt != target else None


def _embed_on(texts: list[str], target: str) -> tuple[list[bytes] | None, EmbedHealth | None]:
    """One host, bounded retries. Returns (vectors, None) or (None, health)."""
    attempts = max(1, Config.EMBED_RETRIES + 1)
    last: EmbedHealth | None = None

    for attempt in range(attempts):
        try:
            resp = _get_embed_client(target).embed(model=MODEL_NAME, input=texts)
            return [struct.pack(f"{len(emb)}f", *emb) for emb in resp.embeddings], None
        except Exception as exc:  # noqa: BLE001 — classified immediately below
            status, detail = classify(exc)
            last = EmbedHealth(status=status, detail=detail,
                               host=target, model=MODEL_NAME)
            if status not in RETRYABLE or attempt == attempts - 1:
                break
            # Linear backoff. Deliberately short: the permanent-starvation case
            # (T-3006) must fail fast rather than stall every task start.
            time.sleep(Config.EMBED_RETRY_BACKOFF * (attempt + 1))

    return None, last


def _embed(texts: list[str], host: str | None = None) -> list[bytes]:
    """Embed a batch of texts, returning raw float32 bytes for sqlite-vec.

    `host` selects the endpoint; None means the query host (Config.EMBED_HOST).
    Bulk reindex passes Config.EMBED_BULK_HOST — see T-3016 for why the two
    workloads belong on different hosts.

    On a host-level failure the other configured host is tried once (T-3017).
    That is the difference between "the sidecar died" and "every embedding path
    in the framework is down", which is what actually happened on 2026-08-15
    while a healthy second host holding the same model sat idle (OBS-259).

    T-3006: retries bounded transient failures and, on exhaustion, raises
    EmbedUnavailable carrying the behavioural class. Previously this re-raised
    the bare Ollama exception, which named neither the subsystem nor the remedy
    and was then discarded by the caller's `2>/dev/null`.
    """
    target = host or Config.EMBED_HOST
    vecs, last = _embed_on(texts, target)
    if vecs is not None:
        return vecs

    alt = _fallback_host(target)
    if alt and last is not None and last.status in FAILOVER:
        log.warning(
            "embed failover: %s unusable [%s: %s] — retrying on %s. "
            "The primary is still the one to fix.",
            target, last.status, last.detail, alt)
        alt_vecs, alt_last = _embed_on(texts, alt)
        if alt_vecs is not None:
            _failovers["count"] = int(_failovers["count"]) + 1  # type: ignore[arg-type]
            _failovers["last"] = {"from": target, "to": alt,
                                  "status": last.status, "at": time.time()}
            return alt_vecs
        log.error("embed failover also failed: %s [%s: %s]",
                  alt, alt_last.status if alt_last else "?",
                  alt_last.detail if alt_last else "")

    # Report the primary's class, not the fallback's: the fallback is a stopgap,
    # and pointing the operator at it would send them to fix the wrong host.
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

    # T-3014 (slice 5): per-file content hash so a scheduled run can tell
    # "unchanged" from "needs re-embedding" without re-chunking the whole
    # corpus. Canary rows are never tracked here — they are always replanted.
    db.execute("""
        CREATE TABLE IF NOT EXISTS file_state (
            path TEXT PRIMARY KEY,
            content_hash TEXT NOT NULL,
            mtime REAL NOT NULL,
            updated_at REAL NOT NULL
        )
    """)

    db.commit()
    return db


def _content_hash(content: str) -> str:
    return hashlib.sha256(content.encode("utf-8", errors="replace")).hexdigest()


def index_freshness() -> dict:
    """How old the index on disk actually is.

    Returns `{built_at, age_seconds, source}` where `source` is one of:

      manifest  — the T-3011 corpus manifest's `finished_at`. Authoritative: it
                  is written once, at the end of a build, by the build itself.
      db_mtime  — no usable manifest, so the database file's mtime. A real answer
                  but a weaker one: any write moves it, so it can only ever be an
                  upper bound on freshness. Every index built before T-3011 lands
                  here, which is why the fallback exists rather than reporting
                  unknown and losing the signal entirely.
      unknown   — no manifest and no readable database. Deliberately not zero, and
                  deliberately not `now`.

    That last distinction is the whole point. A missing answer rendered as a
    number is indistinguishable from a fresh index, and that is exactly how a
    five-month-old index passed for current (T-3004). Callers get `None` and have
    to decide what to do about it. Same tri-state rule as `corpus_health()`.

    Never raises: this is a health primitive, and one that throws reports nothing.
    """
    manifest = read_manifest(DB_PATH)
    if manifest is not None:
        finished = manifest.get("finished_at")
        if isinstance(finished, (int, float)) and not isinstance(finished, bool):
            return {"built_at": float(finished),
                    "age_seconds": time.time() - float(finished),
                    "source": "manifest"}

    try:
        mtime = DB_PATH.stat().st_mtime
    except Exception:  # noqa: BLE001 — missing/unreadable both mean "no answer"
        return {"built_at": None, "age_seconds": None, "source": "unknown"}

    return {"built_at": mtime, "age_seconds": time.time() - mtime,
            "source": "db_mtime"}


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
    if _db is not None and _db_opened_at > 0:
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
    """Get the database connection, reusing the existing index if available.

    STALE_SECONDS is a *connection* TTL: it decides how long this process holds
    one sqlite handle before reopening the file. It says nothing about whether
    the index is current, and reaching it does not cause a rebuild — reopening
    the same file is all that happens. For the index's actual age, call
    `index_freshness()` (T-3012).
    """
    global _db, _db_opened_at

    if _db is not None and (time.time() - _db_opened_at) < STALE_SECONDS:
        return _db

    # Reuse existing DB file if it has data (T-395: avoid expensive full rebuild on every search)
    if DB_PATH.exists() and DB_PATH.stat().st_size > 4096:
        try:
            _db = _init_db()
            count = _db.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
            if count > 0:
                # Stamps when the handle opened. Nothing here rebuilt anything,
                # so no freshness claim is being made or renewed.
                _db_opened_at = time.time()
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
    global _db, _db_opened_at

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
    # T-3014: baseline for the next *incremental* run. A full build has to
    # populate this too, or the first scheduled run after any full rebuild
    # (including a T-3007 model switch) would treat every file as changed.
    file_hashes: dict[str, tuple[str, float]] = {}

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
            try:
                mtime = fpath.stat().st_mtime
            except OSError:
                mtime = start
            file_hashes[rel_path] = (_content_hash(content), mtime)
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
        _db_opened_at = time.time()
        return {"num_docs": 0, "num_chunks": 0, "build_time_ms": 0}

    # Batch embed all chunks (in groups to avoid Ollama timeout), on the bulk
    # host — this is throughput work, not query work (T-3016).
    BATCH_SIZE = 64
    bulk_host = Config.EMBED_BULK_HOST
    embeddings = []
    for i in range(0, len(all_chunks), BATCH_SIZE):
        batch = all_chunks[i:i + BATCH_SIZE]
        log.info("Embedding batch %d/%d (%d chunks)", i // BATCH_SIZE + 1,
                 (len(all_chunks) + BATCH_SIZE - 1) // BATCH_SIZE, len(batch))
        embeddings.extend(_embed(batch, host=bulk_host))

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

    now = time.time()
    for rel_path, (content_hash, mtime) in file_hashes.items():
        db.execute(
            "INSERT INTO file_state (path, content_hash, mtime, updated_at) "
            "VALUES (?, ?, ?, ?) ON CONFLICT(path) DO UPDATE SET "
            "content_hash = excluded.content_hash, mtime = excluded.mtime, "
            "updated_at = excluded.updated_at",
            (rel_path, content_hash, mtime, now),
        )

    db.commit()

    elapsed_ms = int((time.time() - start) * 1000)
    num_docs = len(set(m["path"] for m in all_metadata))

    _db = db
    _db_opened_at = time.time()

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
        "embed_host": bulk_host,
    }


def _delete_path_rows(db: sqlite3.Connection, path: str) -> None:
    """Remove every chunk row for `path` from both tables, plus its file_state."""
    ids = [r[0] for r in db.execute(
        "SELECT id FROM documents WHERE path = ?", (path,)).fetchall()]
    if ids:
        db.executemany("DELETE FROM vec_documents WHERE id = ?",
                       [(i,) for i in ids])
        db.execute("DELETE FROM documents WHERE path = ?", (path,))
    db.execute("DELETE FROM file_state WHERE path = ?", (path,))


def index_one(path: str | Path) -> dict:
    """Embed one document and upsert its chunks into the LIVE index.

    T-1719 A1, arc-002. This is the post-write path: a learning is added or an
    arc-tagged task closes, and the thing just written must be retrievable
    within seconds rather than at the next scheduled reindex. The latency
    budget is <5s for a typical entry, which rules out every existing entry
    point — `build_index()` is a full corpus rebuild (hours) and
    `reindex_incremental()` copies the whole database and swaps it, so both are
    orders of magnitude past the budget for a single short document.

    Writes to the live DB in one transaction, reusing `_delete_path_rows` so a
    re-index of the same path replaces rather than duplicates its chunks.

    CONCURRENCY — this is the part that matters. `reindex_incremental()` builds
    on a copy and `os.replace()`s it over `DB_PATH`. Anything written to the
    live file while that copy is in flight is on the OLD inode and is silently
    discarded by the swap. So this takes the SAME advisory lock, non-blocking,
    and when a reindex owns it returns `{"skipped": "reindex-in-progress"}`
    rather than writing into a file that is about to be replaced. Skipping is
    correct: the running reindex will pick the file up from disk anyway, so the
    chunk lands either way — just at reindex latency instead of post-write
    latency. Blocking would be wrong; it would stall a task close behind a
    25-minute rebuild.

    Returns a dict with `indexed_chunks`, `elapsed_ms`, and `path`; or
    `{"skipped": <reason>}` when nothing was written. Never raises on a missing
    or unreadable file — a post-write hook must not be able to fail a task
    close. Embedder/sqlite errors DO propagate; the caller decides.
    """
    start = time.time()
    fpath = Path(path)
    if not fpath.is_absolute():
        fpath = Path(PROJECT_ROOT) / fpath
    try:
        rel_path = str(fpath.relative_to(PROJECT_ROOT))
    except ValueError:
        return {"skipped": "outside-project-root", "path": str(fpath)}

    if not fpath.is_file():
        return {"skipped": "not-a-file", "path": rel_path}

    # An index that was never built has no baseline to upsert into; the
    # bootstrap is reindex_incremental()'s job, not this hot path's.
    if not is_index_ready():
        return {"skipped": "index-not-ready", "path": rel_path}

    try:
        content = fpath.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        return {"skipped": f"unreadable: {exc}", "path": rel_path}
    if not content.strip():
        return {"skipped": "empty", "path": rel_path}

    lock_path = DB_PATH.with_suffix(DB_PATH.suffix + ".reindex.lock")
    lock_fd = os.open(str(lock_path), os.O_CREAT | os.O_RDWR, 0o644)
    try:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            return {"skipped": "reindex-in-progress", "path": rel_path}

        title = extract_title(fpath, content)
        category = categorize(rel_path)
        task_id = extract_task_id(fpath, content)
        content_hash = _content_hash(content)
        try:
            mtime = fpath.stat().st_mtime
        except OSError:
            mtime = start

        chunks = _chunk_content(content, reserve=len(title) + 2)
        if not chunks:
            return {"skipped": "no-chunks", "path": rel_path}

        # Same convention as the corpus builder: every chunk after the first is
        # prefixed with the title so an isolated chunk still carries its subject.
        texts = [c if i == 0 else f"{title}\n\n{c}" for i, c in enumerate(chunks)]
        # build_index() keeps its own BATCH_SIZE as a function-local; mirroring
        # the value here rather than importing it keeps this path independent of
        # a constant that is tuned for whole-corpus throughput.
        batch_size = 64
        vecs: list[bytes] = []
        for j in range(0, len(texts), batch_size):
            vecs.extend(_embed(texts[j:j + batch_size]))

        db = _get_db()
        _delete_path_rows(db, rel_path)
        stamp = time.time()
        for i, (chunk, emb) in enumerate(zip(chunks, vecs)):
            cur = db.execute(
                "INSERT INTO documents (path, title, category, task_id, "
                "chunk_index, chunk_text) VALUES (?, ?, ?, ?, ?, ?)",
                (rel_path, title, category, task_id, i, chunk),
            )
            db.execute("INSERT INTO vec_documents (id, embedding) VALUES (?, ?)",
                       (cur.lastrowid, emb))
        db.execute(
            "INSERT INTO file_state (path, content_hash, mtime, updated_at) "
            "VALUES (?, ?, ?, ?) ON CONFLICT(path) DO UPDATE SET "
            "content_hash = excluded.content_hash, mtime = excluded.mtime, "
            "updated_at = excluded.updated_at",
            (rel_path, content_hash, mtime, stamp),
        )
        db.commit()
    finally:
        os.close(lock_fd)

    return {
        "path": rel_path,
        "indexed_chunks": len(chunks),
        "elapsed_ms": int((time.time() - start) * 1000),
    }


def reindex_incremental() -> dict:
    """Re-embed only what changed, then swap the result into place atomically.

    T-3014, slice 5 of T-3005. `build_index()` is a full rebuild of the whole
    corpus — 393,082 chunks, hours — which cannot fit inside any schedule that
    also needs to fire again before it finishes. This instead:

      1. Bootstraps with one full `build_index()` if no index exists yet
         (first run ever, or after `DB_PATH` was deleted). An index that
         exists but predates the `file_state` table takes the path below
         with an empty baseline — correct, but it re-embeds everything, so
         it reports `mode: bootstrap-baseline` rather than `incremental`.
      2. Otherwise diffs `collect_files()` against the `file_state` table by
         content hash — sha256, not mtime, so a touch/checkout that doesn't
         change content doesn't trigger a re-embed — and only chunks + embeds
         the changed/added set. Removed files drop their rows. The canaries
         are always replanted with a fresh token: that token, seen live by
         `corpus_health()`, is the thing a scheduled run exists to prove
         happened (T-3014 AC1).
      3. Does all of that on a COPY of the database (`DB_PATH` + reindex.tmp),
         inside one sqlite transaction, and only `os.replace()`s it over the
         live file once the copy is fully committed. A process killed at any
         point before that line leaves `DB_PATH` — and therefore the manifest,
         which is written only *after* the swap — exactly as the previous run
         left them. There is no window where a reader can see a half-built
         index: it is either the old file or the new one, never a mixture.

    Raises whatever the embedder / sqlite raise; the caller (`fw index reindex`)
    is expected to catch and report, same as `build_index`.

    Concurrency is owned HERE, not by the caller. The cron line wraps this in
    flock, but that only serialises cron against cron — a manual run, a second
    console, or anything else that imports this module races it. Observed live
    on the first real bootstrap (T-3014): the scratch file was unlinked out from
    under a 25-minute run, which kept embedding into an unlinked inode and would
    have finished by swapping a path that no longer existed. So: a per-process
    scratch name nobody else will pick, an advisory lock taken here, and an
    identity check before the swap.
    """
    global _db, _db_opened_at

    start = time.time()

    if not is_index_ready():
        stats = build_index()
        stats["mode"] = "bootstrap-full"
        return stats

    lock_path = DB_PATH.with_suffix(DB_PATH.suffix + ".reindex.lock")
    lock_fd = os.open(str(lock_path), os.O_CREAT | os.O_RDWR, 0o644)
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        os.close(lock_fd)
        # Another reindex owns the index. Returning beats queueing: the caller
        # is an hourly cron, and a bootstrap run legitimately outlasts the gap
        # between firings.
        return {
            "mode": "skipped-locked",
            "detail": f"another reindex holds {lock_path.name}",
            "build_time_ms": int((time.time() - start) * 1000),
        }

    # Per-process scratch name: two runs cannot collide on it, and a run that
    # died without unlinking leaves a corpse attributable to a dead pid rather
    # than a live run's working file. Sweep those before starting.
    for stale in DB_PATH.parent.glob(DB_PATH.name + ".reindex.*.tmp*"):
        try:
            stale.unlink()
        except OSError:
            pass

    tmp_path = DB_PATH.with_suffix(DB_PATH.suffix + f".reindex.{os.getpid()}.tmp")

    # A partial run parks its work here instead of throwing it away. The diff
    # below is driven by file_state, so resuming needs no bookkeeping of its
    # own: files this scratch already embedded are recorded, read as unchanged,
    # and skipped. That is what lets an hourly cron finish a ~29-58h bootstrap
    # across many firings rather than restarting it forever (OBS-258).
    resume_path = DB_PATH.with_suffix(DB_PATH.suffix + ".reindex.resume")
    resumed = False
    if resume_path.exists():
        try:
            probe = sqlite3.connect(str(resume_path))
            has_state = probe.execute(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='table' "
                "AND name='file_state'").fetchone()[0]
            probe.close()
            if has_state:
                shutil.move(str(resume_path), str(tmp_path))
                resumed = True
        except sqlite3.Error:
            pass
        if not resumed:
            # Unreadable or schema-less: not worth trusting as a baseline.
            resume_path.unlink(missing_ok=True)
    if not resumed:
        shutil.copy2(DB_PATH, tmp_path)
    tmp_ino = tmp_path.stat().st_ino

    db = None
    swapped = False
    try:
        db = sqlite3.connect(str(tmp_path), check_same_thread=False)
        db.enable_load_extension(True)
        sqlite_vec.load(db)
        db.enable_load_extension(False)
        db.execute("""
            CREATE TABLE IF NOT EXISTS file_state (
                path TEXT PRIMARY KEY,
                content_hash TEXT NOT NULL,
                mtime REAL NOT NULL,
                updated_at REAL NOT NULL
            )
        """)

        existing = dict(db.execute(
            "SELECT path, content_hash FROM file_state").fetchall())

        # The universe of what is actually indexed is `documents`, not
        # `file_state`. They agree for any index this function built, and
        # disagree for one built before slice 5 existed — which is precisely
        # the index the first scheduled run will meet (the live one: 21,292
        # chunks over 1,380 paths, no file_state table at all). Computing
        # removals from the bookkeeping table would mean a legacy index never
        # purges anything, because its bookkeeping is empty: 35 paths on the
        # live index are tasks that moved active/ -> completed/, and the stale
        # copy would sit in search results next to the fresh one forever.
        indexed = {r[0] for r in db.execute(
            "SELECT DISTINCT path FROM documents WHERE category != ?",
            (CANARY_CATEGORY,)).fetchall()}
        # Empty bookkeeping over a non-empty index means no baseline: every
        # file below will read as changed and this run costs a full rebuild.
        # Say so in the stats rather than letting it read as the cheap path.
        baseline_missing = not existing and bool(indexed)

        seen: set[str] = set()
        changed: list[tuple[Path, str, str, str]] = []  # fpath, rel_path, content, hash
        for fpath in collect_files():
            try:
                content = fpath.read_text(errors="replace")
            except Exception:
                continue
            if not content.strip():
                continue
            rel_path = str(fpath.relative_to(PROJECT_ROOT))
            seen.add(rel_path)
            content_hash = _content_hash(content)
            if existing.get(rel_path) != content_hash:
                changed.append((fpath, rel_path, content, content_hash))

        removed = sorted((set(existing) | indexed) - seen)
        for path in removed:
            _delete_path_rows(db, path)

        db.commit()  # removals are durable before any embedding starts

        # Embed and commit in file-sized groups rather than accumulating the
        # whole corpus first. Two reasons, both measured on the real index:
        #
        #  - Durability. At 1.9 chunks/s (measured against the live embed host,
        #    contended) a 394,230-chunk bootstrap is ~29-58h. Accumulating it
        #    all before the first write meant a kill at hour 28 lost everything
        #    and the next cron firing started from zero — an hourly schedule can
        #    never converge on that. Committing per group makes progress
        #    survive, so successive firings chip away at the backlog instead.
        #  - Memory. 394,230 x 768 x 4B is ~1.2GiB of vectors alone, before the
        #    chunk text they were built from. Observed RSS: 1,206 MiB and still
        #    climbing when the run was stopped.
        BATCH_SIZE = 64
        # Checkpoint on accumulated CHUNKS, not on a file count. File sizes vary
        # by orders of magnitude here (mean ~43 chunks, but a long report is
        # hundreds), so "every N files" makes the interval between durable
        # points unpredictable — measured at ~15 min for N=40, which is 15 min
        # of work a kill can still take. Bounding by chunks makes each
        # checkpoint cost about the same wall-clock regardless of what is in it.
        # Files stay atomic: a group is only flushed on a file boundary, so a
        # file's rows and its file_state entry always land together — which is
        # what makes the resume skip correct.
        CHUNK_CHECKPOINT = 512
        embedded_chunks = 0
        # Throughput work goes to the bulk host, not the query host (T-3016).
        bulk_host = Config.EMBED_BULK_HOST

        def _flush(meta_rows: list[dict], texts: list[str]) -> None:
            """Embed `texts`, insert their rows, and commit as one durable step."""
            nonlocal embedded_chunks
            vecs: list[bytes] = []
            for j in range(0, len(texts), BATCH_SIZE):
                vecs.extend(_embed(texts[j:j + BATCH_SIZE], host=bulk_host))
            stamp = time.time()
            done: set[str] = set()
            for meta, emb in zip(meta_rows, vecs):
                cur = db.execute(
                    "INSERT INTO documents (path, title, category, task_id, "
                    "chunk_index, chunk_text) VALUES (?, ?, ?, ?, ?, ?)",
                    (meta["path"], meta["title"], meta["category"],
                     meta["task_id"], meta["chunk_index"], meta["chunk_text"]),
                )
                db.execute("INSERT INTO vec_documents (id, embedding) VALUES (?, ?)",
                           (cur.lastrowid, emb))
                if meta["category"] != CANARY_CATEGORY and meta["path"] not in done:
                    done.add(meta["path"])
                    db.execute(
                        "INSERT INTO file_state (path, content_hash, mtime, updated_at) "
                        "VALUES (?, ?, ?, ?) ON CONFLICT(path) DO UPDATE SET "
                        "content_hash = excluded.content_hash, mtime = excluded.mtime, "
                        "updated_at = excluded.updated_at",
                        (meta["path"], meta["content_hash"], meta["mtime"], stamp),
                    )
            db.commit()
            embedded_chunks += len(vecs)

        group_meta: list[dict] = []
        group_texts: list[str] = []
        for done_files, (fpath, rel_path, content, content_hash) in enumerate(changed, 1):
            _delete_path_rows(db, rel_path)
            title = extract_title(fpath, content)
            category = categorize(rel_path)
            task_id = extract_task_id(fpath, content)
            try:
                mtime = fpath.stat().st_mtime
            except OSError:
                mtime = start
            for i, chunk in enumerate(_chunk_content(content, reserve=len(title) + 2)):
                group_texts.append(f"{title}\n\n{chunk}" if i > 0 else chunk)
                group_meta.append({
                    "path": rel_path, "title": title, "category": category,
                    "task_id": task_id, "chunk_index": i, "chunk_text": chunk,
                    "content_hash": content_hash, "mtime": mtime,
                })
            if len(group_texts) >= CHUNK_CHECKPOINT:
                _flush(group_meta, group_texts)
                group_meta, group_texts = [], []
                log.info("reindex progress: %d/%d files, %d chunks embedded",
                         done_files, len(changed), embedded_chunks)
        if group_texts:
            _flush(group_meta, group_texts)

        all_chunks: list[str] = []
        all_meta: list[dict] = []

        # Canaries are never diffed by hash — they are always replanted, and
        # the token changes every run. That is what proves the run executed
        # rather than merely exited 0 (AC1). Three small documents; cheap.
        # Microsecond resolution: unlike build_index() (an hours-long full
        # rebuild, where second-granularity collisions are not a concern),
        # scheduled incremental runs can plausibly land in the same second.
        canary_token = f"FWCANARY-{int(start * 1_000_000)}"
        canary_ids = [r[0] for r in db.execute(
            "SELECT id FROM documents WHERE category = ?",
            (CANARY_CATEGORY,)).fetchall()]
        if canary_ids:
            db.executemany("DELETE FROM vec_documents WHERE id = ?",
                           [(i,) for i in canary_ids])
            db.execute("DELETE FROM documents WHERE category = ?",
                      (CANARY_CATEGORY,))
        for doc in all_canaries(canary_token):
            for i, chunk in enumerate(_chunk_content(doc.text, reserve=len(doc.title) + 2)):
                all_chunks.append(f"{doc.title}\n\n{chunk}" if i > 0 else chunk)
                all_meta.append({
                    "path": doc.path, "title": doc.title, "category": CANARY_CATEGORY,
                    "task_id": "", "chunk_index": i, "chunk_text": chunk,
                    "content_hash": None, "mtime": None,
                })

        # Canaries last, in their own flush: they are the freshness signal, so
        # they must not land before the corpus they claim to vouch for.
        _flush(all_meta, all_chunks)

        num_chunks = db.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
        num_docs = db.execute(
            "SELECT COUNT(DISTINCT path) FROM documents").fetchone()[0]
        db.close()
        db = None

        # Refuse to publish a file that is not the one we just built. If our
        # scratch file was unlinked and recreated by someone else, swapping it
        # in would install a stranger's database over the live index — a silent
        # wrong-data outcome, the worst class available here. Fail loudly and
        # leave the previous index serving instead.
        try:
            live_ino = tmp_path.stat().st_ino
        except FileNotFoundError:
            raise RuntimeError(
                f"reindex scratch file {tmp_path.name} vanished mid-run; "
                "refusing to swap. The previous index is untouched."
            ) from None
        if live_ino != tmp_ino:
            raise RuntimeError(
                f"reindex scratch file {tmp_path.name} was replaced mid-run "
                f"(inode {tmp_ino} -> {live_ino}); refusing to swap. "
                "The previous index is untouched."
            )

        # The only line that can make this run visible. Anything raised above
        # this point leaves DB_PATH untouched — the tmp copy is discarded in
        # `finally` and the previous index keeps serving.
        os.replace(tmp_path, DB_PATH)
        swapped = True
    finally:
        if db is not None:
            db.close()
        if not swapped and tmp_path.exists():
            # Park the partial work rather than discarding it. Everything in
            # here is committed and consistent — the run simply did not reach
            # the end of the file list. The next run resumes from it.
            try:
                shutil.move(str(tmp_path), str(resume_path))
            except OSError:
                tmp_path.unlink(missing_ok=True)
        for leftover in DB_PATH.parent.glob(DB_PATH.name + f".reindex.{os.getpid()}.tmp*"):
            leftover.unlink(missing_ok=True)
        if swapped:
            resume_path.unlink(missing_ok=True)
        fcntl.flock(lock_fd, fcntl.LOCK_UN)
        os.close(lock_fd)

    # Manifest is written LAST, and only after the swap — so a reader who
    # sees a fresh manifest is guaranteed to also see the matching database
    # (T-3014 AC4). A manifest write failure here is best-effort, same as
    # build_index(): the index itself is already live and correct.
    manifest_written = False
    try:
        write_manifest(DB_PATH, build_manifest(
            num_docs=num_docs,
            num_chunks=num_chunks,
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
        log.warning("corpus manifest not written after incremental reindex: %s", exc)

    # DB_PATH is now a different inode than whatever this process had open.
    _db = None
    _db_opened_at = 0.0

    return {
        # "bootstrap-baseline": the index existed but carried no file_state, so
        # every file was re-embedded. Costs a full rebuild; happens once.
        "mode": "bootstrap-baseline" if baseline_missing else "incremental",
        "num_docs": num_docs,
        "num_chunks": num_chunks,
        "files_changed": len(changed),
        "files_removed": len(removed),
        "build_time_ms": int((time.time() - start) * 1000),
        "canary_token": canary_token,
        "manifest_written": manifest_written,
        # Named, not assumed: a run that quietly embedded against the slow host
        # is 37x more expensive and otherwise indistinguishable from a fast one.
        "embed_host": bulk_host,
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
    with recall_telemetry.record(recall_telemetry.SURFACE_SEMANTIC, query) as _t:
        result = _semantic_search(query, limit)
        _t.observe(result)
        return result


def _semantic_search(query: str, limit: int) -> dict:
    """The semantic path itself, without telemetry.

    Split out so `hybrid_search` can use it without emitting a second row for
    what is one user query — see `web/recall_telemetry` on outermost-only
    counting. Callers wanting the "used" signal recorded should call `search`.
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
    with recall_telemetry.record(recall_telemetry.SURFACE_HYBRID, query) as _t:
        result = _hybrid_search(query, limit)
        _t.observe(result)
        return result


def _hybrid_search(query: str, limit: int) -> dict:
    """The fusion itself. Telemetry lives on the public `hybrid_search`.

    Note this calls the *public* `search`, not a private semantic helper: the
    nested row is suppressed by the re-entrancy guard in `recall_telemetry`,
    which makes that guard load-bearing rather than belt-and-braces. Routing
    around it structurally here would leave the guard untestable — a mutation
    that removed it would break nothing, and the test asserting one-row-per-
    query would pass for the wrong reason.
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
    with recall_telemetry.record(recall_telemetry.SURFACE_RAG, query) as _t:
        result = _rag_retrieve(query, limit)
        _t.observe(result)
        return result


def _rag_retrieve(query: str, limit: int) -> list[dict]:
    """The RAG path itself. Telemetry lives on the public `rag_retrieve`.

    Note this does *not* go through `hybrid_search` despite what the public
    docstring above has long claimed — it runs its own vector query and its own
    RRF fusion. That makes it a third independent recall surface, not a wrapper,
    which is why it earns its own row rather than inheriting one.
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
    """Return stats about the current vector index.

    `built_at` used to be the handle-open time (T-3012). It is kept — callers and
    templates read it — but it now reports what the name always claimed, so the
    two numbers are separated rather than conflated:

      index_built_at / index_age_seconds / freshness_source — the index on disk
      handle_opened_at — when this process opened its connection

    Both are legitimate. Only one of them is the index's age.
    """
    db = _get_db()
    num_chunks = db.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
    num_docs = db.execute("SELECT COUNT(DISTINCT path) FROM documents").fetchone()[0]
    fresh = index_freshness()
    return {
        "num_docs": num_docs,
        "num_chunks": num_chunks,
        "built_at": fresh["built_at"],
        "index_built_at": fresh["built_at"],
        "index_age_seconds": fresh["age_seconds"],
        "freshness_source": fresh["source"],
        "handle_opened_at": _db_opened_at,
        "db_path": str(DB_PATH),
        "model": MODEL_NAME,
        "embedding_dim": EMBEDDING_DIM,
    }
