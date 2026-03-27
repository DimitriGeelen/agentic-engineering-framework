# T-636 Design: Unified Approvals Page

## Current State Analysis

Three independent human-action surfaces exist in Watchtower:

| Action Type | Current Location | Mechanism | Data Source |
|-------------|-----------------|-----------|-------------|
| Tier 0 approvals | `/approvals` | HTMX POST to `/api/approvals/decide` | `.context/approvals/pending-*.yaml` |
| Human AC checkboxes | `/tasks/<T-XXX>` (task detail) | HTMX POST to `/api/task/<id>/toggle-ac` | `.tasks/active/T-XXX-*.md` body |
| GO/NO-GO decisions | `/inception/<T-XXX>` (inception detail) | Form POST to `/inception/<T-XXX>/decide` | Task body `**Decision**: pending` |

The human must visit three different pages to act. No single view shows "what needs my attention."

---

## Proposed Design: Unified `/approvals` Page

### 1. Summary Header (Counts Bar)

A horizontal stat bar at the top, matching the existing `inception-summary` pattern:

```
+-------+  +--------+  +---------+  +--------+
| 1     |  | 3      |  | 2       |  | 6      |
| Tier 0|  | Human  |  | GO      |  | Total  |
|       |  | ACs    |  | Pending |  | Actions|
+-------+  +--------+  +---------+  +--------+
```

Each stat is clickable to filter the list below to that type only.

### 2. Three Grouped Sections

The page renders three collapsible sections, ordered by urgency:

#### Section A: Tier 0 Approvals (Highest urgency -- agent is blocked)

**Exactly the current `/approvals` UI** for pending items. No changes needed. The existing `approval-card` component with approve/reject buttons, feedback textarea, HTMX submission.

- Badge: amber pulsing dot when pending
- Empty state: "No pending Tier 0 approvals."
- Source: `_load_pending_approvals()` (existing function in `approvals.py`)

#### Section B: Pending GO/NO-GO Decisions (High urgency -- inception stalled)

Cards for active inception tasks where `_extract_decision(body) == "pending"`.

Each card shows:
- Task ID + name (linked to `/inception/<T-XXX>`)
- Problem statement (first 2 lines, truncated)
- Assumption progress: `3/5 validated`
- Research artifact links (from `docs/reports/T-XXX-*`)
- Inline GO / NO-GO / DEFER radio buttons + rationale textarea (reuse existing `decision-form` from `inception_detail.html`)

The form POSTs to the existing `/inception/<T-XXX>/decide` endpoint. On success, HTMX removes the card from the list.

- Empty state: "No pending inception decisions."
- Source: scan active tasks for `workflow_type == "inception"` with decision == "pending"

#### Section C: Tasks with Pending Human ACs (Normal urgency -- not blocking)

Cards for active tasks that have unchecked `### Human` acceptance criteria.

Each card shows:
- Task ID + name (linked to `/tasks/<T-XXX>`)
- Status badge (started-work, work-completed, etc.)
- Human AC checklist with interactive checkboxes (reuse existing `toggle-ac` HTMX pattern)
- Each AC has the confidence badge (`[REVIEW]` / `[RUBBER-STAMP]`) and expandable Steps/Expected/If-not

The checkboxes POST to the existing `/api/task/<id>/toggle-ac` endpoint. When all Human ACs for a task are checked, the card auto-collapses or shows a "done" state.

- Empty state: "No tasks with pending human acceptance criteria."
- Source: scan active tasks, parse body for `### Human` ACs where any are unchecked

### 3. Recently Resolved (Collapsed)

A `<details>` section at the bottom showing the last 20 resolved items across all types:
- Resolved Tier 0 (existing)
- Completed GO decisions (decided inception tasks, last 7 days)
- Tasks where all Human ACs were recently checked (last 7 days)

Each with a type badge (`TIER-0`, `GO/NO-GO`, `HUMAN-AC`) and timestamp.

---

## Backend Changes: `approvals.py`

### New Helper Functions

```python
def _load_pending_human_acs():
    """Scan active tasks for unchecked Human ACs.

    Returns list of dicts:
      {task_id, name, status, owner, horizon, human_acs: [{line_idx, checked, text, confidence, steps, expected, if_not}]}

    Only includes tasks where at least one Human AC is unchecked.
    Reuses _parse_acceptance_criteria() from tasks.py.
    """

def _load_pending_go_decisions():
    """Scan active inception tasks where decision == 'pending'.

    Returns list of dicts:
      {task_id, name, status, owner, problem_excerpt, assumption_counts, artifacts, decision_state}

    Reuses _extract_decision(), _extract_section() from inception.py.
    """
```

### Refactoring Plan

The `_parse_acceptance_criteria()` and `_extract_decision()` / `_extract_section()` functions are currently defined inside `tasks.py` and `inception.py` respectively. For the unified page:

**Option A (recommended):** Import them. Since blueprints are Python modules, `approvals.py` can import directly:
```python
from web.blueprints.tasks import _parse_acceptance_criteria, _find_task_file
from web.blueprints.inception import _extract_decision, _extract_section, _load_assumptions
```

**Option B (future):** Move shared helpers to `web/shared.py`. Cleaner but more churn. Defer to a refactor task.

### Updated Route

```python
@bp.route("/approvals")
def approvals():
    # Tier 0 (existing)
    pending_tier0 = _load_pending_approvals()
    resolved_tier0 = _load_resolved_approvals()

    # GO/NO-GO decisions (new)
    pending_go = _load_pending_go_decisions()

    # Human ACs (new)
    pending_acs = _load_pending_human_acs()

    # Counts
    tier0_count = sum(1 for a in pending_tier0 if a.get("status") == "pending")
    go_count = len(pending_go)
    ac_count = sum(
        sum(1 for ac in t["human_acs"] if not ac["checked"])
        for t in pending_acs
    )
    total = tier0_count + go_count + len(pending_acs)

    return render_page(
        "approvals.html",
        page_title="Approvals",
        pending_tier0=pending_tier0,
        resolved_tier0=resolved_tier0,
        pending_go=pending_go,
        pending_acs=pending_acs,
        tier0_count=tier0_count,
        go_count=go_count,
        ac_count=ac_count,
        ac_task_count=len(pending_acs),
        total_count=total,
    )
```

---

## Template Structure: `approvals.html`

```
<style>...</style>

<!-- Summary counts bar -->
<div class="page-header">
    <h1>Approvals {% if total_count %}<small>({{ total_count }} pending)</small>{% endif %}</h1>
</div>
<div class="approvals-summary">
    <div class="approval-stat" data-filter="tier0">
        <span class="stat-value">{{ tier0_count }}</span>
        <span class="stat-label">Tier 0</span>
    </div>
    <div class="approval-stat" data-filter="go">
        <span class="stat-value">{{ go_count }}</span>
        <span class="stat-label">GO Decisions</span>
    </div>
    <div class="approval-stat" data-filter="ac">
        <span class="stat-value">{{ ac_count }}</span>
        <span class="stat-label">Human ACs</span>
    </div>
    <div class="approval-stat total">
        <span class="stat-value">{{ total_count }}</span>
        <span class="stat-label">Total Actions</span>
    </div>
</div>

<!-- Section A: Tier 0 -->
{% if pending_tier0 %}
<h3 id="tier0">Tier 0 Approvals <small>(agent blocked)</small></h3>
{# Existing approval-card markup, unchanged #}
{% for item in pending_tier0 %}
<div class="approval-card {{ item.status }}">
    ... (existing card from current approvals.html)
</div>
{% endfor %}
{% endif %}

<!-- Section B: GO/NO-GO Decisions -->
{% if pending_go %}
<h3 id="go">Inception Decisions <small>({{ go_count }} pending)</small></h3>
{% for t in pending_go %}
<div class="approval-card go-decision">
    <div style="display:flex; justify-content:space-between; align-items:center;">
        <div>
            <a href="/inception/{{ t.task_id }}"><strong>{{ t.task_id }}</strong></a>:
            {{ t.name }}
        </div>
        <span class="status-badge badge-pending">Pending</span>
    </div>
    {% if t.problem_excerpt %}
    <p class="approval-meta">{{ t.problem_excerpt }}</p>
    {% endif %}
    {% if t.artifacts %}
    <div style="font-size:0.8rem; margin:0.25rem 0;">
        Research: {% for a in t.artifacts %}
        <a href="/file/{{ a.path }}">{{ a.name }}</a>{% if not loop.last %}, {% endif %}
        {% endfor %}
    </div>
    {% endif %}
    <div class="approval-meta">
        Assumptions: {{ t.assumption_counts.validated }}/{{ t.assumption_counts.total }} validated
    </div>
    <form action="/inception/{{ t.task_id }}/decide" method="post" style="margin-top:0.5rem;">
        <input type="hidden" name="_csrf_token" value="{{ csrf_token() }}">
        <div class="decision-buttons">
            <label><input type="radio" name="decision" value="go" required>
                <span class="dec-go">GO</span></label>
            <label><input type="radio" name="decision" value="no-go">
                <span class="dec-nogo">NO-GO</span></label>
            <label><input type="radio" name="decision" value="defer">
                <span class="dec-defer">DEFER</span></label>
        </div>
        <textarea name="rationale" placeholder="Rationale..." required
                  class="approval-feedback"></textarea>
        <button type="submit" style="font-size:0.85rem; padding:0.4rem 1rem;">
            Record Decision
        </button>
    </form>
</div>
{% endfor %}
{% endif %}

<!-- Section C: Human ACs -->
{% if pending_acs %}
<h3 id="ac">Human Acceptance Criteria <small>({{ ac_count }} across {{ ac_task_count }} tasks)</small></h3>
{% for t in pending_acs %}
<div class="approval-card human-ac-group">
    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:0.5rem;">
        <div>
            <a href="/tasks/{{ t.task_id }}"><strong>{{ t.task_id }}</strong></a>:
            {{ t.name }}
        </div>
        <span class="status-badge badge-{{ t.status|replace('-','') }}">{{ t.status }}</span>
    </div>
    <ul class="ac-list">
        {% for ac in t.human_acs %}
        <li>
            <form hx-post="/api/task/{{ t.task_id }}/toggle-ac"
                  hx-target="find input[type=checkbox]" hx-swap="outerHTML"
                  class="inline-reset" style="display:inline;">
                <input type="hidden" name="_csrf_token" value="{{ csrf_token() }}">
                <input type="hidden" name="line" value="{{ ac.line_idx }}">
                <input type="checkbox" {% if ac.checked %}checked{% endif %}
                       onchange="this.form.requestSubmit()" style="margin:0;">
            </form>
            {% if ac.confidence == 'review' %}
            <span class="confidence-badge badge-review">Review</span>
            {% elif ac.confidence == 'rubber-stamp' %}
            <span class="confidence-badge badge-rubber-stamp">Rubber-stamp</span>
            {% endif %}
            <span class="{% if ac.checked %}ac-checked{% endif %}">{{ ac.text }}</span>
        </li>
        {% endfor %}
    </ul>
</div>
{% endfor %}
{% endif %}

<!-- Empty state (all clear) -->
{% if not pending_tier0 and not pending_go and not pending_acs %}
<div class="empty-state">
    <p>Nothing needs your attention.</p>
    <p><small>Tier 0 gates, inception decisions, and human ACs will appear here when pending.</small></p>
</div>
{% endif %}

<!-- Resolved (collapsed) -->
{% if resolved_tier0 %}
<details>
    <summary><h3 style="display:inline;">Recent</h3></summary>
    ... (existing resolved cards, unchanged)
</details>
{% endif %}
```

---

## API Endpoints

No new API endpoints needed. All three action types use existing endpoints:

| Action | Endpoint | Method | Already exists |
|--------|----------|--------|---------------|
| Approve/reject Tier 0 | `/api/approvals/decide` | POST | Yes (`approvals.py`) |
| Toggle Human AC | `/api/task/<id>/toggle-ac` | POST | Yes (`tasks.py`) |
| Record GO decision | `/inception/<id>/decide` | POST | Yes (`inception.py`) |

The GO decision endpoint currently uses a full page redirect. For inline use on the approvals page, we have two options:

**Option A (simple):** Keep the form POST with redirect back to `/approvals`. Minimal change.
**Option B (better UX):** Convert to HTMX: add an `hx-post` endpoint that returns an HTML fragment instead of redirect. This would require a new slim endpoint like `/api/inception/<id>/decide` that mirrors the existing logic but returns a fragment.

Recommendation: Start with Option A. Add Option B as a follow-up if the page-refresh feels clunky.

---

## Performance Considerations

The new page scans all active tasks on every load. This is fine for the current scale (~50 active tasks) but should be noted:

- `_load_pending_human_acs()` reads and parses every `.tasks/active/T-*.md` file
- `_load_pending_go_decisions()` reads every active inception task

**Mitigation (if needed later):** Cache results for 30 seconds. Not needed at current scale.

---

## CSS Additions

Reuse existing classes from `approvals.html` and `task_detail.html`. New additions:

```css
/* Summary stats bar */
.approvals-summary {
    display: flex;
    gap: 1rem;
    margin-bottom: 1.5rem;
    flex-wrap: wrap;
}
.approval-stat {
    padding: 0.75rem 1rem;
    border-radius: 8px;
    background: var(--pico-card-background-color);
    border: 1px solid var(--pico-muted-border-color);
    text-align: center;
    min-width: 80px;
    cursor: pointer;
    transition: border-color 0.15s;
}
.approval-stat:hover {
    border-color: var(--pico-primary);
}
.approval-stat .stat-value {
    font-size: 1.5rem;
    font-weight: 700;
    display: block;
}
.approval-stat .stat-label {
    font-size: 0.7rem;
    text-transform: uppercase;
    color: var(--pico-muted-color);
}
.approval-stat.total {
    border-color: var(--pico-primary);
}

/* GO decision card styling */
.approval-card.go-decision {
    border-color: #1565c0;
    background: #1565c008;
}

/* Human AC group card */
.approval-card.human-ac-group {
    border-color: var(--pico-muted-border-color);
}

/* Reuse from inception_detail.html */
.decision-buttons { ... }
.dec-go, .dec-nogo, .dec-defer { ... }

/* Reuse from task_detail.html */
.confidence-badge { ... }
.badge-review, .badge-rubber-stamp { ... }
.ac-list { ... }
.ac-checked { ... }
```

---

## Navigation

The existing "Approvals" nav item in the "Govern" group already points to `/approvals`. No nav changes needed.

---

## Implementation Steps (Build Task Breakdown)

1. **Add helper functions** to `approvals.py`:
   - `_load_pending_human_acs()` (import `_parse_acceptance_criteria` from tasks.py)
   - `_load_pending_go_decisions()` (import from inception.py)
   - Update `approvals()` route to pass new data

2. **Update `approvals.html`** template:
   - Add summary stats bar
   - Add GO/NO-GO section
   - Add Human AC section
   - Move existing Tier 0 cards into a subsection
   - Add empty state for "all clear"

3. **Verify** existing HTMX endpoints work from the new page context (toggle-ac, decide)

4. **Optional follow-up:** HTMX-ify the GO decision form to avoid full page redirect

---

## Files Changed

| File | Change |
|------|--------|
| `web/blueprints/approvals.py` | Add helpers, update route, import from tasks.py and inception.py |
| `web/templates/approvals.html` | Rewrite with three sections + summary bar |

No new files. No new endpoints (unless Option B for GO decisions is pursued).
