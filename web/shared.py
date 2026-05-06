"""Shared helpers for the web UI blueprints."""
from __future__ import annotations

import logging
import os
import re as re_mod
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import yaml
from flask import render_template, request

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

APP_DIR = Path(__file__).resolve().parent
FRAMEWORK_ROOT = APP_DIR.parent


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

NAV_GROUPS = [
    ("Work", [
        ("Tasks",       "tasks.tasks",              None),
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
        ("Arcs",        "arcs.arcs_index",          None),
        ("Terminal",    "terminal.terminal_page",    None),
        ("Sessions",    "sessions_page.sessions_page", None),
    ]),
    ("Govern", [
        ("Approvals",     "approvals.approvals",                   None),
        ("Directives",    "core.directives",                       None),
        ("Enforcement",   "enforcement.enforcement_dashboard",     None),
        ("Discoveries",   "discoveries_bp.discoveries_dashboard",  None),
        ("Hooks",         "hooks.hooks_page",                      None),
        ("Risks",         "risks.risk_register",                   None),
        ("Gaps",          "discovery.gaps",                        None),
        ("Quality",       "quality.quality_gate",                  None),
        ("Reviewer Audit", "reviewer.reviewer_audit",              None),
        ("Reviewer Overrides", "reviewer.reviewer_overrides",      None),
        ("Escalation Drift", "escalation.escalation_drift",        None),
        ("Metrics",       "metrics.project_metrics",               None),
        ("Costs",         "costs.costs_dashboard",                 None),
        ("Config",        "config.config_page",                    None),
        ("Cron",          "cron.cron_registry",                    None),
        ("Pending",       "pending.pending_page",                  None),
    ]),
]

# Flat list for backward compat (used in error handlers, etc.)
NAV_ITEMS = []
for _group_name, _items in NAV_GROUPS:
    NAV_ITEMS.extend(_items)


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
        active_tasks = sorted(active_dir.glob("T-*.md"), key=task_id_sort_key)
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


def load_yaml(path, *, label: str = ""):
    """Load a YAML file. Log and collect errors instead of silently returning {}."""
    path = Path(path)
    if not path.exists():
        return {}
    try:
        with open(path) as f:
            data = yaml.safe_load(f)
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
            data = yaml.safe_load(f)
        if isinstance(data, dict) and data.get("schema_version"):
            return data
    except Exception:
        pass
    return None


def parse_frontmatter(content):
    """Parse YAML frontmatter from a markdown file.

    Returns (frontmatter_dict, body_text). Returns ({}, content) if no
    frontmatter found or parsing fails.
    """
    fm_match = re_mod.match(r"^---\s*\n(.*?)\n---\n?(.*)", content, re_mod.DOTALL)
    if not fm_match:
        return {}, content
    try:
        fm = yaml.safe_load(fm_match.group(1))
    except yaml.YAMLError:
        return {}, content
    if not isinstance(fm, dict):
        return {}, content
    return fm, fm_match.group(2)


_TASK_REF_RE_SHARED = re_mod.compile(r"(?<![\w/-])(T-\d{3,5})(?![\w/-])")
_BARE_URL_RE_SHARED = re_mod.compile(r"(?<![\(\[\"'`])(https?://[^\s<>'\"`)\]]+)")
_CODE_URL_HTML_RE_SHARED = re_mod.compile(r"<code>(https?://[^<\s]+?)</code>")

# T-1764: single source of truth for "viewable artefact paths".
# Both the auto-linker (T-1722) and the /file/ route (T-632) consult these.
# Diverging them — as happened pre-T-1764 — means the linker emits anchors
# the route can't serve (HTTP 404), silently breaking T-1722's contract.

VIEWABLE_DIR_PREFIXES = (
    "docs/reports/",
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


def is_viewable_path(filepath: str) -> bool:
    """Return True iff `filepath` (relative to PROJECT_ROOT) is servable by /file/.

    Single source of truth used by both `_auto_link_files` (T-1722) and the
    `/file/<path>` route (T-632). Drift between linker and route was the
    T-1764 root cause.

    Path-traversal guards live HERE, not in the route — so any caller (linker,
    route, future surfaces) gets the same enforcement.
    """
    if not filepath:
        return False
    if ".." in filepath:
        return False
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
    pattern = (
        # Three guards to keep idempotent and avoid wrapping an already-linked path:
        #   (?<!href=")  — path is not the href target of an existing <a>
        #   (?<!/file/)  — path is not the suffix of an already-built /file/<...> URL
        #   (?<!">)      — path is not the link text immediately following an anchor's closing `">`
        r'(?<!href=")'
        r'(?<!/file/)'
        r'(?<!">)'
        r'(`?)'
        r'((?:' + dirs + r')'
        r'[A-Za-z0-9_/.-]+\.(?:' + exts + r'))'
        r'(`?)'
    )
    return re_mod.compile(pattern)


_ARTEFACT_PATH_RE = _build_artefact_path_re()


def _auto_link_files(html: str) -> str:
    """Convert artefact-path references in rendered HTML to clickable /file/ links.

    Existence-gated: only paths that resolve under PROJECT_ROOT become anchors;
    non-matching prose stays untouched. Backticks (``code spans``) are preserved
    around the link, mirroring the T-1575 contract for backticked URLs.

    Origin: T-633 (introduced in web/blueprints/docs.py for component-doc pages).
    Promoted here in T-1722 so /review, /tasks, /approvals, /inception — every
    Markdown surface — gets one-click artefact navigation.
    """
    if not html:
        return html

    def _replace(m):
        tick1, path, tick2 = m.group(1), m.group(2), m.group(3)
        if (PROJECT_ROOT / path).exists():
            inner = f"{tick1}{path}{tick2}" if (tick1 or tick2) else path
            # Wrap inside <code>…</code> when backticked, mirroring the
            # T-1575 codified shape for backticked URLs.
            if tick1 and tick2:
                return f'<a href="/file/{path}"><code>{path}</code></a>'
            return f'<a href="/file/{path}">{inner}</a>'
        return m.group(0)

    return _ARTEFACT_PATH_RE.sub(_replace, html)


def render_markdown_safe(text: str) -> str:
    """Render Markdown to HTML with safe_mode='escape', auto-link T-XXX refs
    and bare http(s) URLs.

    Used by /review and any blueprint that needs to render an arbitrary chunk
    of task-body markdown (rationale, evidence, etc.) without piping through
    tasks.py's AC-specific helpers. Returns '' for empty input. Caller must
    mark returned string `| safe` in templates.

    Origin: T-1575 — /review surface dumped raw markdown into a `<pre>` block.
    Promoted here (rather than reused from tasks.py) to break the blueprint-
    private parser pattern called out in the T-1575 RCA.
    """
    if not text:
        return ""
    try:
        import markdown2
    except ImportError:
        return text  # graceful degradation
    text = _TASK_REF_RE_SHARED.sub(r"[\1](/tasks/\1)", text)
    text = _BARE_URL_RE_SHARED.sub(lambda m: f"[{m.group(1).rstrip('.,;:!?')}]({m.group(1).rstrip('.,;:!?')})", text)
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


def extract_recommendation(body: str) -> dict:
    """Extract structured fields from a task body's ## Recommendation section.

    Returns dict with `verdict` (GO/NO-GO/DEFER/'?'), `rationale` (str), `evidence`
    (str — concatenation of all Evidence-* sub-blocks), and `raw` (full section
    text after HTML-comment strip). All keys always present.

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
    """
    out = {"verdict": "?", "rationale": "", "evidence": "", "raw": ""}
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
    buckets: dict[str, list[str]] = {"rationale": [], "evidence": []}
    for idx, mk in enumerate(matches):
        label = mk.group(1)
        bucket = _classify_rec_marker(label)
        # Span from end of this marker line to start of next marker (or section end).
        start = mk.end()
        end = matches[idx + 1].start() if idx + 1 < len(matches) else len(section)
        body_span = section[start:end].strip()
        if bucket == "recommendation":
            v = re_mod.match(r"\s*(NO-GO|GO|DEFER)\b", body_span, re_mod.IGNORECASE)
            if v:
                out["verdict"] = v.group(1).upper()
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
        # 'captured_learning' and 'other' intentionally dropped — they belong in
        # neither rationale nor evidence; raw is preserved for full-text needs.

    out["rationale"] = "\n\n".join(b for b in buckets["rationale"] if b).strip()
    out["evidence"] = "\n\n".join(b for b in buckets["evidence"] if b).strip()
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


# ---------------------------------------------------------------------------
# Task metadata cache (T-1233: avoid re-reading 1200+ files on every request)
# ---------------------------------------------------------------------------

import time as _time

_task_cache = {"data": None, "names": None, "tags": None, "ts": 0}
_TASK_CACHE_TTL = 30  # seconds


def get_all_task_metadata():
    """Return list of frontmatter dicts for all tasks (active + completed).

    Cached for _TASK_CACHE_TTL seconds. Each dict has '_location' key.
    """
    now = _time.monotonic()
    if _task_cache["data"] is not None and (now - _task_cache["ts"]) < _TASK_CACHE_TTL:
        return _task_cache["data"]

    all_tasks = []
    names = {}
    for location in ("active", "completed"):
        task_dir = PROJECT_ROOT / ".tasks" / location
        if not task_dir.exists():
            continue
        for f in sorted(task_dir.glob("T-*.md"), key=task_id_sort_key):
            fm, _ = parse_frontmatter(f.read_text())
            if fm:
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
    return all_tasks


def get_task_names():
    """Return {task_id: name} dict. Uses task cache."""
    now = _time.monotonic()
    if _task_cache["names"] is not None and (now - _task_cache["ts"]) < _TASK_CACHE_TTL:
        return _task_cache["names"]
    get_all_task_metadata()  # populate cache
    return _task_cache["names"] or {}


def get_episodic_tags():
    """Return {task_id: [tags]} from episodic files. Cached."""
    now = _time.monotonic()
    if _task_cache["tags"] is not None and (now - _task_cache["ts"]) < _TASK_CACHE_TTL:
        return _task_cache["tags"]

    tags = {}
    episodic_dir = PROJECT_ROOT / ".context" / "episodic"
    if episodic_dir.exists():
        for f in episodic_dir.glob("T-*.yaml"):
            try:
                with open(f) as fh:
                    edata = yaml.safe_load(fh)
                if isinstance(edata, dict):
                    tags[edata.get("task_id", f.stem)] = edata.get("tags", [])
            except yaml.YAMLError:
                continue

    _task_cache["tags"] = tags
    return tags


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


def render_page(template_name, **context):
    """Render a full page or an htmx content fragment.

    Each page template is a pure HTML fragment (no <html>, no extends).
    For full page loads, we render it inside _wrapper.html which extends
    base.html. For htmx requests (HX-Request header present), we return
    just the fragment.
    """
    context.setdefault("nav_groups", NAV_GROUPS)
    context.setdefault("nav_items", NAV_ITEMS)
    context.setdefault("active_endpoint", request.endpoint)
    context.setdefault("project_root", str(PROJECT_ROOT))
    context.setdefault("ambient", build_ambient())
    context.setdefault("yaml_errors", get_yaml_errors())

    if request.headers.get("HX-Request"):
        return render_template(template_name, **context)
    else:
        context["_content_template"] = template_name
        return render_template("_wrapper.html", **context)
