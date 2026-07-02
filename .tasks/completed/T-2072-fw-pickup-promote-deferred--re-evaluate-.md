---
id: T-2072
name: "fw pickup promote-deferred — re-evaluate auto-deferred envelopes when blockers
  ship"
description: >
  Follow-up to T-2071 RCA. Pickup pipeline's G-059 triple-dedup auto-defer is one-way:
  envelopes route to .context/pickup/auto-deferred/ with a breadcrumb naming the blocking
  task, but no mechanism promotes them back when the blocker reaches work-completed.
  Manual cleanup (T-2071) showed P-009 + P-041 sat 1+ month after their blockers shipped.
  Build: 'fw pickup promote-deferred' verb that scans auto-deferred/*.breadcrumb.yaml,
  reads blocking_task: field, checks .tasks/completed/ for that ID, and relocates
  the envelope + breadcrumb to processed/ (or inbox/ for fresh reprocessing). Wire
  into existing pickup-pipeline cron (15-min cadence matches mirror sync). L-441 symmetry
  rule: asymmetric guards manufacture stale state. Same class as T-1912 closing T-1839's
  half-fix. See T-2071 RCA for detail.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/pickup.sh]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-28T17:43:53Z
last_update: '2026-06-11T22:24:06Z'
date_finished: 2026-05-28T19:37:56Z
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
  - ts: '2026-05-28T17:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-28T17:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2072: fw pickup promote-deferred — re-evaluate auto-deferred envelopes when blockers ship

## Context

Closes the L-441-class asymmetry on the pickup pipeline: G-059 auto-defers a triple-collision envelope to `.context/pickup/auto-deferred/` and drops a `.breadcrumb.yaml` naming the blocking local task, but there is no inverse — when the blocking task reaches `.tasks/completed/` nothing promotes the deferred envelope back onto the inbox. T-2071 RCA found P-009 + P-041 sat for 30+ days post-blocker-completion. This adds a `fw pickup promote-deferred` verb that walks each breadcrumb, checks `.tasks/completed/` for the named blocker, and moves the envelope back to `inbox/` for normal re-processing on the next 1-min `pickup process` cron. Same shape as T-1912 closing T-1839's half-fix.

## Acceptance Criteria

### Agent
- [x] `fw pickup promote-deferred` verb exists in `lib/pickup.sh` (alongside `process`/`status`/`list`/`auto-deferred`). Default action: scan `auto-deferred/*.yaml` (skipping `*.breadcrumb.yaml`), read sibling breadcrumb's `blocking_task:`, if that T-ID exists in `.tasks/completed/T-XXX-*.md` → `mv` envelope to `inbox/`, `rm` the breadcrumb, print one PROMOTE line per envelope. If still blocked: STILL-BLOCKED line. If breadcrumb missing: ORPHAN line.
- [x] `--dry-run` flag prints `WOULD PROMOTE`/`WOULD SKIP` without mutating disk.
- [x] `fw pickup process` auto-fires `pickup_promote_deferred` at the start (before scanning inbox). One-cron pattern (T-1112): no separate cron job. Promoted envelopes land in inbox the same tick and get processed in the same run.
- [x] `bats tests/unit/pickup_promote_deferred.bats` covers: (a) empty auto-deferred → no-op; (b) deferred envelope + completed blocker → promoted to inbox, breadcrumb removed; (c) deferred envelope + still-active blocker → untouched; (d) deferred envelope + orphan (no breadcrumb) → ORPHAN line, untouched; (e) `--dry-run` mutates nothing; (f) integration via `fw pickup process` auto-fires promote then processes promoted envelope in the same tick. 8/8 green.
- [x] `fw pickup` help text mentions `promote-deferred` alongside the existing subcommands; `fw pickup promote-deferred -h` prints its own usage block.

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
bash -n lib/pickup.sh
bash -n bin/fw
bats tests/unit/pickup_promote_deferred.bats
out=$(bin/fw pickup 2>&1); echo "$out" | grep -q "promote-deferred"
out=$(bin/fw pickup promote-deferred -h 2>&1); echo "$out" | grep -q "promote-deferred"
out=$(bin/fw pickup promote-deferred --dry-run 2>&1); echo "$?" | grep -q "^0$"
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

## Recommendation

**Recommendation:** GO (complete)

**Rationale:** L-441 symmetry restored on the pickup pipeline. G-059's auto-defer is no longer one-way — when a blocking task reaches `completed/`, the deferred envelope is promoted back to `inbox/` automatically on the next `pickup process` cron tick (1-min cadence). No new cron registration: the verb auto-fires from `pickup process`, matching the T-1112 single-cron pattern. Same shape as T-1912's closure of T-1839's half-fix.

**Evidence:**
- `lib/pickup.sh`: new `pickup_promote_deferred()` function (~75 lines) walks `auto-deferred/`, reads sibling breadcrumb's `blocking_task:`, checks `.tasks/completed/`, moves envelope + removes breadcrumb on match. Sets `last_promoted`/`last_skipped`/`last_orphan` globals.
- `lib/pickup.sh`: `process` case auto-fires `pickup_promote_deferred` before scanning inbox (same `--dry-run` propagation).
- `lib/pickup.sh`: `promote-deferred` subcommand case with `--dry-run` + `-h/--help`; help text wired into `fw pickup` usage.
- `tests/unit/pickup_promote_deferred.bats`: 8 scenarios, all green in ~0.4s. Covers empty / promote / still-blocked / orphan / dry-run / dry-run-still-active / integration-via-process / mixed-batch.
- Live smoke: `fw pickup promote-deferred` on real empty auto-deferred → `0 promoted, 0 still blocked, 0 orphan`. `fw pickup process --dry-run` auto-fires promote silently then scans empty inbox.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-28T17:43:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2072-fw-pickup-promote-deferred--re-evaluate-.md
- **Context:** Initial task creation

### 2026-05-28T19:33:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c7879c53
- **Timestamp:** 2026-06-02T15:22:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - mock-only-integration @ AC vs Verification cross-check
### 2026-05-28T19:37:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
