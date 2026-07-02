---
id: T-2249
name: "BVP driver prompt bundle: cross-link from CLAUDE.md/FRAMEWORK.md/040-ValueDrivers.md
  (T-2246 follow-up)"
description: >
  Three canonical docs (CLAUDE.md / FRAMEWORK.md / 040-ValueDrivers.md) had zero references
  to policy/prompts/ bundle shipped by T-2246. Future agents/operators have no entry
  point. HV/LC cross-link.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-08T06:28:20Z
last_update: '2026-06-11T22:24:12Z'
date_finished: 2026-06-08T06:29:49Z
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
  - ts: '2026-06-11T22:24:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2249: BVP driver prompt bundle: cross-link from CLAUDE.md/FRAMEWORK.md/040-ValueDrivers.md (T-2246 follow-up)

## Context

T-2246 shipped the BVP driver prompt bundle at `policy/prompts/`
(keystone + artefact-template + 5 reference files in `bvp-references/`).
Zero references from CLAUDE.md, FRAMEWORK.md, or 040-ValueDrivers.md.
Future agents/operators have no entry point. This cross-links the bundle
from all three canonical surfaces.

## Acceptance Criteria

### Agent
- [x] `CLAUDE.md` has a `### Driver Session Prompt Bundle (T-2245 / T-2246)` subsection under §Arc-Scoped Driver Suggestion Workflow with table of 7 bundle files
- [x] `FRAMEWORK.md` Quick Reference includes a row pointing at `policy/prompts/bvp-driver-session.md`
- [x] `040-ValueDrivers.md` has a `## Driver Session Prompt Bundle (T-2245 / T-2246)` section + See-also entry
- [x] All three docs reference the same keystone (`bvp-driver-session.md`) by exact path

### Human
<!-- All ACs are deterministic; no Human ACs needed -->

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

grep -q "Driver Session Prompt Bundle (T-2245 / T-2246)" CLAUDE.md
grep -q "policy/prompts/bvp-driver-session.md" FRAMEWORK.md
grep -q "Driver Session Prompt Bundle (T-2245 / T-2246)" 040-ValueDrivers.md
grep -q "policy/prompts/bvp-driver-session.md" CLAUDE.md
grep -q "policy/prompts/bvp-driver-session.md" 040-ValueDrivers.md

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

## Recommendation

**Recommendation:** GO

**Rationale:** Bundle shipped by T-2246 had zero references from canonical
docs. Now all three surfaces (CLAUDE.md / FRAMEWORK.md / 040-ValueDrivers.md)
route to the keystone `policy/prompts/bvp-driver-session.md` with consistent
naming. All 5 grep assertions verify the cross-links are in place.

**Evidence:**
- `CLAUDE.md` §Driver Session Prompt Bundle (after §Arc-Scoped Driver Suggestion Workflow) — table of 7 bundle files + the routing rule
- `FRAMEWORK.md` Quick Reference — one-line entry pointing at keystone
- `040-ValueDrivers.md` §Driver Session Prompt Bundle + See-also entry — full file list
- All 5 grep assertions in Verification PASS

## Updates

### 2026-06-08T06:28:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2249-bvp-driver-prompt-bundle-cross-link-from.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-58afdf96
- **Timestamp:** 2026-06-08T06:29:50Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-08T06:29:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
