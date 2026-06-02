---
id: T-2195
name: "Inception recalibration Slice 9 (meta-finding): commit-counting semantics —
  exempt storage from exploration budget"
description: >
  T-2186 Slice 9 (meta-finding from inception execution). The current inception commit-counter
  (agents/git/lib/hooks.sh:122) counts EVERY T-XXX commit toward the 2-commit exploration
  limit, including filing + demote (storage) commits that carry zero exploration.
  T-2186 itself hit this — its 3rd commit (Step 0 findings) was blocked because filing
  + demote consumed the budget. Fix: distinguish storage commits (status flips, frontmatter-only
  edits, body Context section pointer updates) from exploration commits (research
  artifact body deltas, body section additions to Problem Statement / Assumptions
  / Exploration Plan / Recommendation / Decisions). Heuristic: parse commit's git
  diff; if all changes are within frontmatter or storage-tagged sections, do not count.
  Add learning entry (L-NEW from this incident). Verification: bats test pins counter
  behaviour on synthetic storage vs exploration commits; the T-2186 commit sequence
  would have hit budget at the right place.

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: [inception, commit-counter, T-2186-slice, meta-finding, L-class]
components: [agents/git/lib/hooks.sh, tests/unit/inception_commit_counter.bats]
related_tasks: [T-2186]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-02T22:05:35Z
last_update: 2026-06-02T22:43:34Z
date_finished: 2026-06-02T22:43:34Z
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
bvp_scores_proposed:
  - ts: '2026-06-02T22:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-02T22:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2195: Inception recalibration Slice 9 (meta-finding): commit-counting semantics — exempt storage from exploration budget

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `agents/git/lib/hooks.sh` has a new helper `_count_inception_exploration_commits` that filters task-file-only commits out of the count
- [x] Both call sites (inception-gate counter L138 + research-artifact enforcement L174) use the new helper instead of raw `git log | grep -c`
- [x] Bats test pins behaviour: a synthetic 3-commit sequence (filing → demote → research-artifact edit) counts as 1 exploration commit, not 3 — `tests/unit/inception_commit_counter.bats` 7/7 PASS
- [x] `050-Inceptions.md` "Commit budget" note updated — storage commits exempt by default (no override needed for the T-2186-shaped flow)
- [x] Learning entry filed via `fw context add-learning` capturing the failure class (commit-counter conflated storage with exploration) — L-454
- [x] Reviewer PASS (`bin/fw reviewer T-2195`) — R-fd45bdf0 2026-06-02T22:42:19Z, Findings: none

## Verification

bash -n agents/git/lib/hooks.sh
out=$(cat agents/git/lib/hooks.sh); grep -q "_count_inception_exploration_commits" <<<"$out"
out=$(grep -c "_count_inception_exploration_commits" agents/git/lib/hooks.sh); test "$out" -ge 3
out=$(cat 050-Inceptions.md); grep -q "storage commits" <<<"$out"
bats tests/unit/inception_commit_counter.bats
out=$(cat .context/project/learnings.yaml 2>&1); grep -q "T-2195" <<<"$out"
out=$(bin/fw reviewer T-2195 2>&1); grep -qE "Overall:.*PASS" <<<"$out"

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

### 2026-06-02T22:05:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2195-inception-recalibration-slice-9-meta-fin.md
- **Context:** Initial task creation

### 2026-06-02T22:33:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-60b61736
- **Timestamp:** 2026-06-02T22:43:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-02T22:43:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
