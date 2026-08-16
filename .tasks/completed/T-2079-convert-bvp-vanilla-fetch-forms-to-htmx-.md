---
id: T-2079
name: "convert /bvp vanilla-fetch forms to htmx — eliminate native-submit-to-API-URL
  bug"
description: >
  convert /bvp vanilla-fetch forms to htmx — eliminate native-submit-to-API-URL bug

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [web/blueprints/bvp.py, web/templates/bvp.html]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-28T20:18:42Z
last_update: '2026-08-16T22:24:52Z'
date_finished: 2026-05-28T20:29:30Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:52Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2079: convert /bvp vanilla-fetch forms to htmx — eliminate native-submit-to-API-URL bug

## Context

User-reported: submitting the **Add free driver** form on `/bvp` ended on a `Method Not Allowed` page at `/api/bvp/driver/add`. Server log (`.context/working/watchtower.log`) shows the POST actually succeeded (200) — the 405 came from a follow-up **GET** on the API URL one second later.

Root cause: three forms on `/bvp` use vanilla `fetch()` + `setTimeout(location.reload, 800)` instead of htmx. They also keep a working native `method="POST" action="/api/bvp/..."` fallback. When the JS fails to attach (script error elsewhere on the page, double-click race, or any path that lets the native submit fire), the browser navigates to the JSON API URL. Refresh → GET → 405.

T-1964 (driver-add form) + T-1965 (per-row remove) + the prior commit-weights form (T-1929) all ship this same pattern. htmx is the codebase standard (`_review_acs.html`, `approvals.html`, `_pins.html`); CSRF auto-injects via `web/static/csrf-htmx.js`.

## Acceptance Criteria

### Agent
- [x] `web/templates/bvp.html` — `#bvp-driver-add-form` uses `hx-post="/api/bvp/driver/add"` with `hx-target` + `hx-swap`; the legacy `method="POST" action="..."` attribute pair is removed so native submit cannot fire.
- [x] `web/templates/bvp.html` — `#bvp-commit-form` uses `hx-post="/api/bvp/commit-weights"` with `hx-target` + `hx-swap`; native `method/action` removed.
- [x] `web/templates/bvp.html` — per-row `.dr-remove-btn` buttons use `hx-post="/api/bvp/driver/remove?driver=…"` + `hx-prompt` (rationale collected via browser prompt → `HX-Prompt` header); the vanilla `<script>` IIFE that hooked their `click` is removed.
- [x] The three vanilla `<script>` IIFEs that built `fetch()` calls + `window.location.reload()` are removed (driver-add + remove fully gone; commit-form's IIFE remains but only as `htmx:configRequest` hook for change-diff/rationale validation — no `fetch()` left); on success, htmx triggers reload via `hx-on::after-request="if(event.detail.successful)setTimeout(()=>location.reload(),800)"` on each form/button.
- [x] `web/blueprints/bvp.py` returns a small HTML fragment (success message) + `HX-Trigger: bvpReload` on 200 when `HX-Request` header is present, and returns plain-text error in body on 4xx so htmx renders it in the target div (L-270 — same error visibility on htmx + plain paths). CLI/API callers keep JSON envelope.
- [x] CSRF still works end-to-end (X-CSRF-Token injected by `csrf-htmx.js`) — verified by curl smoke tests (driver-add + driver-remove both returned 200 with HTML fragment + HX-Trigger header, using the meta-tag CSRF token).
- [x] Playwright test `tests/playwright/test_bvp_form_htmx.py` asserts (a) no native `method="POST" action="/api/bvp/..."` remains, (b) each form/button carries the right `hx-post`, (c) submitting the add form does NOT navigate the page URL away from `/bvp`. 5/5 pass. Pre-existing `test_bvp_sliders.py` + `test_bvp_scatter.py` (15 tests) still pass — no regression.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->
- [ ] [REVIEW] Add and Remove a free driver on `/bvp` end-to-end via the UI, then refresh the page; URL stays on `/bvp` (no JSON dump, no 405) and the driver list reflects the change.
  **Steps:**
  1. Open `http://192.168.10.107:3000/bvp` in browser
  2. Fill the **Add free driver** form (name, weight, rationale ≥30 chars). Submit.
  3. Wait for reload. Note the page URL.
  4. Click **Remove** on the driver you just added. Confirm + supply rationale.
  5. Wait for reload. Note the URL again.
  6. Open dev-tools Network tab and re-submit a deliberately-bad form (weight=0, rationale too short). Confirm error renders inline on the page (not as a navigation).
  **Expected:** After every submit URL remains `/bvp` (or `/bvp?...`); driver appears, then disappears; error message renders inline.
  **If not:** Screenshot the URL bar + the rendered page and note which step failed.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# T-2079 specific (L-387 safe: capture-then-grep, never `cmd | grep -q` under pipefail).
# Anti-pattern is gone: no <form method="POST" action="/api/..."> remains in bvp.html.
out=$(grep -n 'method="POST" action="/api/' web/templates/bvp.html 2>&1 || true); [ -z "$out" ]
# htmx took over: all three POSTs are hx-post (driver-add, commit-weights, remove).
out=$(grep -c 'hx-post="/api/bvp/' web/templates/bvp.html); [ "$out" -ge 3 ]
# Routes still POST-only on server side (sanity).
out=$(curl -sS -X OPTIONS "$(bin/fw watchtower url)/api/bvp/driver/add" -i 2>&1); echo "$out" | grep -qi "Allow:.*POST"
# Playwright pin (T-971): structural + behavioural guards for /bvp form htmx-isation.
FW_TEST_PORT=3000 PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework python3 -m pytest tests/playwright/test_bvp_form_htmx.py -q > /tmp/.pw-2079.log 2>&1; grep -q "5 passed" /tmp/.pw-2079.log

## RCA

**Symptom:** Human submitted Add-driver form on `/bvp`; ended on `/api/bvp/driver/add` showing **"Method Not Allowed"**. Server log shows the POST itself returned 200 — the 405 is from a GET on the same URL one second later.

**Root cause:** Three `/bvp` forms use vanilla `<script>` `fetch()` + `setTimeout(window.location.reload, 800)` while ALSO declaring `method="POST" action="/api/bvp/..."` on the `<form>`. If anything prevents the JS submit handler from attaching (script error earlier on the page, double-click race against unhandled handler, browser eats the listener), the native form submit fires and the browser navigates to the JSON API URL. The reload (or any user refresh) then issues a GET to that URL → 405.

**Why structurally allowed:** The codebase standard is htmx (`_review_acs.html`, `approvals.html`, `_pins.html` — `csrf-htmx.js` injects X-CSRF-Token automatically). T-1929 (commit-weights), T-1964 (driver-add), T-1965 (driver-remove) each introduced vanilla-fetch forms with native action attributes as a working fallback, missing that the fallback *is* the failure mode. No lint catches the anti-pattern (`<form method="POST" action="/api/...">` paired with a JS handler that calls preventDefault).

**Prevention:** Codebase convention already exists ("htmx for any POST" — `_review_acs.html`, `approvals.html`). After this fix, follow-up task should add a reviewer pattern that flags `<form method="POST" action="/api/...">` co-located with a `<script>` block in the same template — anti-pattern for the same class. (Out of scope for this task; filed as L-NEW or follow-up task at close.)
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

**Recommendation:** GO (Human eyes-on the UI for the [REVIEW] AC, then close)

**Rationale:**

Bug fully closed: three `/bvp` POST surfaces (driver-add, commit-weights, per-row remove) are now driven exclusively by htmx. The native `<form method="POST" action="/api/bvp/...">` attribute pair — the root-cause structural flaw — is absent from the rendered DOM. Any JS error elsewhere on the page can no longer cause the browser to navigate to a JSON API URL, because there is no native form action to fall back to. CSRF continues to work via the codebase-standard `csrf-htmx.js` (X-CSRF-Token auto-injected on `htmx:configRequest`).

CLI/API compatibility preserved: the three endpoints branch on `HX-Request` header and return HTML for htmx callers, JSON for plain callers. Existing tests pinning the JSON shape (`test_bvp_sliders.py`) all still pass (15/15).

**Evidence:**

- `web/templates/bvp.html` — `grep -c 'hx-post="/api/bvp/'` returns **3** (driver-add, commit-weights, remove); `grep 'method="POST" action="/api/bvp'` returns **empty**.
- `web/blueprints/bvp.py` — three handlers updated with `if request.headers.get("HX-Request"):` branch returning `text/html` + `HX-Trigger: bvpReload`; CLI/API callers keep `application/json` envelope.
- Curl smoke tests (this session):
  - `POST /api/bvp/driver/add` with `HX-Request: true` → 200, `Content-Type: text/html`, `HX-Trigger: bvpReload`, body `✓ OK: added F2 't2079probe' weight=1 Reloading…`
  - `POST /api/bvp/driver/remove?driver=F2` with `HX-Request: true` + `HX-Prompt: "..."` → 200, `Content-Type: text/html`, `HX-Trigger: bvpReload`, body `✓ OK: removed driver F2 Reloading…`
- Playwright suite `tests/playwright/test_bvp_form_htmx.py` — **5/5 pass** (no native action, each form/button has `hx-post`, submit-doesn't-navigate guard).
- Regression: `test_bvp_sliders.py` + `test_bvp_scatter.py` — **15/15 pass** (no break).

**Open follow-ups (out of scope, file separately if pursued):**
- Reviewer pattern that flags `<form method="POST" action="/api/...">` co-located with a `<script>` block — would catch the next instance at static-scan time. Captured in RCA §Prevention; one-task follow-up if the human wants the structural sweep.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-28T20:18:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2079-convert-bvp-vanilla-fetch-forms-to-htmx-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d6ffa155
- **Timestamp:** 2026-06-02T15:01:02Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#5 (Agent)** — `web/blueprints/bvp.py` returns a small HTML fragment (success message) + `HX-Trigger: bvpReload` on 200 when `HX-Request` header is present, and returns plain-text error in body on 4xx so htmx render
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/bvp.py in: `web/blueprints/bvp.py` returns a small HTML fragment (success message) + `HX-Trigger: bvpReload` on 200 when `HX-Request` header is present, and retu`
### 2026-05-28T20:29:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
