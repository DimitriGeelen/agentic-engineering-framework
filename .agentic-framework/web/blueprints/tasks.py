"""Tasks blueprint — task list, detail, status API."""

import re as re_mod
from datetime import datetime, timezone

import markdown2
import yaml
from flask import Blueprint, abort, request, render_template

from lib.arc_membership import task_dict_in_arc
from web.shared import (
    FRAMEWORK_ROOT, PROJECT_ROOT, render_page, parse_frontmatter,
    get_all_task_metadata, get_episodic_tags, task_id_sort_key,
    extract_recommendation, extract_reviewer_verdict, render_markdown_safe,
    _auto_link_files,
)
from web.subprocess_utils import run_fw_command

bp = Blueprint("tasks", __name__)


# T-2222 (OBS-049 full closure): _escape helper for error-fragment renders.
# Mirrors the cockpit.py:255 shape; used by the 6 action-error renders at
# ~L972/990/1006/1022/1045/1061 below to defuse XSS on raw stderr interpolation.
def _escape(text):
    """Escape HTML in error-render fragments. Mirrors cockpit.py:_escape."""
    return (text.replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;").replace('"', "&quot;"))


# ---------------------------------------------------------------------------
# T-1980: per-task BVP/Cost computation reused from /bvp and /arcs/<id> helpers.
# Same math path → numbers cannot drift between surfaces.
# ---------------------------------------------------------------------------

def _task_bvp_data(task_data: dict) -> dict:
    """Compute BVP scores + cost composite for a task frontmatter dict.

    Returns shape: {mode, scores, bvp_raw, bvp_norm, cost, cost_source, weights}.
    mode is 'confirmed' / 'proposed' / 'none'.
    """
    from web.blueprints.bvp import (
        _load_policy, _driver_weights, _compute_bvp, _compute_cost,
        _resolve_cost_estimate, _latest_proposed_scores,
    )

    policy = _load_policy()
    weights = _driver_weights(policy)
    # T-1981: human-readable driver names from policy (D1 → "Antifragility" etc).
    driver_names: dict[str, str] = {}
    for d in (policy.get("protected_drivers") or []):
        if d.get("id") and d.get("name"):
            driver_names[d["id"]] = d["name"]
    for d in (policy.get("free_drivers") or []):
        if d.get("id") and d.get("name"):
            driver_names[d["id"]] = d["name"]

    scores = task_data.get("bvp_scores") if isinstance(task_data.get("bvp_scores"), dict) else None
    if scores:
        mode = "confirmed"
    else:
        proposed = _latest_proposed_scores(task_data) if isinstance(task_data, dict) else None
        if proposed:
            scores = proposed
            mode = "proposed"
        else:
            return {
                "mode": "none",
                "scores": None,
                "bvp_raw": None,
                "bvp_norm": None,
                "cost": None,
                "cost_source": "none",
                "weights": weights,
                "driver_names": driver_names,
            }

    is_proposed = mode == "proposed"
    raw, norm = _compute_bvp(scores, weights)
    ce, _ce_mode = _resolve_cost_estimate(task_data, is_proposed=is_proposed)
    cost, _br, _tier, _effort, src = _compute_cost(ce, default_when_absent=is_proposed)

    return {
        "mode": mode,
        "scores": scores,
        "bvp_raw": raw,
        "bvp_norm": norm,
        "cost": cost,
        "cost_source": src,
        "weights": weights,
        "driver_names": driver_names,
    }


def _attach_bvp_to_tasks(tasks: list[dict]) -> None:
    """T-1982: batch-attach `t["_bvp"] = {mode, norm}` to each task in-place.

    Loads policy ONCE (cheaper than 1200 _task_bvp_data calls). Skips cost
    computation — listing cards just need the norm chip. Tasks with no
    scores get `_bvp = None` (template renders nothing for none-mode).
    """
    from web.blueprints.bvp import (
        _load_policy, _driver_weights, _compute_bvp, _latest_proposed_scores,
    )
    policy = _load_policy()
    weights = _driver_weights(policy)
    for t in tasks:
        scores = t.get("bvp_scores") if isinstance(t.get("bvp_scores"), dict) else None
        if scores:
            mode = "confirmed"
        else:
            proposed = _latest_proposed_scores(t) if isinstance(t, dict) else None
            if proposed:
                scores = proposed
                mode = "proposed"
            else:
                t["_bvp"] = None
                continue
        _raw, norm = _compute_bvp(scores, weights)
        t["_bvp"] = {"mode": mode, "norm": norm}


def _task_arc_data(task_data: dict) -> dict | None:
    """T-1982: load arc YAML for a task with arc_id.

    Returns {arc_id, arc_name, scoped_drivers: [{name, weight, rationale?}, ...]}
    or None if no arc_id / arc file missing.

    Surfaces scoped drivers so the per-task BVP block can show "these arc
    drivers have weights but no per-task score" — making the design gap
    that T-1981 will resolve visible instead of silent.
    """
    arc_id = task_data.get("arc_id")
    if not arc_id:
        return None
    arc_path = PROJECT_ROOT / ".context" / "arcs" / f"{arc_id}.yaml"
    if not arc_path.exists():
        return None
    try:
        arc = yaml.safe_load(arc_path.read_text()) or {}
    except yaml.YAMLError:
        return None
    return {
        "arc_id": arc_id,
        "arc_name": arc.get("name") or "",
        "scoped_drivers": arc.get("scoped_drivers") or [],
    }


# ---------------------------------------------------------------------------
# Enum loading from status-transitions.yaml (T-1179, G-038)
# ---------------------------------------------------------------------------

_ENUM_CACHE = {}

def _load_enums():
    """Load workflow_types and horizons from status-transitions.yaml.

    Cached after first load. Falls back to hardcoded defaults if YAML is missing.
    """
    if _ENUM_CACHE:
        return _ENUM_CACHE
    yaml_path = FRAMEWORK_ROOT / "status-transitions.yaml"
    try:
        with open(yaml_path) as f:
            data = yaml.safe_load(f) or {}
        _ENUM_CACHE["workflow_types"] = data.get("workflow_types", [])
        _ENUM_CACHE["horizons"] = data.get("horizons", [])
        _ENUM_CACHE["statuses"] = data.get("statuses", {}).get("active", [])
        _ENUM_CACHE["owners"] = data.get("owners", [])
    except Exception:
        _ENUM_CACHE["workflow_types"] = ["build", "test", "refactor", "specification", "design", "decommission", "inception"]
        _ENUM_CACHE["horizons"] = ["now", "next", "later"]
        _ENUM_CACHE["statuses"] = ["captured", "started-work", "issues", "work-completed"]
        _ENUM_CACHE["owners"] = ["human", "claude-code"]
    return _ENUM_CACHE


# ---------------------------------------------------------------------------
# Helpers — file finding and frontmatter editing (T-181 spike)
# ---------------------------------------------------------------------------

def _find_task_file(task_id):
    """Find the task markdown file by ID. Returns Path or None."""
    for location in ["active", "completed"]:
        task_dir = PROJECT_ROOT / ".tasks" / location
        if task_dir.exists():
            for f in task_dir.glob(f"{task_id}-*.md"):
                return f
    return None


def _update_frontmatter_field(file_path, field, value):
    """Update a single-line YAML frontmatter field using regex.

    Uses line-level replacement to avoid yaml.dump() formatting changes.
    Only works for simple scalar fields (name, description single-line, etc.).
    Returns (success, error_message).
    """
    content = file_path.read_text()
    fm_match = re_mod.match(r"^(---\n)(.*?)(\n---)", content, re_mod.DOTALL)
    if not fm_match:
        return False, "Cannot parse frontmatter"

    frontmatter = fm_match.group(2)

    # Escape value for YAML — wrap in quotes if it contains special chars
    if any(c in str(value) for c in ':{}[]&*?|->!%@`,"\'#'):
        safe_value = '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'
    else:
        safe_value = str(value)

    # Replace the field line (handles both quoted and unquoted values)
    pattern = re_mod.compile(rf'^({re_mod.escape(field)}:\s*).*$', re_mod.MULTILINE)
    if not pattern.search(frontmatter):
        return False, f"Field '{field}' not found in frontmatter"

    new_frontmatter = pattern.sub(rf'\g<1>{safe_value}', frontmatter, count=1)

    # Also update last_update timestamp
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    ts_pattern = re_mod.compile(r'^(last_update:\s*).*$', re_mod.MULTILINE)
    new_frontmatter = ts_pattern.sub(rf'\g<1>{ts}', new_frontmatter)

    new_content = fm_match.group(1) + new_frontmatter + fm_match.group(3) + content[fm_match.end():]
    file_path.write_text(new_content)
    return True, None


def _normalize_md_relative_links(text):
    """Pre-process Markdown text so leading-dot relative paths survive
    markdown2's safe_mode URL filter (T-1551). `[x](.context/foo.yaml)`
    becomes `[x](./.context/foo.yaml)`. AC bodies commonly link to
    dotfile paths; without this they collapse to href="#"."""
    if not text:
        return text
    return re_mod.sub(r'\]\(\.(?!/)', '](./.', text)


# Match bare T-NNNN (1-5 digits) NOT inside backticks and NOT already
# part of a Markdown link [...]. Lookbehind/lookahead handle adjacency.
# Two-pass implementation: split on inline-code spans, then linkify the
# non-code parts. Avoids regex-only approaches that mishandle nested
# brackets.
_TASK_REF_RE = re_mod.compile(r'(?<![\w/-])T-\d{1,5}(?![\w/-])')


# T-1553: known Watchtower blueprint routes — auto-linked when bare in AC text.
# Whitelist (not arbitrary /<word>) so we never generate broken links.
_WATCHTOWER_BLUEPRINTS = (
    'approvals', 'review', 'tasks', 'inception', 'cron', 'fabric',
    'discoveries', 'metrics', 'costs', 'gaps', 'reviewer', 'sessions',
    'docs', 'audit', 'audits', 'fleet', 'enforcement', 'pending',
    'prompts', 'quality', 'risks', 'settings', 'terminal', 'timeline',
    'config', 'cockpit',
)
_WT_PATH_RE = re_mod.compile(
    r'(?<![\w])(/(?:' + '|'.join(_WATCHTOWER_BLUEPRINTS) + r')'
    r'(?:/[\w-]+)?)(?!\w)'
)


def _walk_skipping_existing_links(text, replacer):
    """Iterate `text`, applying `replacer(match_obj) -> str` only outside
    inline-code spans and already-linked Markdown ranges. T-1552 + T-1553
    share this scaffolding; replacer is the regex/sub callback."""
    if not text:
        return text
    parts = re_mod.split(r'(`[^`]*`)', text)
    out = []
    for i, part in enumerate(parts):
        if i % 2 == 1:
            out.append(part)
            continue
        rewritten = []
        j = 0
        while j < len(part):
            if part[j] == '[':
                close = part.find(']', j)
                if close != -1 and close + 1 < len(part) and part[close + 1] == '(':
                    paren_close = part.find(')', close + 2)
                    if paren_close != -1:
                        rewritten.append(part[j:paren_close + 1])
                        j = paren_close + 1
                        continue
            replaced, advance = replacer(part, j)
            if replaced is not None:
                rewritten.append(replaced)
                j += advance
            else:
                rewritten.append(part[j])
                j += 1
        out.append(''.join(rewritten))
    return ''.join(out)


def _auto_link_watchtower_paths(text):
    """Rewrite bare Watchtower URL paths (`/approvals`, `/review/T-1448`)
    to Markdown links so they're click-traversable from /review/T-XXX
    surfaces (T-1553). Companion to T-1552's T-NNNN linker. Whitelist
    based — only known blueprint routes are touched."""
    def replacer(s, j):
        m = _WT_PATH_RE.match(s, j)
        if m:
            url = m.group(0)
            return f'[{url}]({url})', m.end() - j
        return None, 0
    return _walk_skipping_existing_links(text, replacer)


def _auto_link_task_refs(text):
    """Rewrite bare `T-NNNN` to `[T-NNNN](/tasks/T-NNNN)` so /review surface
    AC steps become click-traversable across tasks (T-1552). Skips inline
    code and already-linked references (see _walk_skipping_existing_links).
    """
    def replacer(s, j):
        m = _TASK_REF_RE.match(s, j)
        if m:
            tid = m.group(0)
            return f'[{tid}](/tasks/{tid})', m.end() - j
        return None, 0
    return _walk_skipping_existing_links(text, replacer)


# T-1575: bare URLs in AC steps (e.g. "Open http://192.168.10.107:3000/review/T-1565")
# rendered as plain text — markdown2's default doesn't auto-link. Without this, the
# human can't click the link the agent wrote into the Steps. Same _walk_skipping
# scaffolding so we don't double-wrap already-linked URLs.
_BARE_URL_RE = re_mod.compile(r"https?://[^\s<>'\"`)\]]+")


def _auto_link_bare_urls(text):
    """Wrap bare http(s) URLs in markdown link syntax so markdown2 emits <a>.
    Skips inline code and already-linked URLs (T-1575)."""
    def replacer(s, j):
        m = _BARE_URL_RE.match(s, j)
        if m:
            url = m.group(0).rstrip(".,;:!?")  # strip trailing punctuation
            return f"[{url}]({url})", len(url)
        return None, 0
    return _walk_skipping_existing_links(text, replacer)


# T-1575 codification: any URL inside a `<code>` block (because the agent
# wrapped it in backticks) must still be clickable. Post-process the rendered
# HTML to wrap `<code>http(s)://...</code>` in an anchor while preserving the
# code-span styling. This guarantees URLs are clickable regardless of how the
# agent wrote them — the rendering layer is the contract, not agent discipline.
_CODE_URL_HTML_RE = re_mod.compile(r"<code>(https?://[^<\s]+?)</code>")


def _linkify_code_urls(html):
    """Wrap <code>http(s)://...</code> in an anchor so backticked URLs in AC
    Steps are clickable. Idempotent (won't double-wrap because we only match
    the bare <code>...</code> shape, not <a>...<code>...</code>...</a>)."""
    if not html or "<code>" not in html:
        return html
    return _CODE_URL_HTML_RE.sub(
        lambda m: f'<a href="{m.group(1)}"><code>{m.group(1)}</code></a>',
        html,
    )


def _render_md_inline(text):
    """Render text as Markdown HTML for inline display (T-1551).
    Strips <p> wrapper for use inside <li> contexts. safe_mode='escape'
    blocks raw HTML — only Markdown syntax (links, code, emphasis) renders.
    Returns '' for empty input. The caller must mark returned strings safe.
    """
    if not text:
        return ''
    text = _auto_link_watchtower_paths(text)
    text = _auto_link_task_refs(text)
    text = _auto_link_bare_urls(text)
    text = _normalize_md_relative_links(text)
    html = markdown2.markdown(text, safe_mode='escape').strip()
    if html.startswith('<p>') and html.endswith('</p>'):
        html = html[3:-4]
    html = _linkify_code_urls(html)
    # T-1722: artefact paths → /file/ anchors (existence-gated, idempotent).
    return _auto_link_files(html)


def _render_md_block(text):
    """Same as _render_md_inline but keeps <p> wrapping for block contexts
    (Expected, If-not). T-1551."""
    if not text:
        return ''
    text = _auto_link_watchtower_paths(text)
    text = _auto_link_task_refs(text)
    text = _auto_link_bare_urls(text)
    text = _normalize_md_relative_links(text)
    html = markdown2.markdown(text, safe_mode='escape').strip()
    html = _linkify_code_urls(html)
    # T-1722: artefact paths → /file/ anchors (existence-gated, idempotent).
    return _auto_link_files(html)


def _parse_ac_body(body):
    """Parse Steps/Expected/If-not from AC body text.

    T-1551: Steps/Expected/If-not are returned as Markdown-rendered HTML
    so `[label](url)`, inline `code`, and `**emphasis**` work in the
    /review/T-XXX surface (the original T-1548 friction). Templates must
    use `| safe` on these values.
    """
    steps = []
    expected = ''
    if_not = ''
    if not body:
        return steps, expected, if_not

    lines = body.split('\n')
    current_field = None
    current_content = []

    for line in lines:
        stripped = line.strip()
        if stripped.startswith('**Steps:**'):
            current_field = 'steps'
            current_content = []
            continue
        elif stripped.startswith('**Expected:**'):
            if current_field == 'steps':
                steps = [s for s in current_content if s.strip()]
            current_field = 'expected'
            rest = stripped[len('**Expected:**'):].strip()
            current_content = [rest] if rest else []
            continue
        elif stripped.startswith('**If not:**'):
            if current_field == 'steps':
                steps = [s for s in current_content if s.strip()]
            elif current_field == 'expected':
                expected = '\n'.join(current_content).strip()
            current_field = 'if_not'
            rest = stripped[len('**If not:**'):].strip()
            current_content = [rest] if rest else []
            continue
        if current_field:
            current_content.append(stripped)

    if current_field == 'steps':
        steps = [s for s in current_content if s.strip()]
    elif current_field == 'expected':
        expected = '\n'.join(current_content).strip()
    elif current_field == 'if_not':
        if_not = '\n'.join(current_content).strip()

    # Strip numbered prefixes from steps (e.g., "1. Do thing" → "Do thing")
    steps = [re_mod.sub(r'^\d+\.\s*', '', s) for s in steps]

    # T-1551: render Markdown so [label](url), `code`, **bold** work in /review/T-XXX
    steps = [_render_md_inline(s) for s in steps]
    expected = _render_md_block(expected)
    if_not = _render_md_block(if_not)

    return steps, expected, if_not


def _parse_acceptance_criteria(body_text):
    """Parse AC checkboxes with section, confidence, and body details.

    Returns list of dicts with keys:
      line_idx, checked, text, section, confidence, body, steps, expected, if_not
    """
    criteria = []
    lines = body_text.split('\n')
    in_ac_section = False
    current_section = 'general'
    in_comment = False

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Track HTML comments (skip them)
        if '<!--' in stripped:
            in_comment = True
        if in_comment:
            if '-->' in stripped:
                in_comment = False
            i += 1
            continue

        # Track AC section boundaries
        if stripped.startswith('## Acceptance Criteria'):
            in_ac_section = True
            current_section = 'general'
            i += 1
            continue
        if in_ac_section and stripped.startswith('## ') and 'Acceptance Criteria' not in stripped:
            in_ac_section = False
            i += 1
            continue

        if not in_ac_section:
            i += 1
            continue

        # Detect subsection headers
        if stripped == '### Agent' or stripped.startswith('### Agent'):
            current_section = 'agent'
            i += 1
            continue
        if stripped == '### Human' or stripped.startswith('### Human'):
            current_section = 'human'
            i += 1
            continue

        # Parse AC checkbox
        m = re_mod.match(r'^- \[([ xX])\] (.+)$', line)
        if m:
            text = m.group(2)
            checked = m.group(1).lower() == 'x'

            # Parse confidence marker
            confidence = None
            cm = re_mod.match(r'^\[RUBBER-STAMP\]\s*(.+)$', text)
            if cm:
                confidence = 'rubber-stamp'
                text = cm.group(1)
            else:
                cm = re_mod.match(r'^\[REVIEW\]\s*(.+)$', text)
                if cm:
                    confidence = 'review'
                    text = cm.group(1)

            # Collect body lines (indented content following this AC).
            # T-1763: track HTML-comment state inside the sub-loop too —
            # a commented-out template checkbox like
            #   <!-- Example:
            #          - [ ] [REVIEW] Dashboard renders correctly
            #          **Steps:** ... -->
            # used to leak into the body and overwrite real Steps/Expected/If-not.
            # Body must mirror the outer loop's HTML-comment skipping so
            # `_parse_ac_body` only sees real content.
            body_lines = []
            body_in_comment = False
            j = i + 1
            while j < len(lines):
                next_line = lines[j]
                next_stripped = next_line.strip()

                # Track HTML comment open/close (state-machine, multi-line tolerant)
                if not body_in_comment and '<!--' in next_stripped:
                    body_in_comment = True
                    if '-->' in next_stripped[next_stripped.index('<!--') + 4:]:
                        # Single-line comment opens and closes on same line
                        body_in_comment = False
                    j += 1
                    continue
                if body_in_comment:
                    if '-->' in next_stripped:
                        body_in_comment = False
                    j += 1
                    continue

                # Outside comment: treat as before
                if re_mod.match(r'^\s*- \[[ xX]\]', next_line):
                    break
                if next_line.startswith('## ') or next_line.startswith('### '):
                    break
                body_lines.append(next_line)
                j += 1

            while body_lines and not body_lines[-1].strip():
                body_lines.pop()

            body = '\n'.join(body_lines) if body_lines else ''
            steps, expected, if_not = _parse_ac_body(body)

            criteria.append({
                'line_idx': i,
                'checked': checked,
                'text': text,
                'section': current_section,
                'confidence': confidence,
                'body': body,
                'steps': steps,
                'expected': expected,
                'if_not': if_not,
            })

        i += 1

    return criteria


def _toggle_ac_line(file_path, line_idx):
    """Toggle an AC checkbox at a specific line index in the body.

    Returns (success, new_state, error_message).
    """
    content = file_path.read_text()
    fm_match = re_mod.match(r"^---\n.*?\n---\n", content, re_mod.DOTALL)
    if not fm_match:
        return False, False, "Cannot parse file"

    body_start = fm_match.end()
    body = content[body_start:]
    lines = body.split('\n')

    if line_idx < 0 or line_idx >= len(lines):
        return False, False, "Line index out of range"

    line = lines[line_idx]
    m = re_mod.match(r'^(- \[)([ xX])(\] .+)$', line)
    if not m:
        return False, False, "Not an AC checkbox line"

    new_state = m.group(2).strip() == ''  # toggle: unchecked → checked
    lines[line_idx] = m.group(1) + ('x' if new_state else ' ') + m.group(3)

    new_content = content[:body_start] + '\n'.join(lines)
    file_path.write_text(new_content)
    return True, new_state, None


def _build_active_filter_chips(active: dict, view: str) -> list[dict]:
    """arc-007 S4c (T-2016): one removable chip per active filter.

    `active` maps filter-key -> value (only non-empty entries). Each chip's
    `clear_url` is the current filter set minus that one key (plus `view`), so
    clicking × drops just that filter and keeps the rest — and the URL stays
    shareable. Per-chip clear-URL logic lives here (testable), not in Jinja.
    """
    from urllib.parse import urlencode

    labels = {
        "q": "search", "owner": "owner", "horizon": "horizon", "tag": "tag",
        "status": "status", "type": "type", "component": "component", "arc": "arc",
    }
    chips = []
    for key in labels:  # stable, deterministic order
        val = active.get(key)
        if not val:
            continue
        rest = {k: v for k, v in active.items() if k != key and v}
        rest["view"] = view
        chips.append({
            "key": key,
            "label": f"{labels[key]}: {val}",
            "clear_url": "/tasks?" + urlencode(rest),
        })
    return chips


@bp.route("/tasks")
def tasks():
    # T-1233: Use cached task metadata (avoids re-reading 1200+ files per request)
    import copy
    all_tasks = [copy.copy(t) for t in get_all_task_metadata()]
    task_tags = get_episodic_tags()

    for t in all_tasks:
        # Merge frontmatter tags with episodic tags (deduplicated)
        fm_tags = t.get("tags", []) or []
        ep_tags = task_tags.get(t.get("id", ""), [])
        combined = list(dict.fromkeys(
            [str(tg) for tg in fm_tags] + [str(tg) for tg in ep_tags]
        ))
        t["_tags"] = combined

    # Apply filters
    status_filter = request.args.get("status", "")
    type_filter = request.args.get("type", "")
    component_filter = request.args.get("component", "")
    tag_filter = request.args.get("tag", "")
    arc_filter = request.args.get("arc", "").strip()  # T-1661: arc:<id> namespace
    owner_filter = request.args.get("owner", "")
    horizon_filter = request.args.get("horizon", "")
    search_query = request.args.get("q", "").strip()
    sort_by = request.args.get("sort", "id")

    if status_filter:
        all_tasks = [t for t in all_tasks if t.get("status") == status_filter]
    if type_filter:
        all_tasks = [t for t in all_tasks if t.get("workflow_type") == type_filter]
    if component_filter:
        all_tasks = [t for t in all_tasks if component_filter in t.get("_tags", [])]
    if tag_filter:
        all_tasks = [t for t in all_tasks if tag_filter.lower() in [str(tg).lower() for tg in t.get("_tags", [])]]
    if arc_filter:
        # T-1661: arc:<id> namespace.
        # T-1880 (T-NEW-15): delegated to shared helper (lib/arc_membership.py).
        # Membership check unions canonical `arc_id:` frontmatter (T-1849) with
        # legacy `arc:<slug>` tag (pre-T-1850 migration). Future storage-format
        # changes update one place instead of three blueprints.
        all_tasks = [t for t in all_tasks if task_dict_in_arc(t, arc_filter)]
    if owner_filter:
        all_tasks = [t for t in all_tasks if t.get("owner") == owner_filter]
    # T-2160 (arc-009 horizon-axis-hardening, Slice 1): horizon='past' is a
    # derived render-time value computed from file location, per T-2159 Q1=(b).
    # Storage enum stays {now, next, later}; past matches _location == 'completed'.
    # Past is never stored in YAML, only derived at read-time.
    if horizon_filter:
        if horizon_filter == "past":
            all_tasks = [t for t in all_tasks if t.get("_location") == "completed"]
        else:
            all_tasks = [t for t in all_tasks if t.get("horizon") == horizon_filter
                         and t.get("_location") != "completed"]
    if search_query:
        q_lower = search_query.lower()
        all_tasks = [t for t in all_tasks if q_lower in t.get("id", "").lower()
                     or q_lower in t.get("name", "").lower()
                     or q_lower in t.get("description", "").lower()
                     or q_lower in " ".join(str(tg) for tg in t.get("_tags", [])).lower()]

    # Collect unique values for filter dropdowns (before sorting)
    owners = sorted(set(t.get("owner", "") for t in all_tasks if t.get("owner")))
    all_tags = sorted(set(
        tg for t in all_tasks for tg in t.get("_tags", []) if tg
    ))

    if sort_by == "name":
        all_tasks.sort(key=lambda t: t.get("name", ""))
    else:
        all_tasks.sort(key=task_id_sort_key)

    statuses = sorted(set(t.get("status", "") for t in all_tasks if t.get("status")))
    types = sorted(set(t.get("workflow_type", "") for t in all_tasks if t.get("workflow_type")))
    components = [
        "context-fabric", "audit", "git-agent", "healing-loop", "cli",
        "observation", "handover", "resume", "metrics", "task-system",
        "specification", "design",
    ]

    # T-1982: attach BVP_norm per task so kanban cards + list view can render a chip.
    _attach_bvp_to_tasks(all_tasks)

    view = request.args.get("view", "board")
    if view not in ("board", "list"):
        view = "board"

    # arc-007 S4c (T-2016): removable chip per active filter.
    active_filter_chips = _build_active_filter_chips({
        "q": search_query, "owner": owner_filter, "horizon": horizon_filter,
        "tag": tag_filter, "status": status_filter, "type": type_filter,
        "component": component_filter, "arc": arc_filter,
    }, view)

    enums = _load_enums()
    return render_page(
        "tasks.html",
        active_filter_chips=active_filter_chips,
        page_title="Tasks",
        tasks=all_tasks,
        statuses=statuses,
        types=types,
        components=components,
        owners=owners,
        all_tags=all_tags,
        status_filter=status_filter,
        type_filter=type_filter,
        component_filter=component_filter,
        tag_filter=tag_filter,
        arc_filter=arc_filter,
        owner_filter=owner_filter,
        horizon_filter=horizon_filter,
        search_query=search_query,
        sort_by=sort_by,
        view=view,
        enum_types=enums["workflow_types"],
        enum_horizons=enums["horizons"],
        # T-2160 (arc-009 Slice 1): render-only horizon list includes 'past'
        # (derived from .tasks/completed/). Edit endpoints use enum_horizons
        # (storage enum: now/next/later); past has no write-path.
        enum_render_horizons=enums["horizons"] + ["past"],
        enum_owners=enums["owners"],
        enum_statuses=enums["statuses"],
    )


@bp.route("/tasks/<task_id>")
def task_detail(task_id):
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    task_data = None
    task_content = ""
    for location in ["active", "completed"]:
        task_dir = PROJECT_ROOT / ".tasks" / location
        if task_dir.exists():
            for f in task_dir.glob(f"{task_id}-*.md"):
                task_data, task_content = parse_frontmatter(f.read_text())
                if not task_data:
                    task_data = None
                break

    if not task_data:
        abort(404)

    episodic = None
    episodic_file = PROJECT_ROOT / ".context" / "episodic" / f"{task_id}.yaml"
    if episodic_file.exists():
        try:
            with open(episodic_file) as f:
                episodic = yaml.safe_load(f)
        except yaml.YAMLError:
            episodic = None

    status_options = _load_enums()["statuses"]

    # Parse AC checkboxes for interactive rendering
    ac_items = _parse_acceptance_criteria(task_content)

    # Find research artifacts (docs/reports/T-XXX-* and fw-agent-tXXX-*)
    artifacts = []
    reports_dir = PROJECT_ROOT / "docs" / "reports"
    if reports_dir.exists():
        tid_lower = task_id.lower().replace("-", "")
        for f in sorted(reports_dir.glob("*.md")):
            fname = f.name.lower().replace("-", "")
            if tid_lower in fname:
                artifacts.append({"name": f.name, "path": f"docs/reports/{f.name}"})

    # Compute whether "Complete Task" button should show (T-640)
    can_complete = False
    if ac_items and task_data.get("status") != "work-completed":
        all_checked = all(ac["checked"] for ac in ac_items)
        can_complete = all_checked

    # T-1584: Surface Recommendation + Reviewer Verdict cards (cross-surface parity
    # with /review T-1575/T-1583 and /approvals T-1531/T-1569). Same drift class as
    # L-316 — three surfaces consume task body, /tasks was the missed third.
    rec = extract_recommendation(task_content)
    reviewer = extract_reviewer_verdict(task_content)
    rec_complete = rec["verdict"] != "?" and bool(rec["rationale"].strip())
    rec_state = "NO-REC" if not rec["raw"].strip() else rec["verdict"]
    rec_rationale_html = render_markdown_safe(rec["rationale"])
    rec_evidence_html = render_markdown_safe(rec["evidence"])

    # T-1980: per-task BVP block (parity with /bvp scatter + /arcs/<id> table).
    bvp = _task_bvp_data(task_data)
    # T-1982: arc membership + scoped-driver visibility on per-task surface.
    arc_data = _task_arc_data(task_data)
    arc_name = arc_data["arc_name"] if arc_data else None
    arc_scoped_drivers = arc_data["scoped_drivers"] if arc_data else []

    return render_page(
        "task_detail.html",
        page_title=f"Task {task_id}",
        task=task_data,
        task_content=task_content,
        episodic=episodic,
        task_id=task_id,
        status_options=status_options,
        ac_items=ac_items,
        artifacts=artifacts,
        can_complete=can_complete,
        verdict=rec["verdict"],
        rec_state=rec_state,
        rec_complete=rec_complete,
        rec_rationale_html=rec_rationale_html,
        rec_evidence_html=rec_evidence_html,
        reviewer=reviewer,
        bvp=bvp,
        arc_name=arc_name,
        arc_scoped_drivers=arc_scoped_drivers,
    )


@bp.route("/tasks/<task_id>/panel")
def task_panel(task_id):
    """arc-007 S4a/S4b (T-2015, T-2017): fragment for the slide-in side panel.

    Deliberately NOT `task_detail.html`: that template's inline scripts add a
    document-level `htmx:afterRequest` listener (would accumulate per panel load)
    and reload `#content` on desc-save (the board, not the panel).

    S4b (T-2017) makes the meta cells (status/owner/horizon/type) inline-editable
    for *active* tasks via the shared `inline_select` macro + the existing
    `/api/task/<id>/<field>` endpoints — zero new JS, so nothing accumulates.
    Completed tasks render read-only (their status falls outside the active enum).
    Rendered via `render_template` (not `render_page`) so no shell chrome wraps it.
    """
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    task_data = None
    task_content = ""
    task_active = False
    for location in ["active", "completed"]:
        task_dir = PROJECT_ROOT / ".tasks" / location
        if task_dir.exists():
            for f in task_dir.glob(f"{task_id}-*.md"):
                task_data, task_content = parse_frontmatter(f.read_text())
                if not task_data:
                    task_data = None
                else:
                    task_active = location == "active"
                break
        if task_data:
            break

    if not task_data:
        abort(404)

    ac_items = _parse_acceptance_criteria(task_content)

    artifacts = []
    reports_dir = PROJECT_ROOT / "docs" / "reports"
    if reports_dir.exists():
        tid_lower = task_id.lower().replace("-", "")
        for f in sorted(reports_dir.glob("*.md")):
            if tid_lower in f.name.lower().replace("-", ""):
                artifacts.append({"name": f.name, "path": f"docs/reports/{f.name}"})

    rec = extract_recommendation(task_content)
    rec_complete = rec["verdict"] != "?" and bool(rec["rationale"].strip())

    bvp = _task_bvp_data(task_data)
    arc_data = _task_arc_data(task_data)
    arc_name = arc_data["arc_name"] if arc_data else None

    enums = _load_enums()

    return render_template(
        "_task_panel.html",
        task=task_data,
        task_id=task_id,
        editable=task_active,
        ac_items=ac_items,
        artifacts=artifacts,
        verdict=rec["verdict"],
        rec_complete=rec_complete,
        rec_rationale_html=render_markdown_safe(rec["rationale"]),
        rec_evidence_html=render_markdown_safe(rec["evidence"]),
        description_html=render_markdown_safe(task_data.get("description", "") or ""),
        bvp=bvp,
        arc_name=arc_name,
        status_options=enums["statuses"],
        enum_owners=enums["owners"],
        enum_horizons=enums["horizons"],
        enum_types=enums["workflow_types"],
    )


@bp.route("/api/task/create", methods=["POST"])
def create_task():
    name = request.form.get("name", "").strip()
    workflow_type = request.form.get("type", "build").strip()
    owner = request.form.get("owner", "human").strip()
    description = request.form.get("description", "").strip()
    tags = request.form.get("tags", "").strip()

    if not name:
        return '<p style="color: var(--pico-del-color);">Task name is required</p>', 400

    enums = _load_enums()
    if workflow_type not in enums["workflow_types"]:
        return '<p style="color: var(--pico-del-color);">Invalid workflow type</p>', 400

    if owner not in enums["owners"]:
        return '<p style="color: var(--pico-del-color);">Invalid owner</p>', 400

    horizon = request.form.get("horizon", "now").strip()
    if horizon not in enums["horizons"]:
        return '<p style="color: var(--pico-del-color);">Invalid horizon</p>', 400

    cmd = [
        "task", "create",
        "--name", name,
        "--type", workflow_type,
        "--owner", owner,
        "--horizon", horizon,
    ]
    if description:
        cmd.extend(["--description", description])
    if tags:
        cmd.extend(["--tags", tags])

    stdout, stderr, ok = run_fw_command(cmd)
    if ok:
        id_match = re_mod.search(r"(T-\d{3,})", stdout)
        task_id = id_match.group(1) if id_match else "new task"
        return f'<p style="color: var(--pico-ins-color);">Created {task_id}: {name}</p>'
    else:
        # T-2222: widen 200 → 1500 + escape + pre-wrap (T-2219/T-2221 sibling pattern; OBS-049).
        return (
            f'<p style="color: var(--pico-del-color); white-space:pre-wrap;">'
            f'Error: {_escape((stderr or stdout)[:1500])}</p>',
            500,
        )


@bp.route("/api/task/<task_id>/horizon", methods=["POST"])
def update_task_horizon(task_id):
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    horizon = request.form.get("horizon", "")
    enums = _load_enums()
    if horizon not in enums["horizons"]:
        return '<p style="color: var(--pico-del-color);">Invalid horizon</p>', 400

    stdout, stderr, ok = run_fw_command(["task", "update", task_id, "--horizon", horizon])
    if ok:
        return f'<p style="color: var(--pico-ins-color);">Horizon set to {horizon}</p>'
    # T-2222: widen 200 → 1500 + escape + pre-wrap (T-2219/T-2221 sibling pattern; OBS-049).
    return (
        f'<p style="color: var(--pico-del-color); white-space:pre-wrap;">'
        f'Error: {_escape((stderr or stdout)[:1500])}</p>',
        500,
    )


@bp.route("/api/task/<task_id>/owner", methods=["POST"])
def update_task_owner(task_id):
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    owner = request.form.get("owner", "")
    enums = _load_enums()
    if owner not in enums["owners"]:
        return '<p style="color: var(--pico-del-color);">Invalid owner</p>', 400

    stdout, stderr, ok = run_fw_command(["task", "update", task_id, "--owner", owner])
    if ok:
        return f'<p style="color: var(--pico-ins-color);">Owner set to {owner}</p>'
    # T-2222: widen 200 → 1500 + escape + pre-wrap (T-2219/T-2221 sibling pattern; OBS-049).
    return (
        f'<p style="color: var(--pico-del-color); white-space:pre-wrap;">'
        f'Error: {_escape((stderr or stdout)[:1500])}</p>',
        500,
    )


@bp.route("/api/task/<task_id>/type", methods=["POST"])
def update_task_type(task_id):
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    wtype = request.form.get("type", "")
    enums = _load_enums()
    if wtype not in enums["workflow_types"]:
        return '<p style="color: var(--pico-del-color);">Invalid workflow type</p>', 400

    stdout, stderr, ok = run_fw_command(["task", "update", task_id, "--type", wtype])
    if ok:
        return f'<p style="color: var(--pico-ins-color);">Type set to {wtype}</p>'
    # T-2222: widen 200 → 1500 + escape + pre-wrap (T-2219/T-2221 sibling pattern; OBS-049).
    return (
        f'<p style="color: var(--pico-del-color); white-space:pre-wrap;">'
        f'Error: {_escape((stderr or stdout)[:1500])}</p>',
        500,
    )


@bp.route("/api/task/<task_id>/complete", methods=["POST"])
def complete_task(task_id):
    """Complete a task from the browser. T-1568 / F2: replaced legacy --force
    with narrow auth flags. Human clicking from UI authorises sovereignty
    bypass and skips shell-context verification, but Recommendation + RCA
    gates still fire — those represent unwritten artefacts, not authorisation.
    """
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    stdout, stderr, ok = run_fw_command([
        "task", "update", task_id, "--status", "work-completed",
        "--skip-sovereignty", "--skip-verification",
        "--reason", "Completed via Watchtower UI (human action)",
    ])
    if ok:
        return (
            '<p style="color: var(--pico-ins-color);">Task completed.</p>'
            f'<div id="complete-button" hx-swap-oob="innerHTML"></div>'
        )
    # T-2222: widen 200 → 1500 + escape + pre-wrap (T-2219/T-2221 sibling pattern; OBS-049).
    return (
        f'<p style="color: var(--pico-del-color); white-space:pre-wrap;">'
        f'Error: {_escape((stderr or stdout)[:1500])}</p>',
        500,
    )


@bp.route("/api/task/<task_id>/status", methods=["POST"])
def update_task_status(task_id):
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    status = request.form.get("status", "")
    allowed = _load_enums()["statuses"]
    if status not in allowed:
        return '<p style="color: var(--pico-del-color);">Invalid status value</p>', 400

    stdout, stderr, ok = run_fw_command(["task", "update", task_id, "--status", status])
    if ok:
        return f'<p style="color: var(--pico-ins-color);">Status updated to {status}</p>'
    # T-2222: widen 200 → 1500 + escape + pre-wrap (T-2219/T-2221 sibling pattern; OBS-049).
    return (
        f'<p style="color: var(--pico-del-color); white-space:pre-wrap;">'
        f'Error: {_escape((stderr or stdout)[:1500])}</p>',
        500,
    )


# ---------------------------------------------------------------------------
# Inline editing API endpoints (T-181 spike)
# ---------------------------------------------------------------------------

@bp.route("/api/task/<task_id>/name", methods=["POST"])
def update_task_name(task_id):
    """Update task name via regex frontmatter editing."""
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    name = request.form.get("name", "").strip()
    if not name:
        return '<p style="color: var(--pico-del-color);">Name cannot be empty</p>', 400
    if len(name) > 200:
        return '<p style="color: var(--pico-del-color);">Name too long (max 200)</p>', 400

    task_file = _find_task_file(task_id)
    if not task_file:
        abort(404)

    ok, err = _update_frontmatter_field(task_file, "name", name)
    if ok:
        return f'<span class="kanban-card-name" title="{name}">{name}</span>'
    return f'<p style="color: var(--pico-del-color);">Error: {err}</p>', 500


@bp.route("/api/task/<task_id>/toggle-ac", methods=["POST"])
def toggle_ac(task_id):
    """Toggle an acceptance criteria checkbox."""
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    try:
        line_idx = int(request.form.get("line", "-1"))
    except (TypeError, ValueError):
        return '<p style="color: var(--pico-del-color);">Invalid line index</p>', 400

    task_file = _find_task_file(task_id)
    if not task_file:
        abort(404)

    ok, new_state, err = _toggle_ac_line(task_file, line_idx)
    if ok:
        checked_attr = "checked" if new_state else ""
        return f'<input type="checkbox" {checked_attr} onchange="this.form.requestSubmit()" style="margin:0;">'
    return f'<p style="color: var(--pico-del-color);">Error: {err}</p>', 500


@bp.route("/api/task/<task_id>/description", methods=["POST"])
def update_task_description(task_id):
    """Update task description (single-line only for now)."""
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    desc = request.form.get("description", "").strip()
    if not desc:
        return '<p style="color: var(--pico-del-color);">Description cannot be empty</p>', 400

    task_file = _find_task_file(task_id)
    if not task_file:
        abort(404)

    # For multi-line descriptions (using > or |), we need to replace the whole block.
    # For now, only handle the simple single-line case as a spike.
    content = task_file.read_text()
    fm_match = re_mod.match(r"^(---\n)(.*?)(\n---)", content, re_mod.DOTALL)
    if not fm_match:
        return '<p style="color: var(--pico-del-color);">Cannot parse frontmatter</p>', 500

    frontmatter = fm_match.group(2)

    # Replace description block — handles both single-line and multi-line (> folded)
    # Pattern: description: > \n  indented lines... (until next non-indented key)
    # Or: description: "single line"
    desc_pattern = re_mod.compile(
        r'^description:.*?(?=\n[a-z_]+:|\Z)', re_mod.MULTILINE | re_mod.DOTALL
    )
    if not desc_pattern.search(frontmatter):
        return '<p style="color: var(--pico-del-color);">Description field not found</p>', 500

    # Use folded scalar for multi-line, plain for single-line
    if '\n' in desc or len(desc) > 80:
        # Folded scalar style
        indented = '\n'.join('  ' + line for line in desc.split('\n'))
        new_desc = f'description: >\n{indented}'
    else:
        safe = '"' + desc.replace('\\', '\\\\').replace('"', '\\"') + '"'
        new_desc = f'description: {safe}'

    new_frontmatter = desc_pattern.sub(new_desc, frontmatter, count=1)

    # Update last_update
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    ts_pattern = re_mod.compile(r'^(last_update:\s*).*$', re_mod.MULTILINE)
    new_frontmatter = ts_pattern.sub(rf'\g<1>{ts}', new_frontmatter)

    new_content = fm_match.group(1) + new_frontmatter + fm_match.group(3) + content[fm_match.end():]
    task_file.write_text(new_content)
    return f'<p style="color: var(--pico-ins-color);">Description updated</p>'
