---
id: T-2396
name: "Master-as-merge-only pre-commit guard (T-2394 G1 first slice)"
description: >
  Build Layer-1 of inception T-2394 (operator GO in chat 2026-06-14): a master-as-merge-only pre-commit guard. New agents/git/lib/master-guard.sh (scanner-pattern, like secret-scan.sh) called from the pre-commit hook in agents/git/lib/hooks.sh. Refuses a direct authored commit when HEAD is on master/main, while allowing merge commits (MERGE_HEAD), fast-forwards (no commit fires the hook), and rebases. Opt-in via config PROTECT_MASTER (default 0 = consumer-safe; set to 1 in this repo). Bypass: FW_ALLOW_MASTER_COMMIT=1 (Tier-2) or git commit --no-verify (Tier-0). Cherry-pick onto master blocked by default per T-2394 Decisions. Bump commit-msg + pre-commit VERSION markers (PL-078). Bats test: block-direct / allow-merge / allow-rebase / allow-feature-branch / off-by-default / env-bypass. Makes the operator invariant structural not advisory (L-405).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [git-hygiene, governance, pre-commit-hook, parallel-agents]
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
created: 2026-06-14T14:14:16Z
last_update: 2026-06-14T14:14:48Z
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

# T-2396: Master-as-merge-only pre-commit guard (T-2394 G1 first slice)

## Context

Layer-1 build of inception [[T-2394]] (operator GO in chat 2026-06-14). Plan: `docs/reports/T-2394-parallel-agent-substrate.md` §Recommendation. Makes the operator's "master is merge-only" invariant structural (L-405), closing G1.

### Build progress (WIP — session hit budget critical mid-build, 2026-06-14)
**DONE (committed `4e573d3b6`, both `bash -n` clean before commit):**
- `agents/git/lib/master-guard.sh` — full guard (scanner-pattern). Logic: PROTECT_MASTER off→allow; FW_ALLOW_MASTER_COMMIT=1→allow+WARN; branch∉{master,main}→allow; MERGE_HEAD/rebase→allow; else BLOCK with message naming both bypasses + branch→merge flow.
- `agents/git/lib/hooks.sh` — pre-commit heredoc calls the guard FIRST (before secret-scan, bash-invoke, `-f` gate); commit-msg VERSION 1.9→1.10 + pre-commit 1.0→1.1 (PL-078).

**REMAINING (next session):**
1. Write `tests/unit/master_guard.bats` (6 cases: block-direct / allow-merge / allow-rebase / allow-feature-branch / off-by-default / env-bypass). Use FW_PROTECT_MASTER=1 env to enable; simulate merge via `echo $(git rev-parse HEAD) > .git/MERGE_HEAD`; rebase via `mkdir .git/rebase-merge`.
2. `bin/fw config set PROTECT_MASTER 1` (writes `protect_master: 1` to this repo's .framework.yaml).
3. `bin/fw reviewer T-2396` → PASS; tick the 7 Agent ACs; run Verification gate.
4. `bin/fw fabric register agents/git/lib/master-guard.sh`.
5. **DEPLOY CAUTION:** `fw git install-hooks --force` updates the SHARED .git/hooks (affects the main checkout + all worktrees). Do NOT run from this worktree while the 2 live master-checkout sessions are active — it would start blocking their direct-master commits immediately (which is the intent, but coordinate first). Cleanest: deploy lands when this branch FFs to master + operator re-runs install-hooks. Guard is inert until BOTH (a) hook reinstalled AND (b) PROTECT_MASTER=1 present on master — so committing the source now is safe for the live sessions.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] `agents/git/lib/master-guard.sh` exists (scanner-pattern), `bash -n` clean; CLI exits 1 (block) for a direct authored commit on master/main when enabled, exits 0 (allow) for merge (MERGE_HEAD), rebase, feature branch, protection-off, or bypass
- [ ] Pre-commit hook in `agents/git/lib/hooks.sh` calls the guard (bash-invoke, `-f` gate per T-2061) before the secret scan; commit-msg + pre-commit VERSION markers bumped (PL-078)
- [ ] Opt-in via config `PROTECT_MASTER` (default 0 — consumer-safe); `FW_PROTECT_MASTER=1` env override works; both bypasses real end-to-end: `FW_ALLOW_MASTER_COMMIT=1` (Tier-2 WARN) and `git commit --no-verify` (Tier-0)
- [ ] Block message names BOTH bypass mechanisms + points at the branch→review→merge flow (L-399/T-1890 parity)
- [ ] Bats test `tests/unit/master_guard.bats` green: block-direct / allow-merge / allow-rebase / allow-feature-branch / off-by-default / env-bypass (≥6 cases, real git temp repos)
- [ ] `PROTECT_MASTER: 1` set in this repo's `.framework.yaml` (turns the guard on here; consumers stay off)
- [ ] Reviewer PASS (`bin/fw reviewer T-2396` → Overall: PASS)

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
bash -n agents/git/lib/master-guard.sh
bats tests/unit/master_guard.bats
grep -q '^protect_master:' .framework.yaml
out=$(bin/fw reviewer T-2396 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

### 2026-06-14T14:14:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2396-master-as-merge-only-pre-commit-guard-t-.md
- **Context:** Initial task creation

### 2026-06-14T14:14:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
