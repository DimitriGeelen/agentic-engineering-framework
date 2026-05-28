# T-2081 — RCA: Complete button transiently reappears on /review/T-XXX

**Inception:** T-2081
**Date:** 2026-05-28
**Status:** Spike complete, awaiting human GO/NO-GO on http://192.168.10.107:3000/inception/T-2081

---

## Symptom

After clicking **Complete Task** on `/review/T-XXX` for a build task:

1. The task DOES correctly transition to `work-completed`.
2. The Complete button initially disappears (POST swap fires).
3. ~1-2 seconds later, the button **reappears** in place.
4. The task is already completed — clicking the reappeared button does no harm, but the user perceives the completion as failed/flaky.

User reported the symptom this session immediately after closing T-2079.

## Root cause

`#ac-container` is on a 5-second htmx poll (`web/templates/review.html:592-594`):

```html
<div id="ac-container"
     hx-get="/review/{{ task_id }}/acs"
     hx-trigger="every 5s">
```

The polling endpoint `web/blueprints/review.py:review_acs_fragment` (L252-298) re-renders `_review_acs.html` from disk. The template (`_review_acs.html:75-106`) branches to the **Complete button** any time `all_checked && total_count > 0 && workflow_type != 'inception'`.

**T-1575 added a `decision_recorded` guard** so an inception's *recorded* decision wouldn't be wiped by the next poll (`review.py:278-284`):

```python
# T-1575: don't re-render the decide form after a decision was recorded.
# The page polls /review/<id>/acs every 5s; without this guard, the success
# message ("Decision recorded — GO") flashes for 5s then gets wiped by the
# poll re-rendering the form.
from web.blueprints.inception import _extract_decision
decision_state = _extract_decision(body)
decision_recorded = decision_state.lower() not in ("pending", "")
```

**The non-inception sibling case was not closed.** A build task that has had Complete pressed (now `work-completed`) has no equivalent `task_completed` flag, so the template still falls through to the Complete-button branch.

### Timeline

| t | Event |
|---|-------|
| 0.0s | User clicks Complete Task button |
| 0.1s | `POST /api/task/<id>/complete` returns `<p>Task completed.</p>` + OOB swap (`tasks.py:1029-1032`) |
| 0.2s | htmx swaps response into `#ac-container` — button gone |
| 0.2-5s | Polling timer (was at random position in its 5s cycle when click happened) fires `GET /review/<id>/acs` |
| ~1-2s mean | Polling response (full re-rendered fragment, **includes** Complete button) lands and overwrites `#ac-container` |
| user perception | "The button came back" |

## Empirical reproduction

```bash
# T-2079 is now in completed/ with status: work-completed
$ curl -sS http://192.168.10.107:3000/review/T-2079/acs > /tmp/.t2079-acs
$ grep -c "Complete Task" /tmp/.t2079-acs
2
$ grep -A3 'class="complete-section"' /tmp/.t2079-acs
<div class="complete-section">
    <form hx-post="/api/task/T-2079/complete" hx-target="#ac-container" hx-swap="innerHTML">
        <button type="submit" class="complete-btn">Complete Task</button>
```

The polling GET endpoint returns the Complete button HTML for a fully-completed task. No race needed to observe — the endpoint is structurally wrong post-completion.

## Why structurally allowed

L-441 sibling-occurrence class. T-1575 fixed the inception leg of the same race. The fix's commit message named the polling race but the patch scoped only to the `decision_recorded` flag. The non-inception leg (`Complete Task` button on build tasks) was logically identical and the same fix shape would have closed it, but no sweep was done at the time.

## Proposed fix (bounded)

~10 LOC across one route + one template:

### 1. `web/blueprints/review.py:review_acs_fragment`

Compute `task_completed` and pass to template:

```python
status = (fm.get("status") or "").strip().lower()
task_completed = status in ("work-completed", "completed")
# ... existing render_template call adds:
#     task_completed=task_completed,
```

### 2. `web/templates/_review_acs.html`

Add a guard branch mirroring `decision_recorded`:

```jinja
{% if decision_recorded %}
  {# existing inception-decide-recorded block #}
{% elif task_completed %}
  {# T-2081: non-inception sibling of T-1575 decision_recorded guard —
     without this, the 5-second poll wipes the POST swap and re-renders
     the Complete button. #}
  <div class="complete-section" id="task-completed-marker">
    <p style="color: var(--pico-ins-color);">
      ✓ Task completed.
      <a href="/review/{{ task_id }}">Reload page</a> for fresh view.
    </p>
  </div>
{% elif all_checked and total_count > 0 %}
  {# existing inception/build branch #}
{% endif %}
```

### 3. Regression net

Playwright test in `tests/playwright/test_review_complete_render_race.py`:

```python
def test_completed_task_poll_does_not_re_render_complete_button(page, base_url):
    """T-2081 guard: GET /review/<id>/acs on a work-completed build task
    must NOT contain the Complete Task button (L-441 sibling of T-1575)."""
    # Use a known completed build task (T-2079 or any work-completed sibling).
    resp = page.request.get(f"{base_url}/review/T-2079/acs")
    assert resp.status == 200
    body = resp.text()
    assert "Complete Task" not in body, (
        "Polling endpoint returns Complete button for a completed task — "
        "the T-2079-class render race. See T-2081 RCA."
    )
```

## Sub-question (resolved inside this fix)

> When a task is partial-complete (`work-completed` + `owner=human` + some Human ACs unchecked), should the Complete button still render so the human can re-finalise?

**No** — and it already doesn't. The `all_checked` precondition means the button only appears when all Human ACs are ticked. Partial-complete with unchecked Human ACs already falls through silently. The `task_completed` short-circuit is safe to apply unconditionally once status is `work-completed`.

## Recommendation

**GO.** Filing the build task to ship the fix when human records the decision.

## Open items for the human

- Confirm fix path is the right shape (mirror T-1575's `decision_recorded` pattern at the template level, computed in the route).
- Confirm message text ("Task completed. Reload page for fresh view.") reads right or want a tighter UX.
