---
id: T-2549
name: "fix fw bpmn promote inception-node materialization (inject DEFER recommendation past T-2204 gate)"
description: >
  fix fw bpmn promote inception-node materialization (inject DEFER recommendation past T-2204 gate)

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
created: 2026-07-19T14:06:09Z
last_update: 2026-07-19T14:10:04Z
date_finished: 2026-07-19T14:10:04Z
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

# T-2549: fix fw bpmn promote inception-node materialization (inject DEFER recommendation past T-2204 gate)

## Context

`fw bpmn promote` (T-2542) raises RuntimeError on any diagram containing a `workflow_type: inception`
node. Root cause: `create_via_gate` (tools/bpmn_promote.py) delegates to `fw task create --type inception`
with no `--recommendation`/`--rationale`, so the T-2204 recommendation-completeness gate (fires under
`CLAUDECODE=1`) refuses the create. Latent since T-2542 — prior e2e used `two-lane-sample.bpmn` (no
inception node) and unit tests mock the gate. Surfaced by 832's `two-lane-joint.bpmn` (first inception
node driven through the REAL gate end-to-end, T-2548). Captured as L-504. Fix: inject a DEFER
recommendation (the honest "promoted from diagram, human go/no-go pending" state) for inception nodes only.

## Acceptance Criteria

### Agent
- [x] `create_via_gate` (tools/bpmn_promote.py) injects `--recommendation DEFER --rationale "..."` for `workflow_type: inception` nodes ONLY; build/test/other types pass no recommendation flags (unchanged)
- [x] `fw bpmn promote all --write` on `two-lane-joint.bpmn` materializes BOTH nodes — `n_inception` (owner:human, wf:inception) no longer refused by the T-2204 gate, `n_plan` (owner:human, wf:build)
- [x] The materialized inception task carries a non-empty `## Recommendation` block with `DEFER` + rationale (satisfies T-2204 at creation, without relying on the T-2208 cron backstop)
- [x] Unit test added pinning the injection: `create_via_gate` passes `--recommendation` for inception, omits it for build (`tests/unit/test_bpmn_promote.py`); full promote suite green (`test_bpmn_promote.py` 16/16 + `bpmn_promote_e2e.bats` 5/5)

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
test "$(sha256sum tests/fixtures/bpmn/two-lane-joint.bpmn | cut -d' ' -f1)" = "efb53839bfddeb44c12bf0d8e11198c4394b017f55f0e0e238eb2524271a8c92"
python3 -m pytest tests/unit/test_bpmn_promote.py -q
bats tests/unit/bpmn_promote_e2e.bats

## RCA

**Symptom:** `fw bpmn promote all --write` raises RuntimeError on any diagram containing a
`workflow_type: inception` node (e.g. 832's `two-lane-joint.bpmn`) — the inception node is never
materialized; the whole promote aborts.

**Root cause:** `create_via_gate` (tools/bpmn_promote.py) delegates to `fw task create --type <wtype>`
and supplies `--owner human` + `FW_TASK_ORIGIN=bpmn-promote` but NO `--recommendation`/`--rationale`.
For `wtype == "inception"` the T-2204 recommendation-completeness gate (fires under `CLAUDECODE=1`)
refuses the create — it demands a GO/NO-GO/DEFER + rationale at filing time. The promote verb had no
inception branch.

**Why structurally allowed:** promote's real-gate behavior for inception nodes was never exercised.
`bpmn_promote_e2e.bats` drove `two-lane-sample.bpmn` (all nodes default to `build` — no `workflowType`
attribute), and `test_bpmn_promote.py`'s 15 units MOCK `create_via_gate`, so the real `fw task create`
inception path was invisible. No fixture had an inception node driven through the real gate until the
joint fixture (T-2548).

**Prevention:** the T-2548 seam-slice e2e drives the joint fixture (WITH an inception node) through the
REAL gate — a permanent regression guard for exactly this class. Plus a unit test in
`test_bpmn_promote.py` pinning the `--recommendation` injection (present for inception, absent for build).

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

### 2026-07-19T14:06:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2549-fix-fw-bpmn-promote-inception-node-mater.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3ae9bfb6
- **Timestamp:** 2026-07-19T14:10:12Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `create_via_gate` (tools/bpmn_promote.py) injects `--recommendation DEFER --rationale "..."` for `workflow_type: inception` nodes ONLY; build/test/other types pass no recommendation flags (unchanged)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tools/bpmn_promote.py in: `create_via_gate` (tools/bpmn_promote.py) injects `--recommendation DEFER --rationale "..."` for `workflow_type: inception` nodes ONLY; build/test/oth`

### 2026-07-19T14:10:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
