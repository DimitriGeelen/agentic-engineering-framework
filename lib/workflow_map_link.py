#!/usr/bin/env python3
"""T-5391: a task tagged `outside-contributor` links the PR workflow map.

Operator 2026-11-24: "I mean from every PR task to the map." The tag is the one
T-5364 reads to raise the review rung (lib/review_policy.py). A task carrying it
gets, once:

  * frontmatter  `workflow_map: aef-github-pr-intake`
  * one line under `## Context`:
    `**Workflow:** outside-PR process map aef-github-pr-intake — <base>/designer/app?load=…`

Tag -> map lives in TAG_MAPS, the one place the map id is named. Idempotent: an
existing `workflow_map:` line is left as it is, and the Context line is not
added twice. A task without a mapped tag is never rewritten (byte-unchanged).

The Watchtower base URL is resolved by the caller (lib/workflow-map-link.sh,
through lib/watchtower.sh), never here, so no port is hard-coded.

CLI:
  workflow_map_link.py needs  FILE           exit 0 = tagged and missing a part, 1 = nothing to do
  workflow_map_link.py apply  FILE BASE_URL  writes what is missing; prints what it added
"""
from __future__ import annotations

import re
import sys
from urllib.parse import quote

OUTSIDE_CONTRIBUTOR_TAG = "outside-contributor"
PR_WORKFLOW_MAP = "aef-github-pr-intake"
# tag -> workflow map id. The single source for the map id (T-5391 criterion 2).
TAG_MAPS = {OUTSIDE_CONTRIBUTOR_TAG: PR_WORKFLOW_MAP}

_FM = re.compile(r"\A---\n(.*?\n)---\n", re.S)


def _tags(fm: str) -> list[str]:
    m = re.search(r"^tags:\s*\[([^\]]*)\]", fm, re.M)
    if m:
        return [t.strip().strip("'\"") for t in m.group(1).split(",") if t.strip()]
    m = re.search(r"^tags:\s*\n((?:\s+-\s.*\n)+)", fm, re.M)
    if m:
        return [ln.strip()[1:].strip().strip("'\"") for ln in m.group(1).splitlines()]
    return []


def map_for(text: str) -> str | None:
    m = _FM.match(text)
    if not m:
        return None
    for t in _tags(m.group(1)):
        if t in TAG_MAPS:
            return TAG_MAPS[t]
    return None


def designer_link(base_url: str, map_id: str) -> str:
    load = quote(f"/api/version?id={map_id}", safe="")
    return f"{base_url.rstrip('/')}/designer/app?load={load}"


def context_line(base_url: str, map_id: str) -> str:
    return (f"**Workflow:** outside-PR process map {map_id} — "
            f"{designer_link(base_url, map_id)}")


def _has_field(fm: str) -> bool:
    return re.search(r"^workflow_map:", fm, re.M) is not None


def _context_bounds(text: str) -> tuple[int, int] | None:
    m = re.search(r"^## Context[ \t]*\n", text, re.M)
    if not m:
        return None
    nxt = re.search(r"^## ", text[m.end():], re.M)
    end = m.end() + nxt.start() if nxt else len(text)
    return m.end(), end


def _has_line(text: str, map_id: str) -> bool:
    b = _context_bounds(text)
    region = text[b[0]:b[1]] if b else text
    return re.search(r"^\*\*Workflow:\*\*.*" + re.escape(map_id), region, re.M) is not None


def needs(text: str) -> bool:
    map_id = map_for(text)
    if not map_id:
        return False
    return not _has_field(_FM.match(text).group(1)) or not _has_line(text, map_id)


def apply(text: str, base_url: str) -> tuple[str, list[str]]:
    map_id = map_for(text)
    if not map_id:
        return text, []
    added: list[str] = []
    fm = _FM.match(text).group(1)
    if not _has_field(fm):
        line = f"workflow_map: {map_id}\n"
        tm = re.search(r"^tags:.*\n(?:\s+-\s.*\n)*", fm, re.M)
        pos = 4 + (tm.end() if tm else len(fm))
        text = text[:pos] + line + text[pos:]
        added.append(f"workflow_map: {map_id}")
    if not _has_line(text, map_id):
        line = context_line(base_url, map_id)
        b = _context_bounds(text)
        if b:
            start, end = b
            body = text[start:end]
            stripped = body.rstrip("\n")
            text = text[:start] + stripped + ("\n\n" if stripped else "") + line + "\n\n" + text[end:]
        else:
            fm_end = _FM.match(text).end()
            ac = re.search(r"^## Acceptance Criteria", text[fm_end:], re.M)
            pos = fm_end + ac.start() if ac else len(text)
            block = "## Context\n\n" + line + "\n\n"
            if pos == len(text) and not text.endswith("\n\n"):
                block = ("\n" if text.endswith("\n") else "\n\n") + block
            text = text[:pos] + block + text[pos:]
        added.append("Context **Workflow:** line")
    return text, added


def main(argv: list[str]) -> int:
    if len(argv) < 3 or argv[1] not in ("needs", "apply"):
        print(__doc__, file=sys.stderr)
        return 2
    path = argv[2]
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if argv[1] == "needs":
        return 0 if needs(text) else 1
    if len(argv) < 4 or not argv[3].strip():
        print("workflow_map_link: apply needs a base URL", file=sys.stderr)
        return 2
    new, added = apply(text, argv[3])
    if added and new != text:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new)
        for a in added:
            print(f"Workflow map: + {a}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
