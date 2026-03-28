# T-636 Spike 3: Terminal-to-Watchtower Bridge Design

## Current State

### emit_review() (lib/review.sh)
- Builds URL as `${base_url}/tasks/${task_id}#human-ac`
- Always targets the task detail page, regardless of approval type
- Shows: QR code, URL, research artifacts, Human AC count
- Called from 3 structural points: `fw task review`, `update-task.sh` (partial-complete), `inception.sh` (decide)
- URL auto-detection: checks WATCHTOWER_URL env, then watchtower.pid + ss port sniff, then hostname -I, default :3000

### check-tier0.sh (agents/context/check-tier0.sh)
- Block message says only: `./bin/fw tier0 approve` (line 326)
- No Watchtower URL emitted
- Already writes `pending-*.yaml` to `.context/approvals/` (line 339-352) for Watchtower pickup
- Already reads `resolved-*.yaml` from Watchtower (lines 217-311) to auto-consume approvals
- The bridge from Watchtower to terminal (approval consumption) EXISTS
- The bridge from terminal to Watchtower (URL in block message) is MISSING

### Watchtower /approvals (web/blueprints/approvals.py)
- Shows pending Tier 0 approvals only
- No Human AC queue, no inception GO decisions
- No task-specific filtering (no `?task=T-XXX` support)
- POST endpoint: `/api/approvals/decide` (command_hash, decision, feedback)
- Only approval type supported: Tier 0

### Task detail page (/tasks/T-XXX#human-ac)
- Has working Human AC checkboxes (toggle-ac API, HTMX)
- Has Agent AC checkboxes
- Has Steps/Expected/If-not structured display
- This IS the approval surface for Human ACs today

### Inception detail page (/inception/T-XXX)
- Has GO/NO-GO/DEFER form with rationale textarea
- Posts to `/inception/<task_id>/decide`
- This IS the approval surface for GO decisions today

## Design Decisions

### D1: Should emit_review() link to /approvals?task=T-XXX instead of /tasks/T-XXX#human-ac?

**Recommendation: No (not yet). Keep /tasks/T-XXX#human-ac as the primary URL, but make emit_review() context-aware.**

Rationale:
- `/tasks/T-XXX#human-ac` already has working checkboxes, structured Human AC cards, Steps/Expected/If-not display. It IS the approval surface for Human ACs.
- `/approvals` today only handles Tier 0. Expanding it to show Human ACs would duplicate task_detail.html's checkbox rendering without adding value.
- The anchor `#human-ac` scrolls directly to the Human section. This is correct behavior.
- If /approvals becomes a "unified inbox" later (Spike 2 scope), it should aggregate and link to task detail pages, not replicate their UI.

**One change needed:** When `emit_review()` is called from `inception.sh` after a GO decision, the URL should point to `/inception/T-XXX` (where the GO form is), not `/tasks/T-XXX#human-ac`. The function currently has no concept of WHY it was called.

**Proposed: Add a `--type` parameter to emit_review():**

```bash
emit_review T-XXX [task_file] [type]
# type: "human-ac" (default), "inception", "tier0"
```

URL routing based on type:
| Type | URL | Why |
|------|-----|-----|
| human-ac | `/tasks/T-XXX#human-ac` | Checkboxes are on task detail page |
| inception | `/inception/T-XXX` | GO/NO-GO form is on inception detail page |
| tier0 | `/approvals?highlight=HASH` | Tier 0 approve buttons are on approvals page |

This is a small, backward-compatible change. The third argument defaults to "human-ac" if omitted, so existing callers (update-task.sh, fw task review) work unchanged. Only inception.sh passes "inception" and check-tier0.sh passes "tier0".

### D2: Should check-tier0.sh emit a Watchtower /approvals link when blocking?

**Recommendation: Yes. This is the highest-value change in this spike.**

Current block message (lines 314-331):
```
TIER 0 BLOCK -- Destructive Command Detected
  Risk: ...
  Command: ...
  To proceed: ./bin/fw tier0 approve
```

Proposed block message:
```
TIER 0 BLOCK -- Destructive Command Detected
  Risk: ...
  Command: ...

  Approve via Watchtower:
  http://192.168.10.170:3000/approvals
  (or scan QR)

  Or approve via CLI:
  cd /opt/999-Agentic-Engineering-Framework && bin/fw tier0 approve
```

Implementation:
- check-tier0.sh already has the pending YAML write. Add URL detection (same pattern as review.sh, or source review.sh's URL logic into a shared function).
- Source `lib/review.sh` and call `emit_review "$task_id" "" "tier0"` -- but check-tier0.sh does not know the task_id (it only sees the command).
- **Alternative (simpler):** Extract the URL detection logic from review.sh into a shared `lib/watchtower-url.sh` function. check-tier0.sh sources it and prints the URL inline in the block message. No QR needed (check-tier0.sh runs in a hook, output goes to stderr, QR rendering in stderr is noisy).

Actually, since check-tier0.sh already knows the command_hash, the URL should be:
```
${base_url}/approvals
```
No task filter needed -- there's typically only one pending Tier 0 at a time. The human opens /approvals, sees the pending card, clicks Approve. The `?highlight=HASH` parameter is nice-to-have for auto-scrolling if multiple pending exist, but the approvals page already shows pending items prominently.

**Implementation steps:**
1. Extract URL detection from `review.sh` lines 35-48 into `lib/watchtower-url.sh` (single function `get_watchtower_url()`)
2. Source it in both `review.sh` and `check-tier0.sh`
3. In check-tier0.sh block message (line 325-328), add the Watchtower URL
4. Keep the CLI fallback (`bin/fw tier0 approve`) for cases where Watchtower is not running

### D3: Should there be a /approve/T-XXX route for task-specific approval?

**Recommendation: No. Use existing routes with query parameters.**

Rationale:
- `/tasks/T-XXX#human-ac` already works for Human ACs
- `/inception/T-XXX` already works for GO decisions
- `/approvals` already works for Tier 0
- A new `/approve/T-XXX` route would need to detect approval type and redirect anyway, adding a layer of indirection without value
- Deep-link pattern is cleaner: the URL tells you where you're going

**If we wanted a universal entry point (future consideration):**
A redirect route could be useful later:
```python
@bp.route("/approve/<task_id>")
def approve_redirect(task_id):
    # Detect type from task file or pending approvals
    if has_pending_tier0(task_id): redirect to /approvals
    if is_inception(task_id): redirect to /inception/T-XXX
    else: redirect to /tasks/T-XXX#human-ac
```
But this is premature. The three approval surfaces exist and work. emit_review() knowing which URL to emit is sufficient.

### D4: How should QR code destination adapt based on approval type?

**Recommendation: The QR code URL should match the emit_review type parameter.**

Current: QR always encodes `/tasks/T-XXX#human-ac`

Proposed: QR encodes the same URL that's printed as text:

| Context | QR destination | Why |
|---------|---------------|-----|
| `fw task review T-XXX` | `/tasks/T-XXX#human-ac` | Human AC checkboxes |
| `update-task.sh` partial-complete | `/tasks/T-XXX#human-ac` | Human AC checkboxes |
| `inception.sh` decide | `/inception/T-XXX` | GO form + research |
| `check-tier0.sh` block | `/approvals` | Approve button |

This follows naturally from D1's type parameter. The QR and the text URL are always the same thing -- the QR is just the scannable version. No special QR logic needed.

**For check-tier0.sh specifically:** QR code is optional. The block message goes to stderr and is consumed by Claude Code's PreToolUse hook. The human sees it in the terminal, but QR rendering in stderr can be noisy. Recommendation: include the URL text but skip the QR in the block message. If the human wants the QR, they can run `fw approvals pending` (which could emit a QR -- future enhancement).

## Implementation Summary

### Changes Required (ordered by value)

1. **Extract `get_watchtower_url()` into `lib/watchtower-url.sh`** (new file, ~20 lines)
   - Move URL detection logic from review.sh lines 35-48
   - Exports `WATCHTOWER_BASE_URL` variable
   - Sourced by both review.sh and check-tier0.sh

2. **Add Watchtower URL to check-tier0.sh block message** (edit ~10 lines)
   - Source `lib/watchtower-url.sh`
   - Add `/approvals` link after existing block text
   - Keep CLI fallback

3. **Add `type` parameter to emit_review()** (edit ~15 lines in review.sh)
   - Third argument: "human-ac" (default) | "inception" | "tier0"
   - URL construction switches on type
   - Header text switches: "Human AC Review" vs "Inception Review" vs "Tier 0 Approval"
   - QR encodes the type-appropriate URL

4. **Pass type from callers** (3 one-line edits)
   - `inception.sh` line 275: `emit_review "$task_id" "$task_file" "inception"`
   - `update-task.sh` line 579: unchanged (default "human-ac" is correct)
   - `fw task review`: unchanged (default "human-ac" is correct)

### Files Modified
- `lib/watchtower-url.sh` (new, ~20 lines)
- `lib/review.sh` (refactor URL detection out, add type param)
- `agents/context/check-tier0.sh` (add Watchtower URL to block message)
- `lib/inception.sh` (pass "inception" type to emit_review)

### Files NOT Modified
- `web/blueprints/approvals.py` -- no new routes needed
- `web/templates/approvals.html` -- Tier 0 UI already complete
- `web/templates/task_detail.html` -- Human AC UI already complete
- `web/templates/inception_detail.html` -- GO form already complete

### Risks
- **URL detection reliability:** The watchtower.pid + ss port sniff is fragile (works on Linux, not macOS). WATCHTOWER_URL env var is the reliable path. Document this.
- **QR in stderr:** check-tier0.sh writes to stderr. QR code rendering in stderr is technically fine but visually noisy. Skip QR for Tier 0 blocks.
- **No task_id in check-tier0.sh:** The hook only sees the command, not which task is active. The Watchtower URL cannot include task context. This is fine -- /approvals shows all pending, and there's rarely more than one.

### Non-Goals (Spike 2/4/5 scope)
- Unified /approvals inbox aggregating Human ACs + GO decisions + Tier 0 (Spike 2)
- Universal `/approve/T-XXX` redirect route (premature, see D3)
- Mobile-optimized approval page (Spike 5)
- Auto-refresh/polling on approvals page (Spike 4)
