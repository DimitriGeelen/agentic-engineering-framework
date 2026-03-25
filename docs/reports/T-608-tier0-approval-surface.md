# T-608: Frictionless Tier 0 Human Confirmation — Research Artifact

## Problem

Tier 0 flow today: hook blocks → human switches terminal → cd → paste command → switch back.
Maximum friction. Need: provably-human confirmation with minimal effort.

## Spike Results

### Spike 1: Claude Code Hook Capabilities — RULED OUT

**Finding:** Hooks are non-interactive by architectural design. They run as shell subprocesses with stdin fed by Claude Code (JSON tool metadata), not user input. No tty, no dialog, no read.

**What hooks CAN do:** Pattern match, read/write files, exit 0 (allow) or exit 2 (block), output to stderr (shown to agent).

**What hooks CANNOT do:** Present interactive prompts, read user input, invoke Claude Code tools, block and wait for user response.

**Current Tier 0 mechanism:** Two-phase file-based approval. Hook detects + blocks (writes `.tier0-approval.pending`), human runs `fw tier0 approve` separately (writes `.tier0-approval` with hash + TTL), hook on retry validates + consumes. This is sound but high-friction.

**Verdict:** Hook interactivity is not a viable path. The architecture fundamentally prevents it.

### Spike 2: Watchtower Approval Surface — LEADING APPROACH (human-directed)

**Concept:** Expand Watchtower's existing Human AC display into an interactive approval interface.

#### Why Watchtower

- Already exists, already shows tasks and Human ACs
- Web UI = out-of-band from agent (agent can't click buttons)
- Mobile-accessible via Traefik (approve from phone)
- Solves BOTH Tier 0 approvals AND the 28-task Human AC backlog

#### Proposed Architecture

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

#### Unfakeability

Agent can READ `.context/approvals/` but the approval response is written by Watchtower's Flask endpoint, not by file write. The agent would need to POST to its own HTTP server — which is detectable and blockable.

#### Existing Watchtower Building Blocks

Explored the current codebase:

- **AC parsing** already exists in `web/blueprints/tasks.py` — extracts checkbox lines with `_parse_acceptance_criteria()`
- **AC toggle** already works via htmx POST to `/api/task/<task_id>/toggle-ac` — real-time, no page reload
- **Inline editing** pattern proven (name, description, status, owner, horizon all use htmx POSTs)
- **Task detail page** renders ACs with counts but does NOT distinguish Agent vs Human ACs

**Gaps to fill:**
1. Parse `### Agent` / `### Human` AC section headers
2. Parse `[RUBBER-STAMP]` / `[REVIEW]` confidence markers
3. Render Human ACs as structured cards (steps/expected/if-not) instead of raw text
4. Add approve/reject buttons + feedback textarea per Human AC
5. New POST endpoint `/api/task/<task_id>/approve-ac` for recording decisions
6. Tier 0 pending approval queue (separate from task ACs)

#### Open Questions

- Should the approval ledger be in `.context/approvals/` or in a SQLite DB?
- How to handle approval expiry (stale approvals from days ago)?
- Should Watchtower send a notification (email, webhook) when approval is pending?
- Can we add websocket/SSE for real-time updates instead of polling?

#### Friction: <1 second (click a button in browser already open)

### Spike 3: Challenge-Response — RULED OUT

**Finding:** Technically infeasible due to hook non-interactivity and retry timing.

**The fatal flaw:** Hook generates challenge → shows to user via stderr → but agent also sees it in the conversation. If agent retries the command, the hook generates a NEW random challenge (old one doesn't match). There is no control flow path where the agent can type the challenge and have the hook verify it — the hook fires BEFORE tool execution, not during.

Even if a timing-based scheme worked, the agent seeing the challenge in conversation output breaks the unfakeability guarantee entirely.

**Verdict:** Infeasible. The hook execution model prevents challenge-response patterns.

### Spike 4: TermLink Approval Channel — FEASIBLE but inferior

**Finding:** A separate TermLink session could serve as an out-of-band approval channel. Human approves in Terminal B while agent works in Terminal A.

**Flow:** Agent writes request → human runs `fw tier0 approve` in Terminal B → file-based handoff.

**Unfakeability:** Yes — the agent cannot interact with Terminal B without human action.

**Friction:** 3-5 seconds (terminal switch + type command). Slightly better than current (no `cd` needed if Terminal B is already in project), but still requires terminal switching.

**Verdict:** Feasible and unfakeable, but offers minimal friction improvement. Watchtower is strictly superior on both friction (<1s vs 3-5s) and scope (also solves Human AC backlog).

## Comparison Matrix

| Criterion | Spike 1 (Hooks) | Spike 2 (Watchtower) | Spike 3 (Challenge) | Spike 4 (TermLink) |
|-----------|-----------------|---------------------|--------------------|--------------------|
| Feasible | No | Yes | No | Yes |
| Unfakeable | N/A | Yes | N/A | Yes |
| Friction | N/A | <1s | N/A | 3-5s |
| Mobile-friendly | No | Yes | No | No |
| Solves Human AC backlog | No | Yes | No | No |
| Infrastructure cost | N/A | Medium (UI build) | N/A | Zero |
| Fits in one session | N/A | Yes (~4hr) | N/A | Yes (~1hr) |

## Recommendation: GO

**Approach:** Watchtower approval surface (Spike 2).

**Why GO:**
1. Provably-human confirmation with <1s friction (meets go criterion: <5s)
2. Agent cannot fake it — web UI writes approval, not file system (meets unfakeability criterion)
3. Implementation fits in one session — existing htmx/Flask patterns, AC parsing already exists
4. Bonus: solves the 28-task Human AC backlog with the same infrastructure
5. Mobile-accessible via Traefik — approve from phone while agent works on desktop

**Why not the alternatives:**
- Spike 1 (hooks): Non-interactive by design — no path forward
- Spike 3 (challenge-response): Infeasible — agent sees challenge, retry generates new one
- Spike 4 (TermLink): Works but still requires terminal switching, no scope expansion

**Suggested build tasks after GO:**
1. T-610: Parse Agent/Human AC sections + confidence markers in Watchtower
2. T-611: Tier 0 approval queue — pending/approved/rejected cards with htmx
3. T-612: Agent pickup mechanism — cron or PostToolUse hook scanning approval ledger

## Dialogue Log

### 2026-03-25 — Human expands on Watchtower approach
- Human proposed: expand existing Human AC display into interactive cards
- Each AC gets: expandable card, approve/reject buttons, feedback text area
- Mobile-responsive for phone approval
- Pickup via cron scanning approval ledger
- Agent: confirmed this solves Tier 0 + Human AC backlog in one system

### 2026-03-25 — All 4 spikes explored
- Spike 1 (hooks): ruled out — non-interactive by design
- Spike 2 (Watchtower): leading approach — human-directed, all criteria met
- Spike 3 (challenge-response): ruled out — infeasible (timing + visibility)
- Spike 4 (TermLink): feasible but inferior to Watchtower on friction and scope
- Recommendation: GO with Watchtower approval surface
