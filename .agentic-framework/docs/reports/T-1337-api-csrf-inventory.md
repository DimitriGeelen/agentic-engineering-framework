# T-1337: Watchtower /api/* CSRF Coverage — Inventory & Classification

**Task:** T-1337 (inception) — G-048 mitigation path
**Date:** 2026-04-19
**Status:** Research complete, recommendation pending Watchtower review

## Problem

`web/app.py:92-107` — CSRF middleware blanket-skips any request whose path starts with `/api/`:

```python
if request.endpoint == "health" or request.path.startswith("/api/"):
    return
```

Same-origin SameSite=Lax cookies provide incidental protection, but this is not a design guarantee. Any page/iframe/redirect that can get the user's browser to POST to `/api/...` bypasses CSRF entirely.

## Inventory

### State-mutating `/api/*` endpoints (25)

| Method | Path | File:Line | Impact if CSRF-forgeable |
|--------|------|-----------|--------------------------|
| POST | /api/decision | session.py:100 | Records a spoofed decision |
| POST | /api/learning | session.py:131 | Injects a spoofed learning |
| POST | /api/session/init | session.py:162 | Re-initializes session state |
| POST | /api/healing/<task_id> | session.py:183 | Triggers healing on arbitrary task |
| POST | /api/sessions | terminal.py:71 | Spawns a terminal session |
| DELETE | /api/sessions/<id> | terminal.py:127 | Kills arbitrary session |
| POST | /api/scan/refresh | cockpit.py:203 | Triggers scan |
| POST | /api/scan/approve/<rec_id> | cockpit.py:216 | Approves discovery recommendation |
| POST | /api/scan/defer/<rec_id> | cockpit.py:248 | Defers discovery recommendation |
| POST | /api/scan/apply/<rec_id> | cockpit.py:275 | Applies recommendation to repo |
| POST | /api/scan/focus/<task_id> | cockpit.py:301 | Changes session focus |
| POST | /api/audit/run | quality.py:97 | Runs audit on demand |
| POST | /api/tests/run | quality.py:111 | Runs test suite on demand |
| POST | /api/v1/cron/jobs/<id>/pause | cron.py:325 | Pauses a cron job |
| POST | /api/v1/cron/jobs/<id>/resume | cron.py:343 | Resumes a cron job |
| POST | /api/v1/cron/jobs/<id>/run | cron.py:361 | Runs a cron job now |
| POST | /api/task/create | tasks.py:439 | Creates arbitrary task |
| POST | /api/task/<id>/horizon | tasks.py:485 | Changes task horizon |
| POST | /api/task/<id>/owner | tasks.py:501 | Changes task owner |
| POST | /api/task/<id>/type | tasks.py:517 | Changes task type |
| POST | /api/task/<id>/complete | tasks.py:533 | Completes arbitrary task |
| POST | /api/task/<id>/status | tasks.py:551 | Changes task status |
| POST | /api/task/<id>/name | tasks.py:571 | Renames task |
| POST | /api/task/<id>/toggle-ac | tasks.py:593 | Toggles AC checkboxes |
| POST | /api/task/<id>/description | tasks.py:615 | Edits task description |

### Read-only `/api/*` endpoints (safe; no classification needed)

`/api/_identity`, `/api/session/status`, `/api/sessions` (GET), `/api/sessions/<id>` (GET), `/api/sessions/profiles`, `/api/termlink/sessions`, `/api/concerns`, `/api/test-summary`, `/api/v1/cron/jobs/<id>/describe`, `/api/timeline/task/<task_id>`, `/api/learnings`, `/api/decisions`, `/api/patterns`, `/api/fabric/report/<filename>`, `/api/fabric/source/<filepath>`.

## Options

### Option A — Full CSRF coverage (remove blanket exemption)

Replace the `request.path.startswith("/api/")` exemption with an explicit allowlist of GET-only read endpoints. State-mutating POST/DELETE under `/api/*` go through the normal CSRF check — clients send `X-CSRF-Token` header (the middleware already accepts the header, line 104).

**Scope:** 1 app.py change + audit of all fetch() callers across templates/JS to add `X-CSRF-Token` header + playwright regression covering each state-mutating endpoint (group into a single parameterized test).

**Effort:** medium. The fetch() sites are numerous but uniform — grep for `fetch\(` and add the header in a helper.

### Option B — Accept status quo, document the SameSite defense

Leave the exemption, add a comment in app.py citing SameSite=Lax as the informal defense, close G-048 as "accepted risk" since Watchtower is local-loopback by design.

**Scope:** trivial (comment-only change).

**Effort:** minimal.

**Risk:** does not survive Watchtower ever being exposed (dev LXC is already on a routable VLAN; prod would be worse). Any cookie misconfiguration silently re-opens the gap. No structural detection.

### Option C — Hybrid: /api/v2/ for token-required, keep /api/* exempt

New `/api/v2/` prefix — all state-mutating endpoints migrate over time; blanket exemption stays for read-like `/api/*`. Incremental migration keeps existing clients working.

**Scope:** middleware change + per-endpoint migration (25 endpoints) + client updates + regression. Effectively Option A done endpoint-by-endpoint with a namespace split.

**Effort:** high (migration cost > benefit vs Option A; adds a versioning concept that isn't otherwise needed).

## Recommendation

**Option A (GO).** Reasons:

1. **Design principle.** CSRF exemption by path prefix is a known anti-pattern. The exemption exists historically (pre-JSON-heavy endpoints) and has not been revisited.
2. **Inventory is bounded.** 25 endpoints is large but fits one build task; all need the same change (read header, compare to session token — middleware already does this if we remove the early return).
3. **Detection-over-mitigation (G-019).** The fix is a positive allowlist — future state-mutating endpoints land under CSRF by default. That's the structural improvement.
4. **Option B is cosmetic.** Accepting risk without a detection mechanism leaves the door open for regression. The gap is already registered; closing it without fixing is audit noise.
5. **Option C adds versioning for no net benefit.** Migration cost dominates; the namespace doesn't buy anything except staging.

**Decomposition for build:** propose one build task with three ordered stages:
- **B1:** middleware flip (explicit allowlist instead of `/api/*` skip). No fetch() changes yet → expect to break un-tokenized clients.
- **B2:** update all fetch() callers to send `X-CSRF-Token` (single helper in a shared JS util).
- **B3:** playwright regression — test one representative state-mutating endpoint per blueprint (not all 25).

B1 and B2 must land in the same commit (otherwise Watchtower UI breaks between them). B3 lands separately.

**Go/No-Go criteria met:**
- Root cause identified: path-prefix CSRF exemption predates the JSON-heavy endpoint migration.
- Fix path bounded: 25 endpoints, one middleware change, one JS helper, one regression.
- Reversible: middleware change is a single revert; fetch() updates are additive (header ignored by current middleware).

## Dialogue Log

No human dialogue in this session — agent framed inception, inventoried endpoints, assessed options, wrote recommendation. Decision pending human review via `fw task review T-1337`.
