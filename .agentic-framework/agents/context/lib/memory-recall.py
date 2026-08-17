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

# T-3056: how many open tasks may appear in one recall. This is an ADDITIVE
# budget, not a share of `limit` — the three memory sources return exactly what
# they returned before this change, and open tasks are appended. That is what
# makes "open tasks crowded out the learnings" unreachable by construction
# rather than by ranking luck.
#
# Two, because the failure this fixes needs only one pointer at the open task
# already diagnosing the problem; a second covers the near-duplicate case. More
# turns the Related-knowledge block into a task list, which is what `fw task
# list` is for.
OPEN_TASK_SLOTS = 2

# A word appearing in more than this fraction of open task NAMES is treated as
# having no discriminating power and dropped before scoring. Measured on the live
# corpus (368 open tasks): 0.10 drops exactly `watchtower` (48 names) and `slice`
# (38) — two words that genuinely cannot tell one task here from another. 0.05
# also drops `dispatch`, `inception`, `corpus`, `termlink`, which are real topic
# words, so it overshoots.
DF_CEILING = 0.10

# ...but only once there is a corpus to measure frequency over. Below this,
# DF_CEILING resolves to a ceiling of 1 (int(5 * 0.10) == 0), so any word shared
# by two tasks would be discarded and a small project would get nothing back,
# permanently and silently. Document frequency is meaningless at that size
# anyway: 10% of eight tasks is not a signal about anything.
DF_MIN_CORPUS = 30

# Minimum distinct query words a task name must match to be offered at all.
# Chosen by reading the MARGINAL pair at each floor on the live corpus (368 open
# tasks) — the hit rate alone does not say whether the hits are any good:
#
#   floor 3 -> 50% of tasks get a hit, and the pairs scoring exactly 3 are junk
#              ("Ship watchtower.service systemd template" offered against
#              "PreToolUse Write/Edit hook refuses save"). Half of all focus
#              calls carrying a wrong answer is worse than the blindness.
#   floor 4 -> 22%, and the pairs scoring exactly 4 are real: T-1773
#              ("spawn-side dispatch driver") against T-1774 ("fw resolver run:
#              CLI integration of spawn driver") — consecutive slices of one
#              piece of work, which is exactly the rediscovery this prevents.
#   floor 5 -> 11%, near-duplicates only (T-1792/T-1794 differ by one word).
#              Correct but too strict: it would miss T-1773/T-1774.
#
# Re-measure rather than trusting these numbers; the corpus moves. The bound is
# pinned two-sided in tests/unit/t3056_recall_open_tasks.bats, because 0% (silent
# no-op) and 100% (noise on every call) are both failures and they look nothing
# alike from the code.
OPEN_TASK_FLOOR = 4


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


def load_open_tasks(exclude: str = None) -> list:
    """The fourth corpus (T-3056): tasks that are still open.

    The three sources above are all harvested from *closed* work, so before this
    the recall surfaces could not see the in-flight half of the project's memory
    at all — an open task already diagnosing a problem was invisible to the agent
    about to diagnose it again. Upstream measured that cost directly: their
    T-1390 was rediscovered as T-1537 twenty-five days later, less accurately.

    `exclude` drops one task id. `fw context focus T-XXX` builds its query from
    T-XXX's own name and description (`get_task_context`), so without this every
    focus call would recall the task just focused on — a self-match that looks
    exactly like the feature working.

    Frontmatter is parsed by regex over the head of each file rather than with
    yaml.safe_load: this runs on the `fw context focus` hot path across a few
    hundred files, and a task body is not needed to know what the task is about.
    """
    items = []
    d = PROJECT_ROOT / ".tasks" / "active"
    if not d.exists():
        return items

    for f in sorted(d.glob("T-*.md")):
        m = re.match(r'^(T-\d+)-', f.name)
        if not m:
            continue
        tid = m.group(1)
        if exclude and tid == exclude:
            continue
        try:
            head = f.read_text(errors="replace")[:4096]
        except OSError:
            continue

        # name: and description: are routinely folded across lines, so pull the
        # continuation too — a truncated name loses the topic words that are the
        # whole point of indexing these.
        name = ""
        nm = re.search(r'^name:[ \t]*(.+(?:\n[ \t]+\S.*)*)', head, re.MULTILINE)
        if nm:
            name = " ".join(nm.group(1).split()).strip('"\'')

        desc = ""
        dm = re.search(r'^description:[ \t]*>?[ \t]*\n((?:[ \t]+\S.*\n)+)',
                       head, re.MULTILINE)
        if dm:
            desc = " ".join(dm.group(1).split())[:300]

        items.append({
            "type": "task",
            "id": tid,
            "text": name or tid,
            "context": desc,
            "task": "",
            "application": "",
        })
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


# Words that carry no topic signal. Not a general stopword list — just the ones
# that show up in task names often enough to manufacture matches.
_NOISE_WORDS = {
    "with", "from", "that", "this", "than", "then", "when", "what", "which",
    "into", "onto", "over", "under", "have", "does", "were", "been", "task",
    "tasks", "only", "never", "always", "must", "will", "would", "could",
    "should", "there", "their", "they", "them", "some", "same", "each", "more",
    "most", "such", "even", "also", "because", "after", "before", "while",
}


def _topic_tokens(text: str) -> set:
    """Topic-bearing words, by the SAME rule on both sides of a comparison.

    Query and haystack must be tokenised identically or the thresholds tuned
    against one of them mean nothing for the other. The first cut of this used
    `[a-z0-9]+` to split the query (so `do_drift` yields `drift`) and `\\bdrift`
    to search the name (where `_` is a word character, so it does not match) —
    `fabric ... do_drift` scored 2 instead of 3 and fell under the floor. The bug
    was invisible in the tuning measurement, which used set intersection on both
    sides and so was self-consistent.
    """
    return {w for w in re.findall(r'[a-z0-9]+', text.lower())
            if len(w) >= 4
            and w not in _NOISE_WORDS
            and not w.isdigit()
            and not re.fullmatch(r't\d+', w)}


def search_open_tasks(query: str, tasks: list, limit: int):
    """Keyword search over open tasks, with a relevance floor (T-3056).

    `search_keyword` scores by raw substring containment over every whitespace
    token, which is fine when a weak hit is one of five results drawn from ~600
    curated one-liners. Against 368 task names it is not: short tokens match
    almost anything, so the open-task slots would fill with noise on every single
    `fw context focus` — and two lines of confident-looking noise per focus call
    is worse than the blindness this task set out to fix.

    So: tokens of four characters or more, minus the words above, and three
    filters that were each chosen against a measurement of the live corpus rather
    than guessed. Returning nothing is the correct answer most of the time.

    **Scored against the task NAME only, not the description.** This is the one
    that mattered. A description carries provenance — "From T-3047 triage M-37
    (ring20-management, 2026-08-04)" — and every sibling filed from the same batch
    carries the same words, so description scoring ranked batch-mates above topic
    matches: focusing T-3056 offered T-3050 at 6 points on
    {context, agents, management, existing, triage, ring20} while the one
    genuinely related task scored 4. Real lexical overlap, zero topical signal.
    Names are written to say what the task is about; that is the field to search.

    **Task ids and bare numbers are dropped**, for the same reason — a query built
    from frontmatter carries the filing source, which is where a task came from
    and not what it is about.

    **Words in more than DF_CEILING of names are dropped**, and a task must match
    at least OPEN_TASK_FLOOR distinct words. Both thresholds are justified against
    measurements in their definitions above.
    """
    words = _topic_tokens(query)
    if not words:
        return []

    # Name only — see docstring.
    haystacks = [(item, _topic_tokens(item["text"])) for item in tasks]
    if not haystacks:
        return []

    if len(haystacks) >= DF_MIN_CORPUS:
        ceiling = max(1, int(len(haystacks) * DF_CEILING))
        words = {w for w in words
                 if sum(1 for _i, names in haystacks if w in names) <= ceiling}
        if not words:
            return []

    # A query with fewer meaningful words than the floor can never clear it, and
    # silently returning nothing forever is the failure mode this task exists to
    # fix. Fall back to requiring every word the query has.
    floor = min(OPEN_TASK_FLOOR, len(words))

    scored = []
    for item, names in haystacks:
        score = len(words & names)
        if score >= floor:
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
    type_colors = {"learning": GREEN, "pattern": YELLOW, "decision": CYAN,
                   "task": BOLD}
    color = type_colors.get(item["type"], NC)
    if item["type"] == "task":
        # T-3056: an open task is a different kind of hit from a harvested
        # learning — it is work in progress someone can be asked about, not a
        # conclusion. Say so, rather than rendering "(from <status>)".
        suffix = " (open task)"
    else:
        suffix = f" (from {item['task']})" if item.get("task") else ""
    text = item["text"]
    if len(text) > 80:
        text = text[:77] + "..."
    return f"{prefix}{color}{item['id']}{NC}: {text}{DIM}{suffix}{NC}"


def _recall_knowledge(query: str, limit: int, use_hybrid: bool) -> list:
    """The original three-source recall, unchanged in behaviour."""
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


def recall(query: str, limit: int = 5, use_hybrid: bool = True,
           exclude_task: str = None):
    """Main recall function — returns formatted output lines.

    Two independent searches, concatenated. Memory (learnings/patterns/decisions)
    keeps its own `limit` and its own hybrid-then-keyword path; open tasks get
    OPEN_TASK_SLOTS on top. Nothing the first search returns can be displaced by
    the second.

    Open tasks are searched by KEYWORD ONLY, deliberately (T-3056 A4). Hybrid
    lives behind `search_hybrid`, which filters vector hits to
    `category == "Project Memory"` and then maps them back onto `items` by
    substring-matching the snippet — a mapping that only works because every
    memory item is a short single sentence. Task hits carry a different category
    and a multi-kilobyte body, so routing them through that mapping would mean
    reworking it for two shapes at once. Keyword scoring over a task's name and
    description is adequate for the job here: those fields are dense with exactly
    the topic words a query is built from. If open-task recall later needs
    semantic matching, the honest change is a second hybrid call with its own
    category filter, not a widened mapping.
    """
    lines = _recall_knowledge(query, limit=limit, use_hybrid=use_hybrid)

    open_tasks = load_open_tasks(exclude=exclude_task)
    for _score, item in search_open_tasks(query, open_tasks, limit=OPEN_TASK_SLOTS):
        lines.append(format_item(item))

    return lines


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

    # T-3056: --task means the query was derived from that task's own
    # frontmatter, so it must not recall itself.
    lines = recall(query, limit=args.limit, use_hybrid=not args.no_hybrid,
                   exclude_task=args.task)

    if lines:
        print(f"{BOLD}Related knowledge:{NC}")
        for line in lines:
            print(line)
    else:
        print(f"{DIM}No relevant prior knowledge found.{NC}")


if __name__ == "__main__":
    main()
