#!/usr/bin/env python3
"""Task-pair §ACD gate (P-012) — G-066 prong 2.

Implementation of T-1713 GO scope. Detects substrate-vs-deliverable
conflation when a build task closes work-completed under an inception
parent that named follow-up build tasks in its Recommendation.

Mirror of T-1668/T-1671 arc-level §ACD gate at task-pair level.
"""
import glob
import json
import os
import re
import sys


def _load_recommendation_block(content):
    """Return the `## Recommendation` body (with HTML comments stripped)
    or None if the block is missing."""
    m = re.search(r"^## Recommendation\s*\n(.*?)(?=^##\s|\Z)",
                  content, re.DOTALL | re.MULTILINE)
    if not m:
        return None
    body = re.sub(r"<!--.*?-->", "", m.group(1), flags=re.DOTALL)
    return body


def _is_go(body):
    """True iff the Recommendation block declares GO."""
    return bool(re.search(
        r"(?m)^[\-\*\s]*\*\*Recommendation:\*\*\s+\*{0,2}GO\b", body))


def _extract_decomposition_items(body):
    """Find the `**Decomposition (follow-up build tasks after GO):**`
    heading inside the Recommendation block and return the bulleted/
    numbered items beneath it. Returns [] if the heading is absent —
    a conservative signal that the inception had a single deliverable
    and the gate is a no-op for this pair."""
    dec_match = re.search(
        r"\*\*Decomposition[^*\n]*?\*\*\s*\n(.*?)(?=\n\*\*[A-Z]|\Z)",
        body, re.DOTALL)
    if not dec_match:
        return []
    dec_body = dec_match.group(1)

    deliverables = []
    for line in dec_body.splitlines():
        line = line.strip()
        if not line:
            continue
        # Match leading bullet/number, optional Bn:/Cn: tag, optional bold,
        # capture the title.
        m = re.match(
            r"^(?:[\-\*]|\d+\.)\s+(?:\*\*)?([A-Z]\d+)?:?\s*\*?\*?(.+?)(?:\*\*)?\s*$",
            line)
        if not m:
            continue
        tag, title = m.groups()
        title = title.strip().rstrip(".").rstrip()
        title = re.sub(r"\s*[\-—:]\s*$", "", title)
        if tag:
            deliverables.append(f"{tag}: {title}")
        else:
            deliverables.append(title)
    return deliverables


def extract_deliverables(task_file):
    """CLI entry: print one deliverable per line.
    Exit codes: 0 parsed, 2 no Recommendation, 3 not GO."""
    if not os.path.isfile(task_file):
        sys.exit(2)
    with open(task_file) as f:
        content = f.read()
    body = _load_recommendation_block(content)
    if body is None:
        sys.exit(2)
    if not _is_go(body):
        sys.exit(3)
    for d in _extract_decomposition_items(body):
        print(d)
    sys.exit(0)


def _find_task_file(framework_root, task_id):
    for status in ("active", "completed"):
        pattern = os.path.join(framework_root, ".tasks", status,
                               f"{task_id}-*.md")
        matches = glob.glob(pattern)
        if matches:
            return matches[0]
    return None


def _read_related_tasks(task_file):
    with open(task_file) as f:
        head = f.read(4000)
    rt_match = re.search(
        r"^related_tasks:\s*(\[[^\]]*\]|\n(?:\s+-\s+\S+\n?)+)",
        head, re.MULTILINE)
    if not rt_match:
        return []
    return re.findall(r"T-\d+", rt_match.group(1))


def _read_task_meta(task_file):
    with open(task_file) as f:
        head = f.read(4000)
    id_m = re.search(r"^id:\s*(T-\d+)", head, re.MULTILINE)
    name_m = re.search(r'^name:\s*"?([^"\n]+)"?', head, re.MULTILINE)
    if not id_m:
        return None
    return {
        "id": id_m.group(1),
        "name": (name_m.group(1) if name_m else "").strip().strip('"'),
        "related": _read_related_tasks(task_file),
    }


_STOPWORDS = {
    "task", "tasks", "with", "from", "into", "that", "this", "will",
    "have", "agent", "build", "follow", "after", "before", "each",
    "when", "over", "than", "only", "also", "next", "first", "last",
    "implementation", "follow-up",
}


def _keywords(s):
    s = re.sub(r"^[A-Z]\d+:\s*", "", s)
    words = re.findall(r"[a-zA-Z]+", s.lower())
    return [w for w in words if len(w) >= 4 and w not in _STOPWORDS]


def _candidate_tasks(framework_root, inception_id, build_id):
    candidates = []
    for status in ("active", "completed"):
        pattern = os.path.join(framework_root, ".tasks", status, "T-*.md")
        for path in glob.glob(pattern):
            meta = _read_task_meta(path)
            if not meta:
                continue
            if meta["id"] == inception_id:
                continue
            if inception_id in meta["related"] or meta["id"] == build_id:
                candidates.append(meta)
    return candidates


def verify_deliverables_shipped(inception_id, build_id, framework_root):
    """CLI entry: print JSON, exit 0/2/3/4."""
    inception_file = _find_task_file(framework_root, inception_id)
    if not inception_file:
        print(json.dumps({"error": "inception_not_found",
                          "inception": inception_id}))
        return 2

    with open(inception_file) as f:
        content = f.read()
    body = _load_recommendation_block(content)
    if body is None:
        print(json.dumps({"error": "no_recommendation",
                          "inception": inception_id}))
        return 2
    if not _is_go(body):
        print(json.dumps({"error": "not_go",
                          "inception": inception_id}))
        return 3

    promised = _extract_decomposition_items(body)

    if not promised:
        # No Decomposition block — single-deliverable inception, gate no-op.
        print(json.dumps({
            "inception": inception_id, "build": build_id,
            "promised": [], "shipped": [], "missing": [],
        }, indent=2))
        return 0

    candidates = _candidate_tasks(framework_root, inception_id, build_id)

    shipped, missing = [], []
    for d in promised:
        kws = set(_keywords(d))
        if not kws:
            shipped.append(d)
            continue
        threshold = min(2, max(1, len(kws) // 2))
        matched = None
        for c in candidates:
            cand_kws = set(_keywords(c["name"]))
            if len(kws & cand_kws) >= threshold:
                matched = c
                break
        if matched:
            shipped.append(f"{d}  ->  {matched['id']}: {matched['name']}")
        else:
            missing.append(d)

    print(json.dumps({
        "inception": inception_id, "build": build_id,
        "promised": promised, "shipped": shipped, "missing": missing,
    }, indent=2))
    return 4 if missing else 0


def main(argv):
    if len(argv) < 2:
        print("usage: task_pair_acd.py extract <task_file>", file=sys.stderr)
        print("       task_pair_acd.py verify <inception_id> <build_id> [framework_root]", file=sys.stderr)
        sys.exit(64)
    cmd = argv[1]
    if cmd == "extract":
        if len(argv) != 3:
            sys.exit(64)
        extract_deliverables(argv[2])
    elif cmd == "verify":
        if len(argv) < 4:
            sys.exit(64)
        framework_root = argv[4] if len(argv) >= 5 else os.getcwd()
        sys.exit(verify_deliverables_shipped(argv[2], argv[3], framework_root))
    else:
        print(f"unknown command: {cmd}", file=sys.stderr)
        sys.exit(64)


if __name__ == "__main__":
    main(sys.argv)
