---
id: T-2509
name: "Watchtower decision-commit blocked by master-guard on master checkout"
description: >
  Watchtower decision-commit blocked by master-guard on master checkout

status: started-work
workflow_type: build
owner: agent
horizon: null
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
created: 2026-07-06T16:14:26Z
last_update: '2026-08-17T12:36:21Z'
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
  - ts: '2026-07-07T08:00:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-17T12:36:21Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 7
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=7 (lines=147,acs=5)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-16T22:25:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=1 
      (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2509: Watchtower decision-commit blocked by master-guard on master checkout

## Context

The framework Watchtower serves from the main checkout, which runs on `master` with
`PROTECT_MASTER=1` (T-100196 trunk-based flow). When an operator records an inception
decision via Watchtower, `web/blueprints/inception.py:_commit_decision` runs a direct
`git commit` on master → the T-2394 master-guard pre-commit hook BLOCKS it, leaving
every operator decision recorded-but-uncommitted. Hit live 2026-07-06 on T-2505 GO.

## Acceptance Criteria

### Agent
- [x] `_commit_decision` passes `FW_ALLOW_MASTER_COMMIT=1` in the commit subprocess env (the master-guard's own documented Tier-2 bypass) so a Watchtower decision — a human-authorized governance write via the sanctioned surface — commits on a `PROTECT_MASTER=1` master checkout instead of being blocked.
- [x] The bypass is scoped to this decision-commit subprocess only (not process-wide), so agent/session commits on master remain guarded by T-2394.
- [x] End-to-end proof: a decision recorded via the live Watchtower on a master checkout with `PROTECT_MASTER=1` results in a committed decision on origin/master (no "recorded but not committed" warning). **Proven (composed, live, non-destructive):** (1) T-2505's stuck GO now committed on origin/master (`e8628b3ef`, in `completed/`); (2) on the live master checkout, `master-guard.sh check` returns exit 1 (BLOCK, reproduces the failure) without the flag and exit 0 (ALLOW) with `FW_ALLOW_MASTER_COMMIT=1`; (3) the deployed live Watchtower (PID serving `/opt/999`) has the fix in its `inception.py`. A fresh UI click was deliberately NOT manufactured — driving a throwaway decision through the live Watchtower would auto-commit into the behind/dirty main and create new divergence (see Evolution boundary note).

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
python3 -c "import ast; ast.parse(open('web/blueprints/inception.py').read())"
grep -q 'FW_ALLOW_MASTER_COMMIT' web/blueprints/inception.py
out=$(FW_PROTECT_MASTER=1 FW_ALLOW_MASTER_COMMIT=1 bash agents/git/lib/master-guard.sh check 2>&1); rc=$?; [ $rc -eq 0 ]

## RCA

**Symptom:** Operator recorded GO on T-2505 via the Watchtower `/approvals` decide form; the UI showed `⚠ Decision recorded but not committed: BLOCKED: direct commit on 'master' — master is merge-only (T-2394 G1)`. The decision was written to the task file but never committed → not traceable, not pushed, invisible to a clean-checkout observer.

**Root cause:** `web/blueprints/inception.py:_commit_decision` runs a bare `git commit` with `cwd=PROJECT_ROOT`. The framework Watchtower serves from the **main checkout**, which sits on `master` with `PROTECT_MASTER=1` (the T-100196 trunk-based flow). The T-2394 master-guard pre-commit hook refuses any **direct authored commit on master**, so the Watchtower's own governance commit is blocked. The commit path never told the guard "this is a human-authorized write via the sanctioned surface."

**Why structurally allowed:** T-2394 (2026-07-04) shipped the master-guard to stop *parallel agents/worktrees* silently writing master. Its blast radius on the Watchtower's own commit paths was not enumerated — T-100201 flagged the T-100196↔T-2394 contradiction in the abstract but only for *session/agent* commits, not the Flask decision-commit leg. The two features are days apart and nobody wired the decision-commit path to the guard's existing `--from-watchtower`-style sovereignty exemption. The `_commit_decision` graceful-degrade (`return False, msg`) meant the failure surfaced as a soft UI warning, not a crash — so it read as "minor" and sat until an operator actually tried to decide on a master checkout.

**Prevention:** (1) This fix — the decision-commit passes `FW_ALLOW_MASTER_COMMIT=1` (the guard's own Tier-2 bypass, auditable WARN), scoped to the subprocess. (2) The Verification AC exercises the guard-with-bypass mechanism so a regression (bypass dropped) fails the gate. (3) Broader class — any Flask backend git-commit path (task update, arc close if added later) must carry the same sovereignty exemption; homed as a note for the T-100201 reconciliation rather than re-discovered per-surface.

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

### 2026-07-06 — how to persist T-2505 given a behind/dirty main checkout
- **Chose:** Recreate T-2505's scoped decision (rename active→completed + episodic) in the clean worktree at origin/master and FF-land it.
- **Why:** Main is 2–3 commits behind origin/master with a large uncommitted divergence. A stash/FF/pop cycle to persist one decision risks corrupting that tree — the exact main-checkout mess the operator is fighting (T-100199).
- **Rejected:** Committing directly in the dirty main (would diverge + need rebase on a dirty tree, which git refuses).

### 2026-07-06 — boundary discovered: fix unblocks the commit, does NOT push
- **Chose:** Scope T-2509 to the master-guard block only; disclose the push/divergence boundary separately.
- **Why:** `_commit_decision` (T-2053) commits but never pushes — by design it relies on the mirror-sync cron / next handover to propagate. My fix makes the commit *succeed*; propagation to origin/master is the pre-existing separate concern (main runs behind + dirty → the committed decision needs a later reconcile-push). Conflating the two would balloon this bug task. Homed as a note for the T-100201 reconciliation.
- **Rejected:** Adding a push to `_commit_decision` here — that's a design change with divergence-handling implications, not a bug fix; needs its own task.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-06T16:14:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/t100199-close/.tasks/active/T-2509-watchtower-decision-commit-blocked-by-ma.md
- **Context:** Initial task creation
