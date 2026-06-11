---
id: T-2309
name: "Watchtower /inception/<T>/decide returns opaque 403 on stale CSRF + theme JS
  leaks into error body (cross-project bug P-003 from 100-Video-riper)"
description: >
  Watchtower /inception/<T>/decide returns opaque 403 on stale CSRF + theme JS leaks
  into error body (cross-project bug P-003 from 100-Video-riper)

status: started-work
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-06-10T11:19:46Z
last_update: '2026-06-11T16:00:03Z'
date_finished:
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
cost_estimate_proposed:
  - ts: '2026-06-10T11:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-10T11:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=4 (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=4 (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2309: Watchtower /inception/<T>/decide returns opaque 403 on stale CSRF + theme JS leaks into error body (cross-project bug P-003 from 100-Video-riper)

## Context

Cross-project pickup P-003 filed by `/opt/100-Video-riper-and-translation-app` agent
on 2026-06-09. The 403 returned by `web/app.py:csrf_protect` (line 120) — fired when
a long-open form's embedded CSRF token goes stale — flows through the generic
`@app.errorhandler(403)` (line 368) which renders `_error.html` with `error_message=
"CSRF token missing or invalid"`. Result: indistinguishable from a real permission
denial. No reload guidance. The bug is sovereignty-critical because this is the LAST
gate on the human's go/no-go decision — they get stuck on a governance action with
no actionable next step.

P-003 also reports `<script>` (theme init from base wrapper) rendering as visible text
in the error body — this may be specific to the consumer's wrapper template. Scope this
task's slice 1 to the CSRF-distinguishable error message + reload guidance.

This is sliced because the full fix (per P-003 recommendations) is three orthogonal
legs:
- **Slice 1 (this task):** Detect CSRF token failures in the 403 handler; render a
  distinct, friendly "session expired — reload and resubmit" message with a Reload
  button instead of the generic Forbidden page.
- **Slice 2 (sibling task, captured+later):** Add `csrf-htmx.js` — listens for htmx
  response 403/CSRF, auto-refetches a fresh token, offers one-click resubmit.
- **Slice 3 (sibling task, captured+later):** Investigate whether `<script>` rendering
  as text in the error body reproduces on this Watchtower (vs. consumer-specific
  wrapper); fix at root if so.

Source bug envelope (this very task's origin):
`.context/pickup/auto-deferred/P-003-bug-report.yaml` (will be moved to
`.context/pickup/processed/` once this slice ships).

## Acceptance Criteria

### Agent
- [x] `web/app.py:forbidden` (line 368-379) distinguishes CSRF failures from generic 403s. When `e.description` matches `"CSRF token"`, the handler renders a CSRF-specific template; otherwise the existing `_error.html` flow is unchanged.
- [x] New template `web/templates/_error_csrf.html` ships with: a clear "Session expired" heading, a one-sentence explanation (page held open across a token change), a copy of the recommended next step ("Reload the page and resubmit your decision"), and a Reload button (`<a href="...">` or `<button onclick="location.reload()">`).
- [x] The CSRF error message is operator-friendly — not "403 Forbidden" or "CSRF token missing or invalid" as the headline. The technical detail (CSRF/token) MAY appear in a smaller secondary line for operator diagnosis but MUST NOT be the prominent text.
- [x] An integration test in `tests/integration/test_csrf_error_template.py` (or extend existing) verifies: a POST to `/inception/T-XXX/decide` with no `_csrf_token` returns 403 AND the response body contains "Session expired" (or equivalent friendly text), NOT just "Forbidden", AND contains a Reload action.
- [x] Existing 403 paths that are NOT CSRF-related (anti-CSRF abort on `/api/*` without token, any other `abort(403)` site) still render the original `_error.html` (regression check: greppable in template logic).
- [x] Sibling tasks for Slice 2 (csrf-htmx.js auto-refresh) and Slice 3 (script-leak investigation) are filed `captured` with `horizon: later` and unique T-IDs noted in this task's Updates section.

### Human

_Sibling slices filed: **T-2310** (Slice 2 — csrf-htmx.js auto-refresh, captured/horizon:later) and **T-2311** (Slice 3 — script-leak investigation, captured/horizon:later)._

- [ ] [REVIEW] Friendly CSRF error message reads cleanly to a real operator stuck on inception decide
      **Steps:**
      1. Open Watchtower at `bin/fw watchtower url` → `/inception/T-2303` (or any pending inception)
      2. Wait for ≥5 minutes (or restart Watchtower in another tab) to invalidate the session token
      3. Click the Decide button (GO/NO-GO/DEFER + rationale)
      **Expected:** A page that says "Session expired" with a Reload button — NOT a bare "403 Forbidden" page. Reload then succeeds.
      **If not:** Note exact wording shown + whether Reload button works + screenshot if layout is broken.

## Recommendation

**Recommendation:** GO

**Rationale:** Slice 1 (the friendly Session-expired template + Reload button) ships
the minimum-viable fix for P-003's sovereignty-critical surface — the inception
decide page no longer dead-ends operators on stale-token failures. Integration test
pinned + live curl shows the friendly headline and the Reload action. Generic 403
paths unchanged (regression test passes). The two follow-on legs (htmx auto-refresh
T-2310, script-leak investigation T-2311) are filed captured/horizon:later for
later scoping.

**Evidence:**
- `web/app.py:forbidden` branches on `description.startswith("CSRF token")` →
  renders `_error_csrf.html` (commit: this task's commit, see git log)
- Live curl against running Watchtower:
  ```
  curl -X POST http://192.168.10.107:3000/inception/T-2303/decide -d 'decision=defer&rationale=x'
  → HTTP 403
  → <title>Session expired — Agentic Engineering Framework</title>
  → <h1>Session expired</h1>
  → <button onclick="location.reload()" class="primary">Reload page</button>
  ```
- `tests/integration/test_csrf_error_template.py`: 3/3 PASS
  - `test_csrf_403_renders_session_expired_template`
  - `test_generic_403_unchanged_for_non_csrf_path`
  - `test_csrf_template_includes_technical_detail_for_diagnosis`
- Sibling slices filed: T-2310 (Slice 2 horizon:later), T-2311 (Slice 3 horizon:later)
- P-003 envelope moved to `.context/pickup/processed/` once Slice 1 ships.

The single Human [REVIEW] AC asks the operator to live-test the recovery flow —
they trigger a stale-token state and confirm the new template reads cleanly. The
agent has all the structural evidence; only the operator's UX taste-call remains.
-->

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
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
test -f web/templates/_error_csrf.html
python3 -m pytest tests/integration/test_csrf_error_template.py -x -q
bin/fw reviewer T-2309 > /tmp/.t2309-review.out 2>&1 && grep -qE "Overall:.*PASS" /tmp/.t2309-review.out

## RCA

**Symptom:** Operator clicked the inception Decide button on `/inception/<T>`; got a bare
"403 Forbidden" page with no guidance on how to recover. Server log confirmed HTTP 403
on `/inception/T-002/decide` after earlier 200s in the same session. Recoverable by
reload (which mints a fresh CSRF token), but the page doesn't say so. Indistinguishable
from a real permission denial. P-003 also reported `<script>` (theme init) rendering as
visible text in the error body — scoped separately (Slice 3).

**Root cause:** `web/app.py:csrf_protect` (line 102-120) aborts with `abort(403,
description="CSRF token missing or invalid")` when the form's embedded `_csrf_token`
no longer matches `session["_csrf_token"]`. The token is minted once per session at
page render and embedded in the form; if the page is held open across edits, a
Watchtower restart, or a session change, the embedded token goes stale. The
`@app.errorhandler(403)` (line 368) doesn't distinguish CSRF failures from other 403s,
so it renders the same generic `_error.html` with `error_message=str(e.description)`.
The technical CSRF detail leaks into the prominent text; no Reload guidance is offered.

**Why structurally allowed:** No layer between `csrf_protect` raising and the generic
error template noticed that this 403 has a known, recoverable cause. The 403 handler
treats all forbidden cases identically — appropriate for genuine permission denials
but wrong for transient session-bound failures. Sovereignty-critical actions (inception
decide is the canonical example) get the same opaque UX as a quick api/* 403.
Discovered cross-project, in field — no test pinned the friendly-error contract.

**Prevention:**
1. **Direct fix (Slice 1):** Branch in 403 handler on `e.description` matching CSRF text
   → render `_error_csrf.html` with friendly message + Reload action.
2. **Test pin:** integration test asserts response body contains "Session expired"
   (or equivalent), Reload action, AND does NOT prominently show "Forbidden" /
   "CSRF token missing or invalid" as the headline.
3. **Slice 2 follow-on:** htmx CSRF auto-refresh — listens for 403 + auto-refetches
   token + offers one-click resubmit. Captures the class for all htmx-driven forms,
   not just inception decide. Filed sibling task.
4. **Slice 3 follow-on:** Investigate `<script>` text-leak — may be consumer-wrapper
   specific; if it reproduces here, fix at the template loader.

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

### 2026-06-10T11:19:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2309-watchtower-inceptiontdecide-returns-opaq.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e053f368
- **Timestamp:** 2026-06-10T11:30:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - AC-verify-mismatch @ AC#1 (Agent)

### 2026-06-10T11:31:24Z — status-update [task-update-agent]
- **Change:** owner: agent → human
