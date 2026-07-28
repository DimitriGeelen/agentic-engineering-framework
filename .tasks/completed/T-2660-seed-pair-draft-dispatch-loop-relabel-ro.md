---
id: T-2660
name: "seed pair-draft: dispatch-loop relabel round (rail T-2659 divergence)"
description: >
  seed pair-draft: dispatch-loop relabel round (rail T-2659 divergence)

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-07-28T11:31:30Z
last_update: 2026-07-28T11:35:53Z
date_finished: 2026-07-28T11:35:53Z
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

# T-2660: seed pair-draft: dispatch-loop relabel round (rail T-2659 divergence)

## Context

Opening move of the pair-draft round the T-2659 red rail calls for (arc-014
ritual: agent seeds skeleton → operator edits in UI → agent re-reads +
normalizes). Seeds `draft-dispatch-loop-relabel` — a draft copy of
`aef-dispatch-loop` implementing option (b) from the rail-274 proposal:
gateway branches relabeled to the enforced ADR-0004 outcome vocabulary
(`paused` / `success / error`) and an explicit error end-path so the map
stops hiding the error outcome. Canonical map bytes UNTOUCHED — promotion
happens only after operator/832 iterate and approve. Draft tier per T-2623
(cheap iteration, stale-draft INFO after 30d, never WARN).

## Acceptance Criteria

### Agent
- [x] Draft `draft-dispatch-loop-relabel` exists in the designer store (saved v1 via /api/save), seeded from canonical `aef-dispatch-loop` v1 with branches relabeled `yes — paused` / `no — success / error`. **Design deviation from filing, deliberate:** NO separate error end-path — reading the machine showed error and success outcomes both converge on outcome evaluate+backprop (error rows recorded, resolver exits 2 after); a structural error fork would misrepresent the code. Option (a)+notes is the honest shape; recorded in Decisions
- [x] Draft round-trips: `parse_map` accepts stored bytes (10 nodes / 10 flows); listed in gallery /api/list
- [x] Rail dry-run against draft bytes GREEN with promotion-time entry (branch regex `— ([a-z_/ ]+)` + split `/`): PASS `{error, paused, success}`
- [x] Canonical untouched: v1 only, md5 631da974f428c07d592a804dd4b6c233 unchanged; canonical rail still DIVERGENT (pin test enforces)
- [x] Deep-link + next-step recorded: open http://192.168.10.107:3001/designer → `draft-dispatch-loop-relabel`; operator (and 832, proposed at rail 274) iterate/approve → follow-up task promotes draft bytes to `aef-dispatch-loop` v2, widens the registry branch regex, flips `test_live_dispatch_loop_divergent_pin` to a PASS pin

## Decisions

### 2026-07-28 — no separate error end-path in the seed
- **Chose:** minimal relabel (`paused` / `success / error` on the existing two branches) + clarifying notes on the gateway (ADR-0004 classification) and outcome node (error converges into backprop; no structural fork before it)
- **Why:** `lib/spawn.py _classify_status` + resolver run show error outcomes flow through the same outcome evaluate+backprop node as success (rows recorded for both; error additionally exits 2). A drawn error fork before backprop would assert structure the code doesn't have — the rail exists to prevent exactly that class of map fiction
- **Rejected:** option (b) (dedicated error branch/end event) from the rail-274 proposal — structurally dishonest for this machine; noted in the draft's XML comment so the pair-round sees the reasoning

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

python3 -c "import json; m=json.load(open('.context/designer/projects/draft-dispatch-loop-relabel/meta.json')); assert m['latest'] >= 1 and m.get('uuid')"
out=$(md5sum .context/designer/projects/aef-dispatch-loop/v1.bpmn); echo "$out" | grep -q 631da974f428c07d592a804dd4b6c233
rc=0; out=$(python3 tools/corpus_conformance.py --map aef-dispatch-loop 2>&1) || rc=$?; [ "$rc" -eq 1 ]
out=$(grep -c 'name="yes — paused"' .context/designer/projects/draft-dispatch-loop-relabel/v1.bpmn); [ "$out" -eq 1 ]

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

<!-- Decisions recorded above, under Acceptance Criteria (T-2660 seed-shape choice). -->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-28T11:31:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2660-seed-pair-draft-dispatch-loop-relabel-ro.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5c0fa79f
- **Timestamp:** 2026-07-28T11:35:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-28T11:35:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
