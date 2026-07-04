---
id: T-100128
name: "Missing-Updates cascade remediation: purge cascade finding-tasks + fix emit
  body-replacement failure"
description: >
  Missing-Updates cascade remediation: purge cascade finding-tasks + fix emit body-replacement
  failure

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
created: 2026-07-04T07:52:16Z
last_update: '2026-07-04T08:00:02Z'
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
  - ts: '2026-07-04T08:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-04T08:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      audit_severity=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-100128: Missing-Updates cascade remediation: purge cascade finding-tasks + fix emit body-replacement failure

## Context

T-100060 (commit 1b21e1dad, 2026-07-03) fixed the audit --emit-tasks cascade root cause (template now includes ## Updates; 7-day cascade grace period) and deleted 59 cascade tasks (T-100000..T-100059). But 46+ cascade finding-tasks from the T-24xx/T-25xx generation created BEFORE the fix still sit in .tasks/active/ — all are "Audit WARN — Task T-XXXX ... missing Updates" findings about other audit-finding tasks. The grace period only suppresses re-emission for 7 days (expires ~2026-07-09 for this batch); the active-task scan will keep flagging these files because they themselves lack ## Updates.

Second defect: T-2448 and T-2470 were created by the emitter with the DEFAULT template body (placeholder ACs, no ## Trigger/## Finding) and no audit_severity/audit_finding_hash frontmatter — the post-create body-replacement step in audit.sh `_emit_findings_as_tasks` silently failed for them. Missing hash breaks dedup → duplicate findings were created (T-2469 duplicates T-2448's finding about T-2221).

Scope: (1) delete pure-cascade finding-tasks in active/ (same class + precedent as T-100060's deletion), (2) investigate + fix the body-replacement failure path so it cannot fail silently, (3) verify audit converges (no missing-Updates findings re-emitted).

## Acceptance Criteria

### Agent
- [x] All active/ tasks flagged "missing Updates section" that reference audit-finding tasks are removed (pure-cascade class, T-100060 precedent); no non-cascade task deleted — safety check confirmed all 46 subjects are audit-finding tasks; T-2448/T-2470 malformed duplicates covered by T-2469 (triaged OPERATIONAL) and T-100067
- [x] Malformed emit path (silent body-replacement failure) root-caused in RCA and hardened: failure now emits an error instead of leaving a default-template task without audit_finding_hash — file resolved from create output `File:` line (glob demoted to fallback), loud [ERROR] on both failure paths; bash -n clean; parsing unit-tested
- [x] Re-run of active-task scan shows zero "missing Updates section" compliance issues in active/ — post-deletion scan: 0 issues, 258/258 valid (was 260/306)

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

out=$(python3 agents/audit/active-task-scan.py .tasks .context/audits 2>&1); ! echo "$out" | grep -q "missing Updates section"
bash -n agents/audit/audit.sh

## RCA

**Symptom:** 46 active tasks flagged "missing Updates section" by the active-task scan — every one an audit-finding task about another audit-finding task (cascade layers 2-3 of the T-100060 recursion). Separately, T-2448/T-2470 sat in active/ with default-template bodies (placeholder ACs) and no `audit_severity`/`audit_finding_hash` frontmatter.

**Root cause:** Two residues of the pre-T-100060 emitter. (1) The cascade tasks were emitted before commit 1b21e1dad added `## Updates` to the emit template — they are data debris, not a live code bug; the 7-day emission grace period masked them but expires ~2026-07-09. (2) The malformed pair: `_emit_findings_as_tasks` resolved the just-created task file via an `active/${task_id}-*.md` glob inside `if ls ...; then` with **no else branch** — when the glob failed (exact trigger undetermined; 2 of ~90 emissions), the frontmatter-insert and body-replace steps were silently skipped, leaving a default-template orphan. Because the orphan carries no `audit_finding_hash`, dedup could not see it and the next audit run emitted a duplicate finding task (T-2469 duplicates T-2448; T-100067 duplicates T-2470).

**Why structurally allowed:** The emitter's file-resolution failure path was a silent no-op — no [ERROR], no counter, nothing in cron logs. Silent failure + hash-based dedup keyed on a field the failure path never wrote = self-amplifying (each failure spawns duplicates).

**Prevention:** (1) File path now parsed directly from `fw task create` output (`File:` line) with the glob demoted to fallback; (2) resolution failure now emits a loud [ERROR] naming the orphaned task id — visible in cron audit logs; (3) create-failure path now echoes the first 5 lines of create output for diagnosis. Cascade class itself is prevented by T-100060 (template + grace period); this task removes the pre-fix debris so the grace-period expiry cannot re-trigger it.

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

### 2026-07-04T07:52:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-100128-missing-updates-cascade-remediation-purg.md
- **Context:** Initial task creation
