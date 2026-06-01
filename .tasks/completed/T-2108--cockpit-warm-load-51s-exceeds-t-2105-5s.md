---
id: T-2108
name: "/ cockpit warm-load 5.1s exceeds T-2105 5s cap — T-1954 cache pattern needed"
description: >
  Discovered by T-2105 all-routes load-time guard. / (cockpit/home) warm-cache load
  measured at 5137ms — just over the 5000ms global cap. Cockpit aggregates everything
  (system health, recent commits, traceability, knowledge counts). Apply T-1954/T-2102
  mtime-keyed cache pattern in web/blueprints/cockpit.py. Currently held under 7000ms
  KNOWN_SLOW elevated cap in test_all_routes_load_time.py — fix closes that exemption.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [arc-007, perf, test-infra, T-1954-cluster, watchtower, cockpit]
components: [web/blueprints/cockpit.py, web/blueprints/timeline.py]
related_tasks: [T-2105, T-1954, T-2102, T-2106, T-2107]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T23:00:22Z
last_update: 2026-05-30T07:38:38Z
date_finished: 2026-05-30T07:11:17Z
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
  - ts: '2026-05-29T23:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-29T23:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2108: / cockpit warm-load 5.1s exceeds T-2105 5s cap — T-1954 cache pattern needed

## Context

Discovered by T-2105 all-routes load-time guard: `/` (cockpit) warm-cache load = 5137ms (exceeds the 5000ms global cap; currently held under a 7000ms KNOWN_SLOW elevated cap with T-2108 as the tracking task). Cockpit aggregates everything — likely multiple slow scans (tasks, approvals, observations, BVP). Apply T-1954/T-2102/T-2106/T-2107 mtime-keyed cache pattern to whichever aggregator is the hot path. After fix `/` should be under the global 5000ms cap and the KNOWN_SLOW entry in `tests/playwright/test_all_routes_load_time.py` is removed.

## Acceptance Criteria

### Agent
- [x] Profile `/` cockpit to identify the hot aggregator(s) (likely a task/approval/observation walker without an mtime cache).
- [x] Apply the T-1954-pattern per-file mtime cache to the hot path(s) — pattern documented in T-1954 / T-2102 / T-2106 / T-2107 RCAs.
- [x] `/` warm-cache HTTP load < 5000ms (verified by direct curl-timing on live Watchtower, post-TTL idle).
- [x] `KNOWN_SLOW` dict in `tests/playwright/test_all_routes_load_time.py` no longer contains `/`; Playwright `test_route_load_time_bounded[/]` PASSES at global 5000ms cap.
- [x] No semantic change — cockpit renders identical task/approval/observation lists pre- and post-fix.

### Human

- [x] [REVIEW] `/` cockpit renders correctly post-cache + dedupe refactor
  **Steps:**
  1. Open http://192.168.10.107:3000/ in browser
  2. Verify the cockpit shows: Action Required summary (Tier 0/GO/Human AC counts), Needs Decision/Framework Recommends/Opportunities/Work Queue cards, System Health panel, Recent Activity, and Human AC tasks list
  3. Touch an active task: `touch .tasks/active/T-2107-search-warm-load-67s-exceeds-t-2105-5s-c.md` then refresh — that task should appear/update in the Human AC list (cache invalidation by mtime works)
  **Expected:** Same layout, same counts as before refactor (semantic identity already verified by Agent AC #5 — 146 tasks identical, action_summary identical).
  **If not:** Note which widget differs and reopen with details — likely a `_HUMAN_VERIFY_CACHE` mtime-key divergence or a missed-pass-through in `get_action_summary`.

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

python3 -c "from web.blueprints.cockpit import get_human_verify_tasks, get_action_summary; r1=get_human_verify_tasks(); r2=get_human_verify_tasks(); assert r1 == r2, 'human_verify non-idempotent'; a1=get_action_summary(); a2=get_action_summary(human_verify=r1); assert a1 == a2, 'action_summary diverges between no-arg and pre-computed'"
grep -q "_HUMAN_VERIFY_CACHE" web/blueprints/cockpit.py
grep -q "T-2108 (/) CLOSED" tests/playwright/test_all_routes_load_time.py
out=$(grep -A2 "KNOWN_SLOW: dict" tests/playwright/test_all_routes_load_time.py); echo "$out" | grep -vq '"/"'
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

**Symptom:** T-2105 all-routes load-time guard measured `/` (cockpit) warm-load at 5137ms — exceeded the 5000ms global cap. Held under elevated 7000ms `KNOWN_SLOW` cap with T-2108 as tracker. Profiling showed steady-state warm hit ~2.5s, post-TTL-expiry hit ~5s.

**Root cause:** TWO compounding issues in `web/blueprints/cockpit.py`:

1. **`get_human_verify_tasks()` walked all 171 active task files on every cockpit render** — read text, parsed frontmatter, parsed ACs. Cold cost ~835ms. Uncached.
2. **`get_action_summary()` called `get_human_verify_tasks()` again** — so the 171-task walk ran *twice* per cockpit render. Cold cost ~857ms (mostly the recursive call).

Combined: ~1.7s of duplicate work per cockpit render, plus the underlying TTL-only outer caches (`_load_all_sessions`, `_get_approval_qr`, `get_all_task_metadata`) that occasionally flushed and added 5-8s rebuild cost.

**Why structurally allowed:** Same class as T-1954/T-2102/T-2106/T-2107 — TTL-only caching design. The duplicate-call leg (`get_action_summary` re-calling `get_human_verify_tasks`) was a pure missing-parameter-passing pattern: each helper independent and pure, but together did the same walk twice. Code review wouldn't catch it; profiling did.

**Prevention:** Already wired by T-2105 (`tests/playwright/test_all_routes_load_time.py`). Removing `/` from `KNOWN_SLOW` closes the elevated cap — the global 5000ms cap now enforces. Any future regression in `_HUMAN_VERIFY_CACHE` invalidation or in the `human_verify` pass-through fails the test. 5th application of T-1954 pattern in 30 days — OBS-039 promotion to `web/shared.py` is now well over the threshold.

## Evolution

### 2026-05-30 — TTL caches AND duplicate walks compound

- **What changed:** Filing assumed a single hot path; reality was a double-walk pattern (get_action_summary calling get_human_verify_tasks recursively) on top of a non-cached walk-all-tasks helper. The dedupe leg was actually a bigger immediate win than the cache leg (50% of warm cost).
- **Plan impact:** Scope grew slightly — both the cache and the dedupe shipped together. ACs unchanged (just "apply cache pattern" captured both legs).
- **Triggered:** None new. Confirms OBS-039 threshold crossed (5th consumer). _knowledge_counts (613ms warm) remains uncached but not on the critical path post-fix.

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

## Recommendation

**Recommendation:** GO

**Rationale:** Cockpit warm load dropped 2.5s → 0.7s (3.6× speedup) and post-TTL load dropped 5.0s → 3.2s — both legs now within the global 5000ms cap. Two compounding wins shipped together: (1) `_HUMAN_VERIFY_CACHE` per-file mtime cache for the 171-task active-walk, (2) dedupe — `get_action_summary` now accepts a pre-computed `human_verify` so the cockpit doesn't run the walk twice per render. Semantic identity verified — 146 tasks identical, `action_summary` identical with or without pre-computed argument. Reviewer PASS, zero findings. Playwright `test_route_load_time_bounded[/]` passes at the global 5000ms cap with `/` removed from KNOWN_SLOW. Only the visual sanity check on cockpit remains.

**Evidence:**
- Warm load (steady state): **2522ms → 712ms** (~3.6× speedup, was the steady-state Playwright measurement)
- Post-TTL idle (was the regression spike): **4964ms → 3234ms** (under 5000ms cap)
- Playwright `[/]` PASS at 5000ms global cap (was held under 7000ms KNOWN_SLOW)
- Reviewer T-2108 PASS, no findings
- Semantic identity: 146 tasks identical, action_summary identical (no-arg vs pre-computed)
- 5th application of T-1954 pattern in 30 days — OBS-039 promotion threshold strongly crossed

**Review URL:** http://192.168.10.107:3000/review/T-2108

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

### 2026-05-29T23:00:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2108--cockpit-warm-load-51s-exceeds-t-2105-5s.md
- **Context:** Initial task creation

### 2026-05-30T06:53:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9d41706e
- **Timestamp:** 2026-05-30T07:11:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-30T07:11:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
