"""The ONE definition of indexable project content (T-5374, T-5376).

Three retrieval paths used to carry three scope lists: the embedding index
(web/search_utils.py), keyword `fw search` (bin/fw, .tasks + .context only) and
the index freshness check (lib/vector_index_health.py DRIFT_DIRS, four dirs).
A design document under docs/design/ was embedded but invisible to keyword
search and never counted as missing from the index. All three now read this
module. Stdlib only: bin/fw and the health check must not import Flask.

T-5376 inverts the default. In a git work tree EVERY git-tracked file with a
document suffix is project content, wherever it lives (a consumer's design/,
architecture/, README.md), minus a short exclusion list: NON_PROJECT_DIRS plus
the project's INDEX_EXCLUDE_DIRS. AUTHORED_DIRS is no longer the gate: it is
still walked (it picks up untracked authored files such as a just-written
episodic) and it is the whole rule only when the project is not a git work tree
or git is missing. indexable_files() is the one function all three paths call.

Content classes (T-3024) still decide the exclusions:
  AUTHORED_AND_DURABLE  — written by a person or agent on purpose: tasks,
      episodics, ADRs, policy, reports, specs, designs, READMEs. IN.
  GENERATED_OR_RESTATED — derived or restated state (docs/generated, handovers,
      live session state, audit/review ledgers, a vendored framework copy). OUT,
      except handovers behind the INDEX_HANDOVERS switch.

A project adds directories with INDEX_EXTRA_DIRS (untracked or non-document
content) and removes them with INDEX_EXCLUDE_DIRS (env FW_<KEY> >
.framework.yaml > empty): colon- or comma-separated, project-relative. Absolute
paths, `..` components and .git are ignored, and INDEX_EXTRA_DIRS cannot re-admit
an excluded directory.
"""
from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

# T-5376: document suffixes, indexed anywhere a git-tracked file carries one.
DOC_SUFFIXES = (".md", ".markdown", ".rst", ".txt", ".adoc")
INDEXED_SUFFIXES = DOC_SUFFIXES + (".yaml", ".yml")

# T-5376: YAML is a document only where the framework writes authored state in
# it; elsewhere in a project it is configuration (CI, compose, registries).
YAML_DIRS = (
    (".tasks",),
    (".context", "episodic"),
    (".context", "project"),
    (".context", "qa"),
    (".fabric", "components"),
    ("policy",),
)

# Class: AUTHORED_AND_DURABLE. Walked in every project; the whole rule only
# outside a git work tree.
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

# T-5376: tracked, document-suffixed, and still not project documentation — a
# vendored framework copy, live session state, scratch, machine-written audit and
# review ledgers, third-party trees, test fixtures. Prefix match on the
# project-relative path. Handovers are governed by INDEX_HANDOVERS, not here.
NON_PROJECT_DIRS = EXCLUDED_DIRS + (
    (".agentic-framework",),
    (".context", "scratch"),
    (".context", "working"),
    (".context", "dispatch"),
    (".context", "audits"),
    (".context", "visual"),
    (".context", "runme"),
    (".context", "reviews"),
    ("vendor",),
    ("tests", "fixtures"),
)
# Excluded at any depth.
NON_PROJECT_COMPONENTS = (".git", "node_modules")


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


def _under(parts: tuple, prefixes) -> bool:
    return any(parts[:len(x)] == x for x in prefixes)


def _excluded(parts: tuple) -> bool:
    return _under(parts, NON_PROJECT_DIRS) or _under(parts, (HANDOVER_DIR,))


def _dir_list(project_root, key: str) -> list:
    """A colon/comma-separated project-relative dir list, sanitised: absolute
    paths, `~`, `..` components and .git are dropped."""
    raw = _config_value(Path(project_root), key) or ""
    out = []
    for item in re.split(r"[:,]", raw):
        item = item.strip()
        if not item or os.path.isabs(item) or item.startswith("~"):
            continue
        item = item.rstrip("/")
        parts = tuple(p for p in item.split("/") if p not in ("", "."))
        if not parts or ".." in parts or parts[0] == ".git":
            continue
        if parts not in out:
            out.append(parts)
    return out


def exclude_dirs(project_root) -> tuple:
    """INDEX_EXCLUDE_DIRS (T-5376): project dirs kept out of all three paths,
    on top of the built-in NON_PROJECT_DIRS."""
    return tuple(_dir_list(project_root, "INDEX_EXCLUDE_DIRS"))


def excluded_parts(project_root) -> tuple:
    """Every exclusion prefix for this project: built-in plus INDEX_EXCLUDE_DIRS."""
    return NON_PROJECT_DIRS + exclude_dirs(project_root)


def extra_dirs(project_root) -> tuple:
    """INDEX_EXTRA_DIRS as a tuple of path-part tuples, sanitised; an entry under
    any exclusion (built-in or INDEX_EXCLUDE_DIRS) is dropped."""
    excl = exclude_dirs(project_root)
    return tuple(p for p in _dir_list(project_root, "INDEX_EXTRA_DIRS")
                 if not _excluded(p) and not _under(p, excl) and p not in AUTHORED_DIRS)


def authored_dirs(project_root) -> tuple:
    """AUTHORED_DIRS plus the project's INDEX_EXTRA_DIRS (handovers not included)."""
    return AUTHORED_DIRS + extra_dirs(project_root)


def is_excluded(path: Path, project_root) -> bool:
    """Under an exclusion (built-in, handovers aside, or INDEX_EXCLUDE_DIRS)?"""
    root = Path(project_root)
    return any(Path(path).is_relative_to(root.joinpath(*x))
               for x in excluded_parts(root))


def in_scope(rel: str, project_root, include_handovers: bool = False,
             _excl: tuple | None = None) -> bool:
    """Could this project-relative path be indexed? Suffix and exclusions only —
    says nothing about whether git tracks it (used for deleted-file drift)."""
    if not rel.endswith(INDEXED_SUFFIXES):
        return False
    parts = tuple(rel.split("/"))
    if any(c in NON_PROJECT_COMPONENTS for c in parts):
        return False
    if _under(parts, (HANDOVER_DIR,)):
        return include_handovers
    excl = _excl if _excl is not None else excluded_parts(project_root)
    return not _under(parts, excl)


def git_tracked(project_root) -> list | None:
    """Project-relative paths git tracks under project_root, or None when this is
    not a git work tree or git is unavailable (the fallback signal)."""
    try:
        r = subprocess.run(["git", "-C", str(project_root), "ls-files", "-z", "--cached"],
                           capture_output=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return None
    if r.returncode != 0:
        return None
    return [p for p in r.stdout.decode("utf-8", "surrogateescape").split("\0") if p]


def indexable_files(project_root, include_handovers: bool = False) -> list:
    """THE inclusion rule (T-5376) for the embedding index, keyword `fw search`
    and the freshness check. Absolute Paths under project_root, de-duplicated.

    git work tree: every tracked file with a DOC_SUFFIXES suffix anywhere, plus
      tracked .yaml/.yml under YAML_DIRS — minus NON_PROJECT_DIRS,
      NON_PROJECT_COMPONENTS and INDEX_EXCLUDE_DIRS.
    every project: the AUTHORED_DIRS + INDEX_EXTRA_DIRS walk (the T-5374 rule;
      picks up untracked authored files) and .context/handovers when
      include_handovers.
    Not a git work tree, or no git: that walk plus top-level *.md and
      agents/*/AGENT.md — unchanged behaviour.
    """
    root = Path(project_root)
    excl = excluded_parts(root)
    seen: set = set()
    out: list = []

    def add(rel: str) -> None:
        if rel not in seen:
            seen.add(rel)
            out.append(root / rel)

    tracked = git_tracked(root)
    if tracked is not None:
        for rel in tracked:
            if rel.endswith((".yaml", ".yml")):
                if not _under(tuple(rel.split("/")), YAML_DIRS):
                    continue
            elif not rel.endswith(DOC_SUFFIXES):
                continue
            if in_scope(rel, root, include_handovers, excl) and (root / rel).is_file():
                add(rel)   # is_file: tracked but deleted in the work tree stays out

    walk = list(authored_dirs(root))
    if include_handovers:
        walk.append(HANDOVER_DIR)
    prefix = len(str(root).rstrip("/")) + 1
    for parts in walk:
        if parts != HANDOVER_DIR and _under(parts, excl):
            continue
        d = root.joinpath(*parts)
        if not d.is_dir():
            continue
        for f in d.rglob("*"):
            if f.suffix not in INDEXED_SUFFIXES or not f.is_file():
                continue
            rel = str(f)[prefix:]
            if in_scope(rel, root, include_handovers, excl):
                add(rel)

    # Top-level specs (CLAUDE.md, FRAMEWORK.md, README.md …) and agent docs —
    # authored by definition. In a git work tree the tracked ones are already in,
    # and an untracked root file is scratch, not a project document.
    if tracked is not None:
        return out
    for f in root.glob("*.md"):
        if f.is_file():
            add(f.name)
    for f in root.glob("agents/*/AGENT.md"):
        rel = str(f)[prefix:]
        if in_scope(rel, root, include_handovers, excl):
            add(rel)
    return out
