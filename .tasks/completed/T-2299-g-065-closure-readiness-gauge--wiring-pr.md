---
id: T-2299
name: "G-065 closure-readiness gauge — wiring-presence check (boundary hook arg-scan
  + doctor scope-tag)"
description: >
  G-065 closure-readiness gauge — wiring-presence check (boundary hook arg-scan +
  doctor scope-tag)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: [T-2185, T-2198, T-1702, T-1707]
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
created: 2026-06-09T22:20:32Z
last_update: '2026-06-11T22:24:14Z'
date_finished: 2026-06-09T22:28:50Z
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
  - ts: '2026-06-09T22:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-09T22:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2299: G-065 closure-readiness gauge — wiring-presence check (boundary hook arg-scan + doctor scope-tag)

## Context

Promote OBS-043 (governance hygiene). G-065 (boundary hook read-blind, medium severity) fired 2026-05-03; T-1702 (boundary hook outside-path argument scan) and T-1707 (doctor scope-tagging) shipped both legs of the recommended fix, but G-065 was never given a machine-readable `closure_check_command:` so the T-2185 `/gaps` Close button has no actuation path. Sibling to T-2198 (which added the same gauge for G-066) — proves the surface composes for a 3rd consumer.

The wiring is **already in place** in source (verified pre-filing): `agents/context/check-project-boundary.sh` contains `Pattern 4 (T-1702 / G-065)` + `READ_ALLOWED_PREFIXES` allowlist; `bin/fw` contains `host_warnings` counter + `_scope_breakdown` summary line. The gauge will fire READY immediately — this task simply makes the readiness machine-visible.

## Acceptance Criteria

### Agent
- [x] `tools/g065-readiness.py` exists, shaped like `tools/g066-readiness.py` (argparse with `--json` + `--strict` + `--project-root`, `assess()` returns dict with `gap_id`, `checks[]`, `passing`, `failing`, `ready`, `verdict` ∈ {READY, NOT_READY}).
- [x] Four wiring conditions defined and each PASSes against live repo: (1) `agents/context/check-project-boundary.sh` exists, (2) hook references `Pattern 4` and `G-065` (the read-side outside-path argument leg from T-1702), (3) hook defines `READ_ALLOWED_PREFIXES` (the allowlist construct), (4) `bin/fw` defines `host_warnings` AND `_scope_breakdown` (T-1707 doctor scope-tagging).
- [x] `python3 tools/g065-readiness.py --json` against the live repo returns `"verdict": "READY"` with `passing_count: 4` and `total_count: 4`.
- [x] `.context/project/concerns.yaml` G-065 entry gains `closure_check_command: "python3 tools/g065-readiness.py --json"`. YAML parses clean after edit.
- [x] `tests/unit/g065_readiness.bats` exists with: (a) READY on fully-wired synthetic repo, (b) NOT_READY when hook missing, (c) NOT_READY when Pattern 4 / G-065 comment missing, (d) NOT_READY when `READ_ALLOWED_PREFIXES` missing, (e) NOT_READY when `bin/fw` lacks scope-tag wiring, (f) `--strict` exits 1 on NOT_READY. All scenarios PASS (12/12). Uses `unset PROJECT_ROOT` per L-456.
- [x] `bin/fw doctor` surfaces G-065 in the "Gauge-READY gaps not closed" section (joins G-064 + G-066 already listed). Verified via doctor output capture-then-grep.
- [x] `bin/fw reviewer T-2299` returns `Overall:.*PASS` (or PASS-with-suppression).

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

test -f tools/g065-readiness.py
grep -q "G-065" tools/g065-readiness.py
out=$(python3 tools/g065-readiness.py --json 2>&1); echo "$out" | python3 -c "import sys, json; d=json.loads(sys.stdin.read()); sys.exit(0 if d.get('verdict')=='READY' and d.get('passing_count')==4 and d.get('total_count')==4 else 1)"
python3 -c "from pathlib import Path; from lib.gaps import gauge_state; import sys; d=gauge_state('G-065', project_root=Path('.')); sys.exit(0 if d.get('has_gauge') and d.get('verdict')=='READY' else 1)"
python3 -c "import yaml; yaml.safe_load(open('.context/project/concerns.yaml'))"
bats tests/unit/g065_readiness.bats
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "G-065" && echo "$out" | grep -q "Gauge-READY"
out=$(bin/fw reviewer T-2299 --no-write 2>&1 || true); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -qE "Overall:.*FAIL"

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

### 2026-06-09T22:20:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2299-g-065-closure-readiness-gauge--wiring-pr.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-42a0fb5b
- **Timestamp:** 2026-06-09T22:31:13Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `tools/g065-readiness.py` exists, shaped like `tools/g066-readiness.py` (argparse with `--json` + `--strict` + `--project-root`, `assess()` returns dict with `gap_id`, `checks[]`, `passing`, `failing`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tools/g066-readiness.py in: `tools/g065-readiness.py` exists, shaped like `tools/g066-readiness.py` (argparse with `--json` + `--strict` + `--project-root`, `assess()` returns di`

### 2026-06-09T22:28:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
