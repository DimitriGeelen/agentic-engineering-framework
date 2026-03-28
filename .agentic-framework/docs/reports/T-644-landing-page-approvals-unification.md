# T-644: Watchtower Landing Page / Approvals Unification

## Problem Statement

Three surfaces now show "what needs human attention":

| Surface | Shows | Interactive? | Entry point |
|---------|-------|-------------|-------------|
| Landing page `/` (cockpit) | "Awaiting Your Verification" — full list of tasks with unchecked Human ACs | No (read-only list) | Default landing |
| Landing page `/` (cockpit) | "Needs Your Decision" — scan-driven action cards | Yes (Approve/Defer buttons) | Default landing |
| `/approvals` | Tier 0 + GO decisions + Human ACs with interactive checkboxes | Yes (full actions) | Nav → Approvals |
| `/tasks/T-XXX` | Full AC cards with Steps/Expected/If-not + Complete button | Yes (full detail) | Click-through |

The landing page's "Awaiting Your Verification" section duplicates `/approvals`'s Human AC section, but without interactivity. The human sees the same information in two places with different capabilities.

## Current Architecture

### Landing page data flow
- `cockpit.py:get_human_verify_tasks()` — parses every active task, extracts Human ACs
- `cockpit.html` lines 115-135 — renders read-only list with checkbox symbols
- Also shows "Needs Your Decision" from scan data (separate from GO decisions)

### /approvals data flow
- `approvals.py:_load_pending_human_acs()` — same scan, returns interactive data
- `approvals.py:_load_pending_go_decisions()` — inception tasks with pending decisions
- `approvals.html` — interactive checkboxes, GO decision forms, Tier 0 cards

### Overlap analysis
- Human ACs: **duplicated** (landing page read-only vs /approvals interactive)
- GO decisions: **partially duplicated** (landing "Needs Your Decision" vs /approvals GO section)
- Tier 0: **not duplicated** (only on /approvals)

## Design Options

### Option A: Summary + Link (Recommended)
Replace the landing page's full "Awaiting Your Verification" list with a compact summary card:

```
┌─────────────────────────────────────────────┐
│  Action Required                            │
│                                             │
│  0 Tier 0    5 GO Decisions    42 Human ACs │
│                                             │
│  ► T-334: Execute launch sequence (4 ACs)   │
│  ► T-449: Deep-dive articles editing (5 ACs)│
│  ► T-448: Cron registry v2 (2 ACs)         │
│                                             │
│  [View all in Approvals →]                  │
└─────────────────────────────────────────────┘
```

- Shows unified counts (all three types)
- Top 3 most-AC tasks as a teaser
- Single CTA to /approvals
- Landing page stays fast (no full AC parsing — just counts)

**Also:** Enrich /approvals Human AC section with expandable Steps/Expected/If-not + per-task Complete button, so /approvals is truly self-contained.

### Option B: Embed approvals mini-view
- Landing page embeds the /approvals summary bar via htmx include
- Less duplication but adds a network request on page load

### Option C: Remove from landing page entirely
- Landing page only shows project health (audit, traceability, patterns)
- All action items move exclusively to /approvals
- Risk: human might not notice pending items if they don't visit /approvals

## Recommendation

**Option A.** It preserves the landing page's role as a "glance dashboard" while eliminating the full duplication. The human sees counts + top items, clicks through to /approvals for the interactive experience.

Additionally, enrich `/approvals` Human AC section:
1. Expandable `<details>` cards matching `task_detail.html` pattern (Steps/Expected/If-not)
2. Per-task "Complete Task" button when all ACs checked
3. This makes `/approvals` the one-stop action hub

## Build tasks (if GO)

1. **Landing page summary card** — replace "Awaiting Your Verification" full list with counts + top 3 + link to /approvals (~30 lines cockpit.html + cockpit.py changes)
2. **Enrich /approvals Human ACs** — expandable AC cards with Steps/Expected/If-not + per-task Complete button (~60 lines approvals.html changes)
3. **Nav badge** — show pending count on "Approvals" nav item (~10 lines shared.py)

## Files to change

| File | Change |
|------|--------|
| `.agentic-framework/web/blueprints/cockpit.py` | Simplify `get_human_verify_tasks()` to return counts + top 3 |
| `.agentic-framework/web/templates/cockpit.html` | Replace full list with summary card |
| `web/blueprints/approvals.py` | Pass full AC detail (steps/expected/if_not) to template |
| `web/templates/approvals.html` | Add expandable AC cards + per-task Complete button |
| `web/shared.py` | Add pending count to nav context for badge |

## Go/No-Go Criteria

**GO if:**
- The summary card pattern is cleaner than the current full list
- /approvals can be made self-contained without excessive complexity
- Nav badge is feasible within render_page() context injection

**NO-GO if:**
- The landing page scan-driven "Needs Your Decision" section conflicts with /approvals GO decisions in a way that can't be resolved without major refactor
