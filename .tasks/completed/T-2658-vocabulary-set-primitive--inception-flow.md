---
id: T-2658
name: "vocabulary-set primitive + inception-flow/audit-cron rails (T-2652 slice 2)"
description: >
  vocabulary-set primitive + inception-flow/audit-cron rails (T-2652 slice 2)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-004, tests/unit/test_corpus_conformance_registry.py, tools/conformance-registry.yaml, tools/corpus_conformance.py]
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
created: 2026-07-28T11:07:51Z
last_update: 2026-07-28T11:16:22Z
date_finished: 2026-07-28T11:16:22Z
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
  - ts: '2026-07-28T11:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-28T11:15:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2658: vocabulary-set primitive + inception-flow/audit-cron rails (T-2652 slice 2)

## Context

T-2652 GO slice 2 (design: `docs/reports/T-2652-conformance-rail-generalization.md`).
Implements the second comparison primitive — **vocabulary-set equality** (a map
gateway's branch set vs an enforced enum in code) — in `tools/corpus_conformance.py`,
and registers the first two rails that use it:

- `aef-inception-flow`: decision gateway branches vs the decide-verb enum in
  `lib/inception.sh` (`go|no-go|defer`).
- `aef-audit-cron`: sweep-result gateway branches vs the audit exit-code contract
  (`0 pass / 1 warn / 2 fail`, `agents/audit/audit.sh`).

Registry entries carry primitive-specific keys (which gateway, how to extract the
enforced vocabulary from the source). Slice 1 (T-2654) shipped the registry +
dispatch; unknown-primitive registration was an explicit exit-2 error until this
slice lands the extractor.

## Acceptance Criteria

### Agent
- [x] `vocabulary-set` primitive implemented in `tools/corpus_conformance.py` and registered in `PRIMITIVE_CHECKS`; registering a map with it no longer exits 2
- [x] Extraction is declarative via registry keys (gateway selector + enforced-vocab extraction spec), not hard-coded per map — a third vocab rail should need only a registry entry
- [x] `aef-inception-flow` registry entry lands and the rail passes against the live map + `lib/inception.sh` decide verbs (or surfaces a real divergence, reported honestly) — PASS live: `{defer, go, no-go}`
- [x] `aef-audit-cron` registry entry lands and the rail passes against the live map + audit exit contract (or surfaces a real divergence, reported honestly) — PASS live: `{0, 1, 2}`
- [x] Negative paths tested: missing gateway in map, enforced-vocab extraction failure, and a genuine vocab mismatch each produce actionable non-zero results (no tracebacks)
- [x] Audit `check_map_conformance` reports the new entries per-map with PASS/WARN evidence lines; existing `aef-task-lifecycle` verdict unchanged (pass wording made primitive-neutral: "matches its enforced machine")
- [x] Unit tests extended (`tests/unit/test_corpus_conformance_registry.py`: 9 new vocab tests incl. 2 live-rail pins) covering the new primitive's pass/divergent/error paths; full conformance test files green (26/26)

<!-- Human section removed: all criteria are deterministic (code + tests + audit
     lines), verified by the commands in ## Verification. No taste judgment. -->

## Verification

python3 -m pytest tests/unit/test_corpus_conformance_registry.py tests/unit/test_corpus_conformance.py -q
out=$(python3 tools/corpus_conformance.py --map aef-inception-flow 2>&1); echo "$out" | grep -q "PASS"
out=$(python3 tools/corpus_conformance.py --map aef-audit-cron 2>&1); echo "$out" | grep -q "PASS"
out=$(python3 tools/corpus_conformance.py --all 2>&1); echo "$out" | grep -c "PASS" | grep -q "^3$"
python3 -c "import yaml; yaml.safe_load(open('tools/conformance-registry.yaml'))"

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

### 2026-07-28T11:07:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2658-vocabulary-set-primitive--inception-flow.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ce665690
- **Timestamp:** 2026-07-28T11:16:27Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `out=$(python3 tools/corpus_conformance.py --all 2>&1); echo "$out" | grep -c "PASS" | grep -q "^3$"`

### 2026-07-28T11:16:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
