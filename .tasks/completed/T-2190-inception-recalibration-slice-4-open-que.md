---
id: T-2190
name: "Inception recalibration Slice 4: Open Questions body section + disposition
  gate in update-task.sh"
description: >
  T-2186 Slice 4. Add '## Open Questions' as a required body section on inception
  templates with per-question shape: prose + confidence: 0-3 + disposition: answered|deferred|dissolved
  + rationale: <evidence>. Add disposition-completeness gate to agents/task-create/update-task.sh
  — fires on --status work-completed when workflow_type=inception; refuses if any
  declared question lacks disposition or rationale. Bypass family: --skip-disposition-gate
  'rationale' (direct) + FW_SKIP_DISPOSITION_GATE=1 (git/wrapper) per T-1890 producer/consumer
  parity, logged Tier-2 to .gate-bypass-log.yaml. Bats test pins gate + bypass. Verification:
  template carries the section; update-task.sh refuses on under-disposed inception;
  bypass works; log entry written.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [inception, gate, disposition, T-2186-slice, update-task]
components: [agents/task-create/update-task.sh, tests/unit/disposition_gate.bats]
related_tasks: [T-2186, T-2187, T-2188]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-02T22:04:27Z
last_update: 2026-06-02T23:18:33Z
date_finished: 2026-06-02T23:18:33Z
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
  - ts: '2026-06-02T22:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-02T22:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2190: Inception recalibration Slice 4: Open Questions body section + disposition gate in update-task.sh

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `.tasks/templates/inception.md` carries `## Open Questions` body section with per-question shape comment block (prose + `confidence: 0-3` + `disposition: answered|deferred|dissolved` + `rationale: <evidence>`)
- [x] `agents/task-create/update-task.sh` carries a disposition-completeness check fired on `--status work-completed` when `workflow_type: inception`: refuses if any question (IW-N or similar) lacks a disposition line or a rationale line
- [x] Direct-invocation bypass `--skip-disposition-gate "rationale"` accepted by update-task.sh and logged Tier-2 to `.context/working/.gate-bypass-log.yaml`
- [x] Env-var bypass `FW_SKIP_DISPOSITION_GATE=1` accepted (T-1890 producer/consumer parity for git/wrapper-shaped callers) and logged Tier-2
- [x] Bats test `tests/unit/disposition_gate.bats` covers: under-disposed inception blocks, complete inception passes, --skip flag bypasses + logs, env-var bypasses + logs, non-inception workflow_type exempt — 7/7 PASS
- [x] `050-Inceptions.md` Disposition Gate section cites the shipped section name, the gate location, and both bypass mechanisms by exact form
- [x] Reviewer PASS (`bin/fw reviewer T-2190`)

## Verification

bash -n agents/task-create/update-task.sh
out=$(cat .tasks/templates/inception.md); grep -q "## Open Questions" <<<"$out"
out=$(cat .tasks/templates/inception.md); grep -q "disposition:" <<<"$out"
out=$(cat agents/task-create/update-task.sh); grep -q "skip-disposition-gate\|SKIP_DISPOSITION_GATE" <<<"$out"
out=$(cat agents/task-create/update-task.sh); grep -q "disposition:" <<<"$out"
bats tests/unit/disposition_gate.bats
out=$(cat 050-Inceptions.md); grep -q "FW_SKIP_DISPOSITION_GATE" <<<"$out"
out=$(cat 050-Inceptions.md); grep -q -- "--skip-disposition-gate" <<<"$out"
out=$(bin/fw reviewer T-2190 2>&1); grep -qE "Overall:.*PASS" <<<"$out"

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

### 2026-06-02T22:04:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2190-inception-recalibration-slice-4-open-que.md
- **Context:** Initial task creation

### 2026-06-02T23:08:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6327e1bf
- **Timestamp:** 2026-06-02T23:18:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-02T23:18:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
