---
id: T-2629
name: "Overlay Slice A — /api/overlay endpoint: live task-state projection onto map carrier uids (aef:annotate payload)"
description: >
  Overlay Slice A — /api/overlay endpoint: live task-state projection onto map carrier uids (aef:annotate payload)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [designer, corpus, t2619-slice]
components: []
related_tasks: [T-2620]
arc_id: designer-corpus
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
created: 2026-07-27T18:01:48Z
last_update: 2026-07-27T18:09:20Z
date_finished: 2026-07-27T18:09:20Z
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
---

# T-2629: Overlay Slice A — /api/overlay endpoint: live task-state projection onto map carrier uids (aef:annotate payload)

## Context

Slice A of the T-2620 GO (operator decided 2026-07-27, /inception/T-2620): the no-external-dependency leg — a Watchtower endpoint emitting the wire-ready `aef:annotate` payload from live task state, per the IW-4 spike (docs/reports/T-2620-live-state-overlay-seam.md §IW-4). Slice B (postMessage wrapper) waits on 832's T-250 ratification and consumes this endpoint verbatim; Slice C (trigger surface) waits on the operator. Design note: the map's `state=` carriers under-determine the projection (two `captured` carriers split on horizon, three `started-work` carriers split on focus/partial-complete), so v0 ships a **map-specific projection profile** for aef-task-lifecycle, with every emitted node filtered against the map's live carriers so map edits can't produce phantom badges.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] tools/corpus_overlay.py: `build_payload(root, map_id)` returns `{type: "aef:annotate", map, generated, nodes: [{uid, badge, text, severity}]}` implementing the IW-4 projection profile for aef-task-lifecycle — captured×horizon→tl_create/tl_parked, started-work→tl_work, issues→tl_heal, work-completed-in-active/→tl_human_review (partial-complete), work-completed-in-completed/ 7-day window→tl_archive, focus badge from focus.yaml, stuck-age severity (info/warn>7d/alert>30d)
- [x] Emitted nodes are filtered against the map's live latest-version carriers (uid exists AND carries `aef:meta state=`) — pinned by test_phantom_uid_filter_drops_buckets_without_live_carrier
- [x] GET /api/overlay?id=aef-task-lifecycle serves the payload as application/json; unknown map id → 404 (also bad-id/path-traversal shapes); a map with no projection profile or no carriers → 200 with empty nodes list
- [x] Unit tests pin the projection rules (7 tests: routing, horizon split, archive window, severity thresholds, focus badge, phantom filter, contract shape) + web tests pin endpoint statuses (3 tests) — 10/10
- [x] Live endpoint responds in <2s (0.38s measured) and its tl_work badge equals the live started-work count (verification command pins the equality)

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

- [ ] [REVIEW] The v0 badge semantics read right to you — counts, "stuck >7d" wording, and the info/warn>7d/alert>30d severity thresholds (these thresholds are the tuning decision point you flagged in draft-trigger-handling; this is your first look at them live)
  **Steps:**
  1. Open http://192.168.10.107:3001/api/overlay?id=aef-task-lifecycle in a browser
  2. Sanity-check the JSON against your sense of the project: does tl_human_review's big number + "alert" match your review-backlog reality? Do "stuck >7d" and the 7d/30d thresholds feel like the right first cut?
  **Expected:** numbers plausible, wording clear, thresholds acceptable as v0 defaults (tuning stays open via the dismissal-feedback loop drafted in draft-trigger-handling)
  **If not:** note which threshold or wording is off — they're constants at the top of tools/corpus_overlay.py (ARCHIVE_WINDOW_DAYS / WARN_DAYS / ALERT_DAYS)

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

python3 -m pytest tests/unit/test_corpus_overlay.py tests/web/test_api_overlay.py -q
curl -s "$(bin/fw watchtower url)/api/overlay?id=aef-task-lifecycle" -o /tmp/.t2629.json && grep -q '"aef:annotate"' /tmp/.t2629.json
test "$(python3 -c "import json;print(next(n['badge'] for n in json.load(open('/tmp/.t2629.json'))['nodes'] if n['uid']=='tl_work'))")" = "$(grep -l '^status: started-work' .tasks/active/T-*.md | wc -l)"
test "$(curl -s -o /dev/null -w '%{http_code}' "$(bin/fw watchtower url)/api/overlay?id=no-such-map")" = "404"

## Recommendation

**Recommendation:** GO

**Rationale:** Slice A is live end-to-end with the exact payload shape Slice B will forward verbatim; the one [REVIEW] AC is the genuine operator call this slice surfaces for the first time — whether the v0 badge/severity semantics read right (the threshold-tuning decision point from draft-trigger-handling, now with live numbers to judge against).

**Evidence:**
- 10/10 tests (7 projection-rule pins incl. partial-complete routing + phantom-uid filter; 3 endpoint contract)
- Live: 200 in 0.38s, tl_work badge = live started-work count, 404 on unknown/bad ids
- Payload byte-shape matches the rail-197 contract 832 advised (`aef:annotate`, nodes[{uid,badge,text,severity}])
- Projection rules in exactly one place (tools/corpus_overlay.py), carriers read from the map's live latest version

## Evolution

### 2026-07-27 — carriers under-determine the projection

- **What changed:** the GO plan said "projection keyed on state carriers"; building it showed `state=` alone can't split tl_create/tl_parked (both captured) or tl_work/tl_human_review (both started-work) — the discriminators (horizon, active-vs-completed, focus) live in task frontmatter, not the map.
- **Plan impact:** v0 ships a map-specific projection profile (PROFILES registry in corpus_overlay.py) instead of a generic carrier walk; generic projection would need richer carrier attrs (e.g. a filter expression) — that's a future pair-draft contract question, not a v0 blocker.
- **Triggered:** nothing filed; noted in T-2620's artifact trail via this task.

## RCA

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

### 2026-07-27T18:01:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2629-overlay-slice-a--apioverlay-endpoint-liv.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2a3ec303
- **Timestamp:** 2026-07-27T18:09:24Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — tools/corpus_overlay.py: `build_payload(root, map_id)` returns `{type: "aef:annotate", map, generated, nodes: [{uid, badge, text, severity}]}` implementing the IW-4 projection profile for aef-task-lif
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tools/corpus_overlay.py in: tools/corpus_overlay.py: `build_payload(root, map_id)` returns `{type: "aef:annotate", map, generated, nodes: [{uid, badge, text, severity}]}` impleme`

### 2026-07-27T18:09:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
