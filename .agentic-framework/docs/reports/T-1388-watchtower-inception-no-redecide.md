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

### 2026-04-22 — User: "process is disjointed, simulate end-to-end"

> "well the process has a lot of friction and seems to be disjointed, believe
> we need to simulate in a termlink session, because honestly believe its
> effectively broken"

Agent ran end-to-end simulation via Playwright against live Watchtower
(`http://192.168.10.107:3000`) on **T-1388 (pending)** and **T-1284 (decided GO)**,
plus backend probing.

### Simulation findings — four stacked frictions

**F1 — One-shot lock (the captured gap)**

Evidence: `docs/screenshots/T-1388-evidence-2-decided-locked.png`. On T-1284 the
entire "Record Decision" card is absent. Only Decision Record (read-only) and
Update Log appear.

**Dead-end map** (all paths tested):
| Path                     | Result                                           |
|--------------------------|--------------------------------------------------|
| UI form (pending)        | ✅ works (T-1388 evidence-1)                     |
| UI form (decided)        | ❌ form element missing from DOM                 |
| Direct POST `/decide`    | ❌ `HTTP 403` (CSRF token required)              |
| `fw inception decide` from Claude Code | ❌ Tier 0 block ("requires human approval") |
| Manual `sed` on task file| ⚠️ Works but bypasses audit (Updates log + timestamp) |

Only escape hatch: `fw tier0 approve` + human-run `fw inception decide`. Not UX.

**F2 — Assumption registration is a separate ritual, uncounted**

Evidence: `docs/screenshots/T-1388-evidence-1-pending-form.png` header shows
`ASSUMPTIONS 0` even though the task body contains A1-A4. The `fw assumption
add` command is a separate CLI path the agent forgot/was-gated from running.
Watchtower's counter reflects what the CLI registered, not what the task body
declares.

Design smell: two sources of truth for assumptions (task body prose vs.
`assumptions.yaml`). The page prompts "Add Assumption" even when the task
body already lists them.

**F3 — Recommendation + Decision Record render near-duplicate content**

Evidence: T-1284 page shows "Agent Recommendation" card and "Decision Record"
card back-to-back. Both contain the same rationale + evidence bullets. The
page ends up 2x longer than necessary and the human must read the same text
twice to confirm they match.

Root cause: `## Recommendation` and `## Decision` are both extracted and
rendered separately, but they typically contain the same payload once the
decision is recorded (`fw inception decide` copies recommendation into
decision block).

**F4 — "Rationale: Recommendation: GO" double-prefix in Decision Record**

Evidence: T-1284 Decision Record shows literal text:
> "Rationale: Recommendation: GO\n\nRationale: The current..."

Text extraction passes "Recommendation: GO" through as the rationale prefix
because `fw inception decide` embeds the whole Recommendation block instead
of extracting just the rationale body. Minor cosmetic, but signals the
extraction pipeline is string-concat, not structured.

### Revised assumptions

- **A1 (confirmed):** The re-decide path is a real need — evidence from
  T-1270 session (manual `sed` fallback). Quantitative A1 test still open.
- **A2 (unknown):** Still want commit archaeology to know if one-shot was
  deliberate or default.
- **A3 (keep):** Revoke vs re-decide UX is distinct.
- **A4 (new):** The re-decide bug is the **headline symptom** but not the
  whole story — the decision page has 3 other frictions (F2-F4) that
  compound the "disjointed" feel. A fix-narrowly-to-F1 approach will leave
  the page feeling broken.

### Revised scope options (user selected S-broad)

- ~~S-narrow:~~ Fix F1 only
- ~~S-medium:~~ F1 + F3 + F4
- **S-broad (selected):** Inception-decision-page UX overhaul covering F1-F5
  plus any frictions surfaced during build.

### 2026-04-22 — Phase 2 spikes (after S-broad selection)

#### Spike A — A1 quantified (re-decide is NOT theoretical)

Scanned all 1200+ task files for `^### .*inception-decision` entries in
`## Updates`. **Result: 60 inceptions have multiple recorded decisions.**

| Task   | Decisions | Context |
|--------|-----------|---------|
| T-837  | 9 | Context-window detection — extensive pivots |
| T-435  | 5 | Claude Code settings documentation |
| T-485  | 5 | Watchtower smoke test suite |
| T-489  | 5 | End-to-end onboarding test |
| T-272  | 4 | Ring20 production deploy |
| T-1346 | 4 | Global /root install isolation |

A1 **strongly confirmed.** The data model already supports multi-decision
(Updates log accumulates entries). **The UI one-shot fights the data model**
— users must `sed`-edit task files to do something the backend cheerfully
supports.

#### Spike B — A2 via git archaeology

`git log --oneline -20 web/templates/inception_detail.html` shows:
- `0d145d5f` T-085 — Built 3-page inception UI (initial)
- `50b82bb6` T-089 — Added write actions (assumption, validate, record decision)
- `1c459e83` T-090 — Markdown rendering
- `fdc01d40` T-1177 — Dynamic section parsing

No commit adds a "deliberate one-shot constraint." The `{% if sections.decision
and dec != 'pending' %}` / `{% elif %}` guard is incidental, not a safety
measure. A2 lean: **oversight, not deliberate**.

#### Spike C (A4) — Backend idempotency (quick CLI read)

`lib/inception.sh do_inception_decide` writes a new `## Decision` block each
call and appends `### <timestamp> — inception-decision` entry to `## Updates`.
Re-running produces a new timestamp entry; does NOT strip the previous
`## Decision` block (hence the "duplicate decision blocks" observed in
T-1200 and T-1283 already). So the backend is already idempotent; it just
has a minor bug (no replacement of the canonical block on second call).

A4 **mostly confirmed.** Small backend tweak needed: on re-decide, replace
(not append) the `## Decision` block so a single canonical remains.

#### F5 discovered — /approvals conflates strategic decisions with rubber-stamp checks

`/approvals` page shows four sections with radically different workloads:
- **1 Tier 0 approval** — single command to approve (high friction, rare)
- **4 GO Decisions** — strategic, require reading evidence + rationale
- **97 Human ACs** — many rubber-stampable; user has separately called this
  "noise" (see earlier dialogue this session on 3-tier validation + reviewer
  agent)
- **94 Total** — sum

Evidence: `docs/screenshots/T-1388-evidence-3-approvals-page.png` +
`docs/reports/T-1388-approvals-snapshot.md`.

Mixing 97 rubber-stamp items with 4 strategic decisions buries the decisions
under verification noise. This friction is **adjacent** to the 3-tier
validation/reviewer-agent discussion the user opened earlier today — different
task, same symptom.

### Recommendation (ready for human decision)

**Recommendation: GO** (S-broad scope per user selection).

**Rationale:** The observed friction is not a single missing button — it's a
decision page that fights its own data model (60 multi-decision inceptions
in the repo proving users want to re-decide), duplicates content (F3),
mis-renders extracted rationale (F4), and buries strategic decisions under
rubber-stamp noise on /approvals (F5). All four directives score against
the current state:

- **Antifragility:** ❌ agents hand-edit task files to work around F1 — each
  edit risks clobbering Updates log, placeholder detector, adjacent sections
- **Reliability:** ❌ F4 produces garbled Decision Record text; F2 counter
  lies (says 0 assumptions when body has 4)
- **Usability:** ❌ F1 (dead-end), F3 (duplicate content), F5 (noise dominates
  signal on /approvals) all named as "broken" by user
- **Portability:** ✅ no regression risk — all fixes are UI-side

**Evidence:**
- 60 inceptions in-repo have multiple decision entries in Updates log
  (Spike A)
- F1-F5 reproduced with live Watchtower + screenshots: evidence-1 (pending
  form), evidence-2 (decided-locked), evidence-3 (approvals conflation)
- Backend `record_decision` is already nearly idempotent (Spike C) — small
  tweak needed, no large refactor
- git archaeology (Spike B) shows one-shot was oversight, not deliberate

**Build decomposition (propose AFTER GO):**
- **B1** — Backend: `record_decision` replaces canonical `## Decision` block
  on re-decide instead of appending (bug fix, covers T-1200 too). Bats
  regression test.
- **B2** — Template: unconditional "Record Decision" form with state-aware
  label ("Record Decision" when pending, "Record Superseding Decision" when
  decided). Show previous decision inline as read-only context.
- **B3** — Template: deduplicate Agent Recommendation vs Decision Record.
  When decision exists AND rationale matches Recommendation: collapse into
  one card with "Decision: GO — Recommendation adopted" header.
- **B4** — Backend: fix F4 rationale extraction — strip leading "Recommendation:
  GO\n" prefix from rationale before persisting.
- **B5** — Template/backend: wire Assumptions counter to task body + CLI
  registry (F2). If task body has A1..A4 and registry has 0, show "4
  declared (unregistered)" hint linking to `fw assumption add`.
- **B6** — `/approvals` split: separate sections for "Decisions" (Tier 0 +
  Inception GO/NO-GO) vs "Verifications" (Human ACs). Counter on nav reads
  "4 decisions, 97 verifications" instead of "113 items need attention".
- **B7** — Playwright test per CLAUDE.md T-971: regression guards decided
  inceptions allow re-decide, Updates log accumulates entries, canonical
  Decision block is replaced not duplicated.

Each B-unit is <1 session. Build units sequence: B1 (backend) → B2 (UI
unblock) → B3+B4 (dedup/cleanup) → B5 (assumption fix) → B6 (approvals
split) → B7 (regression). B1+B2 alone resolve F1 (the original user
request); B3-B6 address the "disjointed" feel; B7 pins invariants.

**Reversibility:** Every B-unit is a small, isolated template/handler edit.
Each produces a git revert point. Can ship B1+B2 first and stop if B3-B6
prove controversial.

**If NO-GO:** The S-narrow path (F1 only) still addresses the reported bug.
S-medium is an intermediate stop.

### Frictions not addressed by this inception (out-of-scope, future work)

- Rewriting inception data model — single-canonical `## Decision` + Updates
  history stays as is
- "Decision history" timeline visualisation — B2's inline previous-decision
  context is enough
- Multi-user authorization / review-of-review — single-human mode only
