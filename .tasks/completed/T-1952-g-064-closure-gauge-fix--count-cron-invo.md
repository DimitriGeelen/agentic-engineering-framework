---
id: T-1952
name: "G-064 closure gauge fix — count cron invocations not dispatch rows + idempotency-saturation
  guard"
description: >
  tools/g064-readiness.py counts dispatch.jsonl rows matching cron-time window, but
  a correctly-idempotent v0.5 cron fire emits zero rows when prior manual runs saturated
  the 7-day idempotency window. Gauge structurally cannot detect autonomous firing
  under this condition. Fix: read .context/working/escalation-drift-LATEST-v0.5.yaml
  'generated' field + skipped_idempotent count as alternate evidence of cron-firing.
  Also: document recommendation to not run v0.5 manually for closure to progress.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/unit/test_g064_readiness.py, tools/g064-readiness.py]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T10:18:17Z
last_update: 2026-05-20T10:25:14Z
date_finished: 2026-05-20T10:25:14Z
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
  - ts: '2026-05-20T10:18:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-1952: G-064 closure gauge fix — count cron invocations not dispatch rows + idempotency-saturation guard

## Context

`tools/g064-readiness.py` counts dispatch.jsonl rows matching the cron-time window (5:33 UTC ± 5 min) as evidence of autonomous cron firing. But the escalation-scan-v0.5 cron is idempotent over a 7-day window: when prior manual runs saturated the window (as happened post-2026-05-05), the cron correctly emits *zero* dispatch rows on each fire. Net effect: cron has been firing on 2026-05-19 + 2026-05-20 per syslog, but gauge reads `cron_firings: 0` — structural blindness identical to G-064's original signature (substrate works, observability surface lies).

Fix: read `.context/working/escalation-drift-LATEST-v0.5.yaml` `generated` field as alternate cron-fire evidence. The v0.5 yaml is rewritten on every invocation regardless of dispatches; its timestamp is a reliable cron-fire heartbeat.

Origin: G-064 readiness assessment 2026-05-20 surfaced the issue (gauge reports `cron_firings: 0` while syslog shows 2 fires).

## Acceptance Criteria

### Agent
- [x] `tools/g064-readiness.py` reads `.context/working/escalation-drift-LATEST-v0.5.yaml` and extracts `generated` timestamp + `dispatched` + `skipped_idempotent` counts
- [x] Assessment dict gains 4 new fields: `v0_5_last_generated`, `v0_5_last_dispatched`, `v0_5_last_skipped_idempotent`, `v0_5_date_added_to_cron`
- [x] Human render block shows "v0.5 LATEST: <ISO>" line with dispatched/skipped breakdown when file exists
- [x] Verdict logic extends: if cron_firing_dates < threshold BUT v0.5 LATEST exists and its `generated` timestamp falls within cron-time window, treat that date as a cron-firing-evidence date (counted toward threshold)
- [x] Header/docstring updated to document idempotency-saturation case + the two cron-fire evidence sources (dispatch rows + v0.5 LATEST timestamp) + KNOWN BUG note pointing at T-1953 for the TZ mismatch
- [x] New unit test in `tests/unit/test_g064_readiness.py` covers idempotency-saturated case: zero dispatches + v0.5 LATEST present → cron-firing-date counted (`test_v0_5_latest_in_window_adds_cron_date`)
- [x] New unit test covers backward compat: no v0.5 LATEST → old behavior unchanged (`test_v0_5_latest_missing_backward_compat`)
- [x] All existing tests still pass (21/21: 13 pre-existing + 8 new)

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

python3 -m pytest tests/unit/test_g064_readiness.py -q 2>&1 | tail -3 | grep -q "21 passed"
out=$(python3 tools/g064-readiness.py 2>&1); echo "$out" | grep -q "v0.5 LATEST:"
out=$(python3 tools/g064-readiness.py --json 2>&1); echo "$out" | python3 -c "import sys, json; d=json.loads(sys.stdin.read()); assert 'v0_5_last_generated' in d and 'v0_5_date_added_to_cron' in d, 'new keys missing'"

## RCA

**Symptom:** `python3 tools/g064-readiness.py` reports `cron_firings: 0` even though syslog shows the v0.5 cron firing daily at 05:33 local (UTC 03:33).

**Root cause:** Two interacting issues:
  1. **Idempotency saturation:** the v0.5 cron is idempotent over 7 days. When manual verification runs (2026-05-05/14/15/18) saturated the skip window, the cron correctly emits zero dispatches per fire — but the gauge only counts dispatch.jsonl rows as cron-fire evidence. Net: cron fires correctly, gauge sees nothing.
  2. **TZ mismatch (separate bug, T-1953):** `CRON_HOUR_UTC=5` assumes the crontab `33 5 * * *` runs at UTC 05:33. Cron actually interprets it as LOCAL time; on +02:00 hosts the real UTC fire is 03:33 — outside the 05:33±5 min window. Even when dispatches DO happen, they can never be flagged as cron-source.

**Why structurally allowed:** Both bugs are observability surfaces lying about substrate state — the exact G-064 signature. Original gauge was built before idempotency was added (T-1727) and before TZ-aware deployment was validated. No test exercised "cron fires and writes v0.5 yaml without emitting dispatches".

**Prevention (this task):**
  - v0.5 LATEST `generated` field now read as alternate cron-fire evidence
  - Saturation diagnostic surfaced in human output (recommends not running v0.5 manually)
  - 8 new tests pin the fallback behaviour + backward compat
  - TZ mismatch documented in docstring + filed as T-1953 (separate scope)

## Evolution

### 2026-05-20 — TZ bug surfaced during testing
- **What changed:** Adding the v0.5 LATEST fallback exposed a deeper bug — `CRON_HOUR_UTC=5` doesn't match where the cron actually fires (UTC 03:33 on local +02:00 hosts). Pre-existing bug, structurally invisible until the v0.5 fallback made the cron-window check fail visibly.
- **Plan impact:** Original AC scope (v0.5 LATEST fallback) unchanged; TZ fix is bigger (refactor `_is_cron_firing` + TZ-portability test refactor).
- **Triggered:** T-1953 filed with full RCA. Not bundled with T-1952 — one-task-one-deliverable.

## EOF marker

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

### 2026-05-20T10:18:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1952-g-064-closure-gauge-fix--count-cron-invo.md
- **Context:** Initial task creation

### 2026-05-20T10:18:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-59f3e74e
- **Timestamp:** 2026-06-02T15:00:38Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 26
     - evidence: `python3 -m pytest tests/unit/test_g064_readiness.py -q 2>&1 | tail -3 | grep -q "21 passed"`
### 2026-05-20T10:25:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
