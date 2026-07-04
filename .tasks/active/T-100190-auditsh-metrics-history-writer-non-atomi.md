---
id: T-100190
name: "audit.sh metrics-history writer non-atomic: truncating open-w corrupts YAML when killed mid-dump"
description: >
  audit.sh metrics-history writer non-atomic: truncating open-w corrupts YAML when killed mid-dump

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
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-07-04T23:37:38Z
last_update: 2026-07-04T23:37:38Z
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

# T-100190: audit.sh metrics-history writer non-atomic: truncating open-w corrupts YAML when killed mid-dump

## Context

Found 2026-07-05 when the pre-push YAML gate (T-1599/T-1610) blocked a push: `.context/project/metrics-history.yaml` was truncated mid-entry (file ended with a bare `warn`, no colon/newline). The writer at `agents/audit/audit.sh:5131` does `open(METRICS_FILE, "w")` — a truncating in-place rewrite (the block also prunes/downsamples, so it rewrites the whole file each audit run). A kill mid-`yaml.dump` (cron audit killed by pkill / session teardown — see T-100146) leaves a corrupt file. Third instance of the non-atomic-YAML-write class: T-2457 (fabric cards, L-493), T-2456 (fw note, L-492). Fix: same-dir temp + `os.replace`. Immediate corruption was recovered via `git checkout -- .context/project/metrics-history.yaml` (HEAD copy valid; cron re-appends).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `agents/audit/audit.sh` metrics-history block writes via same-dir temp file + `os.replace` (no truncating `open(METRICS_FILE, "w")` on the live path)
- [x] bats test pins the atomic pattern (temp+replace present; direct `"w"` write on METRICS_FILE absent) and the writer round-trips: run the extracted python block against a fixture history and the output parses as YAML with entries preserved

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

# Origin-based checks (MAIN's branch lags origin/master where this lands).
git show origin/master:agents/audit/audit.sh > /tmp/.t100190-audit.sh && grep -q "os.replace(tmp_path, METRICS_FILE)" /tmp/.t100190-audit.sh
! grep -q 'with open(METRICS_FILE, "w")' /tmp/.t100190-audit.sh
git show origin/master:tests/unit/audit_metrics_history_atomic.bats > /tmp/.t100190-bats && grep -q "T-100190" /tmp/.t100190-bats
python3 -c "import yaml; yaml.safe_load(open('.context/project/metrics-history.yaml'))"

## RCA

**Symptom:** `git push` from MAIN blocked by the pre-push YAML gate: `.context/project/metrics-history.yaml` failed to parse (truncated mid-entry, last line a bare `warn`).

**Root cause:** the METRICS_EOF block in `agents/audit/audit.sh` rewrote the whole history file in place via truncating `open(METRICS_FILE, "w")`. Any kill mid-`yaml.dump` (cron audit terminated by pkill/session teardown — the T-100146 environment) leaves a partial file. Prune+downsample means every audit run rewrites the entire file, so the exposure window is every run, not just appends.

**Why structurally allowed:** the framework has an atomic-write learning (L-493, from T-2457 fabric cards and T-2456 fw note) but no corpus-wide sweep — each non-atomic writer is found only when its file corrupts. The pre-push gate (T-1599/T-1610) detected the corruption but only at push time, days of cron runs after the truncation could occur.

**Prevention:** `tests/unit/audit_metrics_history_atomic.bats` pins (1) temp+`os.replace` present, (2) truncating write absent, (3) the failure mode itself — a partial temp never corrupts the live file. A corpus sweep for remaining `open(..., "w")` sites on `.context/` YAML is candidate follow-up work (same class, separate task per sizing rules).

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

### 2026-07-04T23:37:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-100190-auditsh-metrics-history-writer-non-atomi.md
- **Context:** Initial task creation
