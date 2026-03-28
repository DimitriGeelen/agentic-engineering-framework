# T-636: Unified Human Approval Experience

## Problem Statement

Two parallel human approval mechanisms exist:
1. **Watchtower `/approvals`** — Web UI with approve/reject buttons, feedback textarea, status badges
2. **`fw task review`** — Terminal QR code + clickable URL + research artifacts + shell command

Both are good. Neither is complete alone:
- Watchtower has the UI but no QR codes, no research artifact links, no shell command fallback
- Terminal review has QR + links but can't approve — just presents info

The human bounces between terminal and browser, running commands in one and clicking in the other.

## What We Have Today

| Feature | Watchtower /approvals | fw task review | fw task update (partial) |
|---------|----------------------|----------------|--------------------------|
| Tier 0 approve/reject | Yes (buttons) | No | No |
| Human AC checkboxes | No | No (shows count) | No |
| QR code | No | Yes | No |
| Clickable URL | No (is the URL) | Yes | Yes (via emit_review) |
| Research artifacts | No | Yes | Yes (via emit_review) |
| Shell command | No | No | Shows "fw task update..." |
| GO decision approve | Yes (same as Tier 0) | No | No |

## Spike Results (5 agents, 1337 lines)

### Spike 1: Current flow audit (252 lines)
Full Tier 0 flow works: agent blocked → YAML created → Watchtower shows → human approves → agent picks up. **6 gaps found:** (1) no agent notification on approval, (2) reject is a dead end — feedback never reaches agent, (3) stale pending files accumulate, (4) block message omits Watchtower as alternative, (5) dual-token race potential, (6) no rejection feedback channel.

### Spike 2: Unified approval page (430 lines)
Design for `/approvals` combining Tier 0, pending Human ACs, and GO decisions in three urgency-ordered sections with summary count bar. Only `approvals.py` and `approvals.html` need changes — reuses existing API endpoints.

### Spike 3: Terminal-to-Watchtower bridge (199 lines)
**Key recommendations:** (1) Keep `/tasks/T-XXX#human-ac` as Human AC URL — it already has working checkboxes. (2) **Highest-value change:** add Watchtower `/approvals` URL to check-tier0.sh block message (~10 lines). (3) No new `/approve/T-XXX` route needed — existing surfaces work. (4) Add `type` param to `emit_review()` so inception routes to `/inception/T-XXX`.

### Spike 4: Human AC checkboxes (142 lines)
**Surprise finding:** Human AC toggle already works end-to-end (toggle-ac endpoint + htmx forms). **3 remaining gaps:** (1) "Complete Task" button when all ACs checked (OOB htmx swap), (2) `--force` flag for browser-initiated completion (sovereignty gate), (3) visual feedback polish (strike-through, progress counters).

### Spike 5: Mobile/QR experience (314 lines)
**Recommends new `/review/T-XXX` route** — minimal mobile-first template (no base.html, no nav chrome, just Pico + htmx). Single-purpose approval card: task name, Human ACs as large checkboxes, Tier 0 approve button, research artifact links. Optional HMAC token for security. Auto-refresh via htmx polling (SSE deferred — Flask dev server is single-threaded).

## Synthesis: Build Plan

### Phase 1: High-value, low-effort (this sprint)
1. **check-tier0.sh Watchtower link** — Add approval page URL to block message. ~10 lines. (Spike 3)
2. **Unified `/approvals` page** — Show Tier 0 + Human ACs + GO decisions grouped by urgency. (Spike 2)
3. **"Complete Task" button** — OOB htmx swap when all Human ACs checked. (Spike 4)
4. **Fix approval YAML quoting** — Already done this session (check-tier0.sh python3 yaml.dump)

### Phase 2: Rich experience (next sprint)
5. **`/review/T-XXX` mobile route** — Minimal approval card optimized for QR scan. (Spike 5)
6. **emit_review() type parameter** — Route to correct Watchtower page by context. (Spike 3)
7. **Rejection feedback channel** — Write rejection reason to YAML, agent reads on retry. (Spike 1)

### Phase 3: Polish (future)
8. **HMAC tokens for QR URLs** — Security for mobile access. (Spike 5)
9. **SSE/polling for live updates** — Auto-refresh approval page. (Spike 5)
10. **Agent notification on approval** — PostToolUse hook checks for resolved approvals. (Spike 1)

## Recommendation

**GO** — Phase 1 delivers the highest value (unified page + Watchtower link in tier0 block + complete button) in ~3 build tasks. The mobile review route (Phase 2) is the stretch goal.

## Evidence Files

Full agent reports (1337 lines total):
- `docs/reports/fw-agent-t636-01-flow-audit.md` — End-to-end flow trace, 6 gaps
- `docs/reports/fw-agent-t636-02-unified-page.md` — Unified approval page design
- `docs/reports/fw-agent-t636-03-bridge.md` — Terminal-to-Watchtower bridge
- `docs/reports/fw-agent-t636-04-ac-checkboxes.md` — Human AC checkbox gaps
- `docs/reports/fw-agent-t636-05-mobile-qr.md` — Mobile/QR approval experience
