---
id: T-2052
name: "no-active-task gate deadlock: blocks fw context focus / task create / work-on
  (its own unblock commands) when focus cleared"
description: >
  Found during T-2030 GO. After a Watchtower inception decision cleared focus (current_task:
  null), the check-active-task PreToolUse hook blocked ALL non-safe Bash — including
  fw context focus, fw task create, and fw work-on, which are the exact commands the
  hook's own block message lists as the unblock path. Deadlock: cannot create/focus
  a task because there is no active task. Only escape was hand-editing the exempt
  .context/working/focus.yaml. Fix: check-active-task.sh must allow fw context focus
  / fw task create / fw work-on (and fw work-on T-XXX) on the Bash fast-path even
  when current_task is empty — they are the task-bootstrap commands. Bug-class: needs
  RCA + bats test.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/check-active-task.sh, agents/context/lib/safe-commands.sh]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-25T19:51:20Z
last_update: 2026-05-25T20:11:54Z
date_finished: 2026-05-25T20:11:54Z
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
  - ts: '2026-05-25T20:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-25T20:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-2052: no-active-task gate deadlock: blocks fw context focus / task create / work-on (its own unblock commands) when focus cleared

## Context

When focus is cleared (`current_task: null`, e.g. after a Watchtower inception decision),
`check-active-task.sh` blocks every non-safe Bash command — including `fw context focus`,
`fw task create`, and `fw work-on`, the exact commands its own block message lists as the
unblock path. Root cause: `is_bash_safe_command` (safe-commands.sh) extracts the base via
`awk '{print $1}'` (first word), so `cd … && bin/fw work-on` and multi-line `cd`↵`bin/fw …`
forms resolve base to `cd`/garbage and never inspect the fw subcommand; additionally
`fw task create` is absent from the fw allowlist entirely (only `list|verify|review`).
Found during T-2030 GO recovery (related: T-2051).

## Acceptance Criteria

### Agent
- [x] `check-active-task.sh` allows task-bootstrap commands (`fw work-on`, `fw task create`,
      `fw context focus`, `fw inception`) regardless of active-task state, robust to a
      `cd … &&` prefix and multi-line forms (whole-command match, not first-word base).
- [x] `fw task create` is added to the fw safe-command allowlist in `safe-commands.sh`
      (sibling gap — single-word `bin/fw task create` was also blocked with no active task).
- [x] Simulating the hook with `current_task: null` and a `cd … && bin/fw context focus …`
      command returns exit 0 (allow), not exit 2 (block).
- [x] A non-bootstrap write command (e.g. `bin/fw task update T-X --status ...`) with
      `current_task: null` still exits 2 (the gate is not weakened for non-bootstrap ops).
- [x] bats regression test pins both: bootstrap allowed + non-bootstrap still blocked, with
      `cd`-prefix and multi-line variants.

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

bash -n agents/context/check-active-task.sh
bash -n agents/context/lib/safe-commands.sh
bats tests/unit/test_check_active_task_bootstrap.bats

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

**Symptom:** After a Watchtower inception decision cleared focus (`current_task: null`),
every non-safe Bash was blocked — including `fw context focus`, `fw task create`, and
`fw work-on`, the exact commands the block message lists as the unblock path. Only escape
was hand-editing the exempt `.context/working/focus.yaml`.

**Root cause:** `is_bash_safe_command` (safe-commands.sh) derives the base command from
`awk '{print $1}'` — the FIRST word. Agent commands are routinely `cd <dir> && bin/fw …`
or multi-line `cd`↵`bin/fw …`, so the base resolved to `cd` (single-line) or multi-word
garbage (multi-line), and the `fw` subcommand was never inspected → not recognised as safe
→ fell through to the no-active-task block. Compounded by `fw task create` being absent
from the fw allowlist (only `list|verify|review`), so even the single-word form was blocked.

**Why structurally allowed:** the safe-command fast-path was designed around simple
single-token commands; no test exercised the bootstrap verbs in `cd …&&` / multi-line form
with focus cleared — the precise state that occurs after every task completion.

**Prevention:** `tests/unit/test_check_active_task_bootstrap.bats` pins bootstrap-allowed
(incl. cd-prefix + multi-line) AND non-bootstrap-still-blocked AND write-pattern-wins. The
fix itself uses a whole-command regex (not first-word base) so it is immune to the prefix
class. Sibling bug T-2051 (Watchtower decide 500 + uncommitted) is what *cleared* focus,
exposing this.

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

### 2026-05-25T19:51:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2052-no-active-task-gate-deadlock-blocks-fw-c.md
- **Context:** Initial task creation

### 2026-05-25T20:01:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c19b0d91
- **Timestamp:** 2026-05-25T20:11:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-25T20:11:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
