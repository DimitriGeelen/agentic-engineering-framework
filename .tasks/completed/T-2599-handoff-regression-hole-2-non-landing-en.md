---
id: T-2599
name: "Handoff regression hole 2: non-landing entries (history/bookmark, no nonce)
  still trigger poisoned restore — server-side 302 nonce-mint on /designer/app"
description: >
  Handoff regression hole 2: non-landing entries (history/bookmark, no nonce) still
  trigger poisoned restore — server-side 302 nonce-mint on /designer/app

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tests/web/test_designer_landing.py, web/blueprints/designer.py]
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
created: 2026-07-22T06:21:40Z
last_update: '2026-08-16T22:25:11Z'
date_finished: 2026-07-22T10:01:35Z
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
  - ts: '2026-07-22T06:30:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-22T06:30:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2599: Handoff regression hole 2: non-landing entries (history/bookmark, no nonce) still trigger poisoned restore — server-side 302 nonce-mint on /designer/app

## Context

Operator re-reported the handoff regression AFTER T-2596's fix went live. Access log evidence (watchtower.log 08:18:58, client 192.168.10.25): `GET /designer/app?load=/api/version?id%3Daef-dispatch-loop%26v%3D2` — NO `&t=` nonce and a non-landing URL encoding → the operator entered via browser history/bookmark (or stale cached markup), bypassing the T-2596 click-time nonce entirely, so the poisoned B1 autosave restore fired again. T-2596's counter only covers clicks through the CURRENT landing markup; any historical URL reproduces the bug forever.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `/designer/app?load=X` where X lacks a `t=` nonce → 302 redirect to the same route with `t=<ms-timestamp>` minted INSIDE the load value; requests already carrying `t=` serve the bundle directly (no redirect loop; F5-of-redirected-URL keeps its nonce so same-session edit restore still works)
- [x] The operator's EXACT logged URL shape (`/designer/app?load=/api/version?id%3Daef-dispatch-loop%26v%3D2`, mixed encoding) redirects correctly and the followed redirect loads the right diagram in a poisoned-autosave browser (Playwright live on :3001)
- [x] `/designer/app` with NO load param is untouched (bundle served directly — B1 last-draft restore by design); bundle bytes remain sha==pin (no bundle modification)
- [x] tests/web pin the redirect (nonce-less load → 302 w/ t= inside load; nonce'd load → 200 bundle; no-load → 200 bundle); full tests/web suite green
- [x] Regressed-entry-path re-test executed by the EXTERNAL termlink testing agent (converted from the [REVIEW] Human AC per operator delegation in chat 2026-07-22: "1 should be able to be exectured by our external termlink testing agent"): dispatch D-3338179-1784714255000 ran independently — 302-mint, nonce-in-Location, redirect-serves-bundle, bare-app-200-direct all PASS (evidence: `fw bus read T-2599 R-001`, 9/9). Browser-level equivalent (poisoned-autosave profile, operator's exact logged URL, correct diagram rendered incl. re-entry loop) verified via Playwright same day.

### Human
<!-- The original [REVIEW] AC ("works in YOUR browser via YOUR entry path") was
     converted to the Agent AC above per explicit operator delegation in chat
     2026-07-22. If the operator still hits a wrong map on any personal entry
     path, reopen: note the address-bar URL + rendered map; watchtower.log
     shows whether the 302 fired. -->

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

python3 -m pytest tests/web/test_designer_landing.py -q
out=$(curl -s -o /dev/null -w "%{http_code}" "$(bin/fw watchtower url)/designer/app?load=/api/version?id%3Daef-dispatch-loop%26v%3D2"); [ "$out" = "302" ]
out=$(curl -s -o /dev/null -w "%{http_code}" "$(bin/fw watchtower url)/designer/app"); [ "$out" = "200" ]

## Recommendation

**Recommendation:** GO

**Rationale:** The regression the operator hit twice (recurrences #3 and #4) is now closed at the only layer that covers every entry path — the server. T-2596's landing-card nonce only protected clicks through current markup; the access log proved the operator's re-entry was a nonce-less history/bookmark URL. The 302 nonce-mint on `/designer/app?load=` defeats the poisoned B1 autosave restore for ALL arrivals (history, bookmarks, cached pages, landing cards), while a redirected URL keeps its nonce so F5/same-session edit restore is intact and the no-load entry (deliberate last-draft behavior) is untouched. Bundle bytes unmodified (sha==pin). The in-bundle root cause (jump-in-place autosave under stale src) is escalated to 832 for 0.3.1.

**Evidence:**
- Operator's exact logged URL (`/designer/app?load=/api/version?id%3Daef-dispatch-loop%26v%3D2`) → 302 with nonce minted inside load; followed in a poisoned-autosave Playwright browser → correct diagram (metaId `aef-dispatch-loop`) rendered
- tests/web 116 passed, 2 skipped — includes new redirect pins in `tests/web/test_designer_landing.py`
- Live on Watchtower :3001 (commit 93cd1c6dd, serving process restarted and verified)
- No-load `/designer/app` → 200 bundle directly; nonce'd load → 200, no redirect loop

## RCA

**Symptom:** Operator re-reported "handoff still regressed" AFTER T-2596's landing-card nonce went live; their access-log entry (08:18:58, 192.168.10.25) shows a nonce-less `?load=...aef-dispatch-loop...` in a non-landing encoding — a browser-history/bookmark replay.

**Root cause:** T-2596's counter lives in the landing page markup, so it only protects clicks through the CURRENT page. Historical URLs (browser history, bookmarks, cached pages) replay nonce-less loads forever, and each replay re-triggers the bundle's B1 same-src poisoned restore.

**Why structurally allowed:** T-2596's re-verify exercised entry through the fixed markup only; nobody replayed a pre-fix URL. Entry-surface fixes must cover ALL entry paths, not the paths the current UI emits.

**Prevention:** the nonce mint moved server-side (302 on any nonce-less load) — entry-path-complete by construction; pinned by test_app_route_mints_nonce_for_nonceless_load.


<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
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

### 2026-07-22T06:21:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2599-handoff-regression-hole-2-non-landing-en.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5f296780
- **Timestamp:** 2026-07-22T10:01:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-22T10:01:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
