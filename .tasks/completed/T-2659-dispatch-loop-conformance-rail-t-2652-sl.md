---
id: T-2659
name: "dispatch-loop conformance rail (T-2652 slice 3)"
description: >
  dispatch-loop conformance rail (T-2652 slice 3)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/unit/test_corpus_conformance_registry.py, tools/conformance-registry.yaml, tools/corpus_conformance.py]
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
created: 2026-07-28T11:19:12Z
last_update: 2026-07-28T11:27:04Z
date_finished: 2026-07-28T11:27:04Z
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

# T-2659: dispatch-loop conformance rail (T-2652 slice 3)

## Context

T-2652 GO slice 3 (design: `docs/reports/T-2652-conformance-rail-generalization.md`).
Registers the `aef-dispatch-loop` conformance rail against the resolver's enforced
pause/outcome vocabulary in `lib/resolver.py`. Slice 2 (T-2658) shipped the
declarative vocabulary-set primitive with the explicit claim that a third vocab
rail should need ONLY a registry entry — this slice is that claim's live test.
If the dispatch-loop machine doesn't reduce to a gateway-vocab comparison, the
honest outcome is recorded (primitive extension or scope note), not forced fit.

## Acceptance Criteria

### Agent
- [x] Dispatch-loop map's decision structure + resolver enforcement points inventoried and recorded (see Inventory below): gateway `worker paused?` (branches `yes — pause_requested` / `no — completed`); enforced enum is the ADR-0004 outcome-status set `lib/spawn.py:57` `_VALID_OUTCOME_STATUSES = {success, error, paused}` (the `_classify_status` contract the gateway routes on — not resolver.py, which holds the pause *preamble*, not the enum)
- [x] `aef-dispatch-loop` registry entry lands; rail is **knowingly DIVERGENT** (honest finding, not forced green): map-asserts/code-refuses `completed`+`pause_requested`; code-allows/map-lacks `error`+`paused`+`success`. The map labels branches with the pause event type + an informal "completed" that collapses success+error and hides the error path. Pair-draft round relabels → rail goes green
- [x] Registry-entry-only claim evaluated honestly: ONE generic extractor tweak needed (punctuation-only token filter after split — see Evolution); no per-map code
- [x] Audit reports 4/4 per-map lines: 3 PASS + dispatch-loop WARN with full evidence + pair-draft mitigation; existing 3 rails' verdicts unchanged
- [x] Live-rail pin test added (`test_live_dispatch_loop_divergent_pin` — pins the honest DIVERGENT state, flips to PASS pin after the pair-round); suites 27/27 green

## Inventory (AC 1)

| Element | Value |
|---------|-------|
| Gateway | `worker paused?` (`agt_gw_paused`) |
| Branch labels | `yes — pause_requested` (→ operator resolves pause), `no — completed` (→ outcome evaluate+backprop) |
| Enforced enum | `lib/spawn.py:57` `_VALID_OUTCOME_STATUSES = frozenset({"success", "error", "paused"})` (ADR-0004, dispatch-safety slice 1) |
| Classification | `_classify_status`: `pause_requested`→paused, `error`→error, `result`+is_error→error, else→success |
| Why not resolver.py | resolver.py holds the pause *preamble* (event JSON shape) and retry chain; the enum the gateway routes on is declared once, in spawn.py |

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

python3 -m pytest tests/unit/test_corpus_conformance_registry.py tests/unit/test_corpus_conformance.py -q
rc=0; out=$(python3 tools/corpus_conformance.py --map aef-dispatch-loop 2>&1) || rc=$?; [ "$rc" -eq 1 ] && echo "$out" | grep -q "code-allows/map-lacks:    error"
python3 -c "import yaml; yaml.safe_load(open('tools/conformance-registry.yaml'))"

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

### 2026-07-28 — registry-entry-only claim + first red rail

- **What changed:** (1) The T-2652 inventory pointed at `lib/resolver.py` for the
  enforced enum, but resolver.py holds the pause *preamble*; the enum the gateway
  routes on is declared once in `lib/spawn.py:57` (`_VALID_OUTCOME_STATUSES`,
  ADR-0004). (2) T-2658's "third vocab rail = registry entry only" claim held
  except for one generic hygiene tweak: `_extract_tokens` now drops
  punctuation-only fragments after split (splitting a frozenset literal on `"`
  leaves `", "` fragments). Generic, not per-map. (3) The rail is the program's
  first *knowingly red* rail: the map's branch labels genuinely diverge from the
  enforced enum (informal "completed" collapses success+error; error path absent).
- **Plan impact:** Green-on-ship is not the success criterion — honest verdict is.
  The divergence drives a pair-draft round (map relabel), after which the pin
  test flips to PASS.
- **Triggered:** pair-draft round proposal posted to 832 on the DM rail (map
  relabel: branch tokens → `paused` / `success / error`, or add error path).

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

### 2026-07-28T11:19:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2659-dispatch-loop-conformance-rail-t-2652-sl.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-17820f13
- **Timestamp:** 2026-07-28T11:27:09Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `rc=0; out=$(python3 tools/corpus_conformance.py --map aef-dispatch-loop 2>&1) || rc=$?; [ "$rc" -eq 1 ] && echo "$out" | grep -q "code-allows/map-lacks:    error"`

### 2026-07-28T11:27:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
