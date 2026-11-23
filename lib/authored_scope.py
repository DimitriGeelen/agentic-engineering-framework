"""The ONE definition of authored, durable project content (T-5374).

Three retrieval paths used to carry three scope lists: the embedding index
(web/search_utils.py), keyword `fw search` (bin/fw, .tasks + .context only) and
the index freshness check (lib/vector_index_health.py DRIFT_DIRS, four dirs).
A design document under docs/design/ was embedded but invisible to keyword
search and never counted as missing from the index. All three now read this
module. Stdlib only: bin/fw and the health check must not import Flask.

Content classes (T-3024):
  AUTHORED_AND_DURABLE  — written by a person or agent on purpose: tasks,
      episodics, ADRs, policy, reports, specs, designs. IN.
  GENERATED_OR_RESTATED — derived or restated state (docs/generated, handovers).
      OUT, except handovers behind the INDEX_HANDOVERS switch.

A project adds its own authored directories with INDEX_EXTRA_DIRS
(env FW_INDEX_EXTRA_DIRS > .framework.yaml > empty): colon- or comma-separated,
project-relative. Absolute paths, `..` components and anything under an
excluded directory are ignored, so the key cannot widen the corpus outside the
project or re-admit generated content.
"""
from __future__ import annotations

import os
import re
from pathlib import Path

INDEXED_SUFFIXES = (".md", ".yaml", ".yml")

# Class: AUTHORED_AND_DURABLE.
AUTHORED_DIRS = (
    (".tasks",),
    (".context", "episodic"),
    (".context", "project"),
    (".context", "qa"),
    (".fabric", "components"),
    ("docs", "reports"),
    # T-3022 spike 8 — authored and previously unreachable.
    ("policy",),
    ("docs", "adr"),
    ("docs", "architecture"),
    ("docs", "design"),
    ("docs", "specs"),
    ("docs", "proposals"),
    ("docs", "upstream-patterns"),
    ("docs", "walkthrough"),
    ("docs", "dispatch-templates"),
    ("docs", "articles"),
)

# Class: GENERATED_OR_RESTATED. Named so the exclusion is auditable.
EXCLUDED_DIRS = (
    ("docs", "generated"),
)

HANDOVER_DIR = (".context", "handovers")


def _config_value(project_root: Path, key: str) -> str | None:
    """env FW_<key> > .framework.yaml <key> > None (the 4-tier contract minus CLI)."""
    env = os.environ.get("FW_" + key)
    if env is not None and env.strip() != "":
        return env.strip()
    cfg = Path(project_root) / ".framework.yaml"
    try:
        text = cfg.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    for line in text.splitlines():
        m = re.match(r"^\s*" + re.escape(key) + r"\s*:\s*(.*?)\s*$", line)
        if m:
            return m.group(1).strip().strip("\"'")
    return None


def _excluded(parts: tuple) -> bool:
    return any(parts[:len(x)] == x for x in EXCLUDED_DIRS)


def extra_dirs(project_root) -> tuple:
    """INDEX_EXTRA_DIRS as a tuple of path-part tuples, sanitised."""
    raw = _config_value(Path(project_root), "INDEX_EXTRA_DIRS") or ""
    out = []
    for item in re.split(r"[:,]", raw):
        item = item.strip()
        if not item or os.path.isabs(item) or item.startswith("~"):
            continue
        item = item.rstrip("/")
        parts = tuple(p for p in item.split("/") if p not in ("", "."))
        if not parts or ".." in parts or parts[0] == ".git" or _excluded(parts):
            continue
        if parts not in out and parts not in AUTHORED_DIRS:
            out.append(parts)
    return tuple(out)


def authored_dirs(project_root) -> tuple:
    """AUTHORED_DIRS plus the project's INDEX_EXTRA_DIRS (handovers not included)."""
    return AUTHORED_DIRS + extra_dirs(project_root)


def is_excluded(path: Path, project_root) -> bool:
    root = Path(project_root)
    return any(Path(path).is_relative_to(root.joinpath(*x)) for x in EXCLUDED_DIRS)
