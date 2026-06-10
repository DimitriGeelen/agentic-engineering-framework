---
id: T-2312
name: "maintenance: fabric enrich (+14 edges) + gitignore episodic-gen + commit handover
  backlog"
description: >
  maintenance: fabric enrich (+14 edges) + gitignore episodic-gen + commit handover
  backlog

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
created: 2026-06-10T13:31:00Z
last_update: 2026-06-10T13:42:24Z
date_finished: 2026-06-10T13:42:24Z
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
  - ts: '2026-06-10T13:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-10T13:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 1
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2312: maintenance: fabric enrich (+14 edges) + gitignore episodic-gen + commit handover backlog

## Context

HV-LC mechanical maintenance batch in autonomous-mode session 2026-06-10. Three independent threads bundled because each is sub-5-min Tier-1 work with shared verification surface:

1. **Fabric enrich** — `bin/fw fabric enrich --dry-run` shows 6 cards enrichable, +14 edges. Audit WARN `Fabric: 91/810 cards have no edges` reduces by 6.
2. **Episodic-gen .gitignore** — `.context/working/episodic-gen/*.log` accumulates one ephemeral invocation log per task close. 261 files currently untracked; sibling `.last-episodic-gen.log` is already gitignored at `.gitignore:12`. Adding the directory pattern stops the noise.
3. **Handover backlog commit** — 11 untracked `S-2026-0609-*.md` + `S-2026-0610-*.md` from auto-handovers that never got committed.

Bundled because none touch source code or governance contracts; single commit minimizes handover-trail churn.

## Acceptance Criteria

### Agent
- [x] Fabric enrichment applied: `bin/fw fabric enrich` run; "cards with no edges" reduced from 91 to ≤89 (saturation floor — re-run dry-run returns 0 cards enrichable). Achieved: 88. Verification: `bin/fw audit > /tmp/T-2312-audit.out 2>&1 || true; grep -oE "Fabric: [0-9]+/[0-9]+ cards have no edges" /tmp/T-2312-audit.out | head -1 | awk -F'[ /]' '{exit ($2 <= 89 ? 0 : 1)}'`
- [x] `.gitignore` contains pattern excluding `.context/working/episodic-gen/`. Verification: `grep -q "episodic-gen" .gitignore`
- [x] All 11+ untracked `.context/handovers/S-2026-0609*.md` and `S-2026-0610*.md` are committed (no longer in `git status --short -uall .context/handovers/`). Verification: `git status --short .context/handovers/ > /tmp/T-2312-hov.out 2>&1; ! grep -qE "^\?\? \.context/handovers/S-2026-06(09|10)-" /tmp/T-2312-hov.out`
- [x] `bin/fw doctor` returns exit 0 (no new WARN/FAIL introduced). Verification: `bin/fw doctor >/tmp/T-2312-doctor.out 2>&1 && grep -qiE "PASS|OK" /tmp/T-2312-doctor.out` (36 PASS/OK lines, 0 FAIL on 2026-06-10 run)

<!-- No Human ACs — pure mechanical maintenance, no render surface, no judgment call. -->

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

grep -q "episodic-gen" .gitignore
bin/fw audit > /tmp/T-2312-audit.out 2>&1 || true; grep -oE "Fabric: [0-9]+/[0-9]+ cards have no edges" /tmp/T-2312-audit.out | head -1 | awk -F'[ /]' '{exit ($2 <= 89 ? 0 : 1)}'
git status --short .context/handovers/ > /tmp/T-2312-hov.out 2>&1; ! grep -qE "^\\?\\? \\.context/handovers/S-2026-06(09|10)-" /tmp/T-2312-hov.out
bin/fw doctor > /tmp/T-2312-doctor.out 2>&1 && grep -qiE "PASS|OK" /tmp/T-2312-doctor.out

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

### 2026-06-10T13:31:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2312-maintenance-fabric-enrich-14-edges--giti.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7f633030
- **Timestamp:** 2026-06-10T13:48:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-10T13:42:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
