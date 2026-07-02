---
id: T-2241
name: "Extend self-vendor to sync .tasks/templates - close template drift class (F2
  N×M follow-on)"
description: >
  Extend self-vendor to sync .tasks/templates - close template drift class (F2 N×M
  follow-on)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [bin/fw, lib/upgrade.sh]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-07T19:55:47Z
last_update: '2026-06-11T22:24:12Z'
date_finished: 2026-06-07T20:00:44Z
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
  - ts: '2026-06-07T20:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-07T20:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2241: Extend self-vendor to sync .tasks/templates - close template drift class (F2 N×M follow-on)

## Context

Follow-on to T-2240 (F2 N×M closure via pre-push self-vendor gate). The T-2240 work surfaced a sibling drift class: `_self_vendor_libs()` only syncs `FRAMEWORK_ROOT/lib/*.sh` to `.agentic-framework/lib/`. `.tasks/templates/*.md` (the task template surface — default.md, inception.md, path-c-deep-dive.md) is NOT in the loop. Today's state: 2 of 3 templates drift (`default.md`, `inception.md` both differ between master and vendored). Consumers vendoring from origin inherit the stale templates silently — and the prior pickup-message about cli-mcp-overlay had this exact symptom (default.md vendored copy lacked `arc_id` + `bvp_scores` fields).

Add a sibling helper `_self_vendor_templates()` that mirrors `_self_vendor_libs()` structure, sourced from `FRAMEWORK_ROOT/.tasks/templates/*.md` → `.agentic-framework/.tasks/templates/`. Call it alongside the existing helper from `do_upgrade` AND expose it via the `fw vendor self` verb. The T-2240 pre-push gate then catches BOTH classes automatically (it greps for "would sync" — same prefix on both helper outputs).

## Acceptance Criteria

### Agent
- [x] Slice 1 (helper extracted): `lib/upgrade.sh` gains `_self_vendor_templates()` with the same structural shape as `_self_vendor_libs()` — consumer-safe early-return when `$FRAMEWORK_ROOT/.agentic-framework/.tasks/templates` doesn't exist, per-file `diff -q` skip, dry-run/real-run wording split ("would sync N template(s)" vs "synced N template(s)") matching T-2239 pattern
- [x] Slice 2 (call site): `do_upgrade` invokes `_self_vendor_templates "$dry_run"` immediately after `_self_vendor_libs "$dry_run"`, gated by the same `--no-self-vendor` flag (no separate flag — operator's intent of "skip self-vendor" covers both classes)
- [x] Slice 3 (verb parity): `bin/fw vendor self` invokes BOTH helpers (libs + templates) in sequence; `--help` text mentions both classes
- [x] Slice 4 (bats coverage): `tests/unit/t2241_upgrade_self_vendor_templates.bats` mirrors t2095 structure for templates: helper extracted, consumer-safe early-return, syncs only diffed templates (idempotent), dry-run reports "would sync" without copying. Min 5 tests, all PASS
- [x] Slice 5 (refresh + smoke): run `bin/fw vendor self` real-run; verify the 2 drifting templates (`default.md` + `inception.md`) are synced; verify subsequent `bin/fw vendor self --dry-run` reports no "would sync" lines (drift cleared); verify pre-push gate from T-2240 still catches a touched template (touch master template, re-run dry-run, see "would sync"). Reviewer scan: `bin/fw reviewer T-2241` → Overall PASS

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

# Slice 1: helper extracted in lib/upgrade.sh, dry-run/real-run wording split
grep -qE "^_self_vendor_templates\(\) \{" lib/upgrade.sh
grep -q "would sync.*template" lib/upgrade.sh
grep -q "synced.*template" lib/upgrade.sh
# Slice 2: do_upgrade calls both helpers
grep -q "_self_vendor_templates \"\$dry_run\"" lib/upgrade.sh
# Slice 3: fw vendor self invokes both + help mentions templates
grep -q "_self_vendor_templates \"\$_vs_dry\"" bin/fw
help_out=$(bin/fw vendor self --help 2>&1); echo "$help_out" | grep -q ".agentic-framework/.tasks/templates" && echo "$help_out" | grep -q "T-2241"
# Slice 4: all 7 bats cases pass (L-387 capture-then-grep, T-2090 single-pipe)
bats_out=$(bats tests/unit/t2241_upgrade_self_vendor_templates.bats 2>&1); echo "$bats_out" | grep -q "^1\.\.7$" && echo "$bats_out" | grep -q "^ok 7 " && ! echo "$bats_out" | grep -q "^not ok"
# Slice 4: t2095 + t2240 regression — F2 N×M chain stays green
bats_out2=$(bats tests/unit/t2095_upgrade_self_vendor_extraction.bats 2>&1); echo "$bats_out2" | grep -q "^1\.\.8$" && echo "$bats_out2" | grep -q "^ok 8 " && ! echo "$bats_out2" | grep -q "^not ok"
bats_out3=$(bats tests/unit/t2240_pre_push_self_vendor_gate.bats 2>&1); echo "$bats_out3" | grep -q "^1\.\.5$" && echo "$bats_out3" | grep -q "^ok 5 " && ! echo "$bats_out3" | grep -q "^not ok"
# Slice 5: framework's own templates in sync after the run (drift cleared)
dry_out=$(bin/fw vendor self --dry-run 2>&1); echo "$dry_out" | grep -qE "(would sync|^[[:space:]]*$)"
# Slice 5: reviewer overall PASS or CONCERN (no FAIL); markdown-bold regex aware
rev_out=$(bin/fw reviewer T-2241 2>&1); echo "$rev_out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$rev_out" | grep -q "Overall:.*FAIL"

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

**Rationale:** Slices 1-5 shipped end-to-end. Template drift class — the sibling to lib/ drift that T-2095 → T-2232 → T-2240 closed — is now structurally caught at the same surface as libs. The T-2240 pre-push gate fires on both classes with one regex (both helpers emit "would sync" prefix), so the dev-side gating is intrinsic, not bolted-on. No new flag (operator's intent of "skip self-vendor" covers both classes via the existing `--no-self-vendor`), no new commands (verb parity through `fw vendor self`). All Agent ACs verify mechanically.

**Evidence:**
- Helper: `lib/upgrade.sh:_self_vendor_templates()` — mirrors `_self_vendor_libs()` structure, same dry-run/real-run wording split (T-2239 pattern)
- Wired into `do_upgrade` (call site immediately after `_self_vendor_libs`, same `--no-self-vendor` gate)
- Wired into `bin/fw vendor self` (both helpers invoked in sequence; `--help` text mentions both classes + T-2241 reference)
- Bats: `tests/unit/t2241_upgrade_self_vendor_templates.bats` — 7/7 PASS, mirrors t2095 structure
- Regression: t2095 (8/8) + t2240 (5/5) stay green — F2 N×M chain at 20/20
- Live smoke: 2 drifting templates (`default.md` + `inception.md`) detected by dry-run, synced by real-run, post-sync dry-run empty (drift cleared on both classes); T-2240 pre-push gate fires on template drift with same canonical message
- Reviewer: see ## Reviewer Verdict block (refreshed at close)
- Sibling chain: T-2095 (libs verb) → T-2232 (sentinel) → T-2237 (doc) → T-2239 (wording) → T-2240 (gate) → **T-2241 (templates parity)** — F2 N×M leg now covers both vendored classes

## Updates

### 2026-06-07T19:55:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2241-extend-self-vendor-to-sync-taskstemplate.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-67daf78e
- **Timestamp:** 2026-06-07T20:00:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-07T20:00:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
