---
id: T-2645
name: "review.py sys.path uses PROJECT_ROOT/lib for dispatch_pause — all /review pages
  500 in split-root consumers (832 G-004, rail 253)"
description: >
  review.py sys.path uses PROJECT_ROOT/lib for dispatch_pause — all /review pages
  500 in split-root consumers (832 G-004, rail 253)

status: work-completed
workflow_type: build
owner: agent
horizon:
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
created: 2026-07-27T23:03:27Z
last_update: '2026-08-16T22:25:13Z'
date_finished: 2026-07-27T23:09:48Z
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
  - ts: '2026-08-16T22:25:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 5
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=5 (body:class-neutral); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2645: review.py sys.path uses PROJECT_ROOT/lib for dispatch_pause — all /review pages 500 in split-root consumers (832 G-004, rail 253)

## Context

832's upstream defect report 1/3 (their T-270 / G-004, rail 253, HIGH for shared-tooling
consumers): `web/blueprints/review.py` inserts `PROJECT_ROOT/lib` on sys.path before
importing `dispatch_pause` (T-1810 helpers), but the module lives at `FRAMEWORK_ROOT/lib`.
Invisible in this repo (roots coincide); in a split-root consumer every /review/T-XXX
page 500s with ModuleNotFoundError while the operator's whole review queue points at
those URLs. 832 runs a product-side shim (`lib/dispatch_pause.py`) as mitigation and
deletes it once this lands + they re-vendor. Their staged fix (git-apply-check-verified
since Jul 5): import FRAMEWORK_ROOT from web.shared, insert FRAMEWORK_ROOT/"lib".
Their prevention proposal (split-root CI smoke job + grep-lint) is a separate scope —
registered as a concern, not built here (one task = one deliverable).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] review.py resolves dispatch_pause via FRAMEWORK_ROOT/lib (832's exact fix shape); no other blueprint uses PROJECT_ROOT to resolve framework-owned lib modules — sweep found+fixed 2 siblings 832 didn't report: approvals.py:23 (identical insert, masked by try/except) and orchestrator.py:434 (workflow-coverage panel silently unavailable); repo-wide grep clean
- [x] Live /review/<id> page still renders on our Watchtower after the change — restart + /review/T-2634, /approvals, /orchestrator all 200 with content
- [x] Split-root defect class registered in concerns.yaml — OBS-097 (open: class-level prevention pending; 832's split-root CI smoke + grep-lint proposal captured verbatim)
- [x] tests/web green for the review blueprint — 7 passed (review/approval/orchestrator selection)

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

out=$(grep -rn 'PROJECT_ROOT / "lib"' web/ 2>&1); test -z "$out"
grep -q 'FRAMEWORK_ROOT / "lib"' web/blueprints/review.py
grep -q 'FRAMEWORK_ROOT / "lib"' web/blueprints/approvals.py
grep -q 'FRAMEWORK_ROOT / "lib"' web/blueprints/orchestrator.py
out=$(curl -s -o /dev/null -w "%{http_code}" "$(bin/fw watchtower url)/review/T-2634"); test "$out" = "200"
out=$(python3 -c "import yaml; d=yaml.safe_load(open('.context/concerns.yaml')); print([c['id'] for c in d])"); echo "$out" | grep -q "OBS-097"

## RCA

**Symptom:** In split-root (shared-tooling) consumers, every `/review/T-XXX` Watchtower
page 500s with `ModuleNotFoundError: dispatch_pause` — the operator's entire review
queue dead while every partial-complete task's Human AC points at those URLs. Reported
by 832 (their T-270/G-004, rail 253) with a product-side shim as mitigation since Jul 5.
Sweep found the same class in approvals.py (masked by try/except — paused-dispatch
surface silently dead) and orchestrator.py (workflow-coverage panel silently
"unavailable").

**Root cause:** Three blueprint sites inserted `PROJECT_ROOT / "lib"` on sys.path to
import framework-owned lib modules (`dispatch_pause`, `workflow_coverage`). `lib/` is
FRAMEWORK-owned; the correct root is `FRAMEWORK_ROOT`. Every other blueprint imports
via `from lib.X import …` which resolves through FRAMEWORK_ROOT (already on sys.path
via the `web` package import), so only these three explicit-insert sites diverge.

**Why structurally allowed:** In this repo PROJECT_ROOT == FRAMEWORK_ROOT, so the wrong
resolution passes every framework-side test and every live check — the failing path
structurally cannot fire where the code is developed. Same producer/consumer-split
class as OBS-096 (reviewer catalogues) and T-1633 (fresh-machine upgrade): 2nd
shared-mode blindspot reported by the same consumer in a month.

**Prevention:** OBS-097 registered (open) carrying 832's class-level proposal: split-root
CI smoke job (synthetic consumer + curl every blueprint route, any 500 fails) +
grep-lint on new `PROJECT_ROOT`-resolution of framework-owned assets. Class-level
prevention needs its own task; this task fixes all three instances and the sweep
confirms zero remaining `PROJECT_ROOT / "lib"` in web/.

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

### 2026-07-27T23:03:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2645-reviewpy-syspath-uses-projectrootlib-for.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ff086ec7
- **Timestamp:** 2026-07-27T23:09:49Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-27T23:09:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
