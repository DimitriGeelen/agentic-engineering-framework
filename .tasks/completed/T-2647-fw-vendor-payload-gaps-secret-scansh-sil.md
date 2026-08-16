---
id: T-2647
name: "fw vendor payload gaps: secret-scan.sh silently skipped + orchestrator-mcp
  baseline missing on fresh consumers (832 G-001, rail 256)"
description: >
  fw vendor payload gaps: secret-scan.sh silently skipped + orchestrator-mcp baseline
  missing on fresh consumers (832 G-001, rail 256)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-004, agents/audit/orchestrator-mcp-scan.sh, 
      agents/git/lib/hooks.sh, tests/unit/upgrade_fresh_machine_simulation.bats]
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
created: 2026-07-27T23:16:37Z
last_update: '2026-08-16T22:25:13Z'
date_finished: 2026-07-27T23:26:28Z
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
      D2: 4
      D3: 2
      D4: 5
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=5 (body:class-neutral); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2647: fw vendor payload gaps: secret-scan.sh silently skipped + orchestrator-mcp baseline missing on fresh consumers (832 G-001, rail 256)

## Context

832's upstream report 3/3 (their T-270 / G-001, rail 256, oldest open gap in their
register, detected 2026-06-05, cross-corroborated by fan-dashboard RCA): `fw vendor` /
`fw init` ship incomplete payloads — advertised subsystems no-op or fail on consumers.
Two confirmed instances their side: (F2) `orchestrator-mcp-scan.sh` expects
`orchestrator-mcp-baseline.yaml` that vendor never copies → first audit FAILs on fresh
consumer; (F4) `secret-scan.sh` absent from their payload → pre-commit prints
"scanner not found … (skipping)" — a security control that SILENTLY no-ops (live their
side today, not historical). Their proposal: extend the T-2637 fresh-machine sim with a
payload-completeness assert (runtime-referenced files must exist in the vendored tree)
+ no-silent-skip policy on security-relevant hooks. Initial verification our side:
secret-scan.sh IS present in our current .agentic-framework/ self-vendor (their snapshot
may predate its addition — vintage TBD); the mcp-baseline resolves
`FRAMEWORK_ROOT/.context/audits/` which is itself questionable (mutable state under the
vendored tree in split-root). Scope per claim: verify vintage vs real gap, fix what is
real, land the sim guard, define no-silent-skip for secret-scan.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] F4 disposition settled: VINTAGE for the payload — secret-scan.sh is in do_vendor's `agents/` include (bin/fw:269) and has shipped in the vendored tree since 2026-05-15 (commit 850130094), predating 832's 2026-06-05 detection; their consumer simply carries an older payload. No vendor-filter change needed; re-vendor delivers it.
- [x] No-silent-skip: pre-commit template v1.2 (agents/git/lib/hooks.sh) — missing scanner now prints an unmissable multi-line warning naming the risk + fix commands; default stays fail-open (missing scanner usually = stale payload, blocking every commit would be hostile); FW_SECRET_SCAN_STRICT=1 opts into blocking (exit 1). Local hooks reinstalled --force.
- [x] F2 disposition settled: REAL live gap, fixed — baselines live under .context/ (excluded from vendor BY DESIGN as per-install state) and the scan hard-exit-2'd → audit FAILed with a misleading "regression" message on every fresh install. Now: missing baseline(s) → exit 3 (first-run, NOTE lines + seed guidance; verified rc=3 on empty project) and audit maps 3 → INFO. Framework-side behavior unchanged (baselines present → normal PASS/WARN path, confirmed live).
- [x] Fresh-machine sim extended: test 6 payload-completeness (secret-scan.sh + master-guard.sh + orchestrator-mcp-scan.sh in vendored tree) + test 7 no-silent-skip pinned against the INSTALLED hook via the vendored fw's own install-hooks (loud warning + fail-open default + strict blocks). 7/7 green on committed state.
- [x] Findings + fix state answered to 832 on the rail (their G-001 close condition) — offset 259 (F4 vintage + loud-fail, F2 fixed, sim teeth, backlog drained)

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

grep -q "SECRET SCAN IS NOT RUNNING" agents/git/lib/hooks.sh
grep -q "FW_SECRET_SCAN_STRICT" agents/git/lib/hooks.sh
grep -q "VERSION=1.2" .git/hooks/pre-commit
rc=0; out=$(PROJECT_ROOT=$(mktemp -d) bash agents/audit/orchestrator-mcp-scan.sh 2>&1) || rc=$?; test "$rc" = "3"
grep -q 'ORCH_EXIT_CAPTURED" = "3"' agents/audit/audit.sh
out=$(bats tests/unit/upgrade_fresh_machine_simulation.bats 2>&1); echo "$out" | grep -q "ok 7"; ! echo "$out" | grep -q "not ok"

## RCA

**Symptom:** (F4) 832's consumer printed "secret-scan: scanner not found … (skipping)"
on EVERY commit — a security control silently no-oping for weeks. (F2) A fresh
consumer's very first `fw audit` FAILed the orchestrator section with a misleading
"regression — gated tool lost its check_task_governance" message, because the drift
baseline never exists on a new install.

**Root cause:** Two distinct causes under one reported class. F4: vintage — the scanner
HAS shipped in the vendor payload since 2026-05-15; their payload predates it. The real
defect was the skip semantics: one ignorable stderr line + exit 0 made the degraded
state costless to ignore. F2: genuine design gap — the baselines live under `.context/`
(per-install state, excluded from vendor BY DESIGN), but the scan treated
missing-baseline as a hard error (exit 2) and audit mapped exit 2 to FAIL with a
regression message. First-run and regression were conflated in one exit code.

**Why structurally allowed:** Both are producer-side blindness (same class as OBS-096,
OBS-097, T-1633): in the framework repo the baseline always exists and the scanner is
always present, so neither degraded path ever fires where the code is developed. The
fresh-machine sim existed (T-1635) but asserted nothing about hook/audit runtime
dependencies until now.

**Prevention:** Sim tests 6+7 (payload-completeness for runtime-referenced scripts +
no-silent-skip contract pinned against the INSTALLED hook via the vendored fw's own
install-hooks path). Distinct first-run exit code (3) keeps future missing-state
conditions from masquerading as regressions. 832's fuller proposal (grep vendored
hooks/scripts for runtime path references, assert existence generically) noted in
OBS-097's class-prevention follow-up scope.

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

### 2026-07-27T23:16:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2647-fw-vendor-payload-gaps-secret-scansh-sil.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-78733209
- **Timestamp:** 2026-07-27T23:27:03Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-27T23:26:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
