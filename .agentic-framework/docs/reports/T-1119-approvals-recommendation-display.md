# T-1119 — Approvals Page Recommendation Display

## Bug

Watchtower approvals page shows inception tasks but hides the agent's recommendation.
The `rationale_hint` only pre-fills the textarea — the human can't see WHY the agent
recommends GO/NO-GO before making their decision.

## Fix

1. `web/blueprints/approvals.py`: Extract full `## Recommendation` section from task
   files and pass as `recommendation` + `rec_decision` (GO/NO-GO/DEFER) to template.

2. `web/templates/_approvals_content.html`: Add collapsible `<details>` block above the
   decision form showing the recommendation with color-coded decision badge (green=GO,
   red=NO-GO, gray=DEFER).

## Result

Each inception card now shows:
- Task name + link
- Problem excerpt
- **Agent Recommendation: GO** (collapsible, open by default)
  - Full recommendation text with rationale and evidence
- Research artifacts
- Decision form (GO/NO-GO/DEFER + rationale)
