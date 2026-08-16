---
id: T-2481
name: "safe zone-3 go-live: land master into MAIN busy checkout without losing transients"
description: >
  Operator's git merge to go live on MAIN aborted (transactional, no loss): 16 tracked
  regenerable transients have local edits + 1 untracked vendored file .agentic-framework/lib/integrate.py
  block the merge. Diagnose MAIN branch topology (t2417-fw-sessions vs origin/master)
  and give a safe, copy-pasteable go-live that preserves real state and discards only
  regenerable churn. Assess whether fw integrate should offer a zone-3 go-live verb.

status: work-completed
workflow_type: build
owner: agent
horizon:
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
created: 2026-06-24T11:33:59Z
last_update: '2026-08-16T22:25:07Z'
date_finished: 2026-06-24T11:40:58Z
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
  - ts: '2026-08-16T22:25:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2481: safe zone-3 go-live: land master into MAIN busy checkout without losing transients

## Context

The operator's `git merge worktree-inception-gov-payload-mediation` on MAIN
(zone-3 go-live) aborted transactionally — no loss. This task diagnoses why and
hands off a safe go-live, and records the systemic gap: `fw integrate` makes the
worktree→master land smooth but offers nothing for going live on MAIN's busy
checkout.

## Findings

**Topology (verified):**
- MAIN checkout is on `t2417-fw-sessions` @ `8b65cd283`; `origin/master` = the
  landed worktree branch @ `a7bb47005`. They diverged → `git merge` is a real
  3-way merge, not FF.
- **No regression risk:** the OBS-080 reanchor fix (`fw_reanchor_from_cwd`,
  `lib/paths.sh` + `check-active-task.sh`) is present on ALL refs incl.
  origin/master (grep-verified). The "+71 unique to t2417" in `diff --stat` was a
  merge-base artifact (old base `dde226557`), not real divergence. master has
  EVERYTHING: reanchor + YAML-timestamp fixes.
- What's genuinely unique to t2417 = session handover `.md` docs (bookkeeping).

**Why the merge aborted (two distinct blockers):**
1. 16 tracked transients with local edits would be overwritten — incl. real-state
   accumulators (feedback-stream +622, .gate-bypass-log +633, decisions +7,
   inbox +14, reviewer-overrides +10) plus regenerable churn (audits, watchtower.*,
   focus.yaml, VERSION, .hook-counter, session.yaml).
2. 1 untracked `.agentic-framework/lib/integrate.py` (an old vendored copy) blocks
   the tracked version the merge wants to write.

**Merge cleanliness (non-mutating `merge-tree` prediction):** committed states
merge with exactly ONE conflict — `.context/handovers/LATEST.md` (a regenerable
pointer both branches bumped). Everything else auto-merges.

## Recommendation

**Recommendation:** GO — go live via the safe sequence below (operator runs it;
mutating MAIN's live checkout is operator's call). No regression risk (master has
the reanchor fix). Preserves MAIN's real-state as a recoverable checkpoint commit;
the only conflict is regenerable.

Safe go-live (run each line in MAIN, one at a time — short on purpose):
```
cd /opt/999-Agentic-Engineering-Framework
rm -f .agentic-framework/lib/integrate.py
git add -u && git commit -m "T-2481: checkpoint MAIN state pre go-live"
git merge origin/master
```
The merge stops on one conflict (`.context/handovers/LATEST.md`). Finish:
```
git checkout --theirs .context/handovers/LATEST.md
git add .context/handovers/LATEST.md && git commit --no-edit
```
MAIN is then live with all fixes. `git add -u` stages only tracked transients (no
untracked sweep → no add/add conflict); the `rm` clears the one untracked blocker,
which the merge repopulates from master's tracked copy.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Zone-3 go-live diagnosed: branch topology, no-regression proof (reanchor on all refs), and the two abort blockers recorded in ## Findings.
- [x] Merge cleanliness predicted non-mutatively (`merge-tree`) — exactly one regenerable conflict (LATEST.md) — so the handoff sequence is confident, not guessed.
- [x] A safe, copy-pasteable go-live sequence is handed to the operator that preserves MAIN's real-state transients (commit checkpoint) and clears only the untracked vendored blocker — NOT self-executed (mutating MAIN's live checkout is operator's call). — see ## Recommendation.
- [x] Systemic gap registered: `fw integrate` has no zone-3 `go-live` verb; follow-up recorded so the next go-live is smooth. — OBS-086 in .context/concerns.yaml (status: watching, proposes `fw integrate go-live`).

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

### 2026-06-24T11:33:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2481-safe-zone-3-go-live-land-master-into-mai.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e5ad60ba
- **Timestamp:** 2026-06-24T11:40:59Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#4 (Agent)** — Systemic gap registered: `fw integrate` has no zone-3 `go-live` verb; follow-up recorded so the next go-live is smooth. — OBS-086 in .context/concerns.yaml (status: watching, proposes `fw integrate go
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/concerns.yaml in: Systemic gap registered: `fw integrate` has no zone-3 `go-live` verb; follow-up recorded so the next go-live is smooth. — OBS-086 in .context/concerns`

### 2026-06-24T11:40:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
