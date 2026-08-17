---
id: T-100194
name: "RCA: host working-branch forked 198/287 commits from origin-master — go-live
  merge exploded into 100+ conflicts"
description: >
  Root-cause why the framework let the host working branch (t2416-fw-safe-mode-hook-timing)
  and origin/master fork into two divergent trunks (198 vs 287 commits past common
  ancestor) undetected across many sessions, so that the operator's go-live 'git merge
  origin/master' produced 100+ conflicts instead of a fast-forward. Discovered 2026-07-05
  during go-live.

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
created: 2026-07-05T16:38:02Z
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
      (workflow:build); effort=8 (lines=244,acs=7)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-05T16:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      audit_severity=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-100194: RCA: host working-branch forked 198/287 commits from origin-master — go-live merge exploded into 100+ conflicts

## Context

On 2026-07-05 the operator ran the go-live merge (`git merge origin/master` on the
host branch `t2416-fw-safe-mode-hook-timing`) that every session handover has been
recommending. Instead of a fast-forward it produced **100+ conflicts** and left the
repo in a broken mid-merge state (`git merge --abort` then failed on an index
inconsistency).

Investigation showed the two trunks have genuinely **forked**, with unique work on
both sides relative to their common ancestor `dde2265`:
- host branch `t2416`: **198 commits** ahead of merge-base
- `origin/master`: **287 commits** ahead of merge-base
- `git diff` host↔master: origin/master has ~14,700 lines the host lacks (a whole
  `govd` governance-envelope feature, resolver pick/loop, litellm doctor, the
  claims-verdict render, dozens of tests); the host has ~2,800 lines origin/master
  lacks — including files origin/master has **no commit for at all**
  (`tests/unit/test_audit_emit_tasks.bats`, `tests/unit/test_task_cache_t100140.py`),
  proving some earlier session committed real work straight to `t2416` and never
  landed it on origin/master.

The mechanism: the session workflow lands work on `origin/master` via throwaway
worktrees (`git worktree add … origin/master` → build → `fw integrate run master
--push`), while the persistent host session stays on `t2416` and only receives
task-file syncs + handover commits. Nothing keeps `t2416` in lockstep with
origin/master, and nothing warns when they drift. "Go live" silently became a
divergent-trunk merge rather than a fast-forward.

This is bug-class (§Post-Fix Root Cause Escalation, G-019): the framework was blind
to a >7-day accumulating divergence. Spawns remediation task **T-100195**.

## Acceptance Criteria

### Agent
- [x] `## RCA` section completed: 5-Whys tracing from the symptom (100+ conflict go-live) to the structural root (no gate keeps host branch in lockstep with origin/master; no WARN on bidirectional divergence)
- [x] Mechanism documented with evidence: enumerate ≥2 commits/files that landed on only one side (e.g. host-only `tests/unit/test_audit_emit_tasks.bats`, `test_task_cache_t100140.py` — confirmed via `git cat-file -e origin/master:<path>` returning absent + `git log origin/master -- <path>` empty)
- [x] Explain why existing rails did not catch it: `FW_BRANCH_BEHIND_WARN`/T-100143 only measures "behind origin/master", not bidirectional fork where the host is also *ahead*; `fw integrate` lands one-way and never merges back
- [x] Remediation traceability: T-100195 referenced here with its scope, and any further spin-outs filed with IDs
- [x] Concern registered in `.context/project/concerns.yaml` (register-first-fix-second) linking this RCA + T-100195

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

python3 -c "import yaml; yaml.safe_load(open('.context/project/concerns.yaml'))"
grep -q "OBS-090" .context/project/concerns.yaml
grep -q "test_audit_emit_tasks.bats" .tasks/active/T-100194-rca-host-working-branch-forked-198287-co.md

## RCA

**Symptom:** The operator's go-live `git merge origin/master` on the host branch
`t2416-fw-safe-mode-hook-timing` produced **100+ conflicts** instead of a fast-forward,
and left the repo in a broken mid-merge state (`git merge --abort` then failed on an
index inconsistency; clean recovery required a Tier-0 `git reset --hard`).

**Root cause:** The framework automates *landing to* the trunk (one-way `fw integrate
run master --push`) but has no invariant that keeps a persistent working branch *current
with* the trunk it publishes to, and no detector for a **bidirectional fork**. The two
directions — "publish my work to master" and "absorb master's work into my branch" — are
distinct; only the first was ever mechanised. Divergence therefore accumulated silently
across the entire life of the branch.

### 5-Whys

1. **Why did go-live conflict instead of fast-forward?**
   The host branch `t2416` and `origin/master` had genuinely **forked**: unique commits
   on *both* sides of merge-base `dde2265` (host +199, master +287), including whole files
   each side lacks. Evidence: `tests/unit/test_audit_emit_tasks.bats` and
   `tests/unit/test_task_cache_t100140.py` are on HEAD but **absent** on origin/master
   (`git cat-file -e origin/master:<path>` → absent, `git log origin/master -- <path>` → 0
   commits); conversely the entire `govd` governance-envelope feature
   (`lib/govd_envelope.py`, `govd_holder.py`, `govd_policy.py`, `govd_relay.py`,
   `agents/govd/govd.sh`) is on origin/master with **0** occurrences on HEAD.

2. **Why did both trunks accumulate unique work?**
   The session workflow lands work onto origin/master via *throwaway worktrees*
   (`git worktree add … origin/master` → build → `fw integrate run master --push`), while
   the persistent host session stays on `t2416` and only ever receives task-file syncs +
   handover commits. Nothing pulls origin/master's commits *back* into `t2416`. Some
   earlier sessions also committed real work straight onto `t2416` (the two host-only test
   files) and never landed it — so drift grew from both ends.

3. **Why didn't the merge-back rail catch it?**
   The one rail meant to catch this — the handover **merge-back nudge** (T-100144) backed
   by `fw_branch_divergence` (`lib/branch-hygiene.sh`) — fires *only* on
   `behind > FW_BRANCH_BEHIND_WARN` (default 50) and recommends `fw integrate run master
   --push`. `fw_branch_divergence` actually *computes* both `ahead` and `behind`
   (`git rev-list --left-right --count origin/master...HEAD`) but the `ahead` value is only
   displayed, never a trigger. A genuine fork (ahead>0 AND behind>0) is therefore
   **indistinguishable** from a mere strand-behind — and the recommended remedy (`fw
   integrate`, one-way) cannot reconcile a fork; it just tries to push more host commits
   onto an already-diverged master and fails on non-fast-forward (exactly what happened
   mid-session before the operator's manual merge).

4. **Why didn't even the imperfect behind-only nudge ever fire on the host?**
   Because that entire branch-hygiene rail (`lib/branch-hygiene.sh`, the T-100144 handover
   nudge, `fw_branch_divergence`) landed on **origin/master only** — it was never merged
   back into `t2416`. Confirmed: `grep -c` for the nudge in HEAD's `agents/handover/
   handover.sh` → 0; `fw_branch_divergence` is ABSENT from HEAD's `lib/`, present on
   `origin/master:lib/branch-hygiene.sh`. **Recursive irony:** the merge-back detector was
   itself stranded by the merge-back gap it was built to close. A detection rail stranded
   on the trunk it is meant to police is no rail at all.

5. **Why is there no lockstep invariant at all? (structural root)**
   "Land to master" and "keep my branch current with master" are two directions; the
   framework mechanised only the first and left the second to a manual `git merge` that no
   gate ever required, scheduled, or verified. There is no bidirectional-fork detector and
   no safe go-live path — "go live" silently degraded from an intended fast-forward into a
   divergent-trunk merge, undetected for the full multi-session (>7-day) life of the branch.

**Why structurally allowed (>7-day blindness, G-019):** No gate, audit, or doctor check
distinguishes *forked* from *behind*, and the one advisory that exists (a) only measures
one direction and (b) was itself origin/master-only. The blindness was sustained across
many sessions — a systemic flaw, not a one-off.

**Prevention (distinct from the fix — spun out as T-100195):**
- **Leg 1 (detection, ships in T-100195):** `fw doctor` WARN when BOTH
  `git rev-list --count origin/master..HEAD > 0` AND `HEAD..origin/master > threshold`
  (bidirectional fork), worded distinctly from the behind-only nudge ("forked — needs
  merge-back or reset, not `fw integrate`"). bats coverage for forked / merely-behind /
  up-to-date.
- **Leg 2 (safe go-live, may spin out):** a reconciling go-live path — `fw integrate`
  auto-merge-back, or a `fw go-live` verb that ff-only-checks and routes a forked branch to
  the T-2473 union resolver / an explicit reset decision, instead of a bare `git merge`.
- **Meta-lesson (rail placement):** a detection rail must live on the branch it polices.
  Branch-hygiene being origin/master-only is the reason the imperfect nudge never ran —
  captured as a learning so future rails aren't stranded the same way.

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

### 2026-07-05T16:38:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-100194-rca-host-working-branch-forked-198287-co.md
- **Context:** Initial task creation

### 2026-07-05T17:13:27Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
