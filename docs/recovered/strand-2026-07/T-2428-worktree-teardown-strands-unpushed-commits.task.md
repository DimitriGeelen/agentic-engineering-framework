---
id: T-2428
name: "worktree teardown strands unpushed commits + handoff commands use ephemeral worktree paths (G-A/G-B remediation)"
description: >
  worktree teardown strands unpushed commits + handoff commands use ephemeral worktree paths (G-A/G-B remediation)

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
created: 2026-07-01T09:18:46Z
last_update: 2026-07-01T09:18:46Z
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

# T-2428: worktree teardown strands unpushed commits + handoff commands use ephemeral worktree paths (G-A/G-B remediation)

## Context

**HIGH-PRIORITY REMEDIATION REQUEST** (operator-requested, 2026-07-01). Filed off the
RCA of why branch `t2353-audit-emit-tasks` (6 commits, tip `b508ceef1`) never reached
origin: the push was blocked by three sequential pre-push gates, the human-run `--no-verify`
bypass one-liner hard-coded the worktree path, and by the time it ran the worktree had been
removed → `cd` failed → nothing pushed. Work survived only because `git worktree remove`
doesn't delete the branch.

Two structural gaps registered:
- **G-071** [medium] — handoff commands tied to the ephemeral worktree cwd (outlives-session
  commands break when the worktree is reaped).
- **G-072** [high] — worktree teardown has no unpushed-commit guard (handover pushes via
  T-1144, but the worktree-removal path is uncovered; WorktreeRemove hook unconfigured).

Learning: **L-486**. This task tracks the FIX for both gaps; it is a forward request —
the ACs below are the deliverables to be implemented, not yet done.

## Acceptance Criteria

### Agent
- [ ] **G-072 teardown guard (primary):** a WorktreeRemove hook OR `fw worktree remove` wrapper that runs `git log <remote>/<branch>..<branch>` and refuses/warns when the worktree's branch has commits absent from all remotes; `--force` (Tier-2 logged) proceeds anyway. Regression test stages an unpushed-branch worktree and asserts the guard fires.
- [ ] **G-071 handoff durability (doc):** CLAUDE.md §Copy-Pasteable Commands gains a worktree-durability clause — outlives-session commands (push / tier0 approve / review handoff) use the durable main-repo path + explicit branch ref, never the `.claude/worktrees/<name>` cwd.
- [ ] **G-071 reviewer detector (optional, static backstop):** reviewer/static-scan flags a handoff command combining a `.claude/worktrees/` cd-prefix with a push/approve/review verb.
- [ ] **Optional — worktree-aware pre-push audit:** the pre-push `fw audit` skips worktree-pathed cron-drift FAILs (structural false-positive in a worktree) so the audit blocks only on the branch's actual changes, not on worktree noise. (Contributing factor in the origin incident.)
- [ ] On close: G-071 and G-072 updated with `fixed_in: T-2428` + `status_mitigation`; RCA below finalised; reviewer PASS.

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

**Symptom:** 6 commits on `t2353-audit-emit-tasks` (tip `b508ceef1`) committed in worktree
`livefire-t2389` never reached origin; branch absent from `git ls-remote origin`. No data lost.

**Proximate cause:** the human-run `--no-verify` bypass one-liner hard-coded the worktree cwd
(`cd .../.claude/worktrees/livefire-t2389 && …`). Days elapsed (06-27 → 07-01); the worktree
was removed; the paste failed at `cd: No such file or directory`; `git push` never ran.

**Contributing chain:** the push was blocked by three *sequential* pre-push gates — (1)
self-vendor (bin/fw mirror stale, fixed inline), (2) full `fw audit` with 3 FAILs that were
all pre-existing worktree noise unrelated to the branch (2× worktree-pathed cron drift + 1×
another session's `loop-detect.js` dist churn), (3) `check-tier0` requiring a human `--no-verify`
approval. The only route was a human-run bypass, whose handoff had to survive the worktree's
lifetime. It did not.

**Root cause (structural, two legs):**
- **G-072:** worktree teardown has no unpushed-commit guard. The T-1144 push guard lives on the
  *handover* path only; `git worktree remove` / session-exit cleanup is a separate, uncovered
  teardown (WorktreeRemove hook unconfigured). A branch can be stranded local-only with no warning.
- **G-071:** the Copy-Pasteable Commands rule (T-609/T-1257) mandates a `cd /path &&` prefix but
  is worktree-blind — for a command that outlives the session it must use the durable main-repo
  path + branch ref, not the ephemeral worktree cwd.

**Why structurally allowed:** the "don't strand unpushed commits" intent was encoded once, in the
handover push (T-1144), and never generalised to the teardown path; and the handoff-command rule
optimised for "runs from any dir now" without accounting for "runs after the worktree is gone."

**Prevention:** see ACs — G-072 teardown guard (primary), G-071 doc clause + optional reviewer
detector, and an optional worktree-aware pre-push audit so worktree noise stops forcing Tier-0
bypasses. Distinct from the immediate remedy (push the surviving branch from the durable path).

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

### 2026-07-01T09:18:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/rca-worktree-push-strand/.tasks/active/T-2428-worktree-teardown-strands-unpushed-commi.md
- **Context:** Initial task creation
