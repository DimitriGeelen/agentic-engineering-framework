---
id: T-2462
name: "safe-list git push/fetch in active-task gate — task-agnostic publication, fixes
  null-focus push deadlock (T-2054 parity)"
description: >
  safe-list git push/fetch in active-task gate — task-agnostic publication, fixes
  null-focus push deadlock (T-2054 parity)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/context/lib/safe-commands.sh, 
      tests/unit/context_safe_commands.bats, 
      tests/unit/test_safe_commands_git_commit.bats]
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
created: 2026-06-22T20:10:23Z
last_update: '2026-08-16T22:25:06Z'
date_finished: 2026-06-22T22:55:27Z
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
  - ts: '2026-08-16T22:25:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2462: safe-list git push/fetch in active-task gate — task-agnostic publication, fixes null-focus push deadlock (T-2054 parity)

## Context

`is_bash_safe_command` (agents/context/lib/safe-commands.sh) allowlisted git's
read-only verbs + `add` (T-2054) + the null-focus `git commit` exemption in
check-active-task.sh (T-2054), but NOT `git push`. Push is task-agnostic — it
only publishes commits that already passed the commit-msg `T-XXX` gate (P-002),
creates no work artifact, mutates no working tree, and is not inspected by the
focus-drift detector (T-1730). Gating it on an active task adds zero governance
and manufactures a deadlock whenever focus is null: (1) post-completion (status
work-completed nulls focus, but "never end a session with unpushed commits"),
and (2) worktree sessions (the Bash PreToolUse hook executes the MAIN repo's
hook code against main's null focus). This is the 3rd leg of the commit→push
pipeline T-2054 exempted (commit+add) but stopped before (L-399 parity gap).
Fix: safe-list `push|fetch`; keep `pull` gated (merges into tree = a write).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `is_bash_safe_command` returns 0 for `git push` and `git fetch`, and 1 for `git pull` (safe-commands.sh git case, `push|fetch) return 0`)
- [x] end-to-end gate: null-focus `git push` / `git push origin <branch>` / `git fetch` exit 0 (allowed); null-focus `git pull` exits 2 (blocked); the T-2054 commit/add/no-verify contract is unchanged
- [x] existing conflicting assertions reconciled: `context_safe_commands.bats` "git push is NOT safe" → now asserts push/fetch safe + pull unsafe; `test_safe_commands_git_commit.bats` "unrelated write blocked" example switched from `git push` to `git pull`
- [x] force-push protection is preserved (Tier-0 `check-tier0.sh` is a separate hook; this gate change does not touch it — `git push --force-with-lease` still gated by tier0)

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
out=$(bats tests/unit/context_safe_commands.bats tests/unit/test_safe_commands_git_commit.bats 2>&1); echo "$out" | grep -q "^ok " && ! echo "$out" | grep -q "^not ok"

## RCA

**Symptom:** `git push` is blocked by the active-task gate with "No active task"
whenever focus is null — forcing a manual bypass (`--no-verify`) or an
operator-terminal push. Hit repeatedly: T-2442 "F11" deadlock, and twice in the
T-2461 session (post-completion + worktree).

**Root cause:** `is_bash_safe_command` allowlists git read-only verbs + `add`,
and check-active-task.sh exempts null-focus `git commit` (both T-2054) — but
`git push` is in neither. Push is task-agnostic (publishes commits already
governed by the commit-msg T-XXX gate; no work artifact, no tree mutation, not
inspected by focus-drift T-1730), yet it fell through to the null-focus block.

**Why structurally allowed:** T-2054 recognised the post-completion checkpoint
deadlock and fixed it for `commit` + `add` — the first two legs of the
commit→add→push pipeline — but stopped before `push`. Classic L-399
producer/consumer parity gap: the exemption shipped for 2 of 3 verbs. The
worktree dimension compounded it (the Bash PreToolUse hook executes the MAIN
repo's hook code against main's null focus), but the push-specific block fires in
plain non-worktree sessions too, every time a task completes and focus nulls.

**Prevention:** safe-list `push|fetch` in the git case (this fix), pinned by
(a) unit assertions in `context_safe_commands.bats` (push/fetch safe, pull not)
and (b) end-to-end null-focus gate tests in `test_safe_commands_git_commit.bats`
(push/fetch exit 0, pull exits 2, T-2054 commit contract intact). The selectivity
test (pull stays blocked) guards against a future blanket-allow of git.

**Follow-up (NOT in this task — separate deliverable):** the worktree Bash
PreToolUse hook resolving PROJECT_ROOT/focus to the MAIN repo still blocks every
non-safe-listed command (e.g. `bats`) in worktree sessions. That is the deeper
T-2410/OBS-080 resolution issue and needs its own RCA + careful paths.sh change;
registering as a note, not bundling (one task = one deliverable).

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

### 2026-06-22T20:10:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2462-safe-list-git-pushfetch-in-active-task-g.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-24ddcadc
- **Timestamp:** 2026-06-22T22:55:34Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `out=$(bats tests/unit/context_safe_commands.bats tests/unit/test_safe_commands_git_commit.bats 2>&1); echo "$out" | grep -q "^ok " && ! echo "$out" | grep -q "^not ok"`

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `force-push`

### 2026-06-22T22:55:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
