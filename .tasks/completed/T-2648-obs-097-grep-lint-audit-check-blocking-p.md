---
id: T-2648
name: "OBS-097 grep-lint: audit check blocking PROJECT_ROOT resolution of framework-owned
  assets"
description: >
  OBS-097 grep-lint: audit check blocking PROJECT_ROOT resolution of framework-owned
  assets

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
created: 2026-07-28T08:07:24Z
last_update: 2026-07-28T08:25:09Z
date_finished: 2026-07-28T08:25:09Z
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
  - ts: '2026-07-28T08:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-28T08:15:09Z'
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
---

# T-2648: OBS-097 grep-lint: audit check blocking PROJECT_ROOT resolution of framework-owned assets

## Context

OBS-097 (832's G-004 class, T-2645 origin): framework-owned assets resolved via
PROJECT_ROOT are invisible bugs in this repo (roots coincide) but break every
split-root consumer. T-2645 fixed the three sys.path instances; the class-level
prevention 832 proposed (grep-lint) was registered but not built. This task
builds the lint as an audit structure check: scan framework Python for
PROJECT_ROOT-resolution of framework-owned dirs (lib/, agents/, policy/, bin/,
web/) and fail/warn on new instances. First calibration sweep already found 8
live instances beyond T-2645's three (bvp.py policy reads, designer/approvals/
cron bin/fw subprocess paths, core.py agents dir, resolver.py policy path) —
their disposition (fix vs legitimate-with-allowlist) is part of this task's
calibration work; fixes of confirmed-broken sites may be split to a sibling
task if the shape is non-trivial.

## Acceptance Criteria

### Agent
- [x] Audit structure check exists that greps framework Python (web/, lib/) for PROJECT_ROOT-resolution of framework-owned asset dirs (lib, agents, policy, bin, web) and reports each offending file:line
- [x] The 8 instances found at calibration are each dispositioned: fixed to FRAMEWORK_ROOT, or explicitly allowlisted with a stated reason (per-project-state files are legitimate PROJECT_ROOT)
- [x] Audit runs clean (no OBS-097 findings) after dispositions land
- [x] A regression test pins the lint: a synthetic offending line is detected; the allowlist suppresses only its stated entries
- [x] OBS-097 concern entry updated: prevention leg 'grep-lint' marked built (CI smoke leg remains open scope)

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

bats tests/unit/audit_split_root_asset_lint.bats
rc=0; out=$(bash agents/audit/audit.sh --section structure 2>&1) || rc=$?; echo "$out" | grep -q "No PROJECT_ROOT resolution of framework-owned assets"
curl -sf "$(bin/fw watchtower url)/designer" > /dev/null
curl -sf "$(bin/fw watchtower url)/cron" > /dev/null
curl -sf "$(bin/fw watchtower url)/project" > /dev/null
curl -sf "$(bin/fw watchtower url)/approvals" > /dev/null
python3 -m pytest tests/web -q

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

### 2026-07-28 — Disposition split of the 8 calibration instances
- **Chose:** 4 fixed to FRAMEWORK_ROOT (designer.py pin + draft-new fw path, approvals.py batch fw path, cron.py FW_BIN); 4 allowlisted (bvp.py POLICY_PATH+RUBRIC_PATH and resolver.py _BVP_POLICY — per-project policy INSTANCES per the T-2229 `fw bvp driver --init` seeding model, parity with bvp.sh's own PROJECT_ROOT reads; core.py /project agents listing — see next decision).
- **Why:** lib/bvp.sh lines 159/591 deliberately read PROJECT_ROOT/policy/value-drivers.yaml and --init copies the framework template INTO the project; flipping the web/lib mirrors would break parity and the per-project driver model.
- **Rejected:** blanket-fixing all 8 — would have broken the BVP per-project model and (core.py) crashed /project in split-root.

### 2026-07-28 — core.py agents listing: revert + OBS-097-allow annotation, not fix
- **Chose:** keep PROJECT_ROOT with an inline `OBS-097-allow:` annotation.
- **Why:** the /project surface is PROJECT_ROOT-relative END-TO-END — the listing's `relative_to(PROJECT_ROOT)` and the project_doc server's containment check both assume it. A lone resolution flip makes relative_to() raise in split-root: the whole page 500s, strictly worse than today's silent omission of agent docs. The paired listing+serving dual-root change is registered as open scope in OBS-097.
- **Rejected:** shipping the flip (initially applied, caught while reading the serving path during live-verify, before commit).

### 2026-07-28 — Allowlist mechanism: semantic content match + inline annotation, not path-prefix
- **Chose:** allowlist by hit-line content (the two policy-instance filenames) plus an explicit `OBS-097-allow:` in-source annotation that must carry a stated reason.
- **Why:** path-prefix allowlists (T-1881 style) would suppress FUTURE new violations in the same files; content matching keeps the ratchet tight while annotations stay visible in review.
- **Rejected:** file-level exemption table inside the check — drifts from source and hides new violations in exempted files.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-28T08:07:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2648-obs-097-grep-lint-audit-check-blocking-p.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-03d59098
- **Timestamp:** 2026-07-28T08:28:41Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 4

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 34
     - evidence: `curl -sf "$(bin/fw watchtower url)/designer" > /dev/null`
  2. **empty-output-success** (partial, heuristic) @ Verification:line 35
     - evidence: `curl -sf "$(bin/fw watchtower url)/cron" > /dev/null`
  3. **empty-output-success** (partial, heuristic) @ Verification:line 36
     - evidence: `curl -sf "$(bin/fw watchtower url)/project" > /dev/null`
  4. **empty-output-success** (partial, heuristic) @ Verification:line 37
     - evidence: `curl -sf "$(bin/fw watchtower url)/approvals" > /dev/null`

### 2026-07-28T08:25:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
