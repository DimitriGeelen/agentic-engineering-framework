"""Tantivy BM25 full-text search for Watchtower.

Indexes all YAML/Markdown files in the framework, provides ranked search
with snippet highlighting. Index is rebuilt on demand when stale.

T-237: Phase 1 — BM25 keyword search via tantivy.
"""

import os
import re
import time
from pathlib import Path

import tantivy

from web.shared import PROJECT_ROOT

# Index lives in /tmp — ephemeral, rebuilt as needed
INDEX_DIR = Path("/tmp/fw-search-index")

# Staleness threshold: rebuild if older than 60 seconds
STALE_SECONDS = 60

# Singleton
_index = None
_index_built_at = 0.0


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
    if ".context/qa/" in path_str:
        return "Saved Answers"
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
    # YAML frontmatter: look for name: field
    name_match = re.search(r'^name:\s*["\']?(.+?)["\']?\s*$', content, re.MULTILINE)
    if name_match:
        return name_match.group(1).strip()

    # Markdown heading
    heading_match = re.search(r'^#\s+(.+)$', content, re.MULTILINE)
    if heading_match:
        return heading_match.group(1).strip()

    # Fallback: filename
    return path.stem.replace("-", " ").replace("_", " ").title()


def _collect_files() -> list[Path]:
    """Collect all indexable files from the project."""
    files = []
    search_dirs = [
        PROJECT_ROOT / ".tasks",
        PROJECT_ROOT / ".context" / "episodic",
        PROJECT_ROOT / ".context" / "project",
        PROJECT_ROOT / ".context" / "handovers",
        PROJECT_ROOT / ".fabric" / "components",
        PROJECT_ROOT / ".context" / "qa",
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


def _build_schema() -> tantivy.Schema:
    """Build the tantivy schema."""
    builder = tantivy.SchemaBuilder()
    builder.add_text_field("title", stored=True, tokenizer_name="en_stem")
    builder.add_text_field("body", stored=True, tokenizer_name="en_stem")
    builder.add_text_field("path", stored=True, tokenizer_name="raw")
    builder.add_text_field("category", stored=True, tokenizer_name="raw")
    builder.add_text_field("task_id", stored=True, tokenizer_name="raw")
    return builder.build()


def _extract_task_id(path: Path, content: str) -> str:
    """Extract T-XXX task ID from path or content."""
    # From filename
    match = re.search(r"(T-\d+)", path.name)
    if match:
        return match.group(1)

    # From content (id: field or task_id: field)
    match = re.search(r"^(?:id|task_id):\s*(T-\d+)", content, re.MULTILINE)
    if match:
        return match.group(1)

    return ""


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

    files = _collect_files()
    indexed = 0

    for fpath in files:
        try:
            content = fpath.read_text(errors="replace")
            if not content.strip():
                continue

            rel_path = str(fpath.relative_to(PROJECT_ROOT))
            title = _extract_title(fpath, content)
            category = _categorize(rel_path)
            task_id = _extract_task_id(fpath, content)

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
