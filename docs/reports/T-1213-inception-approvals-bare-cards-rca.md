# T-1213: RCA — Inception decision cards on /approvals show bare radio buttons

## Problem

On the Watchtower `/approvals` page, inception GO/NO-GO decision cards appear
"bare" — the human sees radio buttons (GO/NO-GO/DEFER) and a rationale textarea,
but **no agent recommendation, no research findings, no context** for making an
informed decision.

This is a recurring issue across ALL projects (framework + every consumer).

## Investigation

### Phase 1: Template analysis

What does the template (`_approvals_content.html`) actually render for inception cards?

### Phase 2: Backend data flow

What data does `approvals.py` → `_load_pending_go_decisions()` pass to the template?

### Phase 3: Real-world testing

What does the actual HTML look like when rendered? Does the data arrive?

### Phase 4: Root cause identification

Why is the recommendation not visible to the human?

## Findings

### Phase 1: Template analysis

`_approvals_content.html` lines 63-123:
- Line 72-74: Problem excerpt shown as `<p class="approval-meta">` (small, muted)
- Line 75-80: Research artifacts as links
- Line 82-85: Assumption counts
- **Line 87-102:** `{% if t.recommendation %}` — CONDITIONAL. When `t.recommendation` is empty, the entire "Agent Recommendation" `<details>` block is HIDDEN
- Line 104-121: Radio buttons + rationale textarea — ALWAYS shown

**Finding:** When recommendation data is missing, the card degrades to JUST radio buttons + textarea. No fallback context is rendered.

### Phase 2: Backend data flow

`approvals.py` → `_load_pending_go_decisions()`:
- Line 103-106: T-1123 filter — skips tasks where `len(rec_section.strip()) < 20`
- Line 127-138: Extracts `rec_display` (full text) and `rec_decision` (GO/NO-GO/DEFER)
- Line 140-161: `rationale_hint` fallback — if no recommendation, falls back to Go/No-Go Criteria
- Returns dict with `recommendation`, `rec_decision`, `rationale_hint`

**Finding:** Backend has a fallback for `rationale_hint` (textarea pre-fill) but NO fallback for the visible recommendation block. The textarea may be pre-filled from Go/No-Go Criteria, but the human doesn't SEE why.

### Phase 3: Real-world testing

Framework Watchtower (:3001): Tested 3 cards (T-1145, T-1151, T-815) — ALL show recommendation with GO/NO-GO badge, 700-1000 char rationale prefill. Framework cards are CORRECT.

Consumer Watchtower: Consumer inception tasks may predate the recommendation requirement. Old tasks have no `## Recommendation` section. The T-1123 filter SHOULD exclude these, but:
- If the consumer's Watchtower was not restarted after `fw upgrade`, it runs old cached code
- If the task has a minimal recommendation stub (>20 chars but no useful content), it passes the filter

### Phase 4: Root cause identification

**RC-1 (UI): No fallback context when recommendation is missing.** The `{% if t.recommendation %}` conditional (line 87) hides the entire recommendation block. When it's hidden, the card shows ONLY:
  - Task name (link)
  - Small muted problem excerpt
  - Radio buttons
  - Textarea (possibly pre-filled from Go/No-Go Criteria, but the human doesn't know WHERE this text came from)

**RC-2 (Process): No structural enforcement for `## Recommendation` before task reaches approvals.** The behavioral rule exists (T-679, CLAUDE.md §Presenting Work for Human Review) but is not mechanically enforced. The agent sometimes writes the recommendation and sometimes doesn't. The `fw inception decide` gate (T-974) requires `## Recommendation`, but the task appears on `/approvals` BEFORE `fw inception decide` runs — the approvals page IS the decision surface.

**RC-3 (Process): Agent inconsistency.** The user confirmed: "often you do do it correct and often you forget." This is a recurring agent behavioral failure, not a one-time bug.

## Proposed Fixes

### Fix 1: UI — Always show context (even without recommendation)

When `t.recommendation` is empty, render a fallback block showing:
- Go/No-Go Criteria section (already extracted but only used for textarea pre-fill)
- Problem statement (already shown but too small/muted)
- Warning: "Agent has not written a recommendation — review task file for findings"

### Fix 2: Process — Structural gate on `fw task review`

When `fw task review` is called on an inception task, check if `## Recommendation` has substantive content (not just template comments). If empty:
- WARN: "No recommendation written yet — the human will see a bare decision card"
- Do NOT block (the agent might be presenting early for discussion), but make the gap visible

### Fix 3: Process — Approvals page inline warning

When rendering a card without recommendation, show a prominent yellow banner:
"Agent recommendation missing. Review the task file or ask the agent to write one before deciding."

This gives the human actionable information instead of a bare form.
