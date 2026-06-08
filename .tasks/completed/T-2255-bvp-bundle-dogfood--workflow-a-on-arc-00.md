---
id: T-2255
name: "BVP bundle dogfood — Workflow A on arc-001 dispatch-safety"
description: >
  BVP bundle dogfood — Workflow A on arc-001 dispatch-safety

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
created: 2026-06-08T11:24:39Z
last_update: 2026-06-08T11:29:52Z
date_finished: 2026-06-08T11:29:52Z
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

# T-2255: BVP bundle dogfood — Workflow A on arc-001 dispatch-safety

## Context

First Workflow A run on arc-001 dispatch-safety since the BVP driver-session bundle landed (T-2245/T-2246). Three proposed scoped drivers (`uncertainty-recognition` w5, `severity-likelihood-calibration` w4, `operator-resolution-latency` w3 — last is weak per R5) now live in `.context/arcs/dispatch-safety.yaml`. Full research artefact at `docs/reports/T-2255-bvp-driver-arc-001-dispatch-safety.md`. No structural gate crossed — these are proposals, operator approves via future `fw arc approve-driver` (T-1925/T-1926, captured in arc-006) or direct YAML edit promoting entries to `scoped_drivers:`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Research artefact written at `docs/reports/T-2255-bvp-driver-arc-001-dispatch-safety.md` with sections: Context (arc summary + why now), Candidates Considered (each with R1 rationale + weight rationale + R5 self-check), Rejected Paths (candidates considered but withdrawn, per R5 manufactured-drivers discipline), Final Spec (YAML mirror of the write), Operational Consequences (how operator engages, what `fw arc approve-driver` would do once the verb lands).
- [x] `.context/arcs/dispatch-safety.yaml` gains a `proposed_scoped_drivers:` block with 2–3 candidates, each shaped `{name, rationale, source: agent, ts: <UTC ISO8601>}` per bundle Workflow A step 3.
- [x] Each candidate's rationale articulates **R1 (differentiation)** — names what the candidate distinguishes that D1-D4 (and existing free drivers F-RECALL, F-ORCH) do not. No candidate's rationale paraphrases to "this is about reliability/usability/portability/antifragility".
- [x] Weight on each candidate ∈ [1, 6] (arc-scoped cap M2). Candidate count ≤ 3 (per arc cap).
- [x] Artefact's "Final Spec" section quotes the YAML block verbatim — no spec-over-dialogue drift (per `bvp-references/discipline-failure-modes.md` Final Spec discipline).
- [x] [REVIEWER] `bin/fw reviewer T-2255` returns Overall: PASS.

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

# Artefact exists
test -f docs/reports/T-2255-bvp-driver-arc-001-dispatch-safety.md

# arc-001 carries the proposed_scoped_drivers block
grep -q "^proposed_scoped_drivers:" .context/arcs/dispatch-safety.yaml

# YAML still parses after the edit
python3 -c "import yaml; yaml.safe_load(open('.context/arcs/dispatch-safety.yaml'))"

# Candidate count cap: 1-3 entries under proposed_scoped_drivers
python3 -c "import yaml; d=yaml.safe_load(open('.context/arcs/dispatch-safety.yaml')); ps=d.get('proposed_scoped_drivers') or []; assert 1 <= len(ps) <= 3, f'cap violation: {len(ps)} candidates'"

# Each candidate has the required shape (name, rationale, source: agent, ts)
python3 -c "import yaml; d=yaml.safe_load(open('.context/arcs/dispatch-safety.yaml')); ps=d.get('proposed_scoped_drivers') or []; [(_:=c['name'], c['rationale'], c['source'], c['ts']) for c in ps]"

# Reviewer PASS (L-387 capture-then-grep — bold-aware regex per memory)
out=$(bin/fw reviewer T-2255 2>&1); echo "$out" | grep -qE "Overall:.*PASS"

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

### 2026-06-08T11:24:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2255-bvp-bundle-dogfood--workflow-a-on-arc-00.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cdad2769
- **Timestamp:** 2026-06-08T11:29:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-08T11:29:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
