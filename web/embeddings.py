"""sqlite-vec semantic search for Watchtower.

Embeds all YAML/Markdown knowledge files using all-MiniLM-L6-v2 (384-dim),
stores vectors in sqlite-vec, and provides semantic + hybrid search (RRF
fusion with Tantivy BM25).

T-245: sqlite-vec embedding layer — semantic search for project knowledge.
"""

import os
import re
import sqlite3
import struct
import time
from pathlib import Path

import sqlite_vec

from web.shared import PROJECT_ROOT

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

MODEL_NAME = "all-MiniLM-L6-v2"
EMBEDDING_DIM = 384
DB_PATH = Path("/tmp/fw-vec-index.db")
STALE_SECONDS = 120  # rebuild if older than 2 minutes

# Singleton state
_db = None
_model = None
_db_built_at = 0.0


# ---------------------------------------------------------------------------
# Embedding model (lazy-loaded singleton)
# ---------------------------------------------------------------------------

def _get_model():
    """Lazy-load the sentence transformer model."""
    global _model
    if _model is None:
        from sentence_transformers import SentenceTransformer
        _model = SentenceTransformer(MODEL_NAME)
    return _model


def _embed(texts: list[str]) -> list[bytes]:
    """Embed a batch of texts, returning raw float32 bytes for sqlite-vec."""
    model = _get_model()
    embeddings = model.encode(texts, show_progress_bar=False, normalize_embeddings=True)
    return [e.tobytes() for e in embeddings]


def _embed_single(text: str) -> bytes:
    """Embed a single text string."""
    return _embed([text])[0]


# ---------------------------------------------------------------------------
# File collection & chunking (mirrors web/search.py)
# ---------------------------------------------------------------------------

def _categorize(path_str: str) -> str:
    """Classify a file path into a search result category."""
    if ".tasks/active/" in path_str:
        return "Active Tasks"
    if ".tasks/completed/" in path_str:
        return "Completed Tasks"
    if ".context/episodic/" in path_str:
        return "Episodic Memory"
    if ".context/project/" in path_str:
        return "Project Memory"
    if ".context/handovers/" in path_str:
        return "Handovers"
    if ".fabric/components/" in path_str:
        return "Component Fabric"
    if "docs/reports/" in path_str:
        return "Research Reports"
    if "/agents/" in path_str:
        return "Agent Docs"
    return "Specifications"


def _extract_title(path: Path, content: str) -> str:
    """Extract a human-readable title from file content."""
    name_match = re.search(r'^name:\s*["\']?(.+?)["\']?\s*$', content, re.MULTILINE)
    if name_match:
        return name_match.group(1).strip()
    heading_match = re.search(r'^#\s+(.+)$', content, re.MULTILINE)
    if heading_match:
        return heading_match.group(1).strip()
    return path.stem.replace("-", " ").replace("_", " ").title()


def _extract_task_id(path: Path, content: str) -> str:
    """Extract T-XXX task ID from path or content."""
    match = re.search(r"(T-\d+)", path.name)
    if match:
        return match.group(1)
    match = re.search(r"^(?:id|task_id):\s*(T-\d+)", content, re.MULTILINE)
    if match:
        return match.group(1)
    return ""


def _collect_files() -> list[Path]:
    """Collect all indexable files from the project."""
    files = []
    search_dirs = [
        PROJECT_ROOT / ".tasks",
        PROJECT_ROOT / ".context" / "episodic",
        PROJECT_ROOT / ".context" / "project",
        PROJECT_ROOT / ".context" / "handovers",
        PROJECT_ROOT / ".fabric" / "components",
        PROJECT_ROOT / "docs" / "reports",
    ]
    for d in search_dirs:
        if d.exists():
            for f in d.rglob("*"):
                if f.is_file() and f.suffix in (".md", ".yaml", ".yml"):
                    files.append(f)
    # Top-level specs
    for f in PROJECT_ROOT.glob("*.md"):
        files.append(f)
    # Agent docs
    for f in PROJECT_ROOT.glob("agents/*/AGENT.md"):
        files.append(f)
    return files


def _chunk_content(content: str, max_chars: int = 1500) -> list[str]:
    """Split content into chunks suitable for embedding.

    Each chunk is roughly max_chars. Splits on section headings (## or ###)
    first, then on double newlines if still too long.
    """
    # Split on markdown headings
    sections = re.split(r'\n(?=#{1,3}\s)', content)
    chunks = []

    for section in sections:
        section = section.strip()
        if not section:
            continue
        if len(section) <= max_chars:
            chunks.append(section)
        else:
            # Split long sections on paragraph boundaries
            paragraphs = section.split("\n\n")
            current = ""
            for para in paragraphs:
                if len(current) + len(para) + 2 > max_chars and current:
                    chunks.append(current.strip())
                    current = para
                else:
                    current = current + "\n\n" + para if current else para
            if current.strip():
                chunks.append(current.strip())

    return chunks if chunks else [content[:max_chars]]


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


def _get_db() -> sqlite3.Connection:
    """Get the database connection, rebuilding index if stale."""
    global _db, _db_built_at

    if _db is not None and (time.time() - _db_built_at) < STALE_SECONDS:
        return _db

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
    files = _collect_files()

    # Collect all chunks with metadata
    all_chunks = []
    all_metadata = []

    for fpath in files:
        try:
            content = fpath.read_text(errors="replace")
            if not content.strip():
                continue

            rel_path = str(fpath.relative_to(PROJECT_ROOT))
            title = _extract_title(fpath, content)
            category = _categorize(rel_path)
            task_id = _extract_task_id(fpath, content)
            chunks = _chunk_content(content)

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

    if not all_chunks:
        _db = db
        _db_built_at = time.time()
        return {"num_docs": 0, "num_chunks": 0, "build_time_ms": 0}

    # Batch embed all chunks
    embeddings = _embed(all_chunks)

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

    return {
        "num_docs": num_docs,
        "num_chunks": len(all_chunks),
        "build_time_ms": elapsed_ms,
    }


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

    # Sort by RRF score descending, take top N
    sorted_paths = sorted(rrf_scores.keys(), key=lambda p: rrf_scores[p], reverse=True)
    return [item_data[p] for p in sorted_paths[:limit]]


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
