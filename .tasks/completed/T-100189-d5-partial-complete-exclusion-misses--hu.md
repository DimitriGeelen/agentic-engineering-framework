---
id: T-100189
name: "D5 partial-complete exclusion misses '### Human (suffix)' headings (T-1062
  FP)"
description: >
  is_partial_complete() in the D5 audit block matches '### Agent\n'/'### Human\n'
  exactly; headings with parenthetical suffixes (T-1679-split style) escape the exclusion
  so T-1062 still flags as a lifecycle anomaly despite being partial-complete. Relax
  both heading regexes and merge multiple ### Agent sections; add a bats fixture with
  a suffixed heading. Origin: T-100122 RCA residual.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-004]
related_tasks: [T-100122]
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
created: 2026-07-04T22:42:43Z
last_update: '2026-08-16T22:24:19Z'
date_finished: 2026-07-06T12:59:32Z
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
  - ts: '2026-07-04T22:45:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-04T22:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      audit_severity=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:19Z'
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

# T-100189: D5 partial-complete exclusion misses '### Human (suffix)' headings (T-1062 FP)

## Context

T-100122 residual: `is_partial_complete()` in the D5 audit block requires `### Agent\n`/`### Human\n` exactly, so annotated headings like `### Human (T-1679 split — …)` (T-1062's real shape) escape the exclusion and the task re-flags daily as a lifecycle anomaly despite being a legitimate partial-complete.

## Acceptance Criteria

### Agent
- [x] D5 heading regexes tolerate suffix text after `### Agent`/`### Human` and merge multiple `### Agent` sections before counting ticks
- [x] bats fixture with suffixed headings + dual Agent sections is excluded; suffixed-heading task with an unticked Agent AC still flags
- [x] Landed D5 block re-run against the live corpus no longer lists T-1062

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
# Slice landed via worktree flow — origin-based checks (MAIN branch lags origin/master).
git show origin/master:agents/audit/audit.sh > /tmp/.t100189-audit.sh && grep -q "T-100189: headings may carry suffixes" /tmp/.t100189-audit.sh
git show origin/master:tests/unit/audit_d5_task_lifecycle.bats > /tmp/.t100189-bats && grep -q "T-100189: partial-complete with suffixed headings" /tmp/.t100189-bats
# Landed D5 block re-run: T-1062 (suffixed-heading partial-complete) no longer flagged
PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework python3 -c "import re,io,contextlib,sys;src=open('/tmp/.t100189-audit.sh').read();m=re.search(\"python3 << 'D5EOF'\\n(.*?)\\nD5EOF\", src, re.S);buf=io.StringIO();ctx=contextlib.redirect_stdout(buf);ctx.__enter__();exec(compile(m.group(1),'d5','exec'));ctx.__exit__(None,None,None);sys.exit(1 if 'T-1062' in buf.getvalue() else 0)"

## RCA

**Symptom:** T-1062 kept re-flagging in the daily D5 audit as a lifecycle anomaly despite being a legitimate partial-complete (human-owned, all Agent ACs ticked, Human AC pending).

**Root cause:** T-100122's `is_partial_complete()` matched section headings with exact-`\n` regexes (`### Agent\n` / `### Human\n`); T-1062 uses annotated headings from a T-1679 AC split (`### Human (T-1679 split — …)`) plus two `### Agent` sections, so the exclusion never matched and the task fell through to the stale-active flag.

**Why structurally allowed:** the T-100122 bats fixtures only covered plain headings — the annotated-heading corpus shape (introduced by legitimate AC-split practice) had no fixture, so the regex gap shipped green.

**Prevention:** heading regexes relaxed to `### Agent[^\n]*\n` / `### Human[^\n]*\n` with multi-section merge; two new bats fixtures pin the suffixed-heading shapes (excluded when complete, flagged when an Agent AC is unticked).

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

### 2026-07-04T22:42:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-100189-d5-partial-complete-exclusion-misses--hu.md
- **Context:** Initial task creation

### 2026-07-04T22:58:56Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ebd2ee52
- **Timestamp:** 2026-07-06T12:59:42Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-06T12:59:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
