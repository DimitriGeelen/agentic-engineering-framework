"""Shared search utilities for Watchtower.

Canonical implementations of file classification, title extraction,
task ID parsing, file collection, and path-to-link resolution.

T-376: Deduplicated from web/search.py and web/embeddings.py.
"""
from __future__ import annotations


import re
from pathlib import Path

from web.shared import PROJECT_ROOT


def categorize(path_str: str) -> str:
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


def extract_title(path: Path, content: str) -> str:
    """Extract a human-readable title from file content."""
    name_match = re.search(r'^name:\s*["\']?(.+?)["\']?\s*$', content, re.MULTILINE)
    if name_match:
        return name_match.group(1).strip()

    heading_match = re.search(r'^#\s+(.+)$', content, re.MULTILINE)
    if heading_match:
        return heading_match.group(1).strip()

    return path.stem.replace("-", " ").replace("_", " ").title()


def extract_task_id(path: Path, content: str) -> str:
    """Extract T-XXX task ID from path or content."""
    match = re.search(r"(T-\d+)", path.name)
    if match:
        return match.group(1)

    match = re.search(r"^(?:id|task_id):\s*(T-\d+)", content, re.MULTILINE)
    if match:
        return match.group(1)

    return ""


def collect_files() -> list[Path]:
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


def aggregate_tags(limit: int = 30) -> list[dict]:
    """Aggregate tags from episodic memory for the tag cloud (T-392).

    Returns a list of {"tag": str, "count": int} sorted by count descending.
    Excludes low-value tags (single-char, pure IDs like D-001, P-001).
    """
    import yaml as _yaml

    counts: dict[str, int] = {}
    ep_dir = PROJECT_ROOT / ".context" / "episodic"
    if ep_dir.exists():
        for f in ep_dir.glob("T-*.yaml"):
            try:
                with open(f) as fh:
                    data = _yaml.safe_load(fh)
                if isinstance(data, dict):
                    for tag in data.get("tags", []):
                        t = str(tag).strip()
                        if t:
                            counts[t] = counts.get(t, 0) + 1
            except Exception:
                continue

    # Filter out noise: single-char, pure directive refs (D1, D2), policy refs (P-xxx)
    skip = re.compile(r'^(D\d|P-\d|[A-Z]-\d|.{0,2})$')
    filtered = [
        {"tag": t, "count": c}
        for t, c in counts.items()
        if not skip.match(t) and c >= 2
    ]
    filtered.sort(key=lambda x: (-x["count"], x["tag"]))
    return filtered[:limit]


def path_to_link(path: str) -> str:
    """Convert a project-relative file path to a Watchtower URL.

    Mirrors the JS pathToLink() function from search.html.
    Registered as a Jinja2 filter for use in templates.
    """
    if not path:
        return ""

    if path.startswith(".tasks/") and "/T-" in path:
        m = re.search(r"/T-(\d+)", path)
        return f"/tasks/T-{m.group(1)}" if m else ""

    if path.startswith(".fabric/components/"):
        comp_id = path.split("/")[-1].replace(".yaml", "")
        return f"/fabric/component/{comp_id}"

    if path.startswith(".context/episodic/") and path.endswith(".yaml"):
        task_ref = path.split("/")[-1].replace(".yaml", "")
        return f"/tasks/{task_ref}"

    if path == ".context/project/learnings.yaml":
        return "/learnings"
    if path == ".context/project/patterns.yaml":
        return "/patterns"
    if path == ".context/project/decisions.yaml":
        return "/decisions"

    if path.endswith(".md") and not path.startswith("."):
        return "/project/" + path.replace(".md", "").replace("/", "--")

    return ""
