# T-636 Design: Mobile/QR Approval Experience

**Author:** Agent (research spike 05)
**Date:** 2026-03-27
**Status:** Design proposal

---

## Current State

- `lib/review.sh` emits a QR code (via python3-qrcode) that encodes `http://<LAN-IP>:<port>/tasks/T-XXX#human-ac`
- The URL lands on the full Watchtower task detail page (`task_detail.html`) with the browser scrolling to `#human-ac`
- The task detail page renders Human ACs as expandable `<details>` cards with interactive checkboxes (htmx POST to `/api/task/T-XXX/toggle-ac`)
- Tier 0 approvals live on a separate page (`/approvals`) with pending/resolved cards and approve/reject buttons
- Pico CSS provides basic responsiveness (viewport meta, some mobile breakpoints in base.html)
- `base.html` already loads `htmx-ext-sse.js` but no templates use SSE yet
- CSRF is **skipped for /api/ routes** (line 71 of app.py), so mobile can POST without session cookies
- No authentication or session tokens exist anywhere in Watchtower

---

## Design Decisions

### 1. Dedicated `/review/T-XXX` Route (Recommended)

**Decision: YES — create a new route and template.**

The full task detail page is designed for desktop dashboarding. It includes:
- Full navigation bar with dropdown menus
- Ambient status strip
- Metadata table with inline-editable selects
- Research artifacts, description, episodic summary, raw task body

On a phone (320-414px wide), this is 5+ screens of scrolling before reaching the Human ACs. The `#human-ac` anchor helps, but the nav chrome still consumes ~100px of vertical space, and the page loads all the JS libraries (Cytoscape, dagre, highlight.js, marked, purify) that are irrelevant to the approval action.

**The `/review/T-XXX` route should:**
- Use a **minimal template** (no base.html inheritance, no nav/footer/ambient strip)
- Include only: Pico CSS + htmx (no Cytoscape, highlight.js, etc.)
- Be a single-purpose "approval card" view
- Set `<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">` for mobile safe areas

**Why not just anchor-link?** Three reasons:
1. Page weight — full task detail loads ~200KB of JS the phone doesn't need
2. Layout control — can't override base.html chrome without a separate template
3. The QR URL is the _primary_ mobile entry point — it deserves its own UX, not an afterthought scroll target

### 2. Mobile Review Page Layout

```
+------------------------------------------+
|  T-042: Add OAuth support                |
|  Status: started-work  Owner: human      |
+------------------------------------------+
|                                          |
|  HUMAN ACCEPTANCE CRITERIA  (1/3)        |
|                                          |
|  +--------------------------------------+|
|  | [ ] [REVIEW] Voice/tone matches      ||
|  |                                      ||
|  | Steps:                               ||
|  | 1. Read first 3 paragraphs           ||
|  | 2. Compare to published posts        ||
|  |                                      ||
|  | Expected: Reads like peer-to-peer    ||
|  |                                      ||
|  |      [  CHECK  ]                     ||
|  +--------------------------------------+|
|                                          |
|  +--------------------------------------+|
|  | [x] [RUBBER-STAMP] Config deployed   ||
|  +--------------------------------------+|
|                                          |
|  +--------------------------------------+|
|  | [ ] [REVIEW] Integration test passes ||
|  |      ...                             ||
|  |      [  CHECK  ]                     ||
|  +--------------------------------------+|
|                                          |
+------------------------------------------+
|  Research Artifacts                       |
|  > T-042-oauth-spike.md                  |
+------------------------------------------+
```

**Key layout rules:**
- **Task header**: ID, name, status, owner. One line each. No editable fields — this is a review surface, not an editing surface.
- **Human ACs only**: Do not show Agent ACs. The human does not need to see or interact with those.
- **One card per AC**: Each Human AC is a full-width card. Unchecked ACs are expanded by default, checked ACs are collapsed.
- **Large touch targets**: The check action is a **dedicated button** (min 48x48px per WCAG), not the native checkbox. The button text changes: "Check" (unchecked) vs "Uncheck" (checked, secondary/outline style).
- **Steps/Expected/If-not**: Shown inline (no `<details>` nesting on mobile — too many tap targets). Font size 16px minimum (prevents iOS zoom on focus).
- **Confidence badges**: Same `badge-review` / `badge-rubber-stamp` styling, slightly larger on mobile.
- **Research artifacts**: Listed below ACs as simple links. Opens in new tab.
- **No description, no episodic, no raw body**: Keep it focused.

### 3. Tier 0 Approval on Mobile

When a Tier 0 approval is pending, it should appear **above** the Human ACs on the review page, with a prominent alert-style card:

```
+------------------------------------------+
|  TIER 0 APPROVAL REQUIRED                |
|  ----------------------------------------|
|  Risk: Force push to main                |
|  Command: git push --force origin main   |
|  ----------------------------------------|
|  [  APPROVE  ]     [ REJECT ]            |
|  Optional feedback: [                  ] |
+------------------------------------------+
```

**Implementation approach:**
- The `/review/T-XXX` route checks `.context/approvals/pending-*.yaml` for any pending approvals (regardless of task — Tier 0 is global)
- If pending approvals exist, render them at the top of the review page
- The approve/reject buttons POST to the existing `/api/approvals/decide` endpoint
- Since CSRF is skipped for `/api/` routes, this works without session state

**Why include Tier 0 on the review page?** The QR code is already in the human's hand. If the agent is blocked on a Tier 0 gate, the human scanning the QR code should see it immediately — not need to navigate to a separate `/approvals` page.

### 4. Auto-Refresh: SSE for Live Updates

**Decision: Use htmx SSE extension (already loaded) for real-time updates.**

When the agent commits changes (e.g., checks an Agent AC, updates task status), the mobile review page should reflect this without manual refresh.

**Mechanism:**
- New Flask endpoint: `/api/review/T-XXX/stream` that returns SSE events
- The endpoint watches the task file's mtime (polling every 2 seconds on the server side — simple, no inotify dependency)
- On change, it emits an SSE event with the updated Human AC state and task status
- The mobile page connects via `hx-ext="sse"` and `sse-connect="/api/review/T-XXX/stream"`
- Individual AC cards have `sse-swap` attributes that replace their content on update
- Tier 0 pending approvals also stream: when a new approval appears or one is resolved, the card updates

**Why SSE over polling?**
- htmx SSE extension is already loaded in base.html and available
- SSE is unidirectional (server → client), which matches the use case (agent changes → phone updates)
- Lower overhead than WebSocket for this one-way flow
- Automatic reconnection built into the EventSource API

**Fallback:** If SSE connection fails (e.g., proxy doesn't support it), add a `<meta http-equiv="refresh" content="30">` fallback. The page is lightweight enough that a full reload every 30 seconds is acceptable.

### 5. Security Considerations

**Current state:** Watchtower has zero authentication. It runs on a LAN (192.168.10.0/24) behind UFW. The QR code encodes a LAN IP URL.

**Threat model for QR codes:**
- QR codes are visible on the terminal screen (shoulder-surfing)
- They encode a predictable URL pattern (`/review/T-XXX`) — task IDs are sequential
- Anyone on the LAN can access any task or approve any Tier 0 request
- The CSRF exemption for `/api/` routes means no session binding

**Recommendation: Add optional HMAC token, defer full auth to a separate task.**

For Phase 1 (this task's scope):
- Append an `?token=<HMAC>` parameter to the QR URL
- HMAC = `HMAC-SHA256(secret_key, task_id + timestamp)` with a 1-hour expiry
- The `/review/T-XXX` route validates the token if present; if absent, falls back to current behavior (no auth)
- The HMAC key is the same `FW_SECRET_KEY` used for CSRF (or auto-generated in dev)
- This gives: (a) QR links are non-guessable, (b) QR links expire, (c) backward compatible

**Token URL format:**
```
http://192.168.10.107:3010/review/T-042?token=<hex>&ts=<unix>
```

**What this does NOT protect against:**
- Someone who intercepts the QR code image or URL (they get the token too)
- Someone who steals the secret key
- Full authentication (login, sessions, roles)

**For Phase 2 (future task):**
- Short-lived PIN display: terminal shows a 4-digit PIN, mobile page prompts for it before showing content
- Device fingerprinting: first scan registers device, subsequent scans auto-authenticate
- Full auth: OAuth/passkey integration

**Pragmatic note:** The framework runs on a home/office LAN with one user. The HMAC token adds a meaningful layer (no casual URL guessing) without the complexity of full auth. The real security is the network perimeter (UFW + LAN isolation).

### 6. Swipe Interactions

**Decision: NO swipe-to-approve. Use explicit tap targets instead.**

Reasoning:
- Swipe gestures conflict with browser navigation (swipe-back on iOS/Android)
- Accidental approvals are worse than extra taps (especially for Tier 0)
- The approval action is infrequent (1-5 times per session) — the interaction cost of a tap is negligible
- Implementing custom swipe handlers adds JS complexity for minimal UX gain

**Instead, optimize for tap:**
- Approval buttons are full-width on mobile (easy thumb target)
- Minimum 48px height per WCAG touch target guidelines
- Visual feedback on tap (Pico's `:active` states are sufficient)
- After checking an AC, the card animates to collapsed state (CSS transition)

---

## Route and File Plan

### New Files

| File | Purpose |
|------|---------|
| `web/templates/review.html` | Standalone mobile review template (no base.html) |
| `web/blueprints/review.py` | Blueprint: `/review/T-XXX`, `/api/review/T-XXX/stream` |

### Modified Files

| File | Change |
|------|--------|
| `web/blueprints/__init__.py` | Register review blueprint |
| `lib/review.sh` | Change QR URL from `/tasks/T-XXX#human-ac` to `/review/T-XXX?token=...` |
| `web/app.py` | No change needed (CSRF already exempts /api/) |

### Template Structure (`review.html`)

```html
<!DOCTYPE html>
<html lang="en" data-theme="light">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <title>Review {{ task_id }}</title>
    <link rel="stylesheet" href="/static/pico.min.css">
    <script src="/static/htmx.min.js"></script>
    <script src="/static/htmx-ext-sse.js"></script>
    <style>
        /* Mobile-first styles: large touch targets, readable text */
        body { padding: 1rem; font-size: 16px; }
        .review-header { margin-bottom: 1rem; }
        .review-header h2 { font-size: 1.2rem; margin: 0; }
        .ac-card { /* full-width, min-height 48px tap zones */ }
        .ac-action-btn { width: 100%; min-height: 48px; font-size: 1rem; }
        .tier0-alert { border: 2px solid #ef4444; background: #ef444411; }
        /* ... */
    </style>
</head>
<body hx-ext="sse" sse-connect="/api/review/{{ task_id }}/stream">
    <!-- Tier 0 approvals (if any) -->
    <!-- Task header (read-only) -->
    <!-- Human ACs with large check buttons -->
    <!-- Research artifact links -->
</body>
</html>
```

### SSE Endpoint (`/api/review/T-XXX/stream`)

```python
@bp.route("/api/review/<task_id>/stream")
def review_stream(task_id):
    """SSE stream: emit events when task file or approvals change."""
    def generate():
        last_mtime = 0
        last_approval_count = 0
        while True:
            time.sleep(2)
            # Check task file mtime
            task_file = _find_task_file(task_id)
            if task_file:
                mtime = task_file.stat().st_mtime
                if mtime != last_mtime:
                    last_mtime = mtime
                    # Re-parse ACs, emit update
                    yield sse_event("ac-update", ...)
            # Check approvals dir
            pending = len(list(APPROVALS_DIR.glob("pending-*.yaml")))
            if pending != last_approval_count:
                last_approval_count = pending
                yield sse_event("approval-update", ...)
    return Response(generate(), mimetype="text/event-stream")
```

### HMAC Token Generation (in `lib/review.sh`)

```bash
# Generate HMAC token for QR URL
local ts=$(date +%s)
local secret=$(python3 -c "
import os
key = os.environ.get('FW_SECRET_KEY', 'dev-key')
print(key)
")
local token=$(echo -n "${task_id}${ts}" | python3 -c "
import sys, hmac, hashlib, os
key = os.environ.get('FW_SECRET_KEY', 'dev-key').encode()
msg = sys.stdin.read().strip().encode()
print(hmac.new(key, msg, hashlib.sha256).hexdigest()[:16])
")
local review_url="${base_url}/review/${task_id}?token=${token}&ts=${ts}"
```

---

## Open Questions for Human Decision

1. **Token enforcement level**: Should `/review/T-XXX` be token-required (rejects without token) or token-optional (validates if present, allows if absent)? Recommendation: optional in dev, required when `FW_SECRET_KEY` is set.

2. **Agent AC visibility**: Should the mobile view show Agent ACs as read-only (for context) or hide them entirely? Recommendation: hide — the human scanning a QR code wants to act, not read agent-side checkboxes.

3. **Tier 0 scope on review page**: Should the review page show ALL pending Tier 0 approvals, or only those associated with the task in the URL? Current Tier 0 approval YAML files are not task-scoped (they contain `command_hash`, `command_preview`, `risk`, `timestamp` but no `task_id`). Recommendation: show all pending — there are rarely more than one at a time, and the human should see everything blocking the agent.

4. **SSE connection limits**: Flask's dev server is single-threaded. An open SSE connection blocks the thread. For dev use (`python3 web/app.py`), should we use polling instead of SSE, or require gunicorn for the review page? Recommendation: detect server type and fall back to polling (meta refresh or htmx `hx-trigger="every 5s"`) in dev mode.

---

## Implementation Sequence

1. **Review blueprint + template** — `/review/T-XXX` with static render (no SSE, no token)
2. **Wire QR URL** — Change `lib/review.sh` to point to `/review/T-XXX`
3. **Tier 0 integration** — Show pending approvals on review page
4. **SSE stream** — Add `/api/review/T-XXX/stream` and live updates
5. **HMAC tokens** — Add token generation to review.sh, validation to review.py
6. **Polish** — Animations, haptic feedback hints, collapsed/expanded states

Steps 1-3 are one build task. Steps 4-5 are a second. Step 6 is a third.
