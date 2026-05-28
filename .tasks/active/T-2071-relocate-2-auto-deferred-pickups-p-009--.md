---
id: T-2071
name: "relocate 2 auto-deferred pickups (P-009 + P-041) whose blockers (T-1498 + T-1541) shipped — files no longer block, manual cleanup"
description: >
  P-009 (status query, low priority) and P-041 (bugfix-fw-task-verify) sit in .context/pickup/auto-deferred/ blocked by T-1498 and T-1541 respectively. Both blockers shipped (work-completed in .tasks/completed/). The pickup pipeline has no auto-promotion mechanism for auto-deferred envelopes when their blockers complete — they sit indefinitely. Cleanup: relocate both envelopes (+ breadcrumb sidecars) from auto-deferred/ to processed/. RCA: note the missing promotion mechanism so a future task can ship it structurally.

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
created: 2026-05-28T17:40:50Z
last_update: 2026-05-28T17:40:50Z
date_finished: null
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

# T-2071: relocate 2 auto-deferred pickups (P-009 + P-041) whose blockers (T-1498 + T-1541) shipped — files no longer block, manual cleanup

## Context

`fw pickup auto-deferred` lists 2 envelopes still blocked by tasks that have shipped:

- `P-009-bug-report-from-ntb-atc.yaml` — status query (low priority), blocked-by `T-1498` (work-completed)
- `P-041-bugfix-fw-task-verify-from-ntb-atc.yaml` — bugfix re-report, blocked-by `T-1541` (work-completed)

Both blocking tasks are in `.tasks/completed/`. The pickup pipeline (`lib/pickup.sh`) has no auto-promotion mechanism — once an envelope is auto-deferred via G-059 triple-dedup, it sits indefinitely even after the blocker ships. Manual cleanup unblocks the auto-deferred surface; a follow-up task can ship the auto-promotion structurally.

## Acceptance Criteria

### Agent
- [x] P-009 envelope (+ breadcrumb) moved from `.context/pickup/auto-deferred/` to `.context/pickup/processed/`
- [x] P-041 envelope (+ breadcrumb) moved from `.context/pickup/auto-deferred/` to `.context/pickup/processed/`
- [x] `fw pickup status` reports `Auto-deferred: 0` after relocation (verified — `Processed: 71` up from 67)
- [x] RCA section captures the auto-promotion gap (no mechanism re-evaluates auto-deferred envelopes when blockers ship) as a deferred follow-up — not a same-task fix (filed in RCA Prevention clause)

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

# T-2071 verification
[ ! -f .context/pickup/auto-deferred/P-009-bug-report-from-ntb-atc.yaml ]
[ ! -f .context/pickup/auto-deferred/P-041-bugfix-fw-task-verify-from-ntb-atc.yaml ]
[ -f .context/pickup/processed/P-009-bug-report-from-ntb-atc.yaml ]
[ -f .context/pickup/processed/P-041-bugfix-fw-task-verify-from-ntb-atc.yaml ]
out=$(bin/fw pickup status 2>&1); echo "$out" | grep -q "Auto-deferred: *0"

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

**Symptom:** 2 auto-deferred pickup envelopes (P-009 + P-041) sit in `.context/pickup/auto-deferred/` indefinitely, even though their named blocking tasks (T-1498 + T-1541) both shipped weeks ago. `fw pickup status` keeps reporting `Auto-deferred: 2`.

**Root cause:** `lib/pickup.sh` G-059 triple-dedup auto-defer is one-way — when the same logical concern arrives a third time it routes to `auto-deferred/` + writes a breadcrumb with `blocking_task: T-XXXX`. There is no re-evaluation pass that scans auto-deferred envelopes and promotes them back to `inbox/` (or moves to `processed/`) once the blocker reaches `work-completed`.

**Why structurally allowed:** The auto-defer mechanism was built (T-1425) as a safety valve for repeat-spam; the promotion side was never paired (asymmetric guard, same class as L-441 half-guard symmetry from T-1912). Reasonable at filing — "the operator will handle it" — but in practice no one ever did, and there is no surfaced timer or audit warning that auto-deferred entries are stale.

**Prevention (deferred, not in this task):** File a follow-up build task to add a `fw pickup promote-deferred` verb that scans `.context/pickup/auto-deferred/*.breadcrumb.yaml`, reads `blocking_task:`, checks `.tasks/completed/` for that ID, and relocates the envelope + breadcrumb to `processed/` (or back to `inbox/`) when the blocker has shipped. Wire it into the existing pickup-pipeline cron. This task ships only the manual cleanup; the structural fix is intentionally split (one bug = one task per CLAUDE.md sizing rules).

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

### 2026-05-28T17:40:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2071-relocate-2-auto-deferred-pickups-p-009--.md
- **Context:** Initial task creation
