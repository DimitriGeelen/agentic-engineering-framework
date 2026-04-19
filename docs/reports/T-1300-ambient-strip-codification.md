# T-1300 — Codify ambient-strip linked-chrome pattern

**Source:** termlink pickup (feature-proposal, P-028)
**Status:** DEFER — framework already has ambient strip; polish not critical

## Proposal

Termlink's T-1117..T-1121 arc enhanced base.html's ambient strip so every
element links to its natural destination:

- Focus task ID → `/tasks/<id>`
- Session age → tooltip shows session ID
- Audit status → `/quality`
- Attention count → `/tasks`
- Fleet dot + "N/M up" → `/fleet` (async)
- Project root → `/project`

Proposed: adopt the contract as the framework default in `web/templates/base.html`.

## Current framework state

`web/templates/base.html` lines 315–331 already renders an ambient strip with
5 elements: focus_task, session age, audit status, attention count, project
root. All rendered as plain `<span>` — **not linked**.

Missing entirely: fleet dot + "N/M up".

## Gap

The framework has the skeleton; it's missing:
1. `url_for()` links around the 5 existing spans (small)
2. Session-ID tooltip on session-age span (small)
3. Fleet indicator — requires a fleet endpoint (this machine isn't a fleet
   node itself; less relevant)

## Recommendation: DEFER

**Rationale:** The ambient strip is already functional. Making elements
clickable is UX polish, not a functional gap. No operator has complained
about needing clicks where spans stand today. With the session's budget
near warn-level and real bug fixes outstanding, this is the least pressing
pickup of the batch.

**Conditions to reconsider (GO later):**
- An operator specifically requests linked chrome in this project
- Another pickup arrives confirming the same pain on a third project
- A session ends with >3 navigation round-trips that linked chrome would
  have saved

## Alternative framing (not recommended now)

If the human wants to take this as a small win anyway, the scope is:
- 5-line edit to base.html to wrap each span in `<a href="{{ url_for(...) }}">`
- Add `title="{{ session_id }}"` to session-age span
- Bats/playwright test: assert 200 + links render

That's a 1-session task. Skipping today to preserve budget for real bugs.

## Decision trail

- Source pickup: P-028-feature-proposal.yaml (termlink, no source task ID)
- Prior art: termlink commits 1912669d, 8b3dfb6b, 55beeaf5, 2b2987cf,
  9a8dc542 (all on termlink main)
- Artifact: this file
- Recommendation: DEFER
