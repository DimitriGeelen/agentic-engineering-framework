"""Tantivy BM25 full-text search for Watchtower.

Indexes all YAML/Markdown files in the framework, provides ranked search
with snippet highlighting. Index is rebuilt on demand when stale.

T-237: Phase 1 — BM25 keyword search via tantivy.
"""

import time
from pathlib import Path

import tantivy

from web.search_utils import categorize, collect_files, extract_task_id, extract_title
from web.shared import PROJECT_ROOT

# Index lives in /tmp — ephemeral, rebuilt as needed
INDEX_DIR = Path("/tmp/fw-search-index")

# Staleness threshold: rebuild if older than 60 seconds
STALE_SECONDS = 60

# Singleton
_index = None
_index_built_at = 0.0


def _build_schema() -> tantivy.Schema:
    """Build the tantivy schema."""
    builder = tantivy.SchemaBuilder()
    builder.add_text_field("title", stored=True, tokenizer_name="en_stem")
    builder.add_text_field("body", stored=True, tokenizer_name="en_stem")
    builder.add_text_field("path", stored=True, tokenizer_name="raw")
    builder.add_text_field("category", stored=True, tokenizer_name="raw")
    builder.add_text_field("task_id", stored=True, tokenizer_name="raw")
    return builder.build()


def build_index() -> tantivy.Index:
    """Build a fresh tantivy index from all framework files."""
    global _index, _index_built_at

    schema = _build_schema()

    # Create index directory
    INDEX_DIR.mkdir(parents=True, exist_ok=True)

    # Clean old index
    for f in INDEX_DIR.iterdir():
        f.unlink()

    index = tantivy.Index(schema, path=str(INDEX_DIR))
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

    _index = index
    _index_built_at = time.time()

    return index


def get_index() -> tantivy.Index:
    """Get the search index, rebuilding if stale."""
    global _index, _index_built_at

    if _index is not None and (time.time() - _index_built_at) < STALE_SECONDS:
        return _index

    return build_index()


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
        "index_dir": str(INDEX_DIR),
        "stale_seconds": STALE_SECONDS,
    }
