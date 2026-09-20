---
id: T-2441
name: "Onboard /opt/505-Ring20-Site to AEF + bootstrap remediation arc"
description: >
  Onboard /opt/505-Ring20-Site to AEF + bootstrap remediation arc

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/audit/audit.sh, bin/fw, tests/unit/watchtower_health_verdict_identity.bats]
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
created: 2026-06-21T06:28:21Z
last_update: 2026-09-20T20:19:24Z
date_finished: 2026-09-20T20:19:24Z
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
  - ts: '2026-07-07T08:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-17T12:36:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 6
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=6 (lines=145,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-07T08:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-08T08:15:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2441: Onboard /opt/505-Ring20-Site to AEF + bootstrap remediation arc

## Context

Two-part task: (1) install AEF into the greenfield `/opt/505-Ring20-Site`, and
(2) turn the friction observed during that install into a remediation arc.
Both parts were carried out in the days immediately following task creation
(2026-06-21/22) but the task file itself was left with template placeholder
ACs and never closed. Verified this session (2026-09-20), re-confirming
rather than re-doing:

- **Onboarding (part 1):** `/opt/505-Ring20-Site` was probed read-only via a
  TermLink worker rooted in that project (project-boundary-safe, T-559).
  `.agentic-framework/`, `.framework.yaml` (`project_name: 505-Ring20-Site`,
  `provider: claude`, `initialized_at: 2026-06-21T06:41:22Z`), `.tasks/`,
  `.context/`, `.claude/` and `.mcp.json` are all present and populated; git
  log shows real post-onboarding work under framework task IDs (`5f4ee0e
  T-012: Session handover S-2026-0622-1332`, `5eeaca7 T-021: Relay v2.0.1
  deploy GO to ring20-management`). The install is live, not a dry run.
- **Remediation arc (part 2):** the dogfooding run is captured in full in
  `docs/reports/T-2441-aef-onboarding-dogfooding.md` (10 findings F1-F10,
  each with symptom/RCA/remediation). Every finding was triaged and every
  resulting task is closed in `.tasks/completed/`: T-2442 (umbrella for the
  bug-report envelope: F4/F5/F9/F10), T-2443 (F4 value-drivers.yaml),
  T-2444 (F5 session-init), T-2445 (F9 Watchtower health false-positive),
  T-2446 (F10 CLAUDE_PROJECT_DIR trust), T-2447 (F2+F8 bug report — legacy
  shim messaging + bare-`fw` routing, same root cause), T-2448 (F2+F8 build
  fix — thin re-exec shim), T-2450 (F3 version reporting), T-2451 (F7
  doctor project/host segmentation), T-2452 (F6 `doctor --quick`), T-2453
  (F1 install freshness). 11 tasks for 10 findings because F2 and F8 shared
  one root cause and were fixed together (bug-report + build pair). No
  literal "arc" YAML anchor was created — the remediation took the shape of
  eleven independent closed tasks instead, which satisfies the same intent
  (friction converted into fixes) without the arc-tracking overhead.

Both halves of the task title are done and evidenced. Nothing further to
build; this pass exists to make the task file honest about that.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **A1 Live onboarding confirmed:** `/opt/505-Ring20-Site` has a live
      AEF install (`.agentic-framework/`, `.framework.yaml`,
      `.tasks/`/`.context/` populated), verified via read-only TermLink
      probe rather than assumed from the 2026-06-21 install log.
- [x] **A2 Remediation findings fully triaged:** all 10 findings (F1-F10)
      in `docs/reports/T-2441-aef-onboarding-dogfooding.md` have a
      corresponding task, and every one of those tasks is in
      `.tasks/completed/`.

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

# A1 (live /opt/505 state) is not re-checked here: project-boundary enforcement
# (T-559) refuses this repo's gate-running host from reading outside-project
# paths even at verification time, and re-probing on every future gate run
# would defeat the point of a one-time confirmation. Evidence is the dispatched
# read-only TermLink probe transcript recorded in the Updates section below.
test -f docs/reports/T-2441-aef-onboarding-dogfooding.md
for t in T-2442 T-2443 T-2444 T-2445 T-2446 T-2447 T-2448 T-2450 T-2451 T-2452 T-2453; do ls .tasks/completed/$t-*.md >/dev/null 2>&1 || { echo "MISSING $t"; exit 1; }; done

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

### 2026-06-21T06:28:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2441-onboard-opt505-ring20-site-to-aef--boots.md
- **Context:** Initial task creation

### 2026-09-20 — reconciliation: backfill real ACs, confirm both halves already delivered
- Task sat 91 days with template placeholder ACs despite both described
  deliverables (live onboarding + remediation arc) having actually shipped
  in the days after creation.
- Dispatched a read-only TermLink worker (`t2441-probe`, `fw termlink
  dispatch --project /opt/505-Ring20-Site`) to confirm current state without
  crossing the T-559 project boundary directly. Transcript confirmed
  `.agentic-framework/`, `.framework.yaml` (`initialized_at:
  2026-06-21T06:41:22Z`), `.tasks/`, `.context/`, `.claude/`, `.mcp.json`
  present, plus post-onboarding commits under real framework task IDs
  (T-012, T-021).
- Confirmed all 10 dogfooding findings (F1-F10) from
  `docs/reports/T-2441-aef-onboarding-dogfooding.md` have closed tasks:
  T-2442, T-2443, T-2444, T-2445, T-2446, T-2447, T-2448, T-2450, T-2451,
  T-2452, T-2453 (11 tasks for 10 findings — F2+F8 shared one fix, filed as
  a bug-report/build pair).
- Backfilled `## Context` and real ACs (A1, A2) reflecting what was
  verified, ticked both, closed the task.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-dbcf0a85
- **Timestamp:** 2026-09-20T20:19:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-20T20:19:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
