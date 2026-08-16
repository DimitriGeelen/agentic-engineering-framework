---
id: T-2239
name: "_self_vendor_libs dry-run message says 'synced' when nothing was copied"
description: >
  lib/upgrade.sh:163 `_self_vendor_libs` prints 'Self-vendor: synced N file(s)' regardless
  of dry_run flag. In dry-run mode no files are copied (verified — git diff is clean
  after fw vendor self --dry-run) but the message reads as if work was done. Fix:
  branch the message on dry_run so dry-run prints 'would sync N file(s)' instead.
  Also: tests/unit/t2095_upgrade_self_vendor_extraction.bats t4 currently asserts
  the wrong (synced) wording in dry-run mode, encoding the bug into the spec. Update
  the assertion. Small bounded UX fix that prepares the helper for clean pre-push
  wiring (the F2 N×M follow-on to T-2095/T-2232/T-2237 durable upgrade-path chain)
  where the message will fire on every developer push.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-07T18:46:08Z
last_update: '2026-08-16T22:24:58Z'
date_finished: 2026-06-07T18:50:25Z
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
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2239: _self_vendor_libs dry-run message says 'synced' when nothing was copied

## Context

`lib/upgrade.sh:163` prints `Self-vendor: synced N file(s)` whenever `_sv_updated > 0`, regardless of `dry_run`. In dry-run mode the `cp` is correctly skipped (line 156 guard, verified — git diff on `.agentic-framework/lib/` is clean after `bin/fw vendor self --dry-run`), so the message lies about what happened. The bats spec encodes the same lie: `tests/unit/t2095_upgrade_self_vendor_extraction.bats` t4 (line 122) asserts `"synced 1 file"` after a dry-run call, so the test would not catch a regression in the wording. This is the F2 N×M follow-on to the T-2095/T-2232/T-2237 durable upgrade-path chain — the next leg is wiring `fw vendor self` into pre-push, where every developer push will see this message. Fix the wording before the surface multiplies.

## Acceptance Criteria

### Agent
- [x] `_self_vendor_libs` in `lib/upgrade.sh` emits `Self-vendor: would sync N file(s)` when `dry_run=true` AND `Self-vendor: synced N file(s)` when `dry_run=false`. Same prefix, distinct verb. No file mutation in dry-run (already guaranteed by the line 156 `cp` guard — preserved unchanged)
- [x] `tests/unit/t2095_upgrade_self_vendor_extraction.bats` t4 asserts the new `would sync` wording in dry-run and explicitly asserts the source/vendored copies still differ (vendored copy NOT mutated)
- [x] All 8 bats tests in `t2095_upgrade_self_vendor_extraction.bats` pass (t1-t8 — the rename of t4's assertion must not regress t3's `synced` assertion on the real-run path)
- [x] Live smoke from framework repo: `bin/fw vendor self --dry-run` emits `would sync` (or zero-file no-output when in-sync) AND mutates nothing under `.agentic-framework/lib/`
- [x] Reviewer scan passes: `bin/fw reviewer T-2239` → Overall PASS (or CONCERN with documented suppress)

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

grep -q "would sync" lib/upgrade.sh
grep -q "Self-vendor:.*synced" lib/upgrade.sh
grep -q "would sync" tests/unit/t2095_upgrade_self_vendor_extraction.bats
bats_out=$(bats tests/unit/t2095_upgrade_self_vendor_extraction.bats 2>&1); echo "$bats_out" | grep -q "^1\.\.8$" && echo "$bats_out" | grep -q "^ok 8 " && ! echo "$bats_out" | grep -q "^not ok"
smoke_out=$(bin/fw vendor self --dry-run 2>&1); echo "$smoke_out" | grep -qE "(would sync|^[[:space:]]*$)"
rev_out=$(bin/fw reviewer T-2239 2>&1); echo "$rev_out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$rev_out" | grep -q "Overall:.*FAIL"

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

**Symptom:** `bin/fw vendor self --dry-run` prints `Self-vendor: synced 13 file(s) to .agentic-framework/lib/` while git diff shows no actual file mutations. The wording reads as if work happened.

**Root cause:** `lib/upgrade.sh:163` formats the message off the `_sv_updated` counter alone, without branching on `dry_run`. The cp guard at line 156 (`if [ "$dry_run" != true ]; then cp ...`) correctly skips the copy in dry-run mode, but the message printer is unconditional. The count is correct (it tracks would-be-copies); the verb (`synced`) is wrong in dry-run.

**Why structurally allowed:** The bats spec `t2095 t4` (line 122) asserts `"synced 1 file"` after a dry-run call — it locks in the misleading wording rather than the would-be-sync semantic. Once tests document a behaviour, the regression net protects that behaviour, including the wrong parts. The L-359 class: spec-as-bug-encoding.

**Prevention:** The corrected `t4` assertion (`"would sync"`) becomes the regression net for the wording. A reader of the test sees `"would sync"` and learns the dry-run contract. Future refactors of `_self_vendor_libs` must preserve the dry-run/real-run wording split or fail t4. Belt-and-braces: the new t4 also asserts `[[ "$output" != *"Self-vendor:"*" synced 1 file"* ]]` — the negative form catches a regression where the real-run verb leaks into the dry-run path.

## Recommendation

**Recommendation:** GO

**Rationale:** Dry-run/real-run wording split is in place at the producer (`_self_vendor_libs:163-172`) and spec'd at the consumer (`t2095 t4`). Live smoke from the framework repo emits `Self-vendor: would sync 13 file(s) to .agentic-framework/lib/` and git diff on `.agentic-framework/lib/` stays clean — semantic and message agree. Reviewer PASS with zero findings after L-387 capture-then-grep cleanup on the Verification block.

**Evidence:**
- `lib/upgrade.sh:163-172`: branched message, comment cross-links T-2239 + F2 N×M follow-on
- `tests/unit/t2095_upgrade_self_vendor_extraction.bats:113-129`: t4 asserts `"would sync 1 file"` + negative assertion against the real-run verb leaking + dry-run mutation-absence preserved
- Bats: 8/8 PASS (t1-t8)
- Live smoke: `bin/fw vendor self --dry-run` → `would sync 13 file(s)`; `git diff --stat .agentic-framework/lib/` → empty
- Reviewer: R-c6b5bb70 Overall PASS, 0 findings (after L-387 fix from initial R-961dc894 CONCERN)

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

### 2026-06-07T18:46:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2239-selfvendorlibs-dry-run-message-says-sync.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a3ee9cd1
- **Timestamp:** 2026-06-07T18:50:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-07T18:50:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
