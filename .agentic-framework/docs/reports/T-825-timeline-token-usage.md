# T-825: Timeline Token Usage — Research Artifact

## Problem Statement

We capture token usage per session (in handover frontmatter as `token_usage: "771.8M tokens, 6290 turns"`).
The Watchtower `/timeline` page shows session history but doesn't display token costs per session.
Should we add token usage to the timeline view?

## Current State

- **Data source**: Handover frontmatter has `token_usage` field (string, e.g., "771.8M tokens, 6290 turns")
- **Timeline blueprint**: `web/blueprints/timeline.py` reads handover frontmatter but doesn't extract `token_usage`
- **Existing tools**: `/costs` page has a dedicated token dashboard, `fw costs session` shows per-session data
- **Data availability**: Every handover file has the field — 100% coverage

## Analysis

### Effort: LOW
- Read `token_usage` from frontmatter (1 line in timeline.py)
- Display in session card (1 line in template)
- Parse the string to extract numeric token count for sorting/aggregation (optional)

### Value: MEDIUM
- Immediate visual correlation: "which sessions consumed the most context?"
- Trend visibility: see if sessions are getting more/less expensive over time
- Combined with tasks-touched: understand cost per deliverable
- No new data collection needed — just surfacing existing data

### Risks: NONE
- Data already exists
- Display-only change
- No new dependencies

## Recommendation

**GO** — minimal effort (< 30 min build), data already available in every handover, adds meaningful context to the timeline view. The `/costs` page provides detailed breakdowns; the timeline adds the temporal dimension showing cost trends over sessions.

### Implementation Plan
1. Add `token_usage` to the session dict in `timeline.py` (~3 lines)
2. Display in session card template (badge or small text)
3. Optionally parse to numeric for a sparkline/trend indicator
