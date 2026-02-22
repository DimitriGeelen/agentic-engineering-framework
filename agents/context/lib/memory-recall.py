#!/usr/bin/env python3
"""Memory recall — query project knowledge for relevant prior learnings,
patterns, and decisions.

Called by `fw context focus` and `fw recall`. Uses hybrid search (T-245)
with fallback to keyword matching on YAML files directly.

T-246: Project memory read-path.
"""

import argparse
import os
import re
import sys
from pathlib import Path

# Colors
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
CYAN = '\033[0;36m'
BOLD = '\033[1m'
DIM = '\033[2m'
NC = '\033[0m'

FRAMEWORK_ROOT = Path(os.environ.get('FRAMEWORK_ROOT',
    Path(__file__).resolve().parent.parent.parent.parent))
PROJECT_ROOT = Path(os.environ.get('PROJECT_ROOT', str(FRAMEWORK_ROOT)))


def load_knowledge_items():
    """Load all learnings, patterns, and decisions from YAML files."""
    import yaml
    items = []

    # Learnings
    lf = PROJECT_ROOT / ".context" / "project" / "learnings.yaml"
    if lf.exists():
        try:
            with open(lf) as f:
                data = yaml.safe_load(f) or {}
            for item in data.get("learnings", []):
                items.append({
                    "type": "learning",
                    "id": item.get("id", ""),
                    "text": item.get("learning", ""),
                    "context": item.get("context", ""),
                    "task": item.get("task", ""),
                    "application": item.get("application", ""),
                })
        except Exception:
            pass

    # Patterns (all 4 categories)
    pf = PROJECT_ROOT / ".context" / "project" / "patterns.yaml"
    if pf.exists():
        try:
            with open(pf) as f:
                data = yaml.safe_load(f) or {}
            for cat in ("failure_patterns", "success_patterns",
                        "antifragile_patterns", "workflow_patterns"):
                for item in data.get(cat, []):
                    items.append({
                        "type": "pattern",
                        "id": item.get("id", ""),
                        "text": item.get("pattern", ""),
                        "context": item.get("description", ""),
                        "task": item.get("learned_from", ""),
                        "application": item.get("mitigation", "")
                            or item.get("example", "")
                            or item.get("context", ""),
                    })
        except Exception:
            pass

    # Decisions
    df = PROJECT_ROOT / ".context" / "project" / "decisions.yaml"
    if df.exists():
        try:
            with open(df) as f:
                data = yaml.safe_load(f) or {}
            for item in data.get("decisions", []):
                items.append({
                    "type": "decision",
                    "id": item.get("id", ""),
                    "text": item.get("decision", ""),
                    "context": item.get("rationale", ""),
                    "task": item.get("task", ""),
                    "application": "",
                })
        except Exception:
            pass

    return items


def search_hybrid(query: str, limit: int = 5):
    """Search using T-245 hybrid search, filtered to project memory."""
    try:
        os.chdir(str(FRAMEWORK_ROOT))
        from web.embeddings import hybrid_search
        results = hybrid_search(query, limit=limit * 3)
        # Filter to project memory files
        memory_results = []
        for item in results.get("results", []):
            if item.get("category") == "Project Memory":
                memory_results.append(item)
        return memory_results[:limit]
    except Exception:
        return None


def search_keyword(query: str, items: list, limit: int = 5):
    """Fallback keyword search across knowledge items."""
    query_words = set(query.lower().split())
    scored = []
    for item in items:
        searchable = f"{item['text']} {item['context']} {item['application']}".lower()
        score = sum(1 for w in query_words if w in searchable)
        if score > 0:
            scored.append((score, item))
    scored.sort(key=lambda x: x[0], reverse=True)
    return scored[:limit]


def get_task_context(task_id: str) -> str:
    """Build a search query from task name, description, and tags."""
    import yaml
    task_file = None
    for d in (PROJECT_ROOT / ".tasks" / "active",
              PROJECT_ROOT / ".tasks" / "completed"):
        if d.exists():
            for f in d.glob(f"{task_id}-*.md"):
                task_file = f
                break
        if task_file:
            break

    if not task_file:
        return task_id

    content = task_file.read_text(errors="replace")

    parts = []
    # Name
    name_match = re.search(r'^name:\s*["\']?(.+?)["\']?\s*$', content, re.MULTILINE)
    if name_match:
        parts.append(name_match.group(1))

    # Description (first 200 chars)
    desc_match = re.search(r'^description:\s*>?\s*\n\s+(.+)', content, re.MULTILINE)
    if desc_match:
        desc = desc_match.group(1).strip()[:200]
        parts.append(desc)

    # Tags
    tags_match = re.search(r'^tags:\s*\[(.+?)\]', content, re.MULTILINE)
    if tags_match:
        parts.append(tags_match.group(1).replace(",", " "))

    return " ".join(parts) if parts else task_id


def format_item(item: dict, prefix: str = "  ") -> str:
    """Format a knowledge item as a concise one-liner."""
    type_colors = {"learning": GREEN, "pattern": YELLOW, "decision": CYAN}
    color = type_colors.get(item["type"], NC)
    task_ref = f" (from {item['task']})" if item.get("task") else ""
    text = item["text"]
    if len(text) > 80:
        text = text[:77] + "..."
    return f"{prefix}{color}{item['id']}{NC}: {text}{DIM}{task_ref}{NC}"


def recall(query: str, limit: int = 5, use_hybrid: bool = True):
    """Main recall function — returns formatted output lines."""
    items = load_knowledge_items()

    if not items:
        return []

    # Try hybrid search first
    if use_hybrid:
        hybrid_results = search_hybrid(query, limit=limit)
        if hybrid_results:
            # Map hybrid results back to knowledge items by matching content
            matched = []
            for hr in hybrid_results:
                snippet = hr.get("snippet", "").lower()
                title = hr.get("title", "").lower()
                for item in items:
                    item_text = item["text"].lower()
                    if item_text in snippet or item_text in title or \
                       any(w in snippet for w in item_text.split()[:3] if len(w) > 3):
                        if item not in matched:
                            matched.append(item)
                            break
            if matched:
                return [format_item(m) for m in matched[:limit]]

    # Fallback: keyword search
    keyword_results = search_keyword(query, items, limit=limit)
    if keyword_results:
        return [format_item(item) for _score, item in keyword_results]

    return []


def main():
    parser = argparse.ArgumentParser(description="Query project memory")
    parser.add_argument("--query", "-q", help="Search query")
    parser.add_argument("--task", "-t", help="Task ID (builds query from task context)")
    parser.add_argument("--limit", "-n", type=int, default=5, help="Max results")
    parser.add_argument("--no-hybrid", action="store_true", help="Skip hybrid search")
    args = parser.parse_args()

    if args.task:
        query = get_task_context(args.task)
    elif args.query:
        query = args.query
    else:
        print(f"{YELLOW}Usage: memory-recall.py --query 'text' or --task T-XXX{NC}",
              file=sys.stderr)
        sys.exit(1)

    lines = recall(query, limit=args.limit, use_hybrid=not args.no_hybrid)

    if lines:
        print(f"{BOLD}Related knowledge:{NC}")
        for line in lines:
            print(line)
    else:
        print(f"{DIM}No relevant prior knowledge found.{NC}")


if __name__ == "__main__":
    main()
