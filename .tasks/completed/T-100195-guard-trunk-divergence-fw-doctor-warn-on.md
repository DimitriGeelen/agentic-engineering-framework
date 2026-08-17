---
id: T-100195
name: "Guard trunk divergence: fw doctor WARN on host↔origin-master fork + safe go-live
  path (not raw git merge)"
description: >
  Structural prevention for T-100194 RCA. Detect bidirectional host↔origin/master
  divergence (both branches ahead of merge-base, not just 'behind' which T-100143
  FW_BRANCH_BEHIND_WARN already covers) and provide a go-live path that reconciles
  safely (ff-only / union resolver / auto-merge-back after fw integrate) instead of
  a raw 'git merge origin/master' that explodes into conflicts.

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
created: 2026-07-05T16:38:42Z
last_update: '2026-08-17T12:36:12Z'
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
  - ts: '2026-07-05T16:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-17T12:36:12Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=185,acs=6)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-05T16:45:05Z'
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
  - ts: '2026-08-16T22:24:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=1 
      (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-100195: Guard trunk divergence: fw doctor WARN on host↔origin-master fork + safe go-live path (not raw git merge)

## Context

Structural prevention for the divergence root-caused in **T-100194** (host branch
`t2416` and origin/master forked 198/287 commits; go-live `git merge` exploded into
100+ conflicts). Two independent prevention legs — this task ships the **detection**
leg and scopes the **safe-go-live** leg (which may spin into its own build/inception
once T-100194's RCA lands, because it involves a flow-design choice).

**Leg 1 — detection (this task):** the framework already WARNs when the host branch
is *behind* origin/master (`FW_BRANCH_BEHIND_WARN`, T-100143), but that check is
one-directional. It stays silent when the host is *also ahead* — the exact
divergent-fork state that made go-live explode. Add a bidirectional check: WARN when
BOTH `git rev-list --count origin/master..HEAD > 0` AND
`git rev-list --count HEAD..origin/master > threshold`, i.e. the trunks have forked
rather than merely lagged.

**Leg 2 — safe go-live (scoped, may spin out):** `git merge origin/master` is the
wrong tool once divergence exists. Candidate designs (T-100194 RCA decides): (a)
`fw integrate` auto-merges origin/master back into the host branch after each
landing so they never drift; (b) a guarded `fw go-live` verb that detects divergence
and routes to ff-only or the T-2473 union resolver instead of a raw merge; (c) the
host session tracks origin/master directly and never accumulates its own trunk.

## Acceptance Criteria

### Agent
- [x] `fw doctor` (and/or audit) emits a WARN when the current working branch has BIDIRECTIONALLY diverged from origin/master (host ahead > threshold AND host behind > threshold) — distinct from the existing "behind" WARN; reuses the `FW_BRANCH_BEHIND_WARN` config surface via a new `diverged-fork` finding class in `fw_branch_hygiene` (doctor scan) + a `fork` line in `fw_branch_divergence` (handover). Refined "ahead ≥1" → "ahead > threshold": an unmerged branch behind master always has ≥1 unique commit, so any-ahead would mislabel every landable feature branch (Decision 1)
- [x] The WARN message names the safe reconciliation path (not "run git merge") — the handover fork block and the doctor FORK hint both say reconcile-while-small (merge origin/master INTO the branch / reset), and explicitly say NOT to use a one-way `fw integrate` on a fork (it cannot absorb what master has)
- [x] bats coverage: `tests/unit/t100195_diverged_fork.bats` — forked branch (ahead>t AND behind>t) → diverged-fork/fork; small-ahead behind branch → behind-threshold (no false fork); merely-behind current checkout (ahead=0) → nudge; up-to-date → neither. Existing t100143/t100144 stay green (17/17)
- [x] Leg 2 disposition recorded in `## Decisions`: spun out as **T-100196** (safe go-live reconciling path — `fw go-live` / integrate auto-merge-back), horizon later

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

# Landed on origin/master via fw integrate; the diverged-fork code is on the trunk.
# (branch-hygiene.sh + the bats are origin/master-only — this branch t2416 lacks
#  them by design; verify against the landed trunk content.)
git show origin/master:lib/branch-hygiene.sh | grep -q "diverged-fork"
git show origin/master:lib/branch-hygiene.sh | grep -q "^        echo \"fork ahead="
D=$(mktemp -d); mkdir -p "$D/lib" "$D/tests/unit"; git show origin/master:lib/branch-hygiene.sh > "$D/lib/branch-hygiene.sh"; git show origin/master:tests/unit/t100195_diverged_fork.bats > "$D/tests/unit/t.bats"; bats "$D/tests/unit/t.bats" >/dev/null 2>&1; rc=$?; rm -rf "$D"; [ $rc -eq 0 ]

## RCA

**Symptom:** (inherited from T-100194) a go-live `git merge origin/master` on a long-lived
working branch produced 100+ conflicts instead of a fast-forward.

**Root cause (of the DETECTION gap this task closes):** `fw_branch_hygiene` and
`fw_branch_divergence` measured only the `behind` dimension. A bidirectional fork (branch
ALSO substantially ahead) was indistinguishable from a landable strand-behind, so the one
advisory that existed recommended a one-way `fw integrate` that cannot reconcile a fork.

**Why structurally allowed:** no finding class separated "ahead AND behind" from "behind";
the `ahead` count was computed (`rev-list --left-right`) but never a trigger.

**Prevention (this task):** a distinct `diverged-fork` finding (both directions past
`FW_BRANCH_BEHIND_WARN`) at the doctor + handover surfaces, worded to name the
reconcile-while-small remedy and to warn AGAINST a bare `git merge` / one-way `fw
integrate` on a fork. Pinned by `tests/unit/t100195_diverged_fork.bats`. The reconciling
*action* (auto-merge-back / `fw go-live`) is Leg 2 → T-100196.

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

### 2026-07-05 — Fork threshold: `ahead > threshold`, not `ahead ≥ 1`
- **Chose:** classify `diverged-fork` only when BOTH `behind > FW_BRANCH_BEHIND_WARN` AND `ahead > FW_BRANCH_BEHIND_WARN`.
- **Why:** an unmerged local branch that is behind master provably has ≥1 unique commit (otherwise its tip is an ancestor → the `merged-undeleted` class). So `ahead ≥ 1` (the original AC wording) would reclassify *every* ordinary landable feature branch as a dangerous fork — false alarms, and wrong advice ("don't use fw integrate" when integrate would land it cleanly). Gating on `ahead > threshold` isolates the genuinely dangerous case (the T-100194 199/287 explosion) where reconciliation really is non-trivial.
- **Rejected:** `ahead ≥ 1` (AC's initial phrasing — too broad, see above); a separate `FW_BRANCH_DIVERGED_WARN` config knob (unnecessary — the shared threshold reads naturally as "substantial in both directions" and keeps one tunable).

### 2026-07-05 — Build on a worktree off origin/master, land via fw integrate
- **Chose:** implement Leg 1 in a throwaway worktree checked out from origin/master, then land via `fw integrate run master --push`.
- **Why:** `lib/branch-hygiene.sh` and `fw_branch_divergence` live on origin/master, NOT on the host branch t2416 (that stranding is itself the T-100194 root cause). Building on t2416 would (a) lack the base code and (b) add to the very fork being fixed. Building off origin/master puts the fix where the code lives and demonstrates the correct non-diverging workflow.
- **Rejected:** editing on t2416 directly (would deepen the fork and conflict on landing).

### 2026-07-05 — Leg 2 (reconciling action) deferred to T-100196
- **Chose:** ship detection here; spin the safe go-live *action* out as T-100196 (horizon later).
- **Why:** early detection is the high-value prevention (forks never grow past the threshold unnoticed). The reconciling verb (`fw go-live` auto-merge-back / union-resolver routing) is a flow-design choice with its own blast radius — one deliverable per task (Task Sizing).
- **Rejected:** implementing both legs under one task (violates one-task-one-deliverable; Leg 2 needs its own design).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-05T16:38:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-100195-guard-trunk-divergence-fw-doctor-warn-on.md
- **Context:** Initial task creation

### 2026-07-05T17:18:36Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
