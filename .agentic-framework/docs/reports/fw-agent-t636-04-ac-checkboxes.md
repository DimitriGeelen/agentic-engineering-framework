# T-636 Design: Human AC Approval via Watchtower Checkboxes

## Current State (Already Implemented)

**This feature already exists.** The codebase already supports interactive Human AC checkboxes in Watchtower. Here is a complete inventory of what is in place:

### Backend (`web/blueprints/tasks.py`)

1. **`_parse_acceptance_criteria(body_text)`** (lines 116-217): Parses the markdown body, tracks `### Agent` / `### Human` section context, and returns a list of dicts with `line_idx`, `checked`, `text`, `section` (agent/human/general), `confidence` (review/rubber-stamp), `body`, `steps`, `expected`, `if_not`.

2. **`_toggle_ac_line(file_path, line_idx)`** (lines 220-247): Toggles a checkbox at a specific body-line index. Reads file, splits body into lines, regex-matches `- [ ]` or `- [x]` at that index, flips the state, writes back. Returns `(success, new_state, error_message)`.

3. **`POST /api/task/<task_id>/toggle-ac`** (lines 556-575): Accepts `line` (integer body-line index) as form data. Calls `_toggle_ac_line`. Returns a replacement `<input type="checkbox">` element for htmx swap.

4. **No section restriction**: The `toggle_ac` endpoint does NOT check whether the toggled line is in the Human section, Agent section, or general section. **Any AC can be toggled from the browser** regardless of section.

### Frontend (`web/templates/task_detail.html`)

1. **Agent ACs** (lines 237-251): Rendered as `<ul class="ac-list">` with htmx forms. Each checkbox POSTs to `/api/task/{task_id}/toggle-ac` with the `line` index. Toggleable from the browser.

2. **Human ACs** (lines 254-301): Rendered as expandable `<details class="human-ac-card">` cards. Each card has:
   - A checkbox in the `<summary>` with htmx POST (same toggle-ac endpoint)
   - Confidence badge (REVIEW / RUBBER-STAMP)
   - Expandable body with Steps, Expected, If-not sections
   - Cards auto-open when unchecked, collapse when checked

3. **General ACs** (lines 304-321): Flat checkbox list, same toggle-ac endpoint.

4. **Progress counter** (line 229): Shows `(checked/total)` for all ACs combined.

### Identification Strategy

- **Line index**: ACs are identified by their `line_idx` (0-based index into the body text after frontmatter). This is computed during parse and passed as a hidden form field.
- **Trade-off**: Line-based identification is fragile if the file is edited between page load and checkbox click (line shifts would toggle the wrong AC). This is acceptable because: (a) simultaneous editing is rare for human-owned tasks, (b) the toggle function validates the target line matches `- [ ]`/`- [x]` regex before modifying, so a shifted index hitting non-AC content returns an error rather than corrupting data.

### Security Considerations

- **CSRF**: All forms include `_csrf_token` hidden field.
- **No section guard**: The backend does NOT enforce that only Human ACs are toggleable. Both Agent and Human ACs can be toggled from the browser. This is by design — the framework convention is that agents should not check Human ACs (enforced by agent behavioral rules in CLAUDE.md), but the UI does not prevent a human from toggling Agent ACs (which is harmless since the human has sovereignty).

---

## What Is Missing (Design for Remaining Gaps)

### Gap 1: "Complete Task" Button When All Human ACs Are Checked

**Current**: After checking all Human ACs, the user must manually change the status dropdown to `work-completed` or run `fw task update` in the terminal.

**Design**: Add a conditional "Complete Task" button that appears when:
- All Human ACs are checked (or no Human ACs exist and all general ACs are checked)
- Task status is NOT already `work-completed`
- Task is in `.tasks/active/`

**Implementation**:

```python
# In task_detail route, compute readiness
all_human_checked = all(ac['checked'] for ac in ac_items if ac['section'] == 'human')
all_agent_checked = all(ac['checked'] for ac in ac_items if ac['section'] == 'agent')
all_general_checked = all(ac['checked'] for ac in ac_items if ac['section'] == 'general')
can_complete = (all_human_checked and all_agent_checked and all_general_checked
                and task_data.get('status') != 'work-completed')
```

```html
{% if can_complete %}
<form hx-post="/api/task/{{ task_id }}/status" hx-target="#complete-result">
    <input type="hidden" name="_csrf_token" value="{{ csrf_token() }}">
    <input type="hidden" name="status" value="work-completed">
    <button type="submit" class="primary">Complete Task</button>
</form>
<span id="complete-result"></span>
{% endif %}
```

**Problem**: After toggling a checkbox via htmx, only the checkbox element is swapped (outerHTML). The page does not re-evaluate whether the Complete button should appear. Two options:

- **Option A (htmx OOB swap)**: The toggle-ac response includes an out-of-band swap for the complete button container. The backend must re-parse the file after toggle to determine AC state. More complex but seamless.
- **Option B (full section reload)**: After toggle, htmx reloads the entire AC section (or the full page). Simpler but causes visual flash.
- **Option C (JS client-side)**: After toggle succeeds, JS counts checked checkboxes on the page and shows/hides the button. Fragile but zero server round-trips.

**Recommendation**: Option A (OOB swap). The toggle-ac endpoint already writes the file, so re-parsing is cheap. Return:
```html
<input type="checkbox" checked onchange="this.form.requestSubmit()" style="margin:0;">
<div id="complete-button-slot" hx-swap-oob="innerHTML">
    <!-- Complete button HTML if all checked, empty if not -->
</div>
```

### Gap 2: Post-Completion Handling

The existing `POST /api/task/<task_id>/status` endpoint calls `run_fw_command(["task", "update", task_id, "--status", status])` which invokes `update-task.sh`. This runs:

1. Human sovereignty gate (R-033) — will **block** if `owner: human` and `--force` not passed
2. AC gate (P-010) — checks agent ACs
3. Verification gate (P-011) — runs shell commands from `## Verification`
4. Move to `completed/`, set `date_finished`, generate episodic

**Problem**: The sovereignty gate blocks agent-initiated completion of human-owned tasks. When the human clicks "Complete" in the browser, the request comes from `run_fw_command` (not from the human's terminal). The `update-task.sh` script sees no `--force` flag and blocks.

**Design options**:
- **Option A**: The Watchtower "Complete Task" button passes `--force` since the human is explicitly clicking it. This is safe because the human IS the sovereign actor.
- **Option B**: Add a `--source watchtower` flag to `update-task.sh` that the sovereignty gate recognizes as human-initiated.
- **Option C**: The status API endpoint already exists and works — it calls `fw task update` which does run the gates. For human-owned tasks, the "Complete" button should pass `--force`.

**Recommendation**: Option A. The button is only visible to the human in the browser. Add `--force` to the command args when source is the Complete button. Log the completion source as "watchtower-ui" in the task's Updates section.

### Gap 3: Visual Feedback After Toggle

**Current**: The checkbox swaps but the surrounding text (strike-through class, progress counter) does not update.

**Design**: Extend the toggle-ac response to use htmx OOB swaps for:
1. The AC text span (add/remove `ac-checked` class)
2. The progress counter `(checked/total)` in the `<summary>` tag
3. The section sub-counter (e.g., "Human (2/3)")

This requires the toggle endpoint to re-parse the full AC state after the write and return multiple OOB swap fragments.

### Gap 4: Agent AC Protection (Optional)

**Current**: Both Agent and Human ACs are toggleable from the browser.

**Assessment**: This is NOT a real gap. The framework's authority model gives the human sovereignty over everything. A human toggling an Agent AC in the browser is equivalent to editing the file directly — permissible. No restriction needed.

If desired later, add a `data-section` attribute to agent AC forms and disable them via CSS (`pointer-events: none; opacity: 0.6`) with a tooltip "Agent ACs are verified by the agent."

---

## Summary of Recommended Build Work

| Item | Effort | Priority |
|------|--------|----------|
| "Complete Task" button (Gap 1) | Small | High — key UX improvement |
| Post-completion --force handling (Gap 2) | Small | High — required for Gap 1 |
| OOB visual feedback (Gap 3) | Medium | Medium — polish |
| Agent AC visual lock (Gap 4) | Trivial | Low — optional |

## Files to Modify

- `web/blueprints/tasks.py`: Extend `toggle_ac()` response with OOB swaps; extend `task_detail()` to compute `can_complete`; potentially add a dedicated `/api/task/<id>/complete` endpoint
- `web/templates/task_detail.html`: Add Complete button slot, OOB target IDs, visual feedback wiring
- No changes needed to `update-task.sh` (use existing `--force` flag)
