---
id: T-2634
name: "overlay profile #2 — aef-inception-flow (uid seed + go/no-go projection)"
description: >
  overlay profile #2 — aef-inception-flow (uid seed + go/no-go projection)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
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
created: 2026-07-27T20:31:42Z
last_update: 2026-07-27T20:39:30Z
date_finished: 2026-07-27T20:39:30Z
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

# T-2634: overlay profile #2 — aef-inception-flow (uid seed + go/no-go projection)

## Context

Extends the T-2620 overlay observation layer (Slice A endpoint T-2629 + Slice B
wrapper T-2630, live on 0.7.1) from one profiled map to two. Deliverable = live
badges on `aef-inception-flow`, headline signal being the **go/no-go decision
queue** (inceptions with a filed Recommendation awaiting the operator) badging
the `if_gw_outcome` gateway — the same actionable data /approvals holds, now
visible in the map.

SCOPE CORRECTION at start-work: the map is ALREADY fully uid-seeded
(`<aef:uid value="if_*"/>` extension elements on every node — the filing-time
"zero uids" read was a grep false-negative: the uid is an element with a value
attribute, not an `aef:uid="…"` attribute). No map edit needed; the task
collapses to the projection profile alone, keyed to the EXISTING uids:
if_file, if_inception, if_gw_outcome, if_done_go, if_done_closed.

**projection profile** — `_inception_flow_buckets` in tools/corpus_overlay.py
registered in PROFILES; reads `.tasks/{active,completed}` frontmatter,
inception tasks only: captured→if_file; started-work/issues→if_inception
(issues tinted warn); work-completed in active/ →if_gw_outcome (warn; err when
stuck >7d — the decision queue); completed within ARCHIVE_WINDOW_DAYS split
GO→if_done_go else if_done_closed by parsing the `## Decision` block.

Landing page auto-picks up the "Live overlay →" link (overlay_ids derives from
PROFILES — no template change needed).

## Acceptance Criteria

### Agent
- [x] `_inception_flow_buckets` profile registered in PROFILES keyed to the
      map's existing uids (if_file/if_inception/if_gw_outcome/if_done_go/
      if_done_closed — no map edit); unit tests cover bucket routing
      (captured/started-work/issues/work-completed-active/completed-GO/
      completed-non-GO) and tone mapping incl. stuck->err
- [x] /api/overlay?id=aef-inception-flow returns wire-shape payload with
      annotations for populated buckets only; /designer/overlay?id=
      aef-inception-flow renders badges live end-to-end (Playwright: >=1 badge,
      0 console errors); landing shows "Live overlay →" on the inception card
      — LIVE: 4 badges (if_file 14 warn, if_gw_outcome 6 err oldest 46d,
      if_done_go 4 info, if_done_closed 1 info), status line "4 badges",
      0 console errors; landing emits overlay?id= links for BOTH profiled maps

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

- [ ] [REVIEW] Inception-map overlay reads useful at a glance (projection-taste
      ratification, same ritual as the T-2629 threshold review)
  **Steps:**
  1. Open the live overlay: `http://192.168.10.107:3001/designer/overlay?id=aef-inception-flow`
  2. Check the decision-queue badge on the "decision?" gateway — count should
     match the inceptions awaiting go/no-go on `http://192.168.10.107:3001/approvals`
  3. Judge the 5 badge points (file/explore/decision-gw/go/closed) — are these
     the right observation points, or should any move/split?
  **Expected:** badges land on the nodes you'd naturally look at; decision-queue
  count matches /approvals; tones (warn on stuck >7d) feel right
  **If not:** edit the map in the UI (pair-draft ritual — agent re-reads and
  normalizes) or note which threshold/placement to change

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
grep -q 'value="if_gw_outcome"' .context/designer/projects/aef-inception-flow/v1.bpmn
python3 -m pytest tests/unit/test_corpus_overlay.py tests/web/test_api_overlay.py tests/web/test_designer_overlay.py -q
out=$(curl -sf "$(bin/fw watchtower url)/api/overlay?id=aef-inception-flow"); grep -q '"annotations"' <<<"$out"
out=$(curl -sf "$(bin/fw watchtower url)/designer/overlay?id=aef-inception-flow"); grep -q 'aef:ready' <<<"$out"

# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

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

## Recommendation

**Recommendation:** GO

**Rationale:** Second overlay profile shipped and live with zero map edits —
the inception map was already fully uid-seeded, so the deliverable collapsed
to a pure server-side projection (tools/corpus_overlay.py). The headline
signal fires on real data: the go/no-go decision queue badges the "decision?"
gateway at 6 waiting / oldest 46d / err tone — the same population /approvals
holds, now visible in the map. Lifecycle profile regression clean (5 badges,
unchanged). The only open judgment is projection taste (badge points +
queue-floor thresholds), which is exactly the [REVIEW].

**Evidence:**
- 17/17 tests green (tests/unit/test_corpus_overlay.py + web overlay suites);
  4 new pins: status/decision routing, non-inception exclusion, queue
  warn-floor + err escalation, terminal info + 7d window
- Live: /api/overlay?id=aef-inception-flow → 4 annotations (if_file 14 warn,
  if_gw_outcome 6 err, if_done_go 4 info, if_done_closed 1 info)
- Playwright e2e: /designer/overlay?id=aef-inception-flow renders 4 badges,
  status line confirms forward, 0 console errors
- Landing card grew "Live overlay →" automatically (overlay_ids derives from
  PROFILES — no template change)

## Evolution

### 2026-07-27 — scope collapse at start-work: map already uid-seeded
- **What changed:** filed on the belief aef-inception-flow had zero uids
  (grep for `aef:uid="…"` attribute form returned 0). The uid is an
  ELEMENT — `<aef:uid value="…"/>` — and every node already carries one.
  Same false-negative would have hit any map; worth remembering the corpus
  serializes uids as extension elements, not attributes.
- **Plan impact:** half the deliverable (uid seed + pair-round map edit +
  prove recreate) vanished — no map write at all, pure server-side profile.
- **Triggered:** `carriers()` relaxation instead: the phantom-uid filter
  required `aef:meta state=` which only the inception map's two end events
  carry; filter now keys on uid presence for ALL nodes (state returned when
  present), which is what the rename/remove protection actually needs.
  Lifecycle behavior unchanged (its 6 profile uids all carry state).

### 2026-07-27 — decision-queue severity is a floor, not a ladder
- **What changed:** the generic oldest-age ladder (info→warn→err) reads wrong
  for if_gw_outcome: a fresh non-empty decision queue rendered info, i.e.
  ambient. A queue awaiting the operator is an action request.
- **Plan impact:** added `_QUEUE_UIDS` (warn floor, err past 7d) alongside
  `_TERMINAL_UIDS` (generalizing the tl_archive special case). Live data
  vindicates it: 6 queued, oldest 46d → err on first render.
- **Triggered:** nothing filed; threshold taste rolls into this task's
  [REVIEW] with T-2629's.

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

### 2026-07-27T20:31:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2634-overlay-profile-2--aef-inception-flow-ui.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e4464604
- **Timestamp:** 2026-07-27T20:39:33Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `python3 -m pytest tests/unit/test_corpus_overlay.py tests/web/test_api_overlay.py tests/web/test_designer_overlay.py -q`

### 2026-07-27T20:39:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
