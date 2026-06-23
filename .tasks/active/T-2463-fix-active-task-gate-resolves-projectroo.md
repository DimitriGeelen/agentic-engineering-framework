---
id: T-2463
name: "fix: active-task gate resolves PROJECT_ROOT to main repo in worktree sessions (reads wrong focus.yaml) — OBS-080"
description: >
  fix: active-task gate resolves PROJECT_ROOT to main repo in worktree sessions (reads wrong focus.yaml) — OBS-080

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
created: 2026-06-23T08:01:54Z
last_update: 2026-06-23T08:01:54Z
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

# T-2463: fix: active-task gate resolves PROJECT_ROOT to main repo in worktree sessions (reads wrong focus.yaml) — OBS-080

## Context

In a git-worktree session the `check-active-task` PreToolUse gate reads the
**main repo's** `focus.yaml`, not the worktree's. The gate runs as
`<main>/bin/fw hook check-active-task`; with `CLAUDE_PROJECT_DIR` unset, `bin/fw`
resolves PROJECT_ROOT via `find_project_root` from the hook's process cwd (the
main launch dir) → reads main's focus. Meanwhile the agent's own tool commands
run with cwd=worktree and operate on the worktree's focus. The two never meet, so
worktree work blocks "No active task" whenever main focus is null (the normal
state). Confirmed by live experiment 2026-06-23 (see ## RCA). Operator-surfaced.
Distinct bug from T-2410 (which fixed task-ID-substring + read-only-subcommand
false-positives of the same hook — different root cause). Sibling: T-2462
safe-listed `git push` to sidestep this for the push case only.

## Acceptance Criteria

### Agent
- [x] `check-active-task.sh` extracts the top-level `cwd` field from its stdin JSON and, when `cwd` is non-empty and resolves (walking up) to a valid project root (has `.framework.yaml` or `.tasks/`), uses THAT root for PROJECT_ROOT + FOCUS_FILE — overriding the `bin/fw`-resolved value. Per-call stdin `cwd` is authoritative (it's the dir the tool actually runs in) and is NOT subject to the T-2446 inherited-env daemon-poison class, so it is trusted directly. Unit test with synthetic stdin `{cwd: <fixture-root>}` asserts focus is read from the fixture. — check-active-task.sh:49-86; pinned by check_active_task_cwd_resolution.bats test 1.
- [x] No-`cwd` / invalid-`cwd` regression: when stdin omits `cwd` or `cwd` is not a project root, resolution is byte-identical to current behavior (regression test on the existing stdin shape). — tests 3 & 5.
- [x] Worktree-vs-main scenario test: two fixture roots (mainfix, wtfix); stdin `cwd=wtfix` with `wtfix` focus = active task → ALLOWED; with `wtfix` focus = null → BLOCKED — proving the gate now reads the cwd-root's focus, not the process-resolved root's. — tests 1 & 2.
- [x] `bash -n agents/context/check-active-task.sh` passes (L-408). — verified.
- [x] Existing hook bats green (no regression): `check_active_task_fp_fix.bats`, `check_active_task_memory_exempt.bats`, `check_active_task_switch_focus.bats`, `integration/check_active_task.bats`. — 47/47 ok across all suites incl. the new 5.

### Human
- [ ] [REVIEW] End-to-end worktree unblock confirmed after merge to master
  **Steps:**
  1. After this lands on master, start (or resume) a session inside a linked worktree with null/idle main focus.
  2. Set the worktree focus to an active task: `cd <worktree> && bin/fw context focus T-XXX`
  3. Run a non-safe Bash command (e.g. `awk 'END{print NR}' VERSION`).
  **Expected:** the command is ALLOWED (gate now reads the worktree's focus).
  **If not:** capture `printenv CLAUDE_PROJECT_DIR`, `pwd`, and the block stderr; the stdin `cwd` may not be the worktree on this Claude Code version — fall back to a launcher that exports `CLAUDE_PROJECT_DIR=<worktree>`.
  **Why merge-gated:** the LIVE gate executes MAIN's copy of the hook (`<main>/bin/fw`), so this fix cannot be verified live from the worktree it's built in — same constraint as T-2462. Agent ACs verify the logic via bats; this AC verifies the real Claude Code `cwd` value end-to-end.

<!-- (template Human-AC guidance retained below for reference)
     Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
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

bash -n agents/context/check-active-task.sh
bats tests/unit/check_active_task_cwd_resolution.bats
bats tests/unit/check_active_task_fp_fix.bats
bats tests/unit/check_active_task_memory_exempt.bats
bats tests/unit/check_active_task_switch_focus.bats
bats tests/integration/check_active_task.bats

## RCA

**Symptom:** In a git-worktree session, non-safe Bash commands (and source
Write/Edit) block "No active task" regardless of the worktree's own focus —
even immediately after `bin/fw context focus T-XXX` succeeds in the worktree.

**Root cause:** The PreToolUse gate runs as `<main>/bin/fw hook
check-active-task` (absolute path to the main repo's `bin/fw` from
`.claude/settings.json`). In a worktree session `CLAUDE_PROJECT_DIR` is unset
(verified: `printenv CLAUDE_PROJECT_DIR` empty; `PWD`=worktree). With it unset,
`bin/fw` (bin/fw:190-234) resolves PROJECT_ROOT via `find_project_root`, which
walks up from the hook subprocess's process cwd — the main launch dir, since
Claude Code spawns hooks from the session's launch directory (same launch-cwd
fact T-2377 documents for transcript discovery). So the gate reads MAIN's
`.context/working/focus.yaml`. The agent's own tool commands run with
cwd=worktree → they resolve PROJECT_ROOT to the worktree and operate on the
worktree's focus. The two focus files never meet; main focus is normally `null`
→ every non-safe command blocks.

**Confirmed by live experiment (2026-06-23):**
- worktree focus.yaml = `T-2410` (set via worktree `bin/fw context focus`); main
  focus.yaml = `null`; gate blocked "No active task" (empty current_task) => it
  read main, not the worktree (else it would see T-2410 -> a STALE-FOCUS message,
  not No-active-task).
- DECISIVE: `PROJECT_ROOT=<main> bin/fw context focus T-2410` (set MAIN focus) ->
  a genuinely non-safe probe (`true && echo`) was then ALLOWED. Setting main
  focus unblocked the gate => gate reads main. (Main focus restored to null after.)
- Pitfall: `git rev-parse` IS safe-listed (safe-commands.sh:44) so it is a
  useless focus probe — it passes regardless. Use a base NOT in the allowlist.

**Why structurally allowed:** the framework's own worktree isolation model
(`.claude/worktrees/`) produces a session whose hook-invocation context (process
cwd = launch dir = main) diverges from its operating tree (the worktree). For a
Bash tool call there is no `file_path` to anchor resolution on (unlike Write/Edit),
and the gate trusted the process-cwd-derived PROJECT_ROOT without consulting the
authoritative per-call `cwd` Claude Code passes on stdin. T-2390/T-2446 added a
`CLAUDE_PROJECT_DIR` path, but it is unset for these hooks, and the T-2446
cwd-consistency guard (added for the /opt/505 daemon-poison case) makes a real
cwd=main win over a differing CLAUDE_PROJECT_DIR — so it cannot rescue the
worktree case either.

**Fix:** `check-active-task.sh` reads the top-level `cwd` from its stdin JSON
(Claude Code documents `cwd` = "working directory when the event fired"; the gate
already reads stdin for tool_name/command/file_path) and, when `cwd` resolves to a
valid project root, uses that root for PROJECT_ROOT + FOCUS_FILE. Per-call stdin
`cwd` is authoritative and not inherited, so it is immune to the T-2446
daemon-poison class — fix lives in the gate only, no change to `bin/fw`'s global
resolution.

**Prevention:** the worktree-vs-main scenario bats test
(`check_active_task_cwd_resolution.bats`) pins that a stdin `cwd` pointing at a
distinct project root drives focus resolution — the next regression of this class
fails the test. (E2E on the real Claude Code `cwd` value is the merge-gated Human
AC, since the live gate runs main's copy of the hook.)

## Recommendation

**Recommendation:** GO

**Rationale:** Root cause confirmed by live experiment (not just code-reading):
the worktree gate reads main's focus.yaml because `bin/fw` resolves PROJECT_ROOT
from the hook's process cwd (main launch dir) when `CLAUDE_PROJECT_DIR` is unset.
Fix reads the authoritative per-call `cwd` Claude Code passes on stdin and
re-anchors PROJECT_ROOT to it — conservative (no-op unless cwd's root differs, so
zero regression for normal sessions) and immune to the T-2446 daemon-poison class
(per-call cwd is fresh, not inherited). The one residual unknown — whether the
real Claude Code `cwd` is the worktree path on this version — is the merge-gated
Human AC; per the CC docs `cwd` = "working directory when the event fired", which
is the worktree, and the session's `PWD` confirms the worktree.

**Evidence:**
- `agents/context/check-active-task.sh:49-86` — cwd re-anchor block
- `tests/unit/check_active_task_cwd_resolution.bats` — 5/5 pass (worktree-allowed, worktree-null-blocked, no-cwd regression, no-op-when-equal, outside-project)
- 47/47 across all check-active-task hook suites (no regression)
- `bash -n` clean; vendored copy synced (`.agentic-framework/...`)
- RCA §"Confirmed by live experiment (2026-06-23)"

**Note:** verification of the real CC `cwd` value is e2e and merge-gated — the
LIVE gate runs main's copy of the hook, so this fix is only observable in worktree
sessions after FF-merge to master (same constraint as T-2462).

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

### 2026-06-23T08:01:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2463-fix-active-task-gate-resolves-projectroo.md
- **Context:** Initial task creation
