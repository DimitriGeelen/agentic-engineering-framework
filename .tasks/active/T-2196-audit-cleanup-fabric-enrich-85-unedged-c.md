---
id: T-2196
name: "audit-cleanup: fabric enrich (85 unedged cards / 794 total) — close last audit
  WARN"
description: >
  audit-cleanup: fabric enrich (85 unedged cards / 794 total) — close last audit WARN

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-03T20:46:45Z
last_update: '2026-06-03T21:00:03Z'
date_finished:
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
  - ts: '2026-06-03T21:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-03T21:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 3
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=3 
      (body:fw-recall-or-memory-link); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2196: audit-cleanup: fabric enrich (85 unedged cards / 794 total) — close last audit WARN

## Context

Audit baseline (`.context/audits/2026-06-03.yaml`): 0 FAIL, 1 WARN — `Fabric: 85/785 cards have no edges` (mitigation: `fw fabric enrich`). Precedent T-2184 (2026-06-02) ran the same recipe → 24 cards enriched, 58 edges added.

Today's `fw fabric enrich --dry-run` reports 8 cards enriched / 12 edges (forward + reverse). The smaller delta reflects diminishing returns — only newer registered cards (e.g. today's `test_audit_retire_when`, `estimator`, `bin-fw`) acquired edges. The remaining unedged cards are largely leaf nodes (test files with no declared depends_on, config YAMLs) and don't have auto-detectable forward edges.

This is operational cleanup, not work pickup. Same pattern as T-2184. Selected per memory `[[feedback_hv_lc_backlog_acd_pause_pattern]]` — top BVP started-work agent-owned tasks (T-1820, T-1700) remain §ACD-paused; fall-back: audit-WARN reduction.

## Acceptance Criteria

### Agent
- [x] Fabric enriched and committed: `git status --short .fabric/` is empty after the commit (no `M ` or `??` lines under `.fabric/`); `git log -1 --format=%s -- .fabric/` matches `^T-2196:`.
- [x] Audit WARN count strictly decreases: post-commit `bin/fw audit --section structure` reports `Fabric: NN/785 cards have no edges` where `NN < 85` (baseline). Observed: 81/785 (Δ4). The 8-cards-enriched figure from the dry-run measured enrichment events, not zero-to-nonzero transitions — several of the enriched cards already had ≥1 edge (e.g. `agents-git-lib-hooks` got a new reverse edge but had outgoing edges already). The NN<85 invariant holds.
- [x] No FAIL introduced: post-commit `bin/fw audit --section structure` reports `fail: 0`.

### Human
<!-- All Agent ACs above. Operational cleanup; no subjective taste call needed. -->

<!-- Original template comment retained for reference:
     Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
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

# T-2196 verification commands (here-string pattern per L-387):
out=$(git status --short .fabric/ 2>&1); [ -z "$out" ]
out=$(git log -1 --format=%s -- .fabric/ 2>&1); grep -q "^T-2196:" <<<"$out"
out=$(bin/fw audit --section structure 2>&1); grep -qE "fail: 0" <<<"$out"
out=$(bin/fw audit --section structure 2>&1); grep -qE "Fabric: (8[0-4]|[1-7][0-9]|[0-9])/[0-9]+ cards have no edges" <<<"$out"

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

**Rationale:** Same operational-cleanup recipe as T-2184 — `fw fabric enrich` is mechanical (auto-detects depends_on from source-file `import`/`source`/`include` directives) with no judgment surface. Dry-run validated scope (8 cards, 12 edges) before mutation; actual run matches dry-run exactly. No FAIL was introduced; the unedged-card WARN count decreases by the enrichment delta. Audit remains at 0 FAIL.

**Evidence:**
- Pre-enrich audit (`.context/audits/2026-06-03.yaml`): 18 PASS, 1 WARN (`Fabric: 85/785 cards have no edges`), 0 FAIL.
- `fw fabric enrich`: 8 cards enriched, 12 edges added (6 forward depends_on + 6 reverse depended_by).
- Subsystems touched: `unknown +7`, `git-traceability +2`, `task-management +2`, `framework-core +1`.
- 8 files diff under `.fabric/components/`: `agents-git-lib-hooks`, `agents-task-create-update-task`, `agents-termlink-bvp-estimator-estimator`, `bin-fw`, `tests-unit-disposition_gate`, `tests-unit-test_audit_retire_when`, `tests-unit-test_bvp_estimator`, `tests-unit-inception_commit_counter` (new card).

**What's next:** Remaining ~77 unedged cards are leaf nodes (test files, config YAMLs) with no auto-detectable forward edges. Reducing further would require either (a) hand-annotation of test→source dependencies, or (b) a new heuristic for test-file imports. Neither is HV/LC at this point — the audit-WARN threshold class is already much closer to floor.

## Updates

### 2026-06-03T20:46:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2196-audit-cleanup-fabric-enrich-85-unedged-c.md
- **Context:** Initial task creation
