"""Shared helpers for the web UI blueprints."""
from __future__ import annotations

import logging
import os
import re as re_mod
import subprocess
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, TypeVar

import yaml
from flask import g, has_request_context, render_template, request

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

APP_DIR = Path(__file__).resolve().parent
FRAMEWORK_ROOT = APP_DIR.parent


# ---------------------------------------------------------------------------
# Test-sentinel filter (T-2228 / T-2225 Slice 3)
# ---------------------------------------------------------------------------
# Tests use the `T-Test-NNN` sentinel namespace (T-2226 convention) instead of
# numeric `T-NNNN` ids to keep test fixtures from colliding with real tasks.
# Slice 1 (T-2226) introduced `tmp_project_root` to isolate writes to tmp_path.
# This Layer 3 filter is defense-in-depth: if a test ever leaks a real
# `.tasks/active/T-Test-001.md` file into PROJECT_ROOT (helper bypassed, future
# author skips the fixture), production scanners — audit / fabric / episodic /
# task-list — silently skip it instead of presenting it as a real task.
#
# Risk-free: real tasks are filed via `fw work-on` / `fw task create` which
# emit numeric `T-NNNN` ids; the `T-Test-` prefix is reserved for fixtures.
def is_test_sentinel(name) -> bool:
    """True if `name` (path or basename or task-id) is a T-Test-NNN sentinel.

    Matches `T-Test-001`, `T-Test-foo.md`, `T-Test-bar.yaml`, and full paths
    ending in any of those. Used by production scanners to filter test fixtures
    that may have leaked into a real `.tasks/active/` or `.context/episodic/`
    directory. See T-2225 / T-2228, docstring at top of section.
    """
    try:
        basename = Path(str(name)).name
    except (TypeError, ValueError):
        return False
    return basename.startswith("T-Test-")


def _discover_project_root(start: Path) -> Path | None:
    """Walk up from `start` looking for `.framework.yaml` (consumer marker).

    Returns the first ancestor containing `.framework.yaml`, or None if no
    valid marker is found.

    Bound (T-1747, G-069): when `start` is inside FRAMEWORK_ROOT, the walk
    stops at FRAMEWORK_ROOT itself. The framework repo IS the framework — it
    has no `.framework.yaml` marker and shouldn't pretend to be a consumer of
    itself, and it MUST NOT climb past FRAMEWORK_ROOT into ancestors. A stray
    `/.framework.yaml` (filesystem-root pollution) once caused PROJECT_ROOT
    to silently resolve to `/`, breaking every Watchtower route that read
    project-relative content.

    For consumer-style starts (cwd outside FRAMEWORK_ROOT), the walk continues
    to filesystem root as before.
    """
    try:
        cur = Path(start).resolve()
    except OSError:
        return None
    try:
        framework_root = FRAMEWORK_ROOT.resolve()
    except OSError:
        framework_root = FRAMEWORK_ROOT
    in_framework = _is_within(cur, framework_root)
    while True:
        if (cur / ".framework.yaml").is_file():
            return cur
        if in_framework and cur == framework_root:
            return None
        if cur.parent == cur:
            return None
        cur = cur.parent


def _is_within(child: Path, parent: Path) -> bool:
    """Return True if `child` is `parent` or a descendant of it."""
    try:
        child.relative_to(parent)
        return True
    except ValueError:
        return False


def _resolve_project_root() -> tuple[Path, str]:
    """Resolve PROJECT_ROOT from (in order): env var, discovered, FRAMEWORK_ROOT.

    Returns (path, source_label) where source ∈ {'env', 'discovered', 'framework'}.
    Env wins unconditionally — operators and `bin/fw` rely on it.
    """
    env_val = os.environ.get("PROJECT_ROOT")
    if env_val:
        return Path(env_val), "env"
    discovered = _discover_project_root(Path.cwd())
    if discovered is not None:
        return discovered, "discovered"
    return FRAMEWORK_ROOT, "framework"


PROJECT_ROOT, _PROJECT_ROOT_SOURCE = _resolve_project_root()
if _PROJECT_ROOT_SOURCE != "env":
    logger.debug("PROJECT_ROOT resolved via %s: %s", _PROJECT_ROOT_SOURCE, PROJECT_ROOT)


def task_id_sort_key(value):
    """Extract numeric portion of task ID for natural sorting.

    Works with task ID strings ('T-1000'), Path objects, or dicts with 'id' key.
    """
    s = value.get("id", "") if isinstance(value, dict) else str(value)
    m = re_mod.search(r"T-(\d+)", s)
    return int(m.group(1)) if m else 0

# ---------------------------------------------------------------------------
# Navigation — grouped for Watchtower command center
# ---------------------------------------------------------------------------

# NAV_GROUPS: top-level nav groups, each a (group_name, items) pair.
# An item is EITHER a leaf  ("Label", "blueprint.endpoint", icon|None)  — a 3-tuple,
# OR a subsection  ("Subsection Label", [leaf, leaf, ...])  — a 2-tuple whose second
# element is a list. Subsections let an oversized group (Govern) render as labelled
# blocks instead of one flat list (T-2008, arc-007 S2a). NAV_ITEMS flattens recursively.
NAV_GROUPS = [
    ("Work", [
        ("Tasks",       "tasks.tasks",              None),
        ("Arcs",        "arcs.arcs_index",          None),
        ("BVP",         "bvp.bvp_scatter",          None),
        ("Inception",   "inception.inception_list",  None),
        ("Assumptions", "inception.assumptions_list", None),
        ("Timeline",    "timeline.timeline",         None),
        ("Prompts",     "prompts.prompts_list",      None),
    ]),
    ("Knowledge", [
        ("Learnings",   "discovery.learnings",   None),
        ("Graduation",  "discovery.graduation",  None),
        ("Patterns",    "discovery.patterns",     None),
        ("Decisions",   "discovery.decisions",    None),
    ]),
    ("Architecture", [
        ("Fabric",      "fabric.fabric_overview",   None),
        ("Explorer",    "fabric.fabric_graph",      None),
        ("Designer",    "designer.designer",         None),
        ("Terminal",    "terminal.terminal_page",    None),
        ("Sessions",    "sessions_page.sessions_page", None),
    ]),
    # Govern is subsectioned (T-2008): 16 items → 4 function-based blocks so the
    # dropdown is scannable rather than a flat wall.
    ("Govern", [
        ("Approvals & Decisions", [
            ("Approvals",     "approvals.approvals",                   None),
            ("Directives",    "core.directives",                       None),
            ("Pending",       "pending.pending_page",                  None),
        ]),
        ("Enforcement", [
            ("Enforcement",   "enforcement.enforcement_dashboard",     None),
            ("Hooks",         "hooks.hooks_page",                      None),
            ("Reviewer Audit", "reviewer.reviewer_audit",              None),
            ("Reviewer Overrides", "reviewer.reviewer_overrides",      None),
        ]),
        ("Health", [
            ("Risks",         "risks.risk_register",                   None),
            ("Gaps",          "discovery.gaps",                        None),
            ("Quality",       "quality.quality_gate",                  None),
            ("Discoveries",   "discoveries_bp.discoveries_dashboard",  None),
            ("Escalation Drift", "escalation.escalation_drift",        None),
            # T-1719 A4: recall-substrate instrument panel. Filed under Health
            # rather than Architecture because the question it answers is "is
            # this working right now", not "how is this put together".
            ("Embeddings",    "embeddings.embeddings_panel",           None),
        ]),
        ("Operations", [
            ("Metrics",       "metrics.project_metrics",               None),
            ("Costs",         "costs.costs_dashboard",                 None),
            ("Config",        "config.config_page",                    None),
            ("Cron",          "cron.cron_registry",                    None),
        ]),
    ]),
]


def _nav_flatten(items):
    """Yield leaf (label, endpoint, icon) tuples from a group's items, recursing
    into any (subsection_label, [items]) subsections. A subsection is a 2-tuple
    whose second element is a list; a leaf is a 3-tuple."""
    out = []
    for it in items:
        if len(it) == 2 and isinstance(it[1], list):  # subsection
            out.extend(_nav_flatten(it[1]))
        else:  # leaf
            out.append(it)
    return out


def nav_group_labels(group_name):
    """Flat list of leaf labels under a top-level nav group (recursing into
    subsections). Returns [] if the group is absent. Used by verification + tests."""
    for name, items in NAV_GROUPS:
        if name == group_name:
            return [leaf[0] for leaf in _nav_flatten(items)]
    return []


# Flat list for backward compat (used in error handlers, search/jump, etc.)
NAV_ITEMS = []
for _group_name, _items in NAV_GROUPS:
    NAV_ITEMS.extend(_nav_flatten(_items))


# ---------------------------------------------------------------------------
# Breadcrumbs (T-2009, arc-007 S2b)
# ---------------------------------------------------------------------------
_BREADCRUMB_INDEX = None  # lazily built: first-path-segment -> (group, label, leaf_endpoint)


def _breadcrumb_index():
    """Map a URL's first path segment -> (group, label, leaf_endpoint), built from
    the *actual* URLs of nav leaves. Path-based (not blueprint-name) so mixed
    blueprints resolve correctly (e.g. `discovery` serves both Knowledge and Govern).
    Cached after first build; requires an app/request context for url_for."""
    global _BREADCRUMB_INDEX
    if _BREADCRUMB_INDEX is not None:
        return _BREADCRUMB_INDEX
    from flask import url_for

    idx = {}
    for gname, items in NAV_GROUPS:
        for label, ep, _icon in _nav_flatten(items):
            try:
                url = url_for(ep)
            except Exception:
                continue
            seg = url.strip("/").split("/", 1)[0]
            if seg:
                idx.setdefault(seg, (gname, label, ep))
    _BREADCRUMB_INDEX = idx
    return idx


def nav_breadcrumb(endpoint, path=""):
    """Build a breadcrumb trail [(label, url|None), ...] for the current page.

    Derived from the request URL's first path segment matched against nav-leaf URLs.
    The final crumb is always the current page (url=None). Returns [] for home and
    for pages under no nav section (better silent than a misleading crumb).
        /tasks          -> [(Work, None), (Tasks, None)]
        /tasks/T-2008   -> [(Work, None), (Tasks, /tasks), (T-2008, None)]
        /arcs/arc-007   -> [(Work, None), (Arcs, /arcs), (arc-007, None)]
        /               -> []
    """
    segs = [s for s in (path or "").split("/") if s]
    if not segs:
        return []
    idx = _breadcrumb_index()
    first = segs[0]
    if first not in idx:
        return []
    group, label, leaf_ep = idx[first]
    crumbs = [(group, None)]
    if len(segs) == 1:
        crumbs.append((label, None))  # the section list is the current page
    else:
        from flask import url_for

        try:
            crumbs.append((label, url_for(leaf_ep)))  # section, linked to its list
        except Exception:
            crumbs.append((label, None))
        crumbs.append((segs[-1], None))  # detail token = current page
    return crumbs


# ---------------------------------------------------------------------------
# Command palette (T-2012, arc-007 S6a) — jump destinations
# ---------------------------------------------------------------------------
def palette_destinations():
    """Jump destinations for the ⌘K command palette: NAV_ITEMS resolved to URLs.

    One source of truth — the same nav whitelist S2c pins use (T-2010). Returns a
    list of {label, url, group} dicts, url_for resolved server-side (try/except so a
    parametrised endpoint never breaks the page). Requires an app/request context.
    """
    from flask import url_for

    out = []
    for gname, items in NAV_GROUPS:
        for label, ep, _icon in _nav_flatten(items):
            try:
                url = url_for(ep)
            except Exception:
                continue
            out.append({"label": label, "url": url, "group": gname})
    return out


# ---------------------------------------------------------------------------
# Ambient status strip — data gathered once per request
# ---------------------------------------------------------------------------

def build_ambient():
    """Build ambient status data for the status strip."""
    ambient = {
        "focus_task": None,
        "session_age": None,
        "audit_status": None,
        "attention_count": 0,
    }

    # Focus task — prefer .context/working/focus.yaml (T-1308), fall back to
    # first active task alphabetically when focus is null/missing/malformed.
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    focus_file = PROJECT_ROOT / ".context" / "working" / "focus.yaml"
    focus_data = load_yaml(focus_file, label="focus.yaml") if focus_file.exists() else {}
    current = (focus_data or {}).get("current_task")
    if current and re_mod.match(r"^T-\d{3,}$", str(current)):
        ambient["focus_task"] = str(current)
    if active_dir.exists():
        # T-2228: skip T-Test-NNN sentinels (test fixtures leaked into PROJECT_ROOT).
        active_tasks = sorted(
            (p for p in active_dir.glob("T-*.md") if not is_test_sentinel(p)),
            key=task_id_sort_key,
        )
        if active_tasks:
            if not ambient["focus_task"]:
                # Fallback: first active task alphabetically.
                stem = active_tasks[0].stem
                match = re_mod.match(r"(T-\d{3,})", stem)
                if match:
                    ambient["focus_task"] = match.group(1)
            ambient["attention_count"] = len(active_tasks)

    # Session age — from latest handover
    handovers_dir = PROJECT_ROOT / ".context" / "handovers"
    if handovers_dir.exists():
        sessions = sorted(handovers_dir.glob("S-*.md"), reverse=True)
        if sessions:
            content = sessions[0].read_text(errors="replace")
            ts_match = re_mod.search(r"timestamp:\s*(\S+)", content)
            if ts_match:
                try:
                    ts = datetime.fromisoformat(ts_match.group(1).replace("Z", "+00:00"))
                    delta = datetime.now(timezone.utc) - ts
                    hours = int(delta.total_seconds() // 3600)
                    if hours < 1:
                        ambient["session_age"] = f"{int(delta.total_seconds() // 60)}m ago"
                    elif hours < 24:
                        ambient["session_age"] = f"{hours}h ago"
                    else:
                        ambient["session_age"] = f"{hours // 24}d ago"
                except (ValueError, TypeError):
                    pass

    # Audit status — via shared helper
    _, summary, _ = load_latest_audit()
    if summary:
        if summary.get("fail", 0) > 0:
            ambient["audit_status"] = "FAIL"
        elif summary.get("warn", 0) > 0:
            ambient["audit_status"] = "WARN"
        else:
            ambient["audit_status"] = "PASS"

    return ambient


# ---------------------------------------------------------------------------
# YAML loading with visible errors (T-403: R-018, R-024)
# ---------------------------------------------------------------------------

# Collects parse errors per-request so templates can surface them.
_yaml_errors: list[str] = []

# T-3458: parse with libyaml's C loader when the binding is present.
#
# Measured on the dashboard route (`/`, cProfile over a warm request): 6.81s of
# 7.62s — 89% of the whole request — was `yaml.load`, 28 of those calls arriving
# through load_yaml below. The corpus size was never the problem; the parser was.
# `yaml.safe_load` silently selects the pure-Python SafeLoader even on a host
# where `yaml.__with_libyaml__` is True, which it is here.
#
# CSafeLoader implements the same YAML 1.1 safe subset as SafeLoader, so this is
# a speed change and not a semantics change — but that claim is checked rather
# than asserted: `tests/unit/t3458_yaml_c_loader.bats` parses every YAML file the
# dashboard touches with both loaders and requires the results to be equal, and
# the before/after page bytes were compared for identity (see the task).
#
# Falls back cleanly: a source build of PyYAML without the C extension keeps the
# previous behaviour rather than failing to import (D4 portability — this must
# not assume libyaml is present on a consumer's host).
_YAML_LOADER = getattr(yaml, "CSafeLoader", yaml.SafeLoader)


def load_yaml(path, *, label: str = ""):
    """Load a YAML file. Log and collect errors instead of silently returning {}."""
    path = Path(path)
    if not path.exists():
        return {}
    try:
        with open(path) as f:
            data = yaml.load(f, Loader=_YAML_LOADER)
        return data if isinstance(data, (dict, list)) else {}
    except yaml.YAMLError as exc:
        desc = label or path.name
        msg = f"YAML parse error in {desc} ({path}): {exc}"
        logger.warning(msg)
        _yaml_errors.append(f"{desc}: {exc}")
        return {}
    except Exception as exc:
        desc = label or path.name
        msg = f"Error reading {desc} ({path}): {exc}"
        logger.warning(msg)
        _yaml_errors.append(f"{desc}: {exc}")
        return {}


def get_yaml_errors() -> list[str]:
    """Return and clear collected YAML errors for the current request."""
    errors = list(_yaml_errors)
    _yaml_errors.clear()
    return errors


def load_scan() -> dict | None:
    """Load the latest scan from .context/scans/LATEST.yaml."""
    latest = PROJECT_ROOT / ".context" / "scans" / "LATEST.yaml"
    if not latest.exists():
        return None
    try:
        with open(latest) as f:
            data = yaml.load(f, Loader=_YAML_LOADER)  # T-3458
        if isinstance(data, dict) and data.get("schema_version"):
            return data
    except Exception:
        pass
    return None


# T-2774: libyaml-backed loader when the C extension is compiled in, pure-Python
# SafeLoader otherwise. `getattr` rather than try/import because PyYAML always
# exposes the name-or-nothing; a wheel built without libyaml simply lacks it, and
# the framework must not require a C toolchain (Directive 4, portability).
#
# Measured on this repo's 2,761-task corpus: 9.820s -> 1.115s (8.8x). The parse
# is byte-for-byte equivalent — all 2,761 frontmatter blocks were loaded under
# both loaders and compared by repr, 0 differing files. That check mattered:
# L-495 has us on record for PyYAML mangling unquoted ISO-8601 Z timestamps, and
# the two loaders resolve implicit types through different code paths, so
# "faster" had to be shown to also mean "same". tests/unit/test_frontmatter_loader_equivalence.py
# pins it against the live corpus so a PyYAML upgrade cannot drift them apart silently.
_YAML_LOADER = getattr(yaml, "CSafeLoader", yaml.SafeLoader)


def parse_frontmatter(content):
    """Parse YAML frontmatter from a markdown file.

    Returns (frontmatter_dict, body_text). Returns ({}, content) if no
    frontmatter found or parsing fails.
    """
    fm_match = re_mod.match(r"^---\s*\n(.*?)\n---\n?(.*)", content, re_mod.DOTALL)
    if not fm_match:
        return {}, content
    try:
        fm = yaml.load(fm_match.group(1), Loader=_YAML_LOADER)
    except yaml.YAMLError:
        return {}, content
    if not isinstance(fm, dict):
        return {}, content
    return fm, fm_match.group(2)


# ---------------------------------------------------------------------------
# Per-file mtime-keyed cache (T-2109)
# ---------------------------------------------------------------------------
# Promoted from 5 re-implementations across the Watchtower blueprints:
#   T-1954 (web/blueprints/bvp.py:_FM_CACHE)        — frontmatter dict
#   T-2102 (web/blueprints/approvals.py:_BODY_CACHE) — body string
#   T-2106 (web/blueprints/timeline.py:_FM_CACHE)    — (fm, body) tuple
#   T-2107 (web/search_utils.py:_TAG_FM_CACHE)       — tag list
#   T-2108 (web/blueprints/cockpit.py:_HUMAN_VERIFY_CACHE) — verify entry
#
# Each variant kept the same shape — `dict[str, tuple[int_mtime_ns, T]]` keyed
# on `str(path)` — but with slight drift on what T is (the 5th site stored a
# dict entry instead of a parsed tuple; the 3rd carried `(fm, body)` not just
# fm). The next consumer should reach for this helper instead of re-implementing.
# L-362 (helper-vs-consumer drift) pins the test contract — see
# tests/unit/test_shared_mtime_cache.py.

T = TypeVar("T")


def mtime_cached_get(
    path: Path,
    parse_fn: Callable[[Path], T],
    cache: dict[str, tuple[int, T]],
    default: T,
) -> T:
    """Return parse_fn(path), cached by (path, st_mtime_ns).

    On warm hits with unchanged mtime, returns the cached parsed value
    without re-invoking `parse_fn`. On cold call, file change, or
    `stat()` OSError (file missing), falls back to `parse_fn` — except
    that an OSError on stat short-circuits to `default` without calling
    `parse_fn` (mirrors all 5 origin sites' behaviour: a missing file is
    not a parse error, it is "no data").

    `parse_fn` is responsible for its own read/parse error handling — it
    must NOT raise on malformed content, but return a sensible fallback
    of the same type T (use `default` for consistency). Raising from
    parse_fn will propagate and bypass the cache write.

    `cache` is a per-consumer dict; callers keep one per distinct
    parse_fn / value-type pair to avoid keying clashes.

    Args:
        path: file whose parsed value to cache.
        parse_fn: callable(path) -> T. Must handle I/O + parse errors.
        cache: per-consumer dict[str, tuple[mtime_ns, T]].
        default: value returned when path.stat() raises OSError.

    Returns:
        Parsed value of type T (possibly cached).
    """
    try:
        mtime_ns = path.stat().st_mtime_ns
    except OSError:
        return default
    key = str(path)
    cached = cache.get(key)
    if cached is not None and cached[0] == mtime_ns:
        return cached[1]
    value = parse_fn(path)
    cache[key] = (mtime_ns, value)
    return value


_TASK_REF_RE_SHARED = re_mod.compile(r"(?<![\w/-])(T-\d{3,5})(?![\w/-])")
_BARE_URL_RE_SHARED = re_mod.compile(r"(?<![\(\[\"'`])(https?://[^\s<>'\"`)\]]+)")
_CODE_URL_HTML_RE_SHARED = re_mod.compile(r"<code>(https?://[^<\s]+?)</code>")

# T-1764: single source of truth for "viewable artefact paths".
# Both the auto-linker (T-1722) and the /file/ route (T-632) consult these.
# Diverging them — as happened pre-T-1764 — means the linker emits anchors
# the route can't serve (HTTP 404), silently breaking T-1722's contract.

VIEWABLE_DIR_PREFIXES = (
    "docs/reports/",
    "docs/articles/",
    "docs/plans/",
    "docs/dispatch-templates/",
    "docs/adr/",       # T-3587: cited as evidence on /approvals
    "docs/runbooks/",  # T-3587: cited as evidence on /approvals
    "docs/arcs/",      # T-3649: arc dossier location (docs/arcs/<id>/README.md, T-3565)
    ".tasks/active/",
    ".tasks/completed/",
    ".context/handovers/",
    ".context/episodic/",
    ".context/audits/",
    ".context/project/",
    ".context/working/",
    ".context/arcs/",
    ".fabric/components/",
    "web/",
    "lib/",
    "bin/",
    "agents/",
    "tests/",
    "tools/",
    "prompts/",
    "policy/",
    "deploy/",
)

VIEWABLE_EXTENSIONS = ("md", "yaml", "yml", "py", "sh", "bats", "json", "toml")

# T-2281 (T-2275 prong B): depth-0 root files cannot match a directory prefix
# by definition. Adding them to the prefix tuple would mis-scope `README.md`
# as a directory. The explicit allowlist bypasses the prefix + extension
# checks so these specific filenames are linkable in rendered task content.
# Extensionless entries (VERSION, LICENSE, CHANGELOG) are intentionally
# included even though they don't satisfy VIEWABLE_EXTENSIONS — root files
# are an allowlist, not a generic depth-0 rule.
ROOT_FILES = frozenset({
    "README.md",
    "CLAUDE.md",
    "FRAMEWORK.md",
    "VERSION",
    "LICENSE",
    "CHANGELOG",
})


_ROOT_DOC_RE = re_mod.compile(r"^\d{3}-[A-Za-z0-9][A-Za-z0-9_-]*\.md$")


def is_root_doc(filepath: str) -> bool:
    """T-3587: a numbered depth-0 doc (001-Vision.md, 040-ValueDrivers.md, …).

    The numbered root docs are cited as evidence like any report; before this
    they were marked "not found" because nothing at depth 0 but ROOT_FILES was
    servable. A shape, not a generic depth-0 rule (T-2281 keeps that out):
    `NNN-Name.md` only, so stray root scratch files stay unserved.
    """
    return bool(_ROOT_DOC_RE.match(filepath))


def is_viewable_path(filepath: str) -> bool:
    """Return True iff `filepath` (relative to PROJECT_ROOT) is servable by /file/.

    Single source of truth used by both `_auto_link_files` (T-1722) and the
    `/file/<path>` route (T-632). Drift between linker and route was the
    T-1764 root cause.

    Path-traversal guards live HERE, not in the route — so any caller (linker,
    route, future surfaces) gets the same enforcement.

    T-2281 (T-2275): depth-0 root files in ROOT_FILES bypass the prefix +
    extension checks (e.g. README.md, VERSION). Allowlist, not generic
    depth-0.
    """
    if not filepath:
        return False
    if ".." in filepath:
        return False
    if filepath in ROOT_FILES or is_root_doc(filepath):
        return True
    if not any(filepath.startswith(d) for d in VIEWABLE_DIR_PREFIXES):
        return False
    ext = filepath.rsplit(".", 1)[-1] if "." in filepath else ""
    if ext not in VIEWABLE_EXTENSIONS:
        return False
    return True


# T-1722: artefact path linkifier — promoted from web/blueprints/docs.py (T-633)
# and extended. Matches paths under known artefact prefixes ending in a known
# extension. The (PROJECT_ROOT/path).exists() guard in _auto_link_files refuses
# to link non-existent paths — eliminates false positives from natural prose
# that happens to share a prefix. The dir/extension lists are derived from
# VIEWABLE_DIR_PREFIXES and VIEWABLE_EXTENSIONS (T-1764) so route and linker
# stay in lockstep.
def _build_artefact_path_re():
    # Strip trailing slashes from dirs to embed cleanly in alternation, then
    # escape regex metachars (the leading `.` in `.tasks/`, `.context/`, etc.)
    dirs = "|".join(re_mod.escape(d) for d in VIEWABLE_DIR_PREFIXES)
    exts = "|".join(re_mod.escape(e) for e in VIEWABLE_EXTENSIONS)
    # T-2281 (T-2275): root-files alternative. Sorted for deterministic regex.
    # The lookbehind on the root-file branch refuses matches when the filename
    # is preceded by a path-body character — e.g. "foo/README.md" must NOT match
    # the standalone "README.md" sub-tail (a directory-prefixed README.md is
    # handled by the dir-branch above; "myREADME.md" must not match at all).
    root_files = "|".join(re_mod.escape(f) for f in sorted(ROOT_FILES))
    pattern = (
        # Three guards to keep idempotent and avoid wrapping an already-linked path:
        # T-3368 removed three lookbehinds that used to sit here:
        #   (?<!href=")  — path is not the href target of an existing <a>
        #   (?<!/file/)  — path is not the suffix of an already-built /file/<...> URL
        #   (?<!">)      — path is not the link text following an anchor's closing `">`
        # All three were asking "am I inside a tag?", which a lookbehind cannot
        # answer: it tests a fixed string at a fixed offset, and tag context is
        # unbounded. They are subsumed by the tag/text partitioning in
        # _auto_link_files, which answers the question directly. Keeping them
        # would not be merely redundant — `(?<!">)` also suppressed a LEGITIMATE
        # link whenever text followed any `">`-terminated tag (`<img src="x.png">
        # web/shared.py` linkified nothing), so they cost real false negatives
        # while providing coverage that was never complete.
        r'(`?)'
        r'('
            # Branch 1: prefix + path-body + extension (existing T-1722 shape).
            r'(?:(?:' + dirs + r')'
            r'[A-Za-z0-9_/.-]+\.(?:' + exts + r'))'
            r'|'
            # Branch 2: root-file allowlist, word-boundary-guarded.
            r'(?<![A-Za-z0-9_/.-])(?:' + root_files + r')'
        r')'
        r'(`?)'
    )
    return re_mod.compile(pattern)


_ARTEFACT_PATH_RE = _build_artefact_path_re()

# T-3368: tag/text partitioning for _auto_link_files.
#
# The capturing group is deliberate — `re.split` with a capturing pattern keeps
# the delimiters, so the result alternates text, tag, text, tag, …, text. Even
# indices are always text and odd indices are always tags, which is what lets the
# loop below rewrite one and never the other.
#
# `<[^>]*>` is not a general HTML parser and is not trying to be. It is exactly
# as strict as the producer: this function only ever sees output from the
# repo's own Markdown renderer with safe_mode='escape', so a literal `<` or `>`
# in the source text arrives already escaped as `&lt;`/`&gt;` and cannot be
# mistaken for a tag. Reaching for html.parser here would buy nothing and would
# rewrite entities on the way out.
_TAG_SPLIT_RE = re_mod.compile(r"(<[^>]*>)")

# `<a` must not also match `<abbr`/`<article`, so require a delimiter after it.
_A_OPEN_RE = re_mod.compile(r"<a(?=[\s/>])", re_mod.IGNORECASE)
_A_CLOSE_RE = re_mod.compile(r"</a(?=[\s>])", re_mod.IGNORECASE)
_PRE_OPEN_RE = re_mod.compile(r"<pre(?=[\s>])", re_mod.IGNORECASE)
_PRE_CLOSE_RE = re_mod.compile(r"</pre(?=[\s>])", re_mod.IGNORECASE)
_CODE_OPEN_RE = re_mod.compile(r"<code(?=[\s>])", re_mod.IGNORECASE)
_CODE_CLOSE_RE = re_mod.compile(r"</code(?=[\s>])", re_mod.IGNORECASE)


# T-3587: the reference shapes agents actually write in Evidence, beyond the
# exact `<prefix>/<path>.<ext>` form T-1722 recognised. Measured on the live
# /review/T-3581 before this change: 8 refs linked, 3 left as plain text —
# a brace group (`docs/reports/T-3579-code-review-{openai,zai}.md`), a bare
# brace group, and a bare filename (`T-3581-rereview-openai.md`). Plain text
# is the failure that matters: a ref the reader cannot follow looks exactly
# like one nobody checked, and a DEAD ref looked exactly like a live one.
#
# One token grammar, classified after matching:
#   - optional leading `/` (absolute path; linked only when under PROJECT_ROOT)
#   - path body with optional `{a,b}` brace groups
#   - a viewable extension, then an optional `:NNN` / `:NNN-MMM` line ref
# The lookbehind refuses a start inside another token (`foo/bar.md` never
# yields `bar.md`), which is also what keeps `http://host/x.md` text inert.
_REF_BRACE = r"\{[A-Za-z0-9_.,/-]*,[A-Za-z0-9_.,/-]*\}"
_REF_CHAR = r"[A-Za-z0-9_.-]"


def _build_ref_re():
    exts = "|".join(re_mod.escape(e) for e in sorted(VIEWABLE_EXTENSIONS, key=len, reverse=True))
    roots = "|".join(re_mod.escape(f) for f in sorted(ROOT_FILES))
    return re_mod.compile(
        r"(`?)"
        r"(?<![A-Za-z0-9_/.{}:~-])"
        r"("
            r"/?(?:" + _REF_CHAR + r"|" + _REF_BRACE + r")"
            r"(?:[A-Za-z0-9_./-]|" + _REF_BRACE + r")*"
            r"\.(?:" + exts + r")"
            r"|(?:" + roots + r")"
        r")"
        r"(?::(\d+)(?:-\d+)?)?"
        r"(?![A-Za-z0-9_/{])"
        r"(`?)"
    )


_REF_RE = _build_ref_re()
_BRACE_GROUP_RE = re_mod.compile(r"\{([^{}]*)\}")

_BASENAME_INDEX: dict = {"built": 0.0, "index": {}}
_BASENAME_TTL = 30.0       # a new report becomes resolvable within this window
_BASENAME_MISS_TTL = 3.0   # …or sooner: a miss forces a rebuild at most this often


def _basename_index(force_fresh: bool = False) -> dict:
    """basename -> sorted repo-relative paths, over the viewable directories only.

    Scoped to VIEWABLE_DIR_PREFIXES on purpose: a bare name that resolves to a
    file the viewer will not serve would produce a link that 404s, which is the
    T-1764 drift this module exists to prevent. ~14.5K files, ~0.14s to build.
    """
    import time as _t
    now = _t.monotonic()
    age = now - _BASENAME_INDEX["built"]
    if age < _BASENAME_TTL and not (force_fresh and age >= _BASENAME_MISS_TTL):
        return _BASENAME_INDEX["index"]
    idx: dict = {}
    suffixes = tuple("." + e for e in VIEWABLE_EXTENSIONS)
    for prefix in VIEWABLE_DIR_PREFIXES:
        base = PROJECT_ROOT / prefix
        if not base.is_dir():
            continue
        for root, dirs, files in os.walk(base):
            dirs[:] = [d for d in dirs if d not in ("__pycache__", "node_modules", ".git")]
            for f in files:
                if f.endswith(suffixes):
                    rel = os.path.relpath(os.path.join(root, f), PROJECT_ROOT)
                    idx.setdefault(f, []).append(rel)
    for v in idx.values():
        v.sort()
    for f in ROOT_FILES:
        if (PROJECT_ROOT / f).is_file():
            idx.setdefault(f, []).insert(0, f)
    try:
        root_docs = [e.name for e in os.scandir(PROJECT_ROOT)
                     if e.is_file() and is_root_doc(e.name)]
    except OSError:
        root_docs = []
    for f in root_docs:
        if f not in ROOT_FILES:
            idx.setdefault(f, []).insert(0, f)
    _BASENAME_INDEX["index"] = idx
    _BASENAME_INDEX["built"] = now
    return idx


_TREE_NAMES: dict = {"built": 0.0, "names": frozenset()}
_TREE_SKIP_DIRS = frozenset({".git", "node_modules", "__pycache__"})

# T-3587 round 2: which bare filenames are resolved at all. A bare name is only
# judged when its shape says it names THIS project's artefact: a task-scoped
# name (T-NNNN…, e.g. a report or an episodic card), a numbered or otherwise
# present depth-0 doc, or a name that is unique under docs/reports/. Generic
# names — Cargo.toml, tsconfig.json, settings.json, AGENT.md, a template's
# snake_case_name.md — stay plain text: in prose they are usually an example,
# and linking them to whichever file happens to share the basename (or marking
# them dead) makes a claim the renderer cannot back.
_PROJECT_NAME_RE = re_mod.compile(r"^T-\d+")


def _exists_anywhere(name: str) -> bool:
    """True iff a file called `name` exists anywhere under PROJECT_ROOT (not .git).

    Built only on a miss of a task-shaped bare name, and cached like the
    basename index. It is the evidence behind "dead": a name the viewer cannot
    serve but that exists somewhere is left as plain text, never marked.
    """
    import time as _t
    now = _t.monotonic()
    if now - _TREE_NAMES["built"] >= _BASENAME_MISS_TTL:
        names = set()
        for _root, dirs, files in os.walk(PROJECT_ROOT):
            dirs[:] = [d for d in dirs if d not in _TREE_SKIP_DIRS]
            names.update(files)
        _TREE_NAMES["names"] = frozenset(names)
        _TREE_NAMES["built"] = now
    return name in _TREE_NAMES["names"]


def _resolve_ref(path: str):
    """Classify one (brace-free) reference.

    Returns (state, target, detail):
      ("ok", rel, None)            servable — link to /file/<rel>
      ("dead", None, reason)       certainly names nothing in this project
      ("ambiguous", None, [paths]) a task-shaped bare name matching several files
      ("unserved", rel, None)      exists, but outside the viewer's allowlist
      (None, None, None)           not ours to judge — left as plain text

    The rule the operator set (round 2): a live reference must never look
    broken. When in doubt the answer is (None, …), plain text — "dead" is
    returned only when the path certainly does not exist.
    """
    while path.startswith("./"):
        path = path[2:]
    if path.startswith("/"):
        root = str(PROJECT_ROOT).rstrip("/") + "/"
        if not path.startswith(root):
            return (None, None, None)
        path = path[len(root):]
    if not path or ".." in path.split("/"):
        return (None, None, None)
    if path in ROOT_FILES and not (PROJECT_ROOT / path).is_file():
        # Extensionless root names (CHANGELOG, VERSION) are ordinary words in
        # prose; an absent one is not a stale reference, just a word.
        return (None, None, None)
    if "/" not in path and path not in ROOT_FILES:
        return _resolve_bare_name(path)
    fp = PROJECT_ROOT / path
    if not fp.is_file():
        if not (PROJECT_ROOT / path.split("/", 1)[0]).is_dir():
            # `src/main.rs`, `path/to/x.md`: a directory this project does not
            # have — another repo, or an example. Not provably stale.
            return (None, None, None)
        return ("dead", None, f"{path} does not exist in this project")
    if not is_viewable_path(path):
        return ("unserved", path, None)
    return ("ok", path, None)


def _resolve_bare_name(name: str):
    matches = _basename_index().get(name) or _basename_index(force_fresh=True).get(name) or []
    if name in matches:  # a depth-0 doc: the name IS the path
        return ("ok", name, None)
    if _PROJECT_NAME_RE.match(name):
        if len(matches) == 1:
            return ("ok", matches[0], None)
        if len(matches) > 1:
            return ("ambiguous", None, matches)
        if _exists_anywhere(name):
            return (None, None, None)
        return ("dead", None, f"No file named {name} anywhere in this project")
    if len(matches) == 1 and matches[0].startswith("docs/reports/"):
        return ("ok", matches[0], None)
    return (None, None, None)


def _ref_markup(text: str, path: str, line, in_pre: bool) -> str | None:
    """HTML for one brace-free reference, or None to leave `text` untouched."""
    import html as _html
    state, target, detail = _resolve_ref(path)
    if state == "ok":
        frag = f"#L{line}" if line else ""
        return f'<a href="/file/{target}{frag}">{text}</a>'
    if in_pre or state is None:
        # Inside a code block only live links are added; marking every
        # unresolved token in a pasted log or diff would bury the code.
        return None
    if state == "dead":
        title = f"Not found: {detail}. This reference is stale or mistyped."
        cls = "file-ref-dead"
    elif state == "ambiguous":
        shown = ", ".join(detail[:5]) + (f" (+{len(detail) - 5} more)" if len(detail) > 5 else "")
        title = f"Ambiguous: {len(detail)} files are named {path}: {shown}. Cite the full path."
        cls = "file-ref-ambiguous"
    else:
        title = (f"{target} exists but is outside the file viewer's allowlist "
                 "(VIEWABLE_DIR_PREFIXES in web/shared.py).")
        cls = "file-ref-unserved"
    return f'<span class="{cls}" title="{_html.escape(title)}">{text}</span>'


def _link_ref_match(m, in_pre: bool) -> str:
    tick1, raw, line, tick2 = m.group(1), m.group(2), m.group(3), m.group(4)
    whole = m.group(0)
    suffix = whole[len(tick1) + len(raw):len(whole) - len(tick2)]  # ":NNN" or ""
    groups = list(_BRACE_GROUP_RE.finditer(raw))
    if not groups:
        text = raw + suffix
        body = f"<code>{text}</code>" if (tick1 and tick2) else text
        out = _ref_markup(body, raw, line, in_pre)
        if out is None:
            return whole
        if tick1 and tick2:
            return out
        return f"{tick1}{out}{tick2}"
    if len(groups) == 1:
        # Keep the text readable: the group stays a group, each member is linked
        # to its own expansion (or marked, if that expansion does not resolve).
        g = groups[0]
        head, tail = raw[:g.start()], raw[g.end():]
        pieces = []
        for member in g.group(1).split(","):
            out = _ref_markup(member, head + member + tail, line, in_pre)
            pieces.append(out if out is not None else member)
        return f"{tick1}{head}{{{','.join(pieces)}}}{tail}{suffix}{tick2}"
    # Several groups: expand the cartesian product and list each expansion.
    import itertools
    parts, last = [], 0
    for g in groups:
        parts.append([raw[last:g.start()]])
        parts.append(g.group(1).split(","))
        last = g.end()
    parts.append([raw[last:]])
    links = []
    for combo in itertools.product(*parts):
        exp = "".join(combo)
        out = _ref_markup(exp, exp, line, in_pre)
        links.append(out if out is not None else exp)
    return f"{tick1}{raw}{suffix}{tick2} ({', '.join(links)})"


def _auto_link_files(html: str) -> str:
    """Convert artefact-path references in rendered HTML to clickable /file/ links.

    Existence-gated: only paths that resolve under PROJECT_ROOT become anchors.
    Backticks (``code spans``) are preserved around the link, mirroring the
    T-1575 contract for backticked URLs.

    T-3587 widened what counts as a reference and stopped leaving the misses
    silent: brace groups expand, bare filenames resolve against the viewable
    directories, `path:NNN` links to `#LNNN`, and a reference that resolves to
    nothing (or to several files, or to a file the viewer will not serve) is
    wrapped in a titled span so it cannot pass for a live link.

    Origin: T-633 (introduced in web/blueprints/docs.py for component-doc pages).
    Promoted here in T-1722 so /review, /tasks, /approvals, /inception — every
    Markdown surface — gets one-click artefact navigation.
    """
    if not html:
        return html

    # T-3368: substitute in TEXT ONLY — never inside a tag, never inside an <a>.
    #
    # This used to be `_ARTEFACT_PATH_RE.sub(_replace, html)` over the whole
    # rendered string, with three lookbehinds in the pattern standing in for tag
    # awareness. Lookbehinds cannot do that job, because they test a fixed string
    # at a fixed offset and the thing they need to know — "am I inside a tag?" —
    # is unbounded. `(?<!href=")` saw `href="p"` and missed `href="./p"`: T-1551
    # normalises leading-dot relative paths to `./`, which puts two characters
    # between the guard and the path, so the six preceding characters read
    # `ef="./`. The path inside the attribute was rewritten into an anchor and the
    # result was `<a href="./<a href="/file/p">p</a>">`. Nothing guarded `src=` at
    # all. A fourth lookbehind would have fixed the reported case and left the
    # class open, which is exactly how this survived T-1722.
    #
    # Splitting on tags is the structural answer, but it is not sufficient alone:
    # once tags are their own segments, the `(?<!">)` guard that kept link TEXT
    # from being linkified no longer sees the `">` before it, so `<a …>p</a>`
    # would nest from the inside instead. Hence the anchor depth counter.
    parts = _TAG_SPLIT_RE.split(html)
    anchor_depth = 0
    pre_depth = 0  # T-3587: inside <pre>, add live links only (see _ref_markup)
    code_depth = 0
    for i, seg in enumerate(parts):
        if i % 2:  # odd indices are the tags themselves — never rewritten
            if _PRE_OPEN_RE.match(seg):
                pre_depth += 1
            elif _PRE_CLOSE_RE.match(seg):
                pre_depth = max(0, pre_depth - 1)
            elif _CODE_OPEN_RE.match(seg):
                code_depth += 1
            elif _CODE_CLOSE_RE.match(seg):
                code_depth = max(0, code_depth - 1)
            elif _A_OPEN_RE.match(seg):
                anchor_depth += 1
            elif _A_CLOSE_RE.match(seg):
                # Clamp: malformed markup can close more anchors than it opened,
                # and a negative depth would silently re-enable rewriting inside
                # the next real anchor.
                anchor_depth = max(0, anchor_depth - 1)
        elif anchor_depth == 0:
            # T-3587 round 2: code is quiet. markdown2 (no fenced-code extra)
            # renders a ``` block as <p><code>, not <pre>, and an inline span
            # may hold a pasted log — neither gets a dead/ambiguous/unserved
            # mark. The one exception is a span that IS the reference
            # (`lib/x.sh`): that is a citation, and a stale one should show.
            whole = seg.strip()
            parts[i] = _REF_RE.sub(
                lambda m: _link_ref_match(
                    m, pre_depth > 0 or (code_depth > 0 and m.group(0).strip() != whole)),
                seg)
    return "".join(parts)


# T-3587: markdown2 reads `task_pair_acd.sh` as `task<em>pair</em>acd.sh`, which
# splits the path across three text nodes before the linker ever sees it — the
# reason `lib/task_pair_acd.sh` on /review/T-3581 was plain text. Escaping the
# underscores of path-shaped tokens (outside code, where markdown does not
# emphasise and a backslash would show literally) keeps each path one token.
_PATH_UNDERSCORE_TOKEN_RE = re_mod.compile(
    r"[A-Za-z0-9_./{},~-]*_[A-Za-z0-9_./{},~-]*\.(?:"
    + "|".join(sorted(VIEWABLE_EXTENSIONS, key=len, reverse=True))
    + r")(?![A-Za-z0-9_])"
)
_MD_CODE_SPLIT_RE = re_mod.compile(r"(```.*?```|~~~.*?~~~|`[^`\n]*`)", re_mod.DOTALL)


def protect_path_underscores(text: str) -> str:
    if not text or "_" not in text:
        return text
    parts = _MD_CODE_SPLIT_RE.split(text)
    for i in range(0, len(parts), 2):  # even indices: outside code
        parts[i] = _PATH_UNDERSCORE_TOKEN_RE.sub(
            lambda m: m.group(0).replace("_", "\\_"), parts[i])
    return "".join(parts)


def render_markdown_safe(text: str, extras: list[str] | None = None) -> str:
    """Render Markdown to HTML with safe_mode='escape', auto-link T-XXX refs
    and bare http(s) URLs.

    Used by /review and any blueprint that needs to render an arbitrary chunk
    of task-body markdown (rationale, evidence, etc.) without piping through
    tasks.py's AC-specific helpers. Returns '' for empty input. Caller must
    mark returned string `| safe` in templates.

    Origin: T-1575 — /review surface dumped raw markdown into a `<pre>` block.
    Promoted here (rather than reused from tasks.py) to break the blueprint-
    private parser pattern called out in the T-1575 RCA.

    T-3649 (055 framework:pickup @236): optional markdown2 ``extras`` (e.g.
    ["tables", "fenced-code-blocks", "header-ids"]) so a caller that needs
    tables keeps this link pipeline instead of calling markdown2 directly.
    ``extras=None`` is the previous behaviour exactly.
    """
    if not text:
        return ""
    try:
        import markdown2
    except ImportError:
        return text  # graceful degradation
    text = _TASK_REF_RE_SHARED.sub(r"[\1](/tasks/\1)", text)
    text = protect_path_underscores(text)
    text = _BARE_URL_RE_SHARED.sub(lambda m: f"[{m.group(1).rstrip('.,;:!?')}]({m.group(1).rstrip('.,;:!?')})", text)
    if extras:
        html = markdown2.markdown(text, safe_mode="escape", extras=list(extras)).strip()
    else:
        html = markdown2.markdown(text, safe_mode="escape").strip()
    # T-1575 codification: backticked URLs (`<code>http://...</code>`) are also
    # clickable. Rendering layer is the contract — agent need not remember to
    # avoid backticks around URLs.
    html = _CODE_URL_HTML_RE_SHARED.sub(
        lambda m: f'<a href="{m.group(1)}"><code>{m.group(1)}</code></a>',
        html,
    )
    # T-1722: artefact paths (docs/reports/*, .tasks/*, .fabric/components/*, etc.)
    # become clickable /file/ links. Existence-gated; same rendering-layer
    # contract as the T-1575 URL/T-NNNN shape — agent need not pre-format.
    html = _auto_link_files(html)
    return html


_REC_MARKER_RE = re_mod.compile(
    # Captures the bold marker text (e.g. "Recommendation:", "Evidence — closed (7):", "Captured learning:").
    # Optional leading `- ` / `* ` bullet (T-1580): authors sometimes nest the markers as a Markdown list.
    r"^[ \t]*(?:[-*][ \t]+)?\*\*([^*]+?)\*\*\s*",
    re_mod.MULTILINE,
)


def _classify_rec_marker(label: str) -> str:
    """Map a bold marker label to a canonical bucket: 'recommendation',
    'rationale', 'evidence', 'captured_learning', or 'other'. Tolerates
    decorations like 'Evidence — closed (7):', 'Evidence — deferred (2):'."""
    s = label.strip().rstrip(":").strip().lower()
    # Strip trailing parenthetical / em-dash decorations
    s = re_mod.split(r"\s*[—–\-]\s*|\s*\(", s, maxsplit=1)[0].strip()
    if s == "recommendation":
        return "recommendation"
    if s == "rationale":
        return "rationale"
    if s == "evidence":
        return "evidence"
    if s in ("captured learning", "learning"):
        return "captured_learning"
    return "other"


# T-3252: matches a verdict token optionally wrapped in its own bold markers
# (e.g. "**GO** — promote…"), since `_REC_MARKER_RE` only consumes the marker
# label ("Recommendation:") and leaves any inline emphasis on the value itself
# in the body span.
_REC_VERDICT_RE = re_mod.compile(
    r"\s*\*{0,2}(KEEP-OPEN|NO[-_]GO|CLOSE|GO|DEFER)\b\*{0,2}",
    re_mod.IGNORECASE,
)


def extract_recommendation(body: str) -> dict:
    """Extract structured fields from a task body's ## Recommendation section.

    Returns dict with `verdict` (GO/NO-GO/DEFER/'?'), `rationale` (str), `evidence`
    (str — concatenation of all Evidence-* sub-blocks), `verdict_note` (str — any
    prose trailing the verdict token on the Recommendation line itself), `other`
    (str — everything else the tokeniser found: text before the first bold marker,
    spans under a marker `_classify_rec_marker` doesn't recognise, and a
    Recommendation span whose value didn't match a known verdict token), and `raw`
    (full section text after HTML-comment strip). All keys always present.

    Tokenises the section by bold markers (`**Recommendation:**`, `**Rationale:**`,
    `**Evidence — closed (7):**`, `**Captured learning:** ...`) and buckets each
    span into its canonical field. Tolerates decorated labels (em-dash + qualifier
    + parenthetical), so multi-block evidence and captured-learning trailers don't
    leak into the rationale.

    Uses H2+ terminator (L-293) so appended Updates entries don't pollute the
    extraction.

    Origin: T-1575 — consolidates three parsers. First implementation (commit
    6d4a44fbd) had a hardcoded marker alternation that missed `**Evidence —
    closed (7):**` and similar real-world labels, dumping evidence + captured
    learning back into the rationale block. This second implementation replaces
    the alternation with a generic marker tokenizer.

    T-3252: that tokenizer then silently discarded every span it couldn't name
    (`other`, `captured_learning`), the text before the first marker, and any
    prose trailing the verdict token on the Recommendation line — measured at
    602/1058 cards on this repo's own corpus, 3401 dropped fragments
    (`docs/reports/T-3252-recommendation-text-loss.md`). Nothing is dropped now:
    every span that isn't rationale/evidence/verdict lands in `other` instead,
    with its author-written label preserved where it had one.
    """
    out = {"verdict": "?", "rationale": "", "evidence": "", "other": "", "verdict_note": "", "raw": ""}
    if not body:
        return out
    m = re_mod.search(r"^## Recommendation\s*$(.*?)(?=^#{2,} |\Z)",
                      body, re_mod.MULTILINE | re_mod.DOTALL)
    if not m:
        return out
    section = re_mod.sub(r"<!--.*?-->", "", m.group(1), flags=re_mod.DOTALL).strip()
    out["raw"] = section

    # Walk all bold markers and slice the section into labeled spans.
    matches = list(_REC_MARKER_RE.finditer(section))
    buckets: dict[str, list[str]] = {"rationale": [], "evidence": [], "other": []}

    # T-3252 shape (a): text before the first marker — never inside any span, so
    # never bucketed. When there are no markers at all, the whole section is
    # "before the first marker".
    preamble = (section[:matches[0].start()] if matches else section).strip()
    if preamble:
        buckets["other"].append(preamble)

    for idx, mk in enumerate(matches):
        label = mk.group(1)
        bucket = _classify_rec_marker(label)
        # Span from end of this marker line to start of next marker (or section end).
        start = mk.end()
        end = matches[idx + 1].start() if idx + 1 < len(matches) else len(section)
        body_span = section[start:end].strip()
        if bucket == "recommendation":
            # NO_GO underscore form tolerated and normalized to NO-GO (T-1391
            # contract; T-1575's alternation dropped it — T-2581 regression fix).
            # Tolerates the verdict token itself being bold-wrapped (T-3252).
            v = _REC_VERDICT_RE.match(body_span)
            if v:
                out["verdict"] = v.group(1).upper().replace("_", "-")
                # T-3252 shape (b): prose after the verdict token on the same
                # line (e.g. "GO — demand has not materialised") — previously
                # discarded outright. Strip the author's own leading separator
                # (dash/em-dash) since the renderer supplies its own — otherwise
                # "GO" + " — " + "— demand…" doubles up.
                trailing = re_mod.sub(r"^[—–\-]\s*", "", body_span[v.end():].strip())
                if trailing:
                    out["verdict_note"] = trailing
            elif body_span:
                # Recommendation marker present but no recognised verdict token
                # (e.g. "SHIP", "DROP") — still real author text, keep it.
                buckets["other"].append(body_span)
        elif bucket == "rationale":
            buckets["rationale"].append(body_span)
        elif bucket == "evidence":
            # Preserve the decorated label (e.g. "Evidence — closed (7):") so
            # readers can distinguish closed vs deferred groupings. Blank line
            # between heading and body is required for markdown2 to render the
            # following `-` lines as a <ul> list, not a continuation paragraph.
            heading = label.strip().rstrip(":").strip()
            if heading.lower() != "evidence":
                buckets["evidence"].append(f"**{heading}**\n\n{body_span}")
            else:
                buckets["evidence"].append(body_span)
        else:
            # T-3252 shape (c): 'captured_learning' and 'other' — previously
            # dropped along with everything up to the next recognised marker.
            # Keep the label so a reader can tell an author's own heading from
            # one the parser understands.
            if body_span or label.strip():
                heading = label.strip().rstrip(":").strip()
                buckets["other"].append(f"**{heading}**\n\n{body_span}" if body_span else f"**{heading}**")

    out["rationale"] = "\n\n".join(b for b in buckets["rationale"] if b).strip()
    out["evidence"] = "\n\n".join(b for b in buckets["evidence"] if b).strip()
    out["other"] = "\n\n".join(b for b in buckets["other"] if b).strip()
    return out


def extract_recommendation_verdict(body: str) -> str:
    """Compatibility shim — see extract_recommendation. Returns just the verdict
    string ('GO'/'NO-GO'/'DEFER'/'?'). Kept for handover.sh and existing call
    sites. New code should call extract_recommendation() directly.

    Origin: T-1533 — third call site triggered the factor-out per the framework's
    "no premature abstraction" rule. T-1575 consolidated to extract_recommendation.
    """
    return extract_recommendation(body)["verdict"]


def extract_recommendation_state(body: str) -> str:
    """Return review-queue state: 'GO'|'NO-GO'|'DEFER'|'NO-REC'|'?'.

    Distinguishes 'agent owes a recommendation' (NO-REC — no `## Recommendation`
    section at all, or section is empty/whitespace/HTML-comments-only) from
    'verdict missing or unparseable' (?). Both look the same to
    `extract_recommendation_verdict`, so review-queue / handover / /approvals
    rendered them identically — blending 'not ready for review' with 'agent
    deferred without saying GO/NO-GO'.

    Origin: T-1576 — parallel to T-1570 (which surfaced the same gap on the
    inception side of /approvals). Build tasks with all Agent ACs done +
    Human ACs pending + no Recommendation polluted the queue with bare '?'.
    """
    rec = extract_recommendation(body)
    if not rec["raw"].strip():
        return "NO-REC"
    return rec["verdict"]


def _strip_html_comments(text: str) -> str:
    """Remove HTML comments, distinguishing a real opener from a quoted one.

    `re.sub(r"<!--.*?-->", "", text, flags=DOTALL)` is wrong on this corpus.
    Task bodies quote `<!--` inside backticks when they discuss the template, so
    openers outnumber closers — T-1545 carries four `<!--` and two `-->`. The
    naive form pairs the third opener with the second closer and swallows ~3.9KB
    of real content, including a genuine unchecked Human AC.

    The discriminator is position, not balance: a real comment opener starts its
    line, or closes on the same line. A `<!--` embedded mid-sentence with its
    closer lines away is prose ABOUT a comment, not a comment.

      1. `<!--` and `-->` on one line     -> inline comment, strip the span.
      2. `<!--` at column 0 (after ws)    -> block comment, strip to `-->`;
                                             with no `-->` at all, bound at the
                                             next `^#` heading so an unterminated
                                             comment cannot eat later sections.
      3. anything else                    -> quoted text, leave it alone.

    A removed span that contained a newline leaves one behind. Without that, the
    text before the opener is joined onto the line after it, and a `### Human`
    heading that is no longer at column 0 is invisible to every anchor
    downstream — silent, and indistinguishable from a task with no Human ACs.
    """
    out: list[str] = []
    i = 0
    while True:
        s = text.find("<!--", i)
        if s < 0:
            out.append(text[i:])
            break
        line_start = text.rfind("\n", 0, s) + 1
        at_line_start = text[line_start:s].strip() == ""
        close = text.find("-->", s)
        eol = text.find("\n", s)
        same_line = close >= 0 and (eol < 0 or close < eol)

        if not same_line and not at_line_start:
            # Case 3: quoted. Emit it verbatim and continue past the marker.
            out.append(text[i:s + 4])
            i = s + 4
            continue

        out.append(text[i:s])
        if close < 0:
            h = re_mod.search(r"^#", text[s:], re_mod.MULTILINE)
            nxt = s + h.start() if h else len(text)
        else:
            nxt = close + 3
        if "\n" in text[s:nxt]:
            out.append("\n")
        i = nxt
    return "".join(out)


def count_unchecked_human_acs(body: str) -> int:
    """Count unchecked `- [ ]` AC lines inside the `### Human` block.

    Returns 0 if no Human block exists, or if every Human AC is checked. This
    is the canonical "needs human review" predicate (T-2075, T-2064 GO scope):
    both `/approvals` (web) and `fw review-queue` (CLI) call this rather than
    re-implement their own scan — otherwise the two surfaces silently drift.

    Rules (must stay aligned with `_parse_acceptance_criteria` in tasks.py and
    the inline CLI regex this replaces at bin/fw):

    - Only `- [ ]` lines INSIDE a `### Human` subsection count. `### Agent` ACs,
      `## Verification`, and decorative checklists elsewhere are ignored.
    - EVERY `### Human` block counts, wherever it sits, and each is bounded by the
      next heading of level 1-3. It is deliberately NOT scoped to the
      `## Acceptance Criteria` block (T-3139): three live tasks carried an
      intervening `## Status:` / `## Measured Behaviour` heading between the two,
      which truncated the scope and hid a real operator decision; one carried a
      SECOND `### Human` block that a single `re.search` never reached.
    - HTML comment blocks (`<!-- ... -->`) are stripped before counting, so the
      `[REVIEW] Voice/tone…` placeholder in the template comment never inflates
      the count (T-1581 fix, also the L-298 cockpit class).
    - Tasks where the `### Human` subsection is absent return 0.
    - Empty `body` returns 0.

    The predicate does NOT classify by `[REVIEW] / [REVIEWER] / [RUBBER-STAMP]`
    confidence — that's a downstream display concern (verdict colour, sort
    priority). The "show this task in the queue?" question is independent of
    the prefix.
    """
    if not body:
        return 0
    # Strip comments FIRST and over the whole body, then find EVERY `### Human`
    # block wherever it sits. See T-3139 for why each of those three words is
    # load-bearing; the docstring above carries the summary.
    text = _strip_html_comments(body)
    total = 0
    for m in re_mod.finditer(
        r"^### Human\s*$(.*?)(?=^#{1,3} |\Z)",
        text, re_mod.MULTILINE | re_mod.DOTALL,
    ):
        total += len(re_mod.findall(r"^\s*-\s*\[ \]", m.group(1), re_mod.MULTILINE))
    return total


def needs_human_review(body: str) -> bool:
    """Boolean wrapper over `count_unchecked_human_acs`.

    True iff the task body has ≥1 unchecked `### Human` acceptance criterion.
    Use this in queue-build code paths (`_load_pending_human_acs`, `fw
    review-queue`) to decide whether a task appears in the review queue at all.
    See T-2075 / T-2064 GO scope.
    """
    return count_unchecked_human_acs(body) > 0


def count_human_acs(body: str) -> tuple[int, int]:
    """Return ``(total, unchecked)`` Human criteria, scoped exactly as
    `count_unchecked_human_acs` scopes them (every `### Human` block, comments
    stripped — T-3139). ``unchecked`` always equals that function's result.

    T-3590: the batch-complete "ready" test needs the total as well as the
    unchecked count, because "no unchecked Human criteria" is vacuously true of a
    task whose Human block the parser failed to find.
    """
    if not body:
        return 0, 0
    text = _strip_html_comments(body)
    total = unchecked = 0
    for m in re_mod.finditer(
        r"^### Human\s*$(.*?)(?=^#{1,3} |\Z)",
        text, re_mod.MULTILINE | re_mod.DOTALL,
    ):
        total += len(re_mod.findall(r"^\s*-\s*\[[ xX]\]", m.group(1), re_mod.MULTILINE))
        unchecked += len(re_mod.findall(r"^\s*-\s*\[ \]", m.group(1), re_mod.MULTILINE))
    return total, unchecked


def has_unchecked_review_ac(body: str) -> bool:
    """True iff an unchecked `[REVIEW]` criterion sits in any `### Human` block
    (same scoping as `count_unchecked_human_acs`). Sort-priority signal for
    /approvals (T-3590 — was read from `_parse_acceptance_criteria`, which stops
    at an intervening `## ` heading)."""
    if not body:
        return False
    text = _strip_html_comments(body)
    for m in re_mod.finditer(
        r"^### Human\s*$(.*?)(?=^#{1,3} |\Z)",
        text, re_mod.MULTILINE | re_mod.DOTALL,
    ):
        if re_mod.search(r"^\s*-\s*\[ \]\s*\[REVIEW\]", m.group(1), re_mod.MULTILINE):
            return True
    return False


def is_ready_for_batch_completion(status: str, body: str) -> bool:
    """The ONE predicate for "the /approvals batch button may close this task" (T-3590).

    Ready means all three:
      - ``status == "work-completed"`` — partial-complete (Agent criteria and
        gates already passed, task held in active/ for the human). Batch-complete
        runs with ``--skip-acceptance-criteria --skip-verification``, so a
        ``started-work`` task must never qualify, whatever its Human boxes say.
      - at least one Human criterion exists (no vacuous "all ticked"), and
      - none is unchecked, counted by `count_human_acs` (T-3139 scoping).

    Admission to the pending list (`needs_human_review`), the page's ready count
    and `complete_batch` all use this scoping; do not reimplement it with
    `_parse_acceptance_criteria` — that parser stops at an intervening `## `
    heading, which is how T-2200/T-2202 were offered as "ready" while carrying an
    unticked [REVIEW] criterion.
    """
    if str(status or "").strip() != "work-completed":
        return False
    total, unchecked = count_human_acs(body)
    return total > 0 and unchecked == 0


def extract_reviewer_verdict(body: str) -> dict:
    """Extract the reviewer agent's verdict from `## Reviewer Verdict (vX.Y)`.

    Returns dict with `overall` (str|None — e.g. "PASS"/"FAIL"/"WARN"),
    `findings` (int — 0 for "none"), and `needs_human` (bool|None).
    All keys present; `overall is None` means no verdict block exists.

    Origin: T-1569 / F3 from T-1565 audit. The reviewer (lib/reviewer/static_scan.py)
    is the only mechanical advisor in the approval arc, but /approvals never surfaced
    its findings at decision time.
    """
    out = {"overall": None, "findings": 0, "needs_human": None}
    if not body:
        return out
    m = re_mod.search(
        r"^## Reviewer Verdict \(v[0-9.]+\)[^\n]*\n(.*?)(?=^#{2,} |\Z)",
        body, re_mod.MULTILINE | re_mod.DOTALL,
    )
    if not m:
        return out
    section = m.group(1)
    overall_m = re_mod.search(r"^- \*\*Overall:\*\*\s*([A-Z][A-Z_-]*)", section, re_mod.MULTILINE)
    if overall_m:
        out["overall"] = overall_m.group(1).strip()
    nh_m = re_mod.search(r"^- \*\*Needs Human:\*\*\s*(yes|no)\b", section, re_mod.MULTILINE | re_mod.IGNORECASE)
    if nh_m:
        out["needs_human"] = nh_m.group(1).lower() == "yes"
    f_m = re_mod.search(r"^- \*\*Findings:\*\*\s*(\d+|none)\b", section, re_mod.MULTILINE | re_mod.IGNORECASE)
    if f_m:
        v = f_m.group(1).lower()
        out["findings"] = 0 if v == "none" else int(v)
    return out


def extract_recommendation_claims_verdict(body: str) -> dict:
    """Extract the claims-validator verdict from `## Recommendation Verdict (vX.Y)`.

    Returns dict with `overall` (str|None — CONFIRMED/CONTRADICTED/UNVERIFIED),
    `claims` (list of {raw, kind, status, detail}), `total` (int) and
    `passed` (int). `overall is None` means no verdict block exists.

    Origin: T-100188 (T-100186 GO slice B). The block is written by
    lib/reviewer/recommendation_claims.py (T-100187) when `fw reviewer` runs
    on an inception task.
    """
    out = {"overall": None, "claims": [], "total": 0, "passed": 0}
    if not body:
        return out
    m = re_mod.search(
        r"^## Recommendation Verdict \(v[0-9.]+\)[^\n]*\n(.*?)(?=^#{2,} |\Z)",
        body, re_mod.MULTILINE | re_mod.DOTALL,
    )
    if not m:
        return out
    section = m.group(1)
    overall_m = re_mod.search(r"^- \*\*Overall:\*\*\s*([A-Z]+)", section, re_mod.MULTILINE)
    if overall_m:
        out["overall"] = overall_m.group(1).strip()
    for row in re_mod.finditer(r"^\| `([^`|]+)` \| (\w+) \| ([^|]+) \|", section, re_mod.MULTILINE):
        cell = row.group(3).strip()
        if "pass" in cell:
            status = "pass"
        elif "fail" in cell:
            status = "fail"
        else:
            status = "unverifiable"
        detail = cell.split("—", 1)[1].strip() if "—" in cell else ""
        out["claims"].append(
            {"raw": row.group(1), "kind": row.group(2), "status": status, "detail": detail}
        )
    out["total"] = len(out["claims"])
    out["passed"] = sum(1 for c in out["claims"] if c["status"] == "pass")
    return out


# ---------------------------------------------------------------------------
# Task metadata cache (T-1233: avoid re-reading 1200+ files on every request)
# ---------------------------------------------------------------------------

import time as _time

# T-3459: `tags` carries its OWN timestamp. It used to share `ts`, which is
# written only by get_all_task_metadata() (below), and that was wrong in both
# directions at once:
#
#   * get_episodic_tags() stored its result but never stamped `ts`, so unless
#     get_all_task_metadata() happened to have run in the last TTL the cache
#     never read as valid and the 3929-document episodic scan ran AGAIN on the
#     next request. Measured on /metrics: the whole corpus re-parsed per hit.
#   * and when get_all_task_metadata() DID stamp `ts`, a `tags` computed
#     arbitrarily long ago began reading as fresh — and nothing recomputed it,
#     because the freshness check was now satisfied. Stale data served
#     indefinitely, for exactly as long as the other function kept being called.
#
# One timestamp for two independently-populated entries cannot be right: either
# it is stamped by both (and each makes the other look fresh) or by one (and the
# other never caches). Both halves of that were live.
_task_cache = {"data": None, "names": None, "tags": None, "ts": 0, "tags_ts": 0,
               "sig": None, "tags_sig": None}
# T-3575: freshness is CHANGE-driven, not time-driven. The 30s TTL meant any visit
# more than 30s after the previous one rebuilt ~3,600 task files + ~3,900 episodic
# files (measured 3.35s cold vs 0.19s warm on /tasks), so most real visits were the
# slow one. The cache is now validated by a (name, mtime_ns, size) signature over the
# source files — one stat per file, ~50ms, no reads — and a rebuild re-parses only
# files whose mtime moved (per-file mtime_cached_get). The TTL survives only as a
# minutes-long safety net for anything a stat signature cannot see.
_TASK_CACHE_TTL = 300  # seconds — safety net only; freshness comes from the signature

_TASK_FM_CACHE: dict = {}       # path -> (mtime_ns, frontmatter dict | None)
_EPISODIC_TAGS_CACHE: dict = {}  # path -> (mtime_ns, (task_id, tags) | None)
_TASK_BUILD_LOCK = threading.Lock()
_TAGS_BUILD_LOCK = threading.Lock()


def _dir_signature(directory, prefix, suffix):
    """Signature of the files in `directory` named `prefix*suffix`.

    Any add, remove, rename, or in-place rewrite (mtime or size moves) changes it.
    Reads no file content.
    """
    sig = []
    try:
        with os.scandir(directory) as it:
            for entry in it:
                name = entry.name
                if name.startswith(prefix) and name.endswith(suffix):
                    try:
                        st = entry.stat()
                    except OSError:
                        continue
                    sig.append((name, st.st_mtime_ns, st.st_size))
    except OSError:
        return ()
    sig.sort()
    return tuple(sig)


def _task_files_signature():
    """Stat-signature of every task file, computed at most once per request.

    T-3575 review: the walk stats ~3,600 files (~29ms), and callers that read
    task metadata in a loop (arcs._read_task_meta x53 on /arcs/continuous-run)
    paid it per call. Memoised in flask.g so a request pays once and the next
    request re-stats; outside a request (tests, CLI) it is always computed.
    """
    memo = None
    # GET/HEAD only: a mutating request may write a task file and re-read it.
    if has_request_context() and request.method in ("GET", "HEAD"):
        memo = g.__dict__.setdefault("_task_files_sig", {})
        if PROJECT_ROOT in memo:
            return memo[PROJECT_ROOT]
    sig = tuple(
        (loc, _dir_signature(PROJECT_ROOT / ".tasks" / loc, "T-", ".md"))
        for loc in ("active", "completed")
    )
    if memo is not None:
        memo[PROJECT_ROOT] = sig
    return sig


def _parse_task_fm_file(path):
    try:
        fm, _ = parse_frontmatter(path.read_text())
    except OSError:
        return None
    return fm or None


def get_all_task_metadata():
    """Return list of frontmatter dicts for all tasks (active + completed).

    Cached until a task file changes (T-3575; safety TTL _TASK_CACHE_TTL).
    Each dict has '_location' key.
    """
    now = _time.monotonic()
    sig = _task_files_signature()
    if (_task_cache["data"] is not None
            and _task_cache["sig"] == sig
            and (now - _task_cache["ts"]) < _TASK_CACHE_TTL):
        return _task_cache["data"]
    with _TASK_BUILD_LOCK:  # T-3627: concurrent misses wait for one build
        if (_task_cache["data"] is not None
                and _task_cache["sig"] == sig
                and (_time.monotonic() - _task_cache["ts"]) < _TASK_CACHE_TTL):
            return _task_cache["data"]
        return _build_task_metadata(now, sig)


def _build_task_metadata(now, sig):
    all_tasks = []
    names = {}
    for location in ("active", "completed"):
        task_dir = PROJECT_ROOT / ".tasks" / location
        if not task_dir.exists():
            continue
        for f in sorted(task_dir.glob("T-*.md"), key=task_id_sort_key):
            if is_test_sentinel(f):  # T-2228: skip T-Test-NNN sentinels
                continue
            parsed = mtime_cached_get(f, _parse_task_fm_file, _TASK_FM_CACHE, default=None)
            if parsed:
                fm = dict(parsed)  # per-request-safe: the per-file cache stays unmutated
                fm["_location"] = location
                fm["_path"] = str(f)  # T-1244: enable body re-read without re-glob
                all_tasks.append(fm)
                tid = fm.get("id", "")
                name = fm.get("name", "")
                if tid and name:
                    names[tid] = name

    _task_cache["data"] = all_tasks
    _task_cache["names"] = names
    _task_cache["ts"] = now
    _task_cache["sig"] = sig
    return all_tasks


def request_task_metadata(loader=None):
    """`get_all_task_metadata()` at most once per GET/HEAD request (T-3600).

    The shared cache makes each call cheap, not free: a builder that asks per
    arc member (arcs._task_meta_index, ~550 calls on one /approvals build) still
    pays the validity check each time. Memoised in flask.g like
    `_task_files_signature`; outside a request it always calls through.
    `loader` lets a module pass its own binding (tests substitute it there).
    """
    loader = loader or get_all_task_metadata
    if has_request_context() and request.method in ("GET", "HEAD"):
        memo = g.__dict__.setdefault("_task_meta_rows", {})
        key = (PROJECT_ROOT, loader)
        if key not in memo:
            memo[key] = loader()
        return memo[key]
    return loader()


def get_task_names():
    """Return {task_id: name} dict. Uses task cache."""
    get_all_task_metadata()  # validates the cache, rebuilds only on change
    return _task_cache["names"] or {}


def _parse_episodic_tags_file(path):
    try:
        # T-3458: this loop parses EVERY .context/episodic/T-*.yaml —
        # thousands of files — so it is the single largest YAML cost on
        # a cold request, and the one place the 12x parser difference
        # measured in isolation actually has thousands of documents to
        # apply to. It was missed by the first pass of that change,
        # which touched only load_yaml; the task's own test caught it.
        with open(path) as fh:
            edata = yaml.load(fh, Loader=_YAML_LOADER)
    except (yaml.YAMLError, OSError):
        return None
    if isinstance(edata, dict):
        return (edata.get("task_id", path.stem), edata.get("tags", []))
    return None


def get_episodic_tags():
    """Return {task_id: [tags]} from episodic files. Cached until they change (T-3575)."""
    now = _time.monotonic()
    episodic_dir = PROJECT_ROOT / ".context" / "episodic"
    sig = _dir_signature(episodic_dir, "T-", ".yaml")
    if (_task_cache["tags"] is not None
            and _task_cache["tags_sig"] == sig
            and (now - _task_cache["tags_ts"]) < _TASK_CACHE_TTL):
        return _task_cache["tags"]
    with _TAGS_BUILD_LOCK:  # T-3627: concurrent misses wait for one build
        if (_task_cache["tags"] is not None
                and _task_cache["tags_sig"] == sig
                and (_time.monotonic() - _task_cache["tags_ts"]) < _TASK_CACHE_TTL):
            return _task_cache["tags"]
        return _build_episodic_tags(episodic_dir, now, sig)


def _build_episodic_tags(episodic_dir, now, sig):
    tags = {}
    if episodic_dir.exists():
        for f in episodic_dir.glob("T-*.yaml"):
            if is_test_sentinel(f):  # T-2228: skip T-Test-NNN sentinels
                continue
            entry = mtime_cached_get(f, _parse_episodic_tags_file, _EPISODIC_TAGS_CACHE, default=None)
            if entry:
                tags[entry[0]] = entry[1]

    _task_cache["tags"] = tags
    _task_cache["tags_ts"] = now   # T-3459: stamp what we just computed
    _task_cache["tags_sig"] = sig
    return tags


# T-3627: Watchtower wedged on 2026-10-01 — 59 of 91 threads were rebuilding the
# /graduation index at once, because a cache miss had no lock: every concurrent
# request that missed did the whole-corpus read itself. Two rules, shared here so
# the next cache does not re-learn them:
#   1. single flight — one build per cache; concurrent misses wait for it and
#      take its result (`signature_cached`);
#   2. bounded heavy routes — past N in flight, answer 503 + Retry-After instead
#      of queueing another thread (`limit_inflight`).
_SIG_CACHES: dict = {}       # name -> (sig, value, monotonic ts)
_SIG_LOCKS: dict = {}        # name -> threading.Lock
_SIG_LOCKS_GUARD = threading.Lock()


def episodic_files_signature():
    """Stat-signature of .context/episodic/T-*.yaml (the episodic half of the corpus)."""
    return _dir_signature(PROJECT_ROOT / ".context" / "episodic", "T-", ".yaml")


def _file_stat_sig(path):
    try:
        st = path.stat()
    except OSError:
        return None
    return (st.st_mtime_ns, st.st_size)


def signature_cached(name, sig, build, ttl=None):
    """Return build(), cached under `name` until `sig` changes (T-3627).

    `sig` is a cheap stat-signature of everything `build` reads (see
    `_task_files_signature`, `episodic_files_signature`). PROJECT_ROOT is folded in
    so a re-pointed root never serves another corpus. A miss takes the cache's own
    lock and re-checks, so N concurrent misses run `build` once, not N times.
    `ttl` (default `_TASK_CACHE_TTL`) is only a safety net.
    """
    ttl = _TASK_CACHE_TTL if ttl is None else ttl
    key = (str(PROJECT_ROOT), sig)

    def _hit():
        entry = _SIG_CACHES.get(name)
        if entry is not None and entry[0] == key and (_time.monotonic() - entry[2]) < ttl:
            return True, entry[1]
        return False, None

    ok, value = _hit()
    if ok:
        return value
    with _SIG_LOCKS_GUARD:
        lock = _SIG_LOCKS.setdefault(name, threading.Lock())
    with lock:
        ok, value = _hit()
        if ok:
            return value
        value = build()
        _SIG_CACHES[name] = (key, value, _time.monotonic())
        return value


def limit_inflight(limit, retry_after=5):
    """Decorator: at most `limit` concurrent executions of a heavy view (T-3627).

    Past the limit the view answers 503 with Retry-After at once rather than
    occupying another server thread on work already in progress.
    """
    import functools

    def deco(view):
        sem = threading.BoundedSemaphore(limit)

        @functools.wraps(view)
        def wrapper(*args, **kwargs):
            if not sem.acquire(blocking=False):
                from flask import Response
                logger.warning("T-3627: %s at in-flight limit %d — 503", view.__name__, limit)
                return Response(
                    "Busy: this page is being rebuilt; retry shortly.\n", status=503,
                    headers={"Retry-After": str(retry_after)}, mimetype="text/plain")
            try:
                return view(*args, **kwargs)
            finally:
                sem.release()
        return wrapper
    return deco


def sse_event(event_type, **kwargs):
    """Format a Server-Sent Event string.

    Returns 'data: {"type": "<event_type>", ...}\\n\\n'
    """
    import json
    payload = {"type": event_type, **kwargs}
    return f"data: {json.dumps(payload)}\n\n"


def load_latest_audit():
    """Load the most recent audit YAML file.

    Returns (timestamp, summary_dict, findings_list).
    Returns (None, {}, []) if no audit data found.
    Used by core.py (dashboard status) and quality.py (full audit view).
    """
    audit_dir = PROJECT_ROOT / ".context" / "audits"
    if not audit_dir.exists():
        return None, {}, []
    # T-1307: filter to date-named audits only so stray non-date YAML
    # (e.g. upgrades.yaml) can't win the reverse-sort.
    audit_files = sorted(audit_dir.glob("[0-9][0-9][0-9][0-9]-*.yaml"), reverse=True)
    if not audit_files:
        return None, {}, []
    data = load_yaml(audit_files[0], label="audit report")
    if not data:
        return None, {}, []
    timestamp = data.get("timestamp", "Unknown")
    summary = data.get("summary", {})
    findings = data.get("findings", [])
    return timestamp, summary, findings


def linkify_tasks(text):
    """Convert T-XXX references to clickable Watchtower links (T-851)."""
    if not text:
        return text
    return re_mod.sub(
        r'\b(T-\d{3,})\b',
        r'<a href="/tasks/\1">\1</a>',
        str(text),
    )


_FRAGMENT_CONVENTION_VIOLATION = (
    "render_page() template {tmpl!r} starts with `{{% extends \"base.html\" %}}`, "
    "but render_page() wraps templates inside _wrapper.html which already extends base.html. "
    "Rendering through this path produces a double-base.html chain (two Watchtower nav stacks). "
    "Convention: page templates rendered via render_page() are pure HTML fragments — "
    "no `<html>`, no `{{% extends %}}`. See sibling examples: inception.html, decisions.html, "
    "fabric_explorer.html, tasks.html. Either remove the extends/block wrapping, or switch "
    "the route to use `render_template()` directly (see escalation_drift.html, reviewer_audit.html). "
    "Convention documented in web/shared.py:render_page() docstring. "
    "Origin: T-1898 fix + T-1899 prevention."
)


def _check_render_page_fragment_convention(template_name):
    """Raise RuntimeError if `template_name` violates the fragment convention.

    Reads the template source via the active Flask app's jinja_env loader and
    examines the first non-empty, non-Jinja-comment line. If it starts with
    `{% extends "base.html"`, the convention is violated — render_page()
    cannot safely wrap such a template.

    The check is best-effort: if the source cannot be read (e.g. test-time
    string loader), the guard silently passes. Real violations live on disk.
    """
    try:
        from flask import current_app
        loader = current_app.jinja_env.loader
        source, _path, _uptodate = loader.get_source(current_app.jinja_env, template_name)
    except Exception:
        return  # best-effort — bail rather than mask real Jinja errors

    # Find first non-empty, non-Jinja-comment line.
    in_comment = False
    for raw in source.splitlines():
        line = raw.strip()
        if not line:
            continue
        if in_comment:
            if "#}" in line:
                in_comment = False
                rest = line.split("#}", 1)[1].strip()
                if not rest:
                    continue
                line = rest
            else:
                continue
        if line.startswith("{#"):
            if "#}" in line[2:]:
                rest = line.split("#}", 1)[1].strip()
                if not rest:
                    continue
                line = rest
            else:
                in_comment = True
                continue
        # First substantive line found
        if line.startswith('{% extends "base.html"') or line.startswith("{% extends 'base.html'"):
            raise RuntimeError(_FRAGMENT_CONVENTION_VIOLATION.format(tmpl=template_name))
        return  # convention satisfied (or unrelated content) — done


def operator_facing_stderr(text):
    """T-3280 (G-102 defect B): translate fw gate stderr into operator-facing text.

    Origin: the T-3278 GO incident (2026-09-05) — the disposition gate's refusal
    was rendered raw to the operator, including its Tier-2 bypass instructions
    (`--skip-disposition-gate`, `FW_SKIP_DISPOSITION_GATE=1`), the internal
    `--skip-sovereignty` warning, and `=== Task Update ===` header noise. Gate
    block messages are written FOR AGENTS (CLAUDE.md requires them to name their
    bypass mechanisms); the operator is not the audience, and showing a human
    bypass flags as the remedy normalises Tier-2 bypass for what is actually an
    authoring gap. T-2219 widened this rendering; this function keeps the width
    (the reason must stay visible) and fixes the register.

    T-3284: lives here (not in a blueprint) because every Watchtower surface
    that renders a subprocess's stderr to the operator is this function's
    audience — inception decide (htmx + redirect paths) and the approvals
    decide/batch-complete endpoints all call it. One implementation, N call
    sites: parity by construction (L-399, same move as T-3279's predicate
    extraction into lib/inception-readiness.sh).

    Drops instruction/noise lines, keeps substantive reason lines. The
    drop-patterns are one list so a [REVIEW] finding can extend it in one place.
    """
    import re as _re
    if not text:
        return ""
    drop_patterns = [
        r"--skip-[a-z-]+",                # any Tier-2 skip-flag instruction line
        r"FW_[A-Z_]+=1",                  # env-var bypass instruction line
        r"^\s*Options:\s*$",              # the bypass-options block header
        r"^\s*\d+\.\s",                   # numbered option lines under it
        r"logged Tier-2",                  # bypass-logging notes
        r"=== Task Update ===",            # update-task.sh banner noise
        r"^Task:\s|^File:\s",              # update-task.sh header lines
        r"WARNING: Completing human-owned task",  # internal sovereignty note
    ]
    kept = []
    for line in text.splitlines():
        if any(_re.search(p, line) for p in drop_patterns):
            continue
        kept.append(line)
    # collapse runs of blank lines left by the drops
    out, prev_blank = [], False
    for line in kept:
        blank = not line.strip()
        if blank and prev_blank:
            continue
        out.append(line)
        prev_blank = blank
    return "\n".join(out).strip()


def render_page(template_name, **context):
    """Render a full page or an htmx content fragment.

    Each page template is a pure HTML fragment (no <html>, no extends).
    For full page loads, we render it inside _wrapper.html which extends
    base.html. For htmx requests (HX-Request header present), we return
    just the fragment.

    T-1899 guard: full-page loads check that the template begins as a fragment
    (no `{% extends "base.html" %}`) and raise RuntimeError otherwise — closes
    the convention-violation detection window opened by T-1898.
    """
    context.setdefault("nav_groups", NAV_GROUPS)
    context.setdefault("nav_items", NAV_ITEMS)
    context.setdefault("active_endpoint", request.endpoint)
    context.setdefault("project_root", str(PROJECT_ROOT))
    context.setdefault("ambient", build_ambient())
    context.setdefault("yaml_errors", get_yaml_errors())
    # Breadcrumb (T-2009, arc-007 S2b): path-derived, rendered inside #content so
    # it survives htmx swaps (the chrome outside #content goes stale on htmx nav).
    context.setdefault("breadcrumb", nav_breadcrumb(context["active_endpoint"], request.path))
    # Pin toggle state (T-2010, arc-007 S2c): the current page's pin metadata for
    # the breadcrumb-bar star (None on non-nav pages → no toggle). Function-level
    # import avoids a settings↔shared circular at module load.
    if "wt_pinnable" not in context:
        try:
            from web.blueprints.settings import pin_state_for

            context["wt_pinnable"] = pin_state_for(context["active_endpoint"])
        except Exception:
            context["wt_pinnable"] = None

    if request.headers.get("HX-Request"):
        # Prepend the breadcrumb partial so an htmx #content swap also refreshes it.
        crumb = render_template("_breadcrumb.html", **context)
        return crumb + render_template(template_name, **context)
    else:
        _check_render_page_fragment_convention(template_name)
        context["_content_template"] = template_name
        return render_template("_wrapper.html", **context)
