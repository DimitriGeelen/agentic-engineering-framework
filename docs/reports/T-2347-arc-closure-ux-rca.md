---
task: T-2347
title: Arc closure UX RCA — Watchtower arc-action handoff defaults to CLI
status: in-progress
recommendation: GO
created: 2026-06-12
---

# T-2347 — Arc closure UX RCA

## 1. Trigger

Session 2026-06-12, operator asked "what do we need to do to close the bvp driver arc?" Agent replied with three shell commands (approve-driver × 2 + `fw arc close`). Operator pushed back: **"why can this not be done through the watchtower, please incept RCA and remediate the ARC mechanics and what is hampering, broken at the moment"**.

Two prior session moments compounded the trigger:
1. Operator approved arc-011 drivers via Watchtower buttons (confirmed by /bvp screenshot — drivers active). Agent had given CLI in handoff. Watchtower path worked despite agent's CLI handoff.
2. Earlier the operator caught a stale claim that `fw arc create` was Sovereign-blocked (it isn't) — memory `feedback_verify_governance_claims_before_parroting` already exists for this class.

## 2. Symptom

For arc closure on arc-006 (value-prioritisation), agent surfaced:
```
cd /opt/999-Agentic-Engineering-Framework && bin/fw arc close value-prioritisation --demo docs/reports/value-prioritisation-demo/ --decision "..." --i-am-human
```
…when a Watchtower close form exists at `http://192.168.10.107:3000/arcs/value-prioritisation/close` (route declared `web/blueprints/arcs.py:1253`).

Same pattern for proposed scoped driver resolution: CLI block surfaced when `/arcs/<slug>` already renders Approve buttons (template lines `web/templates/arc_detail.html` rendering driver approve forms at `web/blueprints/arcs.py:919-1149`).

## 3. 5-Whys

| # | Why | Evidence |
|---|-----|----------|
| 1 | Why did agent surface CLI for arc close? | No memory entry exists routing "arc actions" → Watchtower URLs. Memories `feedback_use_fw_task_review` / `feedback_review_concrete_links` only cover **task review** handoffs. |
| 2 | Why no memory for arc actions? | The class wasn't burned before. T-679 (task review handoff rule) triggered the existing memories; an "arc action" equivalent never had its precipitating incident — until today. |
| 3 | Why does the operator have to know `--from-watchtower` vs `--i-am-human` at all? | Because arc_detail.html:430-447 instructs the operator to copy a CLI command instead of clicking a button that exists at `/arcs/<slug>/close`. |
| 4 | Why does arc_detail.html instruct CLI when the form exists? | The §ACD Completion Discipline block was authored before the Watchtower close form landed (T-1911/T-1902 per blueprint comment). The form was added; the instruction block was never updated. |
| 5 | Why isn't arc-006 in `/approvals` Arc Closure section? (which would route operator past arc_detail.html entirely) | `_load_close_ready_arcs` filter at `web/blueprints/approvals.py:405` uses `_completion_stats(constituents)` which returns **35/51 = 68%** for arc-006, below the 80% threshold — but `bin/fw arc show value-prioritisation` shows **49+/53 = 92%**. Constituent resolver parity gap. |

**Root cause class:** Watchtower UX surfaces exist for both actions (approve-driver buttons + close form + /approvals "Arc Closure" section). Three independent regressions push agent + operator off the Watchtower path back to CLI:
- **A.** arc_detail.html advises CLI instead of linking the form
- **B.** /approvals close-ready filter under-counts constituents, excluding arc-006 from auto-surface
- **C.** Agent has no memory rule routing arc actions to Watchtower URLs

## 4. Evidence — three defects

### Defect A — arc_detail.html advises CLI

File: `web/templates/arc_detail.html:417-447`

```html
{% if arc.status != 'closed' %}
<h2>§Arc Completion Discipline — three-question check</h2>
... (three-question prose) ...
<p>When you can answer all three with evidence, close the arc:</p>
<pre><code>cd {{ project_root }} && bin/fw arc close {{ arc_id }} \
    --demo &lt;path-to-wire-evidence&gt; \
    --decision "&lt;success|partial|failed|cancelled&gt; — &lt;one-line summary&gt;"</code></pre>
```

The CLI block IS the close affordance on the page. There is no link to `/arcs/<slug>/close` despite that route existing at `web/blueprints/arcs.py:1253` (`arc_close_surface` GET renders the form, POST shells to `fw arc close --from-watchtower`).

The template DOES mention `--from-watchtower` in advisory prose (line 447: "used by Flask backend when Watchtower closes the arc on the human's behalf") — which is a tell that the Watchtower path was known to exist but the link was never added.

### Defect B — /approvals close-ready filter under-counts

File: `web/blueprints/approvals.py:405-444` `_load_close_ready_arcs`

Filter:
```python
if str(arc.get("status") or "").strip() != "in-progress":  continue
constituents = _resolve_constituents(arc)
stats = _completion_stats(constituents)
if stats["ratio"] < threshold:  continue   # threshold=0.80
rec = _anchor_recommendation(arc)
if not rec.get("present"):  continue
```

Live evaluation for arc-006:
- `status` = `in-progress` ✓
- `_completion_stats` = `{'completed': 35, 'total': 51, 'ratio': 0.686}` ✗ (below 0.80)
- `_anchor_recommendation` = `{'present': True, 'verdict': 'GO', ...}` ✓

But `bin/fw arc show value-prioritisation` lists ~53 tasks tagged `arc:value-prioritisation` of which ~49 are work-completed. So `_resolve_constituents` is missing ~2 tasks AND counts ~14 fewer completed.

Cause hypothesis (deferred to Slice B build task): `_resolve_constituents` walks `arc_id:` frontmatter AND `tags: [arc:<slug>]` independently; old arc-006 tasks have `tags:` but not `arc_id:` because the field was introduced after most of them shipped (T-1849). The merge math may be reading completed/active heterogeneously.

### Defect C — agent CLI default for arc actions

File: `CLAUDE.md` — `§Presenting Work for Human Review` (T-679) — covers task review handoffs (`fw task review T-XXX` → Watchtower URL). No equivalent rule for arc actions. The closest is `§Arc Completion Discipline` which constrains the agent FROM auto-closing arcs but doesn't say "use the Watchtower URL when surfacing the action to operator".

Memory entries `feedback_use_fw_task_review`, `feedback_human_review_links`, `feedback_review_concrete_links`, `feedback_post_grill_governance` all govern task-review handoffs only.

Behavior pattern (this session, 2026-06-12):
- arc-011 approve-driver: agent gave CLI; operator clicked Watchtower instead and it worked
- arc-006 close: agent gave CLI; operator pushed back

## 5. Candidate remediation slices

Each slice is independent (filed only after `fw inception decide T-2347 go`).

| Slice | Scope | Files | Cost | BVP |
|-------|-------|-------|------|-----|
| **A1** | Replace CLI block in arc_detail.html with prominent "Close arc" button → `/arcs/<slug>/close`; keep collapsible CLI fallback for headless/no-Watchtower case | `web/templates/arc_detail.html:417-447` | S — single template, ~20 LoC | High — every arc closure routes here |
| **B1** | Fix `_resolve_constituents` / `_completion_stats` parity: align with CLI's `arc_tasks_by_id` logic so arc-006 surfaces in /approvals "Arc Closure" | `web/blueprints/arcs.py:422-555` (or call out to CLI lookup); bats test | M — parity verification across all arcs | High — operator's primary discovery surface |
| **C1** | CLAUDE.md addition `§Arc Action Handoffs`: rule that arc actions (`fw arc close`, `fw arc approve-driver`, `fw arc abandon`) be surfaced as Watchtower URLs to operator, not CLI. Sibling to T-679. Capture memory entry. | `CLAUDE.md` + memory file | XS — prose + memory | Medium — prevents class recurrence |
| **C2** | (optional) Make `fw arc close` agent-refusal message at `lib/arc.sh:670-705` *display the resolved Watchtower URL* prominently as the primary surface (it does now mention it, but mid-block). | `lib/arc.sh:670-705` | XS — block-message edit | Low — defense in depth |

**Recommended order:** C1 (CLAUDE.md + memory) ships in this session as a one-line write — closes the class for agent behavior immediately. A1 + B1 are real build tasks that need their own ACs + verification.

## 6. Recommendation

**GO** — each defect has cited file:line evidence, bounded scope, reversibility (template + parity-fix + doc edit), and high value (arc closure is the keystone artefact for every arc the framework runs). DEFER would be a hedge — I've walked the evidence.

After GO: file T-2347a (Slice A1 — arc_detail.html), T-2347b (Slice B1 — constituent parity), and ship C1 (memory + CLAUDE.md note) inline as the immediate behavioral fix. C2 is a candidate only.

## 7. Dialogue Log

### 2026-06-12 — Trigger conversation

**Operator:** "ok what do we need to do to closed teh bvp driver arc?"

**Agent (initial reply):** Provided CLI-only handoff with three shell commands (`cd … && bin/fw arc approve-driver …` × 2 + `bin/fw arc close …`).

**Operator pushback:** "why can this not be done through teh watchtower, please incept RCA and remediate the ARC mechanics and what is hampering, broken at teh moement"

**Agent (this artefact):** Investigated; found three defects (A) template instruction stale, (B) /approvals filter undercount, (C) no agent memory rule for arc actions. Filed T-2347 with recommendation GO.

**Decision point:** Operator GO/NO-GO/DEFER on T-2347 — does the candidate slice set (A1+B1+C1) match intent, or do they want different scope?

## 8. Out-of-scope (explicit)

- **F-AUTONOMY activation** — arc-006 closure is independent; F-AUTONOMY belongs in the continuous-run arc (T-2158 dependency)
- **Arc abandonment UX** — `fw arc abandon` likely has the same CLI-default class but is outside this RCA's scope
- **Arc creation UX** — `fw arc create` requires `--headline-mechanic` (G-062 gate); deserves separate scrutiny if the same CLI-default pattern shows up
- **Cross-project arc actions** — TermLink-mediated arc closure on remote consumers; not this RCA
