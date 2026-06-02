---
id: T-2163
name: "horizon write-side prevention: null horizon at close-time in update-task.sh"
description: >
  Slice 4 of arc-009 horizon-axis-hardening. After T-2162 added the read-side audit rail (CTL-030 catches drift), every task close still produces a fresh drift candidate that requires running the migration to clean. This slice plugs the source: when update-task.sh moves a task to .tasks/completed/ (full close, not partial-complete), null the stored horizon in the same write so no drift is ever introduced. Partial-complete (stays in active/) keeps its horizon since that branch still renders via the stored value. AC: (i) post-close, the just-moved file has horizon: null; (ii) re-running the migration after a fresh close emits 0 changes; (iii) bats test pinning full-close vs partial-complete behavior.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:horizon-axis-hardening]
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-01T12:21:05Z
last_update: 2026-06-01T12:27:28Z
date_finished: 2026-06-01T12:27:28Z
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

# T-2163: horizon write-side prevention: null horizon at close-time in update-task.sh

## Context

Slice 4 of arc-009 horizon-axis-hardening. Plugs the recurrence loop's source: after every full task close, `update-task.sh` currently leaves the stored `horizon:` value untouched, so each new close is a fresh drift candidate that CTL-030 catches and the migration cleans. This slice nulls horizon in the same write that moves the file to `.tasks/completed/`, so no drift is ever introduced.

Partial-complete (stays in active/) keeps its horizon since the active/ render path still uses the stored value.

## Acceptance Criteria

### Agent
- [x] `update-task.sh` nulls the stored horizon field on full close (the branch that moves to `.tasks/completed/`) — not on partial-complete (which keeps the file in active/).
- [x] After closing a fresh task via this code path, the just-moved file in `.tasks/completed/` has `horizon: null`. Verified by reading the file post-close in the bats test.
- [x] Re-running `bin/migrate-horizon-null-completed.sh` after a fresh full close emits `0 changes` (no new drift candidates).
- [x] Bats test pins both branches: (a) full close → file in completed/ with `horizon: null`; (b) partial-complete (1 unchecked Human AC) → file stays in active/ with horizon preserved.
- [x] At least one commit references `T-2163` AND `arc-009` (or `horizon-axis-hardening`).

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

# AC1: update-task.sh has the null-horizon line in the full-close branch
grep -q "T-2163.*horizon-axis-hardening" agents/task-create/update-task.sh
grep -q "horizon: null" agents/task-create/update-task.sh

# AC2-AC4: bats tests pass (pin write-side behavior end-to-end)
bats tests/unit/update_task_horizon_null_on_close.bats >/tmp/.t2163-bats 2>&1; grep -q "^ok 4" /tmp/.t2163-bats

# AC5: commit reference verified post-commit; left for git log inspection

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

### 2026-06-01 — pipefail-on-missing-tags caught during bats build
- **What changed:** Initial test fixture omitted `tags:` field, which trips `check_rca_for_bugfix` under `set -eo pipefail` (the `grep '^tags:'` returns 1 on a tag-less file → pipeline fails → script exits silently). Fixed by adding `tags: []` to the test fixture template.
- **Plan impact:** None for the slice itself; the bats fixture is sturdier.
- **Triggered:** No new sub-task. Class is documented in CLAUDE.md as L-387 SIGPIPE family, but this is a different surface (grep-no-match-on-frontmatter-field). Worth a memory note if it recurs.

### 2026-06-01 — closes the recurrence loop fully
- **What changed:** Combined with Slice 3 (T-2162 CTL-030 read-side rail), arc-009 now has both write-side prevention and read-side detection. The migration script (T-2161) is now ONLY needed for the one-time historical sweep — future closes don't introduce drift.
- **Plan impact:** Arc-009 is fully structurally closed on the recurrence dimension. Headline mechanic continues to hold; demo evidence in `docs/reports/arc-009-demo-evidence.md` remains valid.
- **Triggered:** Update arc-009 demo evidence note to mention Slice 4.

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

## Recommendation

**Recommendation:** GO — close.

**Rationale:** All 5 Agent ACs pass. Write-side prevention is now in `update-task.sh:1660` — one `sed` line, scoped to the full-close branch only (partial-complete keeps horizon). Bats covers both branches plus horizon=next variant plus migration-zero-changes-after-close. arc-009 recurrence loop is now structurally closed at both surfaces (write-side prevention here + read-side rail CTL-030 from T-2162).

**Evidence:**
- `agents/task-create/update-task.sh:1660-1668` — null-horizon write inside full-close branch with T-2163 + arc-009 comment trail
- `tests/unit/update_task_horizon_null_on_close.bats` — 4 cases, all green
- Test 4 specifically verifies post-close + migration rerun = 0 changes (the loop is closed)
- Partial-complete branch unaffected: test 2 confirms file stays in active/ with horizon preserved.

## Decisions

### 2026-06-01 — null at move time, not at AC-tick time
- **Chose:** Inject `_sed_i 's/^horizon:.*/horizon: null/'` right after the move-to-completed line.
- **Why:** Single-purpose code at the move boundary is easy to reason about — it mirrors `date_finished` assignment which happens right before the move. Any future refactor that changes the close flow will inevitably touch this region; the comment trail makes the intent explicit.
- **Rejected:** Earlier in the AC-tick flow (would null prematurely before the gate checks pass); in a separate function (adds indirection for one sed line).

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

### 2026-06-01T12:21:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2163-horizon-write-side-prevention-null-horiz.md
- **Context:** Initial task creation

### 2026-06-01T12:22:43Z — status-update [task-update-agent]
- **Change:** tags: +arc:horizon-axis-hardening

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b0c28654
- **Timestamp:** 2026-06-02T15:01:27Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — Re-running `bin/migrate-horizon-null-completed.sh` after a fresh full close emits `0 changes` (no new drift candidates).
  - **AC-verify-mismatch** (narrow, heuristic) — `path=bin/migrate-horizon-null-completed.sh in: Re-running `bin/migrate-horizon-null-completed.sh` after a fresh full close emits `0 changes` (no new drift candidates).`
### 2026-06-01T12:27:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
