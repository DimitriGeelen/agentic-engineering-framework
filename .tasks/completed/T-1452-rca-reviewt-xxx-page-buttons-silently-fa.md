---
id: T-1452
name: "RCA: /review/T-XXX page buttons silently fail — CSRF token not sent on htmx
  POSTs"
description: >
  Mobile review page (/review/T-XXX) renders correctly but every action button silently
  fails: AC checkbox toggle, 'Complete Task' button, Tier 0 approve/reject. Root cause:
  review.html is standalone (does not extend base.html) and lacks the htmx:configRequest
  listener at base.html:430 that injects X-CSRF-Token. csrf_protect in web/app.py:103
  (T-1343 / G-048) returns 403 on /api/* mutations. Likely broken since T-1343 landed;
  no Playwright test on /review/T-XXX caught it because GETs work fine.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [bugfix, csrf, watchtower, mobile-review, regression]
components: []
related_tasks: [T-667, T-1343, T-1450]
created: 2026-04-25T13:35:00Z
last_update: '2026-08-16T22:24:33Z'
date_finished: 2026-04-25T11:51:10Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1452: RCA — /review/T-XXX page buttons silently fail (CSRF regression)

## Context

Reported by user 2026-04-25 while attempting to close T-1447 / T-1450 Human ACs. Clicking the AC checkbox or "Mark Complete" button on `/review/T-XXX` produced no visible response. The page itself rendered fine; the failures were silent.

## Symptom

- Open `http://192.168.10.107:3000/review/T-1447` in a browser
- Tick the AC checkbox → no state change, no error toast, no console error visible
- Click "Complete Task" → same: nothing happens

## Investigation (this session)

| Hypothesis | Test | Result |
|------------|------|--------|
| API endpoint returns 403/404 | `curl -X POST http://192.168.10.107:3000/api/task/T-1447/toggle-ac` | **HTTP 403 Forbidden** (CSRF rejection) |
| API endpoint returns 403/404 (complete) | `curl -X POST http://192.168.10.107:3000/api/task/T-1447/complete` | **HTTP 403 Forbidden** |
| Server enforces CSRF on /api/* | grep `csrf_protect` `web/app.py` | confirmed at `web/app.py:93-114` (T-1343 / G-048) |
| review.html injects X-CSRF-Token | grep `csrf` `web/templates/review.html` | NOT PRESENT |
| base.html injects X-CSRF-Token | grep `csrf` `web/templates/base.html` | present at `web/templates/base.html:429-435` (`htmx:configRequest` listener) |

## Root cause

`web/templates/review.html` is a standalone mobile-first template (per T-667 design — explicitly does not extend `base.html` to keep page weight low). Because of that, it never installs the `htmx:configRequest` listener defined in `base.html`. htmx POSTs go without `X-CSRF-Token`. The CSRF guard added by T-1343 / G-048 returns 403 silently (htmx receives 403 but has no error UI on `hx-swap="none"` + `hx-on::after-request`).

## Blast radius

EVERY mutation on the mobile review page is broken:
1. Checkbox toggle on Human ACs (`/api/task/<id>/toggle-ac`) — `_review_acs.html:15`
2. "Complete Task" button (`/api/task/<id>/complete`) — `_review_acs.html:60`
3. Tier 0 approve/reject buttons (`/api/approvals/decide`) — `review.html:304`

Mobile QR-scan workflow (the entire reason `/review/<task_id>` exists per T-667) has been broken since T-1343 landed CSRF enforcement.

## Why undetected

- No Playwright test on `/review/<task_id>`
- Existing smoke tests assert HTTP 200 on GET, which works fine
- htmx swallows 403 responses silently when `hx-swap="none"`; user sees no error
- T-1343 / G-048 author tested `base.html`-extending pages, missed the standalone template

This is exactly the kind of regression the v1.0+ reviewer is supposed to catch via `mock-only-integration` AC pattern — but no AC text mentioned the integration claim explicitly.

## Inception questions (before deciding)

1. **Fix shape: minimal vs structural?**
   - **Minimal:** copy the 7-line `htmx:configRequest` listener into `review.html` as inline `<script>`. Fast, isolated, low risk. Doesn't prevent the next standalone template having the same bug.
   - **Structural:** extract `static/csrf-htmx.js` (the listener + `fetchWithCsrf` wrapper). Both `base.html` and `review.html` `<script src=...>` it. One source of truth.
2. **Regression test:** Playwright test on `/review/<task_id>` that ticks an AC and verifies the API call returned 2xx. Tier 1 (server smoke) is insufficient — needs DOM interaction.
3. **Reviewer pattern candidate (v1.7+):** "Standalone template with htmx but no CSRF listener" — static check across `web/templates/*.html` files that bypass base.html. Anti-pattern: any file containing `hx-post|hx-put|hx-delete|hx-patch` and a `<head>` block that doesn't include the CSRF listener line.
4. **Audit other standalone templates:** `_review_error.html`, `cockpit.html` (?), any others — same bug class may exist.

## Proposed scope (post go/no-go)

- Build T-1452a: structural fix (extract `static/csrf-htmx.js`) + Playwright test on `/review/<task_id>` toggle-ac + audit other standalone templates
- Capture as L-269 if the audit turns up additional victims
- Optional v1.7 reviewer pattern: filed against T-1443 design report tunings list

## Acceptance Criteria

### Agent
- [x] RCA captured (this document)
- [x] Symptom reproduced via curl: HTTP 403 on `/api/task/T-1447/toggle-ac` and `/api/task/T-1447/complete`
- [x] Root cause identified: `review.html` lacks `htmx:configRequest` CSRF listener
- [x] Blast radius enumerated: 3 distinct mutations (toggle-ac, complete, tier0/decide)
- [x] Pre-existing concern: no Playwright test on `/review/<task_id>` mutations
- [x] Bugfix task drafted (this file as inception; build task spawned post-decision)
- [x] [Inception decision recorded] go/no-go/defer with chosen fix shape *(GO with structural-fix recorded 2026-04-25T11:49Z×3 — see Updates section; manually ticked because auto-tick regex did not match this AC text — captured as observation OBS-NEW-csrf-decide-no-feedback)*

### Human
- [x] [REVIEW] Decide go/no-go and choose fix shape (minimal vs structural)
  **Steps:**
  1. Open http://192.168.10.107:3000/inception/T-1452
  2. Pick: GO (minimal) | GO (structural) | DEFER | NO-GO
  3. Provide rationale
  **Expected:** Decision recorded; if GO, agent spawns T-1452a build task
  **If not:** comment in task body or feedback-stream

## Recommendation

**Recommendation:** GO with **structural fix** (Option 2).

**Rationale:** This bug is recurrence-prone. Any future standalone template (mobile-second-screen, embedded widgets, kiosk views) will hit the same trap. A 30-line `static/csrf-htmx.js` extracted from base.html is one-time cost; the Playwright regression test prevents recurrence via DOM-level coverage. Total scope ~2–3 hours including the audit sweep.

**Evidence:**
- 3 mutations broken right now → user-visible UX failure
- Same bug class will hit any new standalone template (cheap to prevent now, expensive to discover later)
- The "extract shared script" approach mirrors the existing pattern (`pico.min.css`, `htmx.min.js`, etc. are already shared)
- Cost-benefit: structural fix takes maybe 1.5x the time of minimal fix but eliminates a whole class of recurrence

## Verification

# Reproduce symptom (will fail before fix, pass after)
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$(bin/fw watchtower url)/api/task/T-1447/toggle-ac" -d "line=5" | grep -q "^403$"

## Decisions

<!-- Recorded after human go/no-go on inception/T-1452 -->

## Updates

### 2026-04-25T13:35:00Z — task-created [inception-rca]
- **Action:** Created inception bugfix task with full RCA
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1452-rca-reviewt-xxx-page-buttons-silently-fa.md
- **Context:** Reported by user during T-1447/T-1450 Human AC closure attempt; reproduced and root-caused this session

### 2026-04-25T11:49:36Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** This bug is recurrence-prone. Any future standalone template (mobile-second-screen, embedded widgets, kiosk views) will hit the same trap. A 30-line `static/csrf-htmx.js` extracted from base.html is one-time cost; the Playwright regression test prevents recurrence via DOM-level coverage. Total scope ~2–3 hours including the audit sweep.

### 2026-04-25T11:49:49Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** This bug is recurrence-prone. Any future standalone template (mobile-second-screen, embedded widgets, kiosk views) will hit the same trap. A 30-line `static/csrf-htmx.js` extracted from base.html is one-time cost; the Playwright regression test prevents recurrence via DOM-level coverage. Total scope ~2–3 hours including the audit sweep.

### 2026-04-25T11:50:04Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** This bug is recurrence-prone. Any future standalone template (mobile-second-screen, embedded widgets, kiosk views) will hit the same trap. A 30-line `static/csrf-htmx.js` extracted from base.html is one-time cost; the Playwright regression test prevents recurrence via DOM-level coverage. Total scope ~2–3 hours including the audit sweep.

### 2026-04-25T11:51:10Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** This bug is recurrence-prone. Any future standalone template (mobile-second-screen, embedded widgets, kiosk views) will hit the same trap. A 30-line `static/csrf-htmx.js` extracted from base.html is one-time cost; the Playwright regression test prevents recurrence via DOM-level coverage. Total scope ~2–3 hours including the audit sweep.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-122854f1
- **Timestamp:** 2026-06-02T14:57:34Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -s -o /dev/null -w "%{http_code}
" -X POST "$(bin/fw watchtower url)/api/task/T-1447/toggle-ac" -d "line=5" | grep -q "^403$"`
### 2026-04-25T11:51:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
