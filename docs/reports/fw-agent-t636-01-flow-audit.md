# T-636 Flow Audit: Tier 0 Human Approval End-to-End

## 1. Watchtower `/approvals` — What It Can Do Today

**File:** `web/blueprints/approvals.py` (142 lines)

### Endpoints

| Route | Method | Purpose |
|-------|--------|---------|
| `/approvals` | GET | Renders approval queue page (pending + resolved) |
| `/api/approvals/decide` | POST | Human approves or rejects a pending Tier 0 request (HTMX) |

### Data Model

- **Source dir:** `.context/approvals/`
- **Pending files:** `pending-{hash12}.yaml` — written by `check-tier0.sh` on block
- **Resolved files:** `resolved-{hash12}.yaml` — written by the `/api/approvals/decide` endpoint on human action
- **Expiry:** 1 hour (`EXPIRY_SECONDS = 3600`). Expired items render as `expired` status in the UI (grayed out, no buttons).

### Decide Flow (`/api/approvals/decide`)

1. Reads `command_hash` + `decision` (approved|rejected) + optional `feedback` from POST form
2. CSRF token validated (Flask-WTF)
3. Loads `pending-{hash12}.yaml`, verifies it exists
4. If `decision == "approved"`: writes `.context/working/.tier0-approval` with `{hash} {unix_timestamp}` — this is the token `check-tier0.sh` reads
5. Moves `pending-*.yaml` to `resolved-*.yaml` with response metadata (decision, feedback, responded_at, mechanism=watchtower)
6. Deletes the pending file
7. Returns HTMX fragment: "Approved. Agent can retry the command."

### Missing / Gaps

- **No polling/push.** The agent must manually retry the command; there is no notification channel from Watchtower back to the agent session.
- **No reject feedback display to agent.** If human rejects, the resolved file captures feedback, but the agent only sees the original "TIER 0 BLOCK" message on retry, with no reject reason.
- **No auto-expire cleanup.** Expired pendings linger on disk until manually cleaned or overwritten.

---

## 2. `lib/review.sh` — `emit_review()` Output

**File:** `lib/review.sh` (108 lines)

This is **not** part of the Tier 0 flow. It handles Human AC review output for task partial-completion. Included here because it was requested.

### What It Outputs

1. A boxed header: `Human AC Review: T-XXX` with `X/Y checked` count
2. A Watchtower URL pointing to `/tasks/T-XXX#human-ac`
3. A QR code (if `python3-qrcode` installed) — allows phone scanning
4. Research artifact links from `docs/reports/T-XXX-*.md`
5. Footer: "Click the link or scan QR to review Human ACs"

### Callers

- `fw task review`
- `update-task.sh` (on partial-complete, when Human ACs remain)
- `inception.sh` (on decide)

### Relevance to T-636

`emit_review()` is the **Human AC** review surface. It is a **different approval flow** from Tier 0. Tier 0 approvals go through `.context/approvals/` and Watchtower `/approvals`. Human AC approvals go through the task detail page (`/tasks/T-XXX`). These are two independent approval mechanisms.

---

## 3. `check-tier0.sh` — Pending Approval Creation (lines 217-354)

**File:** `agents/context/check-tier0.sh` (354 lines total)

### How Pending Approvals Are Created (Block Path, lines 313-354)

When a destructive command is detected AND no valid approval exists:

1. **Block message** printed to stderr (lines 313-331):
   - Shows risk description and command preview
   - Instructs: `./bin/fw tier0 approve` then retry

2. **CLI pending file** written (line 334):
   - Path: `.context/working/.tier0-approval.pending`
   - Format: `{full_sha256_hash} {unix_timestamp} PENDING`
   - Used by `fw tier0 approve` CLI command

3. **Watchtower pending YAML** written (lines 336-352):
   - Path: `.context/approvals/pending-{hash12}.yaml`
   - Contains: timestamp, type (tier0), risk, command_preview (first 200 chars), command_hash, status (pending)
   - This is what Watchtower reads via `_load_pending_approvals()`

4. **Exit 2** — Claude Code PreToolUse exit code for "block"

### Two Approval Token Sources (lines 166-311)

`check-tier0.sh` checks TWO approval sources in order:

| Priority | Source | Mechanism | TTL |
|----------|--------|-----------|-----|
| 1st | `.context/working/.tier0-approval` | `fw tier0 approve` CLI or Watchtower `/api/approvals/decide` | 5 min (300s) |
| 2nd | `.context/approvals/resolved-{hash12}.yaml` | Watchtower only (T-612 pickup) | 1 hour (3600s, env `TIER0_WATCHTOWER_TTL`) |

**Source 1 (CLI token, lines 166-215):**
- Reads hash + timestamp from `.tier0-approval`
- Validates hash matches AND age < 300 seconds
- On match: deletes token, logs to `bypass-log.yaml`, exits 0 (allow)
- On mismatch/stale: deletes file, falls through

**Source 2 (Watchtower resolved file, lines 217-311):**
- Checks if `resolved-{hash12}.yaml` exists
- Python validates: status == "approved", command_hash matches, age < TTL
- On match: marks file as `consumed`, logs to `bypass-log.yaml` with `mechanism: watchtower`, exits 0
- On EXPIRED/SKIP: falls through to block

---

## 4. Approval UI (`web/templates/approvals.html`)

**File:** `web/templates/approvals.html` (152 lines)

### Layout

1. **Page header:** "Approvals" with pending count badge
2. **Pending section:** Cards with amber border, each showing:
   - Risk description (bold)
   - Status badge (PENDING / EXPIRED)
   - Timestamp
   - Command preview (monospace)
   - HTMX form with: optional feedback textarea, Approve (green) + Reject (red outline) buttons
   - Expired items show "Expired -- agent must retry" instead of buttons
3. **Recent section:** Last resolved approvals (approved=green, rejected=red) with response timestamp and feedback

### HTMX Integration

- Approve/Reject posts to `/api/approvals/decide` via HTMX (`hx-post`)
- Response is swapped inline (`hx-target="#result-{n}"`)
- No page reload needed — single-click approval

---

## 5. Full Flow Trace

### Path A: CLI Approval (`fw tier0 approve`)

```
Agent runs destructive command (e.g., git push --force)
  │
  ▼
check-tier0.sh (PreToolUse hook)
  ├─ Keyword pre-filter matches
  ├─ Python pattern matching → BLOCKED
  ├─ No valid approval token found
  ├─ Writes .context/working/.tier0-approval.pending (CLI token source)
  ├─ Writes .context/approvals/pending-{hash12}.yaml (Watchtower surface)
  ├─ Prints block message to stderr
  └─ exit 2 (block)
  │
  ▼
Human runs: fw tier0 approve
  ├─ Reads .tier0-approval.pending → gets hash
  ├─ Writes .tier0-approval with hash + timestamp
  ├─ Deletes .pending file
  └─ Prints "Approved. Retry the command now."
  │
  ▼
Agent retries the same command
  │
  ▼
check-tier0.sh (runs again)
  ├─ Pattern matches again → BLOCKED
  ├─ Checks .tier0-approval → hash matches, age < 300s
  ├─ Deletes .tier0-approval (single-use)
  ├─ Logs to bypass-log.yaml (mechanism: "fw tier0 approve")
  └─ exit 0 (allow)
```

### Path B: Watchtower Web Approval

```
Agent runs destructive command
  │
  ▼
check-tier0.sh (PreToolUse hook)
  ├─ Same as Path A: blocks, writes both files
  └─ exit 2
  │
  ▼
Human opens Watchtower /approvals page
  ├─ _load_pending_approvals() reads .context/approvals/pending-*.yaml
  ├─ Checks expiry (> 3600s → expired, no buttons)
  └─ Renders card with Approve/Reject buttons
  │
  ▼
Human clicks Approve
  ├─ POST /api/approvals/decide (command_hash, decision=approved)
  ├─ Writes .context/working/.tier0-approval (same file CLI writes!)
  ├─ Moves pending → resolved YAML (with response metadata)
  └─ Returns "Approved. Agent can retry the command."
  │
  ▼
Agent retries the same command
  │
  ▼
check-tier0.sh (runs again)
  ├─ FIRST checks .tier0-approval (Source 1) → if present and valid, allows
  ├─ OR if .tier0-approval was already consumed/expired:
  │   checks resolved-{hash12}.yaml (Source 2, T-612)
  │   → status=approved, hash matches, age < 3600s → APPROVED
  ├─ Marks resolved file as "consumed"
  ├─ Logs to bypass-log.yaml (mechanism: "watchtower")
  └─ exit 0 (allow)
```

### Key Timing Windows

| Token | Written By | TTL | Single-Use |
|-------|-----------|-----|------------|
| `.tier0-approval` | CLI `fw tier0 approve` OR Watchtower POST | 300s (5 min) | Yes (deleted on use) |
| `resolved-{hash12}.yaml` | Watchtower POST only | 3600s (1 hour) | Yes (marked consumed) |

The dual-token system means Watchtower approval has **two chances** to be picked up:
1. Via the `.tier0-approval` file (5 min window, same as CLI)
2. Via the resolved YAML file (1 hour window, T-612 fallback)

---

## 6. Identified Issues and Gaps

### Gap 1: No Agent Notification
The agent must manually retry the command. There is no push notification, polling loop, or event system to tell the agent "your approval is ready." The human must say "I approved it" or the agent must speculatively retry.

### Gap 2: Reject Path is a Dead End
If the human clicks Reject in Watchtower:
- The resolved file captures `decision: rejected` and optional feedback
- But check-tier0.sh never reads rejected resolutions (only checks for `status == 'approved'`)
- The agent sees the same "TIER 0 BLOCK" message on retry, with no indication it was explicitly rejected
- The pending YAML is deleted, so the Watchtower UI no longer shows it — the request just disappears

### Gap 3: Stale Pending Files Not Auto-Cleaned
Pending YAML files that expire (>1 hour) remain on disk. They show as "expired" in the UI but are never deleted. Over time, the approvals directory accumulates stale files.

### Gap 4: Block Message Only References CLI
The stderr block message (line 326) says `./bin/fw tier0 approve` — it does not mention the Watchtower web UI as an alternative. The agent only knows about the CLI path unless it reads CLAUDE.md.

### Gap 5: Race Condition on Dual Token
If a command is approved via Watchtower, the endpoint writes BOTH `.tier0-approval` AND the resolved YAML. If the agent retries quickly, Source 1 (`.tier0-approval`) is consumed first. The resolved YAML remains with status `approved` (not consumed) until the 1-hour TTL. A different command with the same hash (unlikely but possible) could theoretically use it.

### Gap 6: No CSRF on API endpoint visible in template
CSRF token IS present (`{{ csrf_token() }}` in template line 112, hidden input), but the enforcement depends on Flask-WTF being properly configured. Not verified in this audit.

---

## 7. Audit Summary

The Tier 0 approval flow is **functional and well-structured** with two independent paths (CLI and Watchtower) that converge on the same token file. The T-612 enhancement adds a resilient fallback via resolved YAML files with a longer TTL.

The main architectural gap is the **lack of a feedback channel from human back to agent** — both for approvals (agent must speculatively retry) and rejections (agent never learns why it was rejected). This is a UX issue, not a security issue.
