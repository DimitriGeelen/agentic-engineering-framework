---
id: T-1888
name: "ship T-1886 RCA Candidate B — PostToolUse nudge on .claude/settings.json edits to remind agent to refresh enforcement baseline"
description: >
  ship T-1886 RCA Candidate B — PostToolUse nudge on .claude/settings.json edits to remind agent to refresh enforcement baseline

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc-grooming, prevention, governance, hooks]
components: [agents/context/check-settings-edit.sh, .claude/settings.json, .context/project/enforcement-baseline.sha256, tests/unit/hook_check_settings_edit.bats]
related_tasks: [T-1886, T-1887, T-1849, T-1730, T-1731, T-1687]
arc_id: arc-grooming
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-17T20:41:20Z
last_update: 2026-05-17T20:58:28Z
date_finished: 2026-05-17T20:58:28Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1888: ship T-1886 RCA Candidate B — PostToolUse nudge on .claude/settings.json edits to remind agent to refresh enforcement baseline

## Context

T-1887 deployed Candidate A (L-398 template hint). This slice ships Candidate B — a PostToolUse advisory hook that fires whenever `.claude/settings.json` is written/edited, reminding the agent to add `bin/fw enforcement baseline` to the task's Verification block. Strictly advisory (exit 0 always); does not block. Same pattern as existing `check-fabric-new-file.sh` (T-371): JSON-in/JSON-out with `additionalContext`.

Dogfood: installing the hook itself edits `.claude/settings.json`, which means the very installation triggers the new nudge. That nudge is the test of whether the prevention works end-to-end — the agent installing the hook should refresh the baseline in the same task as a result.

## Acceptance Criteria

### Agent
- [x] `agents/context/check-settings-edit.sh` exists, executable, follows the existing check-fabric-new-file.sh pattern (JSON stdin/stdout, exit 0)
- [x] Hook script returns empty output when tool_name != Write/Edit or file_path != `.claude/settings.json`
- [x] Hook script emits `additionalContext` with the L-398 reminder when the matched edit occurs
- [x] `.claude/settings.json` PostToolUse section registers `fw hook check-settings-edit` on `Write|Edit` matcher
- [x] Baseline refreshed after registration (dogfood — `fw doctor` reports Enforcement baseline intact)
- [x] `tests/unit/hook_check_settings_edit.bats` exists with 3 cases: match-fires, non-match-silent, non-settings-write-silent — all PASS

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

test -x agents/context/check-settings-edit.sh
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Enforcement baseline intact"
bats tests/unit/hook_check_settings_edit.bats
# Functional probe — simulate hook input with .claude/settings.json target, expect additionalContext mentioning the baseline command:
out=$(echo '{"tool_name":"Edit","tool_input":{"file_path":".claude/settings.json"}}' | bash agents/context/check-settings-edit.sh); echo "$out" | grep -q "enforcement baseline"
# Negative probe — non-settings edit must produce no output:
out=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"random/file.py"}}' | bash agents/context/check-settings-edit.sh); test -z "$out"

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

## Evolution

### 2026-05-17 — bats test setup() collision

- **What changed:** First version of `tests/unit/hook_check_settings_edit.bats` defined a local `setup()` to initialise `HOOK=`, which shadowed the shared `tests/test_helper.bash` `setup()` that creates `TEST_TEMP_DIR`. `teardown()` then failed on every case because `TEST_TEMP_DIR` was unset. All 6 cases reported "not ok" even though the hook produced correct stdout.
- **Plan impact:** The bats template I assumed (override setup to inject vars) is the wrong shape for this codebase — the helper's setup/teardown are mandatory. Future hook-test files should declare locals inside each `@test` body or in a `_run_hook` helper, not in `setup()`.
- **Triggered:** Inlined HOOK= via a `run_hook()` helper instead of a local setup. No new task — pattern correction folded into this slice.

### 2026-05-17 — bug-class gate false-positive on prevention-deployment titles

- **What changed:** Task title contains "RCA Candidate B" (referring to deployment of a candidate identified in T-1886's RCA), which trips the bug-class title regex. Same shape as T-1887 ("RCA" in title) — both are prevention-deployment slices, not bug fixes.
- **Plan impact:** None for this slice (used --skip-rca as designed). But: the bug-class regex catches by title keyword, not by workflow semantics. Prevention-deployment slices of an RCA's candidates will keep tripping the gate when the title cites the RCA being addressed.
- **Triggered:** Noted as observation, not filed — pattern is small and the --skip-rca bypass is cheap. Watch for accumulation before promoting to a registry entry.

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

## Recommendation

**Recommendation:** GO — work-completed.

**Rationale:** T-1886 RCA Candidate B (PostToolUse nudge) is now deployed. Pairs with T-1887 Candidate A (template hint) — together they cover both the pre-task hint (read the template) and the post-edit nudge (read the additionalContext). Candidate C (pre-push block on baseline drift) remains reserved; not needed unless the nudge proves insufficient.

**Evidence:**
- `agents/context/check-settings-edit.sh` written + executable; smoke-tested with positive/negative/malformed-input cases
- 6/6 bats cases pass (tests/unit/hook_check_settings_edit.bats): match-fires (Edit + Write), non-match-silent, non-edit-tool-silent, malformed-JSON-tolerated, wrong-dir-silent
- `.claude/settings.json` PostToolUse section now includes `fw hook check-settings-edit` on `Write|Edit` matcher (one new entry, additive — does not collide with existing `commit-cadence` on same matcher)
- Dogfood-validated: registering the hook itself was an Edit to `.claude/settings.json`; baseline diverged; refreshed via `bin/fw enforcement baseline`; `fw doctor` now reports "Enforcement baseline intact"
- Hash before: `b3f1fc73…`; hash after: `4e54c076…`

**Arc:** arc-grooming. Slice family closed: T-1884 (CTL-026 promotion) + T-1885 (fabric card hygiene) + T-1886 (baseline refresh + RCA) + T-1887 (Candidate A) + T-1888 (Candidate B). Five hygiene-tail slices shipped this session.

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

### 2026-05-17T20:41:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1888-ship-t-1886-rca-candidate-b--posttooluse.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f4b5d9e2
- **Timestamp:** 2026-06-02T15:00:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-17T20:58:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
