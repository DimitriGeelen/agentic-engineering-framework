# T-608: Frictionless Tier 0 Human Confirmation — Research Artifact

## Problem

Tier 0 flow today: hook blocks → human switches terminal → cd → paste command → switch back.
Maximum friction. Need: provably-human confirmation with minimal effort.

## Leading Approach: Watchtower Approval Surface

Human-directed (2026-03-25 conversation). Expand Watchtower's existing Human AC display into an interactive approval interface.

### Why Watchtower

- Already exists, already shows tasks and Human ACs
- Web UI = out-of-band from agent (agent can't click buttons)
- Mobile-accessible via Traefik (approve from phone)
- Solves BOTH Tier 0 approvals AND the 26-task Human AC backlog

### Proposed Architecture

```
Agent hits gate → writes .context/approvals/T-XXX.yaml
                          ↓
Watchtower shows pending approval (badge/card)
                          ↓
Human clicks approve/reject + feedback in browser
                          ↓
Watchtower API writes response to approval ledger
                          ↓
Cron/hook scans for new approvals → agent picks up
```

### Unfakeability

Agent can READ `.context/approvals/` but the approval response is written by Watchtower's Flask endpoint, not by file write. The agent would need to POST to its own HTTP server — which is detectable and blockable.

### Open Questions

- Should the approval ledger be in `.context/approvals/` or in a SQLite DB?
- How to handle approval expiry (stale approvals from days ago)?
- Should Watchtower send a notification (email, webhook) when approval is pending?
- Can we add websocket/SSE for real-time updates instead of polling?

## Other Approaches Considered

See task file for Spikes 1, 3, 4 (hook capabilities, challenge-response, TermLink channel).

## Dialogue Log

### 2026-03-25 — Human expands on Watchtower approach
- Human proposed: expand existing Human AC display into interactive cards
- Each AC gets: expandable card, approve/reject buttons, feedback text area
- Mobile-responsive for phone approval
- Pickup via cron scanning approval ledger
- Agent: confirmed this solves Tier 0 + Human AC backlog in one system
