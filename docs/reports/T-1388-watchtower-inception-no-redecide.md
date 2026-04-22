# T-1388: Watchtower inception page — no revoke/re-decide affordance

**Status:** INCEPTION captured 2026-04-22. Awaiting GO/NO-GO.
**Priority:** High (blocks legitimate workflow; agents silently edit task files to work around it).

## Symptom

Once `fw inception decide T-XXX go|no-go|defer` records a decision on a task,
Watchtower's `/inception/T-XXX` page renders the Decision Record as a read-only
banner. The POST form that originally accepted the decision disappears. A human
who realises the decision was wrong, based on stale evidence, or has been
superseded by new scoping has **no UI path** to change it.

Observed today: during G-056 work the agent wanted to record a corrected
decision on T-1270 after fresh research; the only path was to manually strip
the `## Decisions` block out of the task markdown so the form would re-render.

## Root cause (code evidence)

`web/templates/inception_detail.html` lines 306–326:

```jinja
{% if sections.decision and dec != 'pending' %}
    <article class="section-card">
        <header>Decision Record</header>
        <div class="section-content">{{ sections.decision }}</div>
    </article>
{% elif dec == 'pending' and task._location == 'active' %}
    <article class="section-card">
        <header>Record Decision</header>
        <form action="/inception/{{ task_id }}/decide" method="post">
            ...
        </form>
    </article>
{% endif %}
```

The two branches are mutually exclusive. No third branch offers "revoke" or
"re-decide". Backend route `web/blueprints/inception.py:393` (`record_decision`)
has no counterpart for clearing or overwriting a decision.

## Why this is a framework gap (not just missing UI)

1. **Sovereignty is one-way.** The framework positions the human as sovereign
   ("can override anything"), but once a decision is recorded the UI removes the
   override path. The only remaining affordance is `sed`-editing the task file,
   which is unsafe (no audit trail, breaks the placeholder detector, risks
   clobbering other sections).

2. **Decision-as-output-not-snapshot mismatch.** The framework models decisions
   as immutable artifacts (`## Decision` block + `Updates` entry). But real
   inceptions iterate: "GO" may flip to "NO-GO" after a failed spike, or "DEFER"
   may upgrade to "GO" after new evidence. The data model supports this
   implicitly (multiple decision entries in `## Updates`) but the UI model does
   not expose it.

3. **Agent workaround is worse than the bug.** Today if an agent needs to
   re-decide, the only path is to hand-edit the task file. That bypasses the
   inception-decide pipeline (which captures rationale, timestamp, propagates
   to Updates log) and breaks audit.

## Assumptions to test

- **A1:** Humans actually want to re-decide occasionally (vs. create a new
  follow-up task). Worth quantifying: how many current active+completed
  inceptions have multiple decision entries in `## Updates`? If zero, this
  pattern is theoretical.

- **A2:** The current one-shot form is a deliberate constraint to prevent
  accidental clicks, not an oversight. (Commit archaeology on
  inception_detail.html will tell us.)

- **A3:** "Revoke" and "re-decide" are the same UX or different. A revoke
  returns to pending; a re-decide overwrites with new values. The user story
  is probably "re-decide with new rationale".

- **A4:** The backend `record_decision` route already writes idempotently —
  if we just expose the form unconditionally (or behind a "re-open" toggle)
  the plumbing already works.

## Exploration plan

- **Spike A — Data gathering:** Count active+completed inceptions with
  multiple decision entries in `## Updates`. Quantifies A1.
- **Spike B — Commit archaeology:** Why does the template lock after decision?
  `git log -p web/templates/inception_detail.html` for the decision block.
  Tests A2.
- **Spike C — Backend idempotency:** Confirm `lib/inception.sh do_inception_decide`
  can overwrite an existing decision cleanly (writes new `## Decision` block,
  appends Update entry). Tests A4.
- **Spike D — UX sketch:** Two designs:
  - **D1 (minimal):** "Re-open decision" button on the Decision Record card →
    clears `## Decisions`, re-renders form. One click, high blast radius.
  - **D2 (safer):** "Record new decision" form stays visible below the Record,
    requires typing the previous decision as confirmation. Two-step, explicit.

## Scope fence

**IN:**
- UI affordance on `/inception/T-XXX` to record a superseding decision
- Backend route(s) to accept revoke or re-decide with audit entry
- Invariant test: re-decided tasks have both decision entries in Updates log

**OUT:**
- Rewriting inception data model (decision stays single-canonical in `## Decision`,
  history stays in `## Updates`)
- "Decision history" visualisation (follow-up if justified)
- Authorization / multi-user review (single-human mode)

## Dialogue log

### 2026-04-22 — User diagnosis → task creation

- **User:** "Root cause for the filed learning: Watchtower's /inception/T-XXX
  page is one-shot: renders decision form only when no decision exists. There's
  no 'revoke' or 'redecide' affordance in the UI. If the first decision turns
  out wrong or gets superseded by new scoping, the only path is to clear the
  ## Decisions section in the task file so the form re-renders. — inception
  bugfix high priority"
- **Agent (playback):** Verified via `web/templates/inception_detail.html:306-326`
  and `web/blueprints/inception.py:393` — form element is gated on `dec == 'pending'`,
  no revoke route exists. Registered G-057 in concerns.yaml. Created T-1388
  inception with full Problem Statement, Assumptions, Exploration Plan,
  Scope Fence.
