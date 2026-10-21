"""Tantivy BM25 full-text search for Watchtower.

Indexes all YAML/Markdown files in the framework, provides ranked search
with snippet highlighting. Index is rebuilt on demand when stale.

T-237: Phase 1 — BM25 keyword search via tantivy.
"""
from __future__ import annotations


import atexit
import os
import shutil
import tempfile
import threading
import time
from pathlib import Path

import tantivy

from web.search_utils import categorize, collect_files, extract_task_id, extract_title
from web.shared import PROJECT_ROOT

# Index lives in /tmp — ephemeral, rebuilt as needed. T-4458: each build gets its
# own directory (<INDEX_PARENT>/<INDEX_PREFIX><pid>-*). The old single fixed
# directory was shared by every thread and every Watchtower on the host, and two
# rebuilds deleted each other's segment files mid-commit -> HTTP 500 on /search.
INDEX_PARENT = Path(tempfile.gettempdir())
INDEX_PREFIX = "fw-search-index-"
INDEX_DIR = None  # directory of the index currently served (for index_stats)

# Staleness threshold: rebuild if older than 60 seconds
STALE_SECONDS = 60

# Singleton
_index = None
_index_built_at = 0.0
_build_lock = threading.Lock()   # held for the whole build
_flag_lock = threading.Lock()    # guards _rebuilding only; never held across a build
_rebuilding = False
_retired_dirs: list = []  # previous generations, removed one build later


def _build_schema() -> tantivy.Schema:
    """Build the tantivy schema."""
    builder = tantivy.SchemaBuilder()
    builder.add_text_field("title", stored=True, tokenizer_name="en_stem")
    builder.add_text_field("body", stored=True, tokenizer_name="en_stem")
    builder.add_text_field("path", stored=True, tokenizer_name="raw")
    builder.add_text_field("category", stored=True, tokenizer_name="raw")
    builder.add_text_field("task_id", stored=True, tokenizer_name="raw")
    return builder.build()


def _remove_orphan_dirs() -> None:
    """Remove index directories left by Watchtower processes that have exited."""
    for d in INDEX_PARENT.glob(INDEX_PREFIX + "*"):
        pid = d.name[len(INDEX_PREFIX):].split("-", 1)[0]
        if not pid.isdigit() or int(pid) == os.getpid():
            continue
        try:
            os.kill(int(pid), 0)
        except ProcessLookupError:
            shutil.rmtree(d, ignore_errors=True)
        except OSError:
            pass


def _remove_own_dirs() -> None:
    """T-4526: remove this process's index directories when it exits.

    Without it every exited process left its last generation behind until some
    other process built an index (and only then if it shared INDEX_PARENT):
    ~1 GB of /tmp/fw-search-index-* on the shared host. The pid prefix keeps a
    forked child from removing its parent's live index.
    """
    mine = f"{INDEX_PREFIX}{os.getpid()}-"
    for d in [*_retired_dirs, INDEX_DIR]:
        if d is not None and Path(d).name.startswith(mine):
            shutil.rmtree(d, ignore_errors=True)


atexit.register(_remove_own_dirs)


def build_index() -> tantivy.Index:
    """Build a fresh tantivy index from all framework files.

    Serialised by _build_lock and written to a directory no other build uses, so
    a concurrent request never sees a half-written or half-deleted index (T-4458).
    """
    with _build_lock:
        return _build_index_locked()


def _build_index_locked() -> tantivy.Index:
    global _index, _index_built_at, INDEX_DIR

    schema = _build_schema()

    _remove_orphan_dirs()
    new_dir = Path(tempfile.mkdtemp(prefix=f"{INDEX_PREFIX}{os.getpid()}-", dir=INDEX_PARENT))

    index = tantivy.Index(schema, path=str(new_dir))
    writer = index.writer(heap_size=50_000_000)

    files = collect_files()
    indexed = 0

    for fpath in files:
        try:
            content = fpath.read_text(errors="replace")
            if not content.strip():
                continue

            rel_path = str(fpath.relative_to(PROJECT_ROOT))
            title = extract_title(fpath, content)
            category = categorize(rel_path)
            task_id = extract_task_id(fpath, content)

            writer.add_document(tantivy.Document(
                title=title,
                body=content,
                path=rel_path,
                category=category,
                task_id=task_id,
            ))
            indexed += 1
        except Exception:
            continue

    writer.commit()
    index.reload()

    # Searchers opened on the previous generation may still be reading it, so it
    # is removed one build later, not now.
    while _retired_dirs:
        shutil.rmtree(_retired_dirs.pop(), ignore_errors=True)
    if INDEX_DIR is not None:
        _retired_dirs.append(INDEX_DIR)

    _index = index
    _index_built_at = time.time()
    INDEX_DIR = new_dir

    return index


def _rebuild_in_background() -> None:
    global _rebuilding
    try:
        build_index()
    except Exception:
        pass  # keep serving the previous index; the next stale read retries
    finally:
        with _flag_lock:
            _rebuilding = False


def get_index() -> tantivy.Index:
    """Get the search index, rebuilding if stale.

    A stale index is still served while a background thread rebuilds it: the
    build reads every file in the corpus (17 s at load ~20, T-4458), which must
    not sit on a request thread once there is something to answer with.
    """
    global _rebuilding

    if _index is not None and (time.time() - _index_built_at) < STALE_SECONDS:
        return _index

    if _index is not None:
        with _flag_lock:
            start = not _rebuilding
            _rebuilding = True
        if start:
            threading.Thread(target=_rebuild_in_background, name="fw-search-rebuild",
                             daemon=True).start()
        return _index

    with _build_lock:
        if _index is not None:  # another request finished the first build while we waited
            return _index
        return _build_index_locked()


def search(query_str: str, limit: int = 30) -> dict:
    """Search the index and return categorized results with snippets.

    Returns:
        {
            "query": str,
            "total_hits": int,
            "categories": {
                "Category Name": [
                    {
                        "path": str,
                        "title": str,
                        "task_id": str,
                        "score": float,
                        "snippet": str,  # HTML with <b> highlights
                    }
                ]
            }
        }
    """
    index = get_index()
    searcher = index.searcher()
    schema = index.schema

    try:
        parsed = index.parse_query(query_str, ["title", "body"])
    except Exception:
        return {"query": query_str, "total_hits": 0, "categories": {}}

    results = searcher.search(parsed, limit)
    categories: dict[str, list] = {}

    # Create snippet generators
    try:
        body_snippets = tantivy.SnippetGenerator.create(
            searcher, parsed, schema, "body"
        )
    except Exception:
        body_snippets = None

    for score, addr in results.hits:
        doc = searcher.doc(addr)

        path = doc.get_first("path") or ""
        title = doc.get_first("title") or ""
        category = doc.get_first("category") or "Other"
        task_id = doc.get_first("task_id") or ""

        snippet_html = ""
        if body_snippets:
            try:
                snippet = body_snippets.snippet_from_doc(doc)
                snippet_html = snippet.to_html()
            except Exception:
                pass

        if category not in categories:
            categories[category] = []

        categories[category].append({
            "path": path,
            "title": title,
            "task_id": task_id,
            "score": round(score, 3),
            "snippet": snippet_html,
        })

    return {
        "query": query_str,
        "total_hits": len(results.hits),
        "categories": categories,
    }


def index_stats() -> dict:
    """Return basic stats about the current index."""
    index = get_index()
    searcher = index.searcher()
    return {
        "num_docs": searcher.num_docs,
        "built_at": _index_built_at,
        "index_dir": str(INDEX_DIR) if INDEX_DIR else "",
        "stale_seconds": STALE_SECONDS,
    }
