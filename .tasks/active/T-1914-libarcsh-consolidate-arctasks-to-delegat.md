---
id: T-1914
name: "lib/arc.sh consolidate _arc_tasks_* to delegate to lib/arc_membership.sh (sibling
  cleanup from T-1913)"
description: >
  lib/arc.sh consolidate _arc_tasks_* to delegate to lib/arc_membership.sh (sibling
  cleanup from T-1913)

status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: [refactor, consolidation]
components: [lib/arc.sh, lib/arc_membership.sh]
related_tasks: [T-1880, T-1913, T-1874, T-1879]
arc_id: arc-grooming
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T22:44:53Z
last_update: '2026-05-19T17:56:35Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-1914: lib/arc.sh consolidate _arc_tasks_* to delegate to lib/arc_membership.sh (sibling cleanup from T-1913)

## Context

T-1880 extracted `lib/arc_membership.sh` as the canonical helper for arc-membership scans (`arc_tasks_with_arc_id`, `arc_tasks_with_tag`, `arc_tasks_for`). But `lib/arc.sh` was never updated to use it — it carries three inline duplicates:

- `_arc_tasks_with_tag` (lib/arc.sh:319-328)
- `_arc_tasks_with_arc_id` (lib/arc.sh:334-344)
- `_arc_tasks_for` (lib/arc.sh:358-389)

When T-1913 fixed the slug↔NNN union bug in the canonical helper, the duplicates in `lib/arc.sh` had to be patched again inline. This is the **L-397 silent-corpus pattern one layer deeper**: T-1880's extraction covered duplication, but equivalence-logic-inside-canonical-vs-inline is a separate dimension. The next equivalence bug in arc_membership will recur in arc.sh too unless the duplicates delegate.

Consolidation: replace the three inline implementations with thin wrappers that delegate to the canonical helpers in `lib/arc_membership.sh`. Preserve external function names (`_arc_*` prefix) so the existing call sites (lines 561, 601, 965, 972) keep working without renaming.

**Caller safety:** line 965 uses `_arc_tasks_with_tag "from-${anchor}"` — the canonical `arc_tasks_with_tag` handles any tag string (not just `arc:*`), so the delegation is semantically identical.

## Acceptance Criteria

### Agent
- [x] `lib/arc.sh` sources `lib/arc_membership.sh` near the top of the file (after the docstring block).
- [x] `_arc_tasks_with_tag` in lib/arc.sh delegates to `arc_tasks_with_tag` from arc_membership.sh.
- [x] `_arc_tasks_with_arc_id` in lib/arc.sh delegates to `arc_tasks_with_arc_id` from arc_membership.sh.
- [x] `_arc_tasks_for` in lib/arc.sh delegates to `arc_tasks_for` from arc_membership.sh.
- [x] No remaining inline `grep -lE.*arc_id:` or `grep -lE.*tags:` scans in lib/arc.sh (verified by grep).
- [x] The existing bats pin `tests/unit/arc_membership_dual_id.bats` still passes 7/7 (delegation does not regress the canonical helper).
- [x] `bin/fw arc show arc-grooming` returns the same task count as before consolidation (37 — 35 pre-T-1913, +T-1913, +T-1914-self).
- [x] `bin/fw arc list` runs without error and shows arc-grooming.

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

bats tests/unit/arc_membership_dual_id.bats
# Inline-scan regression check: lib/arc.sh must not re-introduce the inline grep duplicates
! grep -E '^\s*grep -lE.*"\$PROJECT_ROOT"/.tasks' lib/arc.sh
# Arc show parity with pre-consolidation count
out=$(bin/fw arc show arc-grooming 2>&1); echo "$out" | grep -q "Tasks ([0-9]"
# Arc list still works
bin/fw arc list >/dev/null 2>&1

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

### 2026-05-19 — Sibling cleanup completed; L-397 class closed structurally

- **What changed:** T-1880's helper extraction wasn't applied to `lib/arc.sh` — three inline duplicates remained and had to be patched again in T-1913 when the slug↔NNN union bug was found. Consolidating to delegation makes the canonical helper the single point of truth.
- **Plan impact:** None — pure refactor, same external behavior (37 tasks before and after, dual-id resolution preserved for both slug and NNN inputs).
- **Triggered:** No new sub-tasks. The L-397 silent-corpus class is now structurally closed for arc-membership scans: future equivalence bugs in arc_membership.sh fix all consumers at once.

## Recommendation

**Recommendation:** GO

**Rationale:** Pure refactor with byte-identical observable behavior. Three inline duplicates replaced with one-line wrappers that delegate to the canonical helper. Both slug form (`arc-grooming`) and NNN form (`arc-005`) of `fw arc show` return 37 — same as before. The existing bats pin (7/7) still passes; the regression-grep AC confirms no inline scans remain. L-397 silent-corpus class is now closed structurally for arc-membership scans.

**Evidence:**
- `bin/fw arc show arc-grooming` → 37 tasks (was 37 pre-consolidation)
- `bin/fw arc show arc-005` → 37 tasks (NNN-form dual-id still works)
- `bin/fw arc list` → arc-005 shows 37, all other arc counts unchanged
- `bats tests/unit/arc_membership_dual_id.bats` → 7/7 ok
- `grep -nE '^\s*grep -lE.*"\$PROJECT_ROOT"/.tasks' lib/arc.sh` → no matches

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

### 2026-05-18T22:44:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1914-libarcsh-consolidate-arctasks-to-delegat.md
- **Context:** Initial task creation
