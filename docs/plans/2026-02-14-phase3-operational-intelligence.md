# Phase 3: Operational Intelligence — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `/metrics` dashboard, a first-class `/patterns` browser with escalation ladder visualization, and a system health row to the Watchtower dashboard.

**Architecture:** Two new page routes (metrics, patterns), one navigation update, one dashboard enhancement. Follows existing Flask+htmx+Pico CSS patterns. All data gathered in-process from YAML/git — no subprocess to `metrics.sh`.

**Tech Stack:** Python 3 / Flask / Jinja2 / htmx / Pico CSS / PyYAML

---

### Task 1: Navigation Update

**Files:**
- Modify: `web/shared.py:23-37`

**Step 1: Update NAV_GROUPS**

In `web/shared.py`, replace the `NAV_GROUPS` list (lines 23-37) with:

```python
NAV_GROUPS = [
    ("Work", [
        ("Tasks",    "tasks.tasks",        None),
        ("Timeline", "timeline.timeline",  None),
    ]),
    ("Knowledge", [
        ("Learnings", "discovery.learnings",  None),
        ("Patterns",  "discovery.patterns",   None),
        ("Decisions", "discovery.decisions",  None),
    ]),
    ("Govern", [
        ("Directives", "core.directives",          None),
        ("Gaps",       "discovery.gaps",            None),
        ("Quality",    "quality.quality_gate",      None),
        ("Metrics",    "metrics.project_metrics",   None),
    ]),
]
```

**Step 2: Commit**

```bash
git add web/shared.py
git commit -m "T-058: Update nav groups for Phase 3 (Patterns + Metrics)"
```

Note: The app will error on import until the new blueprints exist. That's expected — Tasks 2 and 3 fix it.

---

### Task 2: Metrics Blueprint + Template

**Files:**
- Create: `web/blueprints/metrics.py`
- Create: `web/templates/metrics.html`
- Modify: `web/app.py:69-81` (add blueprint import + registration)

**Step 1: Create `web/blueprints/metrics.py`**

```python
"""Metrics blueprint — project health dashboard."""

import re as re_mod
import subprocess
from datetime import datetime, timezone

import yaml
from flask import Blueprint

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("metrics", __name__)


def _load_yaml(path):
    """Safely load a YAML file, return empty dict on failure."""
    if not path.exists():
        return {}
    try:
        with open(path) as f:
            data = yaml.safe_load(f)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _task_counts():
    """Count active and completed tasks."""
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    completed_dir = PROJECT_ROOT / ".tasks" / "completed"
    active = len(list(active_dir.glob("T-*.md"))) if active_dir.exists() else 0
    completed = len(list(completed_dir.glob("T-*.md"))) if completed_dir.exists() else 0
    return active, completed


def _traceability():
    """Percentage of recent commits referencing T-XXX."""
    try:
        result = subprocess.run(
            ["git", "log", "--oneline", "-200", "--format=%s"],
            capture_output=True, text=True, timeout=10,
            cwd=str(PROJECT_ROOT),
        )
        if result.returncode != 0 or not result.stdout.strip():
            return 0
        lines = [l for l in result.stdout.strip().split("\n") if l.strip()]
        if not lines:
            return 0
        total = len(lines)
        traced = sum(1 for l in lines if re_mod.search(r"T-\d+", l))
        return int(round(traced / total * 100))
    except Exception:
        return 0


def _quality_scores():
    """Compute description quality % and acceptance criteria coverage %."""
    desc_ok = 0
    ac_ok = 0
    total = 0

    for d in [PROJECT_ROOT / ".tasks" / "active", PROJECT_ROOT / ".tasks" / "completed"]:
        if not d.exists():
            continue
        for f in d.glob("T-*.md"):
            total += 1
            content = f.read_text(errors="replace")
            fm_match = re_mod.match(r"^---\n(.*?)\n---", content, re_mod.DOTALL)
            if fm_match:
                try:
                    fm = yaml.safe_load(fm_match.group(1))
                except yaml.YAMLError:
                    continue
                if isinstance(fm, dict):
                    desc = fm.get("description", "")
                    if isinstance(desc, str) and len(desc.strip()) >= 50:
                        desc_ok += 1
            if re_mod.search(r"(?i)(acceptance.criteria|## AC|## Acceptance)", content):
                ac_ok += 1

    if total == 0:
        return 0, 0
    return int(round(desc_ok / total * 100)), int(round(ac_ok / total * 100))


def _knowledge_counts():
    """Count learnings, patterns, decisions, practices."""
    project_dir = PROJECT_ROOT / ".context" / "project"

    lf = _load_yaml(project_dir / "learnings.yaml")
    learnings = len(lf.get("learnings", []))

    pf = _load_yaml(project_dir / "patterns.yaml")
    patterns = (
        len(pf.get("failure_patterns", []))
        + len(pf.get("success_patterns", []))
        + len(pf.get("antifragile_patterns", []))
        + len(pf.get("workflow_patterns", []))
    )

    df = _load_yaml(project_dir / "decisions.yaml")
    decisions = len(df.get("decisions", []))

    pr = _load_yaml(project_dir / "practices.yaml")
    practices = len(pr.get("practices", []))

    return {"learnings": learnings, "patterns": patterns, "decisions": decisions, "practices": practices}


def _recent_commits():
    """Get last 10 commits as (hash, message, has_task_ref) tuples."""
    try:
        result = subprocess.run(
            ["git", "log", "--oneline", "-10"],
            capture_output=True, text=True, timeout=10,
            cwd=str(PROJECT_ROOT),
        )
        if result.returncode != 0 or not result.stdout.strip():
            return []
        commits = []
        for line in result.stdout.strip().split("\n"):
            if not line.strip():
                continue
            parts = line.split(" ", 1)
            h = parts[0]
            msg = parts[1] if len(parts) > 1 else ""
            has_ref = bool(re_mod.search(r"T-\d+", msg))
            commits.append({"hash": h, "message": msg, "traced": has_ref})
        return commits
    except Exception:
        return []


def _stale_tasks():
    """Find active tasks with issues or no update in >7 days."""
    stale = []
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    if not active_dir.exists():
        return stale

    now = datetime.now(timezone.utc)
    for f in active_dir.glob("T-*.md"):
        content = f.read_text(errors="replace")
        fm_match = re_mod.match(r"^---\n(.*?)\n---", content, re_mod.DOTALL)
        if not fm_match:
            continue
        try:
            fm = yaml.safe_load(fm_match.group(1))
        except yaml.YAMLError:
            continue
        if not isinstance(fm, dict):
            continue

        tid = fm.get("id", f.stem[:5])
        name = fm.get("name", "")[:40]
        status = fm.get("status", "")

        if status == "issues":
            stale.append({"id": tid, "name": name, "reason": "has issues"})
            continue

        last_update = fm.get("last_update")
        if last_update:
            try:
                ts = last_update if isinstance(last_update, datetime) else datetime.fromisoformat(str(last_update).replace("Z", "+00:00"))
                if hasattr(ts, "tzinfo") and ts.tzinfo is None:
                    ts = ts.replace(tzinfo=timezone.utc)
                days = (now - ts).days
                if days > 7:
                    stale.append({"id": tid, "name": name, "reason": f"no update in {days}d"})
            except (ValueError, TypeError):
                pass

    return stale


@bp.route("/metrics")
def project_metrics():
    """Project health dashboard."""
    active, completed = _task_counts()
    traceability = _traceability()
    desc_quality, ac_coverage = _quality_scores()
    knowledge = _knowledge_counts()
    commits = _recent_commits()
    stale = _stale_tasks()

    return render_page(
        "metrics.html",
        page_title="Project Metrics",
        active_count=active,
        completed_count=completed,
        traceability=traceability,
        desc_quality=desc_quality,
        ac_coverage=ac_coverage,
        knowledge=knowledge,
        commits=commits,
        stale_tasks=stale,
    )
```

**Step 2: Create `web/templates/metrics.html`**

```html
<style>
    .metrics-grid {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 1rem;
        margin-bottom: 1rem;
    }
    @media (max-width: 768px) {
        .metrics-grid { grid-template-columns: 1fr 1fr; }
    }
    .metrics-wide {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 1rem;
    }
    @media (max-width: 768px) {
        .metrics-wide { grid-template-columns: 1fr; }
    }
    .metric-card { text-align: center; }
    .metric-card .metric-value {
        font-size: 2rem;
        font-weight: 700;
        line-height: 1.2;
    }
    .metric-card .metric-label {
        font-size: 0.85rem;
        color: var(--pico-muted-color);
        text-transform: uppercase;
        letter-spacing: 0.04em;
    }
    .metric-card .metric-sub {
        font-size: 0.8rem;
        color: var(--pico-muted-color);
        margin-top: 0.25rem;
    }
    .gauge-bar {
        height: 6px;
        border-radius: 3px;
        background: var(--pico-muted-border-color);
        margin-top: 0.5rem;
        overflow: hidden;
    }
    .gauge-fill {
        height: 100%;
        border-radius: 3px;
        transition: width 0.3s;
    }
    .gauge-green { background: #2e7d32; }
    .gauge-yellow { background: #f9a825; }
    .gauge-red { background: #c62828; }
    .commit-list {
        list-style: none;
        padding: 0;
        margin: 0;
    }
    .commit-list li {
        padding: 0.4em 0;
        border-bottom: 1px solid var(--pico-muted-border-color);
        font-size: 0.875rem;
        font-family: monospace;
    }
    .commit-list li:last-child { border-bottom: none; }
    .commit-hash { color: var(--pico-muted-color); }
    .commit-traced { font-weight: 600; }
    .commit-untraced { color: var(--pico-muted-color); }
    .stale-list {
        list-style: none;
        padding: 0;
        margin: 0;
    }
    .stale-list li {
        padding: 0.4em 0;
        border-bottom: 1px solid var(--pico-muted-border-color);
        font-size: 0.875rem;
    }
    .stale-list li:last-child { border-bottom: none; }
    .wt-section-title {
        margin: 0 0 0.75rem 0;
        font-size: 1rem;
        letter-spacing: 0.04em;
        text-transform: uppercase;
        color: var(--pico-muted-color);
    }
</style>

<div class="page-header" style="display: flex; justify-content: space-between; align-items: center;">
    <div>
        <h1>{{ page_title }}</h1>
        <p>Project health at a glance.</p>
    </div>
    <a role="button" class="outline" style="font-size: 0.85rem;"
       hx-get="/metrics" hx-target="#content" hx-swap="innerHTML">Refresh</a>
</div>

<!-- Top row: 4 metric cards -->
<div class="metrics-grid">
    <article class="metric-card">
        <div class="metric-value">{{ active_count }}</div>
        <div class="metric-label">Active Tasks</div>
        <div class="metric-sub">{{ completed_count }} completed</div>
    </article>

    <article class="metric-card">
        <div class="metric-value">{{ traceability }}%</div>
        <div class="metric-label">Traceability</div>
        <div class="gauge-bar">
            <div class="gauge-fill {% if traceability >= 90 %}gauge-green{% elif traceability >= 70 %}gauge-yellow{% else %}gauge-red{% endif %}"
                 style="width: {{ traceability }}%;"></div>
        </div>
    </article>

    <article class="metric-card">
        <div class="metric-value">{{ desc_quality }}%</div>
        <div class="metric-label">Description Quality</div>
        <div class="metric-sub">{{ ac_coverage }}% AC coverage</div>
        <div class="gauge-bar">
            <div class="gauge-fill {% if desc_quality >= 90 %}gauge-green{% elif desc_quality >= 70 %}gauge-yellow{% else %}gauge-red{% endif %}"
                 style="width: {{ desc_quality }}%;"></div>
        </div>
    </article>

    <article class="metric-card">
        <div class="metric-value">{{ knowledge.learnings + knowledge.patterns + knowledge.decisions + knowledge.practices }}</div>
        <div class="metric-label">Knowledge Items</div>
        <div class="metric-sub">{{ knowledge.learnings }}L {{ knowledge.patterns }}P {{ knowledge.decisions }}D {{ knowledge.practices }}Pr</div>
    </article>
</div>

<!-- Bottom row: commits + stale tasks -->
<div class="metrics-wide">
    <article>
        <h4 class="wt-section-title">Recent Commits</h4>
        {% if commits %}
        <ul class="commit-list">
            {% for c in commits %}
            <li>
                <span class="commit-hash">{{ c.hash }}</span>
                <span class="{{ 'commit-traced' if c.traced else 'commit-untraced' }}">{{ c.message }}</span>
            </li>
            {% endfor %}
        </ul>
        {% else %}
        <p style="color: var(--pico-muted-color); font-style: italic;">No commits found.</p>
        {% endif %}
    </article>

    <article>
        <h4 class="wt-section-title">Needs Attention</h4>
        {% if stale_tasks %}
        <ul class="stale-list">
            {% for t in stale_tasks %}
            <li>
                <a href="/tasks/{{ t.id }}" hx-target="#content" hx-swap="innerHTML" hx-push-url="true">
                    <strong>{{ t.id }}</strong>
                </a>
                {{ t.name }} — <small style="color: var(--pico-del-color);">{{ t.reason }}</small>
            </li>
            {% endfor %}
        </ul>
        {% else %}
        <p style="color: var(--pico-muted-color); font-style: italic;">All tasks healthy.</p>
        {% endif %}
    </article>
</div>
```

**Step 3: Register blueprint in `web/app.py`**

After line 74 (`from web.blueprints.session import bp as session_bp`), add:

```python
from web.blueprints.metrics import bp as metrics_bp
```

After line 81 (`app.register_blueprint(session_bp)`), add:

```python
app.register_blueprint(metrics_bp)
```

**Step 4: Verify the page loads**

Run: `curl -sf http://localhost:3000/metrics | head -5`
Expected: HTML content (may need server restart first)

**Step 5: Commit**

```bash
git add web/blueprints/metrics.py web/templates/metrics.html web/app.py
git commit -m "T-058: Add metrics dashboard page"
```

---

### Task 3: Patterns Route + Template

**Files:**
- Modify: `web/blueprints/discovery.py` (add route + helper)
- Create: `web/templates/patterns.html`

**Step 1: Add patterns route to `web/blueprints/discovery.py`**

Add at the end of the file (after the `search` route):

```python
@bp.route("/patterns")
def patterns():
    all_patterns = []
    pf = PROJECT_ROOT / ".context" / "project" / "patterns.yaml"
    if pf.exists():
        with open(pf) as f:
            data = yaml.safe_load(f)
        if data:
            for p in data.get("failure_patterns", []):
                p["_type"] = "failure"
                all_patterns.append(p)
            for p in data.get("success_patterns", []):
                p["_type"] = "success"
                all_patterns.append(p)
            for p in data.get("antifragile_patterns", []):
                p["_type"] = "antifragile"
                all_patterns.append(p)
            for p in data.get("workflow_patterns", []):
                p["_type"] = "workflow"
                all_patterns.append(p)

    type_filter = request.args.get("type", "").strip().lower()
    if type_filter and type_filter in ("failure", "success", "antifragile", "workflow"):
        filtered = [p for p in all_patterns if p["_type"] == type_filter]
    else:
        type_filter = ""
        filtered = all_patterns

    type_counts = {}
    for p in all_patterns:
        t = p["_type"]
        type_counts[t] = type_counts.get(t, 0) + 1

    return render_page(
        "patterns.html",
        page_title="Patterns",
        patterns=filtered,
        all_count=len(all_patterns),
        type_filter=type_filter,
        type_counts=type_counts,
    )
```

**Step 2: Create `web/templates/patterns.html`**

```html
<style>
    .pattern-tabs {
        display: flex;
        gap: 0.5rem;
        margin-bottom: 1.5rem;
        flex-wrap: wrap;
    }
    .pattern-tabs a {
        padding: 0.35em 0.85em;
        border-radius: var(--pico-border-radius);
        font-size: 0.875rem;
        text-decoration: none;
        border: 1px solid var(--pico-muted-border-color);
        color: var(--pico-color);
    }
    .pattern-tabs a:hover {
        background: var(--pico-primary-focus);
    }
    .pattern-tabs a.active {
        background: var(--pico-primary);
        color: #fff;
        border-color: var(--pico-primary);
    }
    .pattern-card {
        margin-bottom: 1rem;
        border-left: 4px solid var(--pico-muted-border-color);
    }
    .pattern-card.type-failure  { border-left-color: #c62828; }
    .pattern-card.type-success  { border-left-color: #2e7d32; }
    .pattern-card.type-antifragile { border-left-color: #6a1b9a; }
    .pattern-card.type-workflow { border-left-color: #1565c0; }

    .pattern-badge {
        display: inline-block;
        padding: 0.15em 0.5em;
        border-radius: 3px;
        font-size: 0.75rem;
        font-weight: 700;
        color: #fff;
        margin-right: 0.5rem;
        vertical-align: middle;
    }
    .badge-failure  { background: #c62828; }
    .badge-success  { background: #2e7d32; }
    .badge-antifragile { background: #6a1b9a; }
    .badge-workflow { background: #1565c0; }

    .pattern-title {
        font-weight: 600;
        font-size: 1.05rem;
    }
    .pattern-meta {
        font-size: 0.8rem;
        color: var(--pico-muted-color);
        margin-top: 0.5rem;
    }

    /* Escalation ladder */
    .escalation-ladder {
        display: flex;
        align-items: center;
        gap: 0;
        margin-top: 0.75rem;
        padding: 0.5rem;
        background: var(--pico-card-background-color);
        border-radius: var(--pico-border-radius);
        border: 1px solid var(--pico-muted-border-color);
    }
    .escalation-step {
        display: flex;
        flex-direction: column;
        align-items: center;
        min-width: 3.5rem;
    }
    .escalation-step .step-letter {
        width: 2rem;
        height: 2rem;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        font-weight: 700;
        font-size: 0.85rem;
        border: 2px solid var(--pico-muted-border-color);
        color: var(--pico-muted-color);
        background: transparent;
    }
    .escalation-step.active .step-letter {
        border-color: #6a1b9a;
        background: #6a1b9a;
        color: #fff;
    }
    .escalation-step .step-label {
        font-size: 0.65rem;
        color: var(--pico-muted-color);
        margin-top: 0.2rem;
        text-align: center;
        max-width: 5rem;
    }
    .escalation-connector {
        flex: 1;
        height: 2px;
        background: var(--pico-muted-border-color);
        min-width: 1rem;
    }
    .escalation-connector.active {
        background: #6a1b9a;
    }
</style>

<div class="page-header">
    <h1>{{ page_title }}</h1>
    <p>{{ all_count }} patterns from project experience.</p>
</div>

<!-- Tab bar -->
<div class="pattern-tabs">
    <a href="/patterns"
       class="{{ 'active' if not type_filter else '' }}"
       hx-target="#content" hx-swap="innerHTML" hx-push-url="true">All ({{ all_count }})</a>
    {% for t in ['failure', 'success', 'antifragile', 'workflow'] %}
    {% if type_counts.get(t, 0) > 0 %}
    <a href="/patterns?type={{ t }}"
       class="{{ 'active' if type_filter == t else '' }}"
       hx-target="#content" hx-swap="innerHTML" hx-push-url="true">{{ t | capitalize }} ({{ type_counts[t] }})</a>
    {% endif %}
    {% endfor %}
</div>

<!-- Pattern cards -->
{% if patterns %}
{% for p in patterns %}
<article class="pattern-card type-{{ p._type }}">
    <header style="padding-bottom: 0;">
        <span class="pattern-badge badge-{{ p._type }}">{{ p.id }}</span>
        <span class="pattern-title">{{ p.pattern }}</span>
    </header>

    {% if p.description %}
    <p>{{ p.description }}</p>
    {% endif %}

    {% if p._type == 'failure' and p.mitigation %}
    <p><strong>Mitigation:</strong> {{ p.mitigation }}</p>
    {% elif p._type == 'success' and p.context %}
    <p><strong>Context:</strong> {{ p.context }}</p>
    {% elif p._type == 'workflow' and p.example %}
    <p><strong>Example:</strong> {{ p.example }}</p>
    {% endif %}

    {% if p._type == 'antifragile' %}
        {% if p.capability_gained %}
        <p><strong>Capability gained:</strong> {{ p.capability_gained }}</p>
        {% endif %}

        {% if p.escalation_ladder %}
        <div class="escalation-ladder">
            {% set ladder = p.escalation_ladder | lower %}
            <div class="escalation-step {{ 'active' if 'a ' in ladder or 'a(' in ladder else '' }}">
                <div class="step-letter">A</div>
                <div class="step-label">Don't repeat</div>
            </div>
            <div class="escalation-connector {{ 'active' if 'b ' in ladder or 'b(' in ladder else '' }}"></div>
            <div class="escalation-step {{ 'active' if 'b ' in ladder or 'b(' in ladder else '' }}">
                <div class="step-letter">B</div>
                <div class="step-label">Improve technique</div>
            </div>
            <div class="escalation-connector {{ 'active' if 'c ' in ladder or 'c(' in ladder else '' }}"></div>
            <div class="escalation-step {{ 'active' if 'c ' in ladder or 'c(' in ladder else '' }}">
                <div class="step-letter">C</div>
                <div class="step-label">Improve tooling</div>
            </div>
            <div class="escalation-connector {{ 'active' if 'd ' in ladder or 'd(' in ladder else '' }}"></div>
            <div class="escalation-step {{ 'active' if 'd ' in ladder or 'd(' in ladder else '' }}">
                <div class="step-letter">D</div>
                <div class="step-label">Change ways</div>
            </div>
        </div>
        {% endif %}
    {% endif %}

    <div class="pattern-meta">
        {% if p.learned_from %}
        Learned from: <a href="/tasks/{{ p.learned_from }}" hx-target="#content" hx-swap="innerHTML" hx-push-url="true"><code>{{ p.learned_from }}</code></a>
        {% endif %}
        {% if p.date_learned %} | {{ p.date_learned }}{% endif %}
        {% if p.directive %} | Directive: {{ p.directive }}{% endif %}
    </div>
</article>
{% endfor %}
{% else %}
<p style="color: var(--pico-muted-color); font-style: italic;">No patterns match this filter.</p>
{% endif %}
```

**Step 3: Verify the page loads**

Run: `curl -sf http://localhost:3000/patterns | grep -c "pattern-card"` (after server restart)
Expected: A number >= 1

**Step 4: Commit**

```bash
git add web/blueprints/discovery.py web/templates/patterns.html
git commit -m "T-058: Add patterns page with escalation ladder visualization"
```

---

### Task 4: Remove Patterns from Learnings Page

**Files:**
- Modify: `web/templates/learnings.html:42-136`

**Step 1: Replace the patterns `<details>` block**

In `web/templates/learnings.html`, replace everything from line 42 (`<!-- Patterns section -->`) through line 136 (`{% endif %}` closing the patterns details) with:

```html
<!-- Patterns link (moved to dedicated page) -->
<p style="margin-top: 1.5rem;">
    <a href="/patterns" hx-target="#content" hx-swap="innerHTML" hx-push-url="true">
        View all {{ patterns.failure|length + patterns.success|length + patterns.workflow|length }} patterns &rarr;
    </a>
</p>
```

Also update the header on line 3 to remove patterns from the count:

```html
    <p>{{ learnings|length }} learnings and {{ practices|length }} practices from project experience.</p>
```

**Step 2: Update discovery.py learnings route**

The `learnings()` route in `discovery.py` still loads `patterns_grouped` (line 76-84). We still need it for the pattern count in the link. No code change needed — the template uses the same variable for the count.

**Step 3: Commit**

```bash
git add web/templates/learnings.html
git commit -m "T-058: Move patterns out of learnings page to dedicated /patterns"
```

---

### Task 5: Dashboard System Health Row

**Files:**
- Modify: `web/blueprints/core.py` (add `_get_pattern_summary` helper, pass data to index)
- Modify: `web/templates/index.html` (add System Health section)

**Step 1: Add pattern summary helper to `web/blueprints/core.py`**

After the `_get_inception_checklist()` function (after line 175), add:

```python
def _get_pattern_summary():
    """Count patterns by type for the dashboard."""
    pf = _load_yaml(PROJECT_ROOT / ".context" / "project" / "patterns.yaml")
    return {
        "failure": len(pf.get("failure_patterns", [])),
        "success": len(pf.get("success_patterns", [])),
        "antifragile": len(pf.get("antifragile_patterns", [])),
        "workflow": len(pf.get("workflow_patterns", [])),
    }
```

**Step 2: Pass pattern_summary to the index route**

In the `index()` function's `return render_page(...)` call (around line 206), add:

```python
        pattern_summary=_get_pattern_summary(),
```

**Step 3: Add System Health row to `web/templates/index.html`**

After the Project Pulse `</article>` (line 323), before `{% endif %}` (line 325), add:

```html
{# --- System Health ----------------------------------------- #}
<article>
    <h4 class="wt-section-title">System Health</h4>
    <ul class="wt-pulse">
        <li>
            Traceability:
            <span class="wt-pulse-value" style="color: {% if traceability >= 90 %}#2e7d32{% elif traceability >= 70 %}#f9a825{% else %}#c62828{% endif %}">{{ traceability }}%</span>
        </li>
        <li>
            Knowledge:
            <a href="{{ url_for('discovery.learnings') }}" hx-target="#content" hx-swap="innerHTML" hx-push-url="true">
                <span class="wt-pulse-value">{{ knowledge_counts.learnings }}</span>L
            </a>,
            <a href="{{ url_for('discovery.patterns') }}" hx-target="#content" hx-swap="innerHTML" hx-push-url="true">
                <span class="wt-pulse-value">{{ pattern_summary.failure + pattern_summary.success + pattern_summary.antifragile + pattern_summary.workflow }}</span>P
            </a>,
            <a href="{{ url_for('discovery.decisions') }}" hx-target="#content" hx-swap="innerHTML" hx-push-url="true">
                <span class="wt-pulse-value">{{ knowledge_counts.decisions }}</span>D
            </a>
        </li>
        <li>
            Patterns:
            {% if pattern_summary.failure > 0 %}
            <span class="wt-pulse-value" style="color: #c62828;">{{ pattern_summary.failure }}</span> failure,
            {% endif %}
            <span class="wt-pulse-value" style="color: #2e7d32;">{{ pattern_summary.success }}</span> success,
            <span class="wt-pulse-value" style="color: #6a1b9a;">{{ pattern_summary.antifragile }}</span> antifragile
        </li>
        <li>
            <a href="{{ url_for('metrics.project_metrics') }}"
               hx-target="#content" hx-swap="innerHTML" hx-push-url="true"
               style="font-size: 0.85rem;">Full metrics &rarr;</a>
        </li>
    </ul>
</article>
```

**Step 4: Commit**

```bash
git add web/blueprints/core.py web/templates/index.html
git commit -m "T-058: Add system health row to dashboard"
```

---

### Task 6: Tests

**Files:**
- Modify: `web/test_app.py`

**Step 1: Add `/metrics` and `/patterns` to route tests**

In `TestRoutes`, update the `@pytest.mark.parametrize` list (line 50-64) to include:

```python
            "/metrics",
            "/patterns",
            "/patterns?type=failure",
```

In `TestHtmxPartials`, update the fragment test list (line 86) to include:

```python
        ["/", "/tasks", "/timeline", "/decisions", "/learnings", "/gaps", "/quality", "/metrics", "/patterns"],
```

**Step 2: Add Phase 3 test class**

At the end of `test_app.py`, add:

```python
# =========================================================================
# Phase 3 — Operational Intelligence
# =========================================================================


class TestMetrics:
    """Metrics page shows project health data."""

    def test_metrics_has_task_counts(self, client):
        resp = client.get("/metrics")
        html = resp.data.decode()
        assert "Active Tasks" in html
        assert "completed" in html.lower()

    def test_metrics_has_traceability(self, client):
        resp = client.get("/metrics")
        html = resp.data.decode()
        assert "Traceability" in html
        assert "gauge-" in html

    def test_metrics_has_knowledge_counts(self, client):
        resp = client.get("/metrics")
        html = resp.data.decode()
        assert "Knowledge Items" in html

    def test_metrics_has_recent_commits(self, client):
        resp = client.get("/metrics")
        html = resp.data.decode()
        assert "Recent Commits" in html

    def test_metrics_has_refresh_button(self, client):
        resp = client.get("/metrics")
        html = resp.data.decode()
        assert "Refresh" in html


class TestPatterns:
    """Patterns page shows categorized patterns with filtering."""

    def test_patterns_has_all_types(self, client):
        resp = client.get("/patterns")
        html = resp.data.decode()
        assert "FP-" in html or "SP-" in html or "AF-" in html or "WP-" in html

    def test_patterns_filter_by_type(self, client):
        resp = client.get("/patterns?type=failure")
        html = resp.data.decode()
        assert "FP-" in html
        assert "SP-" not in html

    def test_patterns_antifragile_has_escalation(self, client):
        resp = client.get("/patterns?type=antifragile")
        html = resp.data.decode()
        assert "escalation-ladder" in html
        assert "step-letter" in html

    def test_patterns_has_tab_bar(self, client):
        resp = client.get("/patterns")
        html = resp.data.decode()
        assert "pattern-tabs" in html
        assert "Failure" in html

    def test_patterns_cards_link_to_tasks(self, client):
        resp = client.get("/patterns")
        html = resp.data.decode()
        assert "/tasks/T-" in html


class TestPhase3Integration:
    """Cross-cutting Phase 3 integration checks."""

    def test_learnings_no_longer_has_pattern_tables(self, client):
        resp = client.get("/learnings")
        html = resp.data.decode()
        assert "Failure Patterns" not in html
        assert "pattern" in html.lower()  # but has the link

    def test_learnings_has_patterns_link(self, client):
        resp = client.get("/learnings")
        html = resp.data.decode()
        assert "/patterns" in html

    def test_nav_has_patterns(self, client):
        resp = client.get("/")
        html = resp.data.decode()
        assert "Patterns" in html

    def test_nav_has_metrics(self, client):
        resp = client.get("/")
        html = resp.data.decode()
        assert "Metrics" in html

    def test_dashboard_has_system_health(self, client):
        resp = client.get("/")
        html = resp.data.decode()
        assert "System Health" in html
```

**Step 3: Run all tests**

Run: `cd /opt/999-Agentic-Engineering-Framework && python -m pytest web/test_app.py -v`
Expected: All tests pass (existing + new)

**Step 4: Commit**

```bash
git add web/test_app.py
git commit -m "T-058: Add Phase 3 tests (metrics, patterns, integration)"
```

---

### Task 7: Restart Server + Smoke Test

**Step 1: Restart the web server**

```bash
# Find and kill the existing server
pkill -f "python.*web/app.py" || true
sleep 1
# Start fresh
cd /opt/999-Agentic-Engineering-Framework && python -m web.app --port 3000 &
sleep 2
```

**Step 2: Smoke test all new routes**

```bash
curl -sf http://localhost:3000/metrics | grep -q "Project Metrics" && echo "metrics: OK" || echo "metrics: FAIL"
curl -sf http://localhost:3000/patterns | grep -q "pattern-card" && echo "patterns: OK" || echo "patterns: FAIL"
curl -sf http://localhost:3000/patterns?type=failure | grep -q "FP-" && echo "patterns filter: OK" || echo "patterns filter: FAIL"
curl -sf http://localhost:3000/ | grep -q "System Health" && echo "dashboard: OK" || echo "dashboard: FAIL"
curl -sf http://localhost:3000/learnings | grep -q "Failure Patterns" && echo "learnings: STILL HAS PATTERNS (FAIL)" || echo "learnings: OK"
```

Expected: All OK

**Step 3: Final commit if any fixes needed**

---

## Execution Order

```
Task 1 (nav update) → Task 2 (metrics blueprint) → Task 3 (patterns route)
    → Task 4 (learnings cleanup) → Task 5 (dashboard health) → Task 6 (tests)
    → Task 7 (restart + smoke)
```

Tasks 2 and 3 can run in parallel after Task 1. Tasks 4 and 5 can run in parallel after Task 3. Task 6 depends on all prior tasks. Task 7 is final.
