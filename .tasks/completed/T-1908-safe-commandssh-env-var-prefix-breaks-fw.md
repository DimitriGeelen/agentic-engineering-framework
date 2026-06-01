---
id: T-1908
name: "safe-commands.sh env-var prefix breaks FW_SWITCH_FOCUS bypass — fw work-on T-XXX with FW_SWITCH_FOCUS=1 prefix gets blocked because first-token extraction returns 'FW_SWITCH_FOCUS=1' instead of 'fw'"
description: >
  safe-commands.sh env-var prefix breaks FW_SWITCH_FOCUS bypass — fw work-on T-XXX with FW_SWITCH_FOCUS=1 prefix gets blocked because first-token extraction returns 'FW_SWITCH_FOCUS=1' instead of 'fw'

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T20:12:21Z
last_update: 2026-05-18T20:14:29Z
date_finished: 2026-05-18T20:14:29Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1908: safe-commands.sh env-var prefix breaks FW_SWITCH_FOCUS bypass — fw work-on T-XXX with FW_SWITCH_FOCUS=1 prefix gets blocked because first-token extraction returns 'FW_SWITCH_FOCUS=1' instead of 'fw'

## Context

The T-1730 focus-drift gate's bypass-mechanism contract (L-399 / T-1890) says: when blocked, the agent can prefix `FW_SWITCH_FOCUS=1` to ANY command including `git commit` (where git rejects unknown flags). But `is_bash_safe_command` in `agents/context/lib/safe-commands.sh:25` extracts the base command with `awk '{print $1}' | sed 's|.*/||'` — with an env-var prefix, `$1` is `FW_SWITCH_FOCUS=1`, not `fw`. So `FW_SWITCH_FOCUS=1 bin/fw work-on T-XXX` does NOT match the `fw work-on` safe-command allowlist, falls through to the captured-status block, and dies — even though the agent followed the documented contract.

This bit me in this session: T-1907 was filed with status `captured`, focus pointed at T-1687, and I needed to start T-1907. The block message said "FW_SWITCH_FOCUS=1 to any command". When I added the prefix, the safe-commands extractor shifted and the captured-status block fired.

Fix: strip env-var prefixes (regex `^[A-Z_][A-Z0-9_]*=\S+`) repeatedly from the command before extracting `$1`. This makes `is_bash_safe_command` match the actual command, not the env-prefix.

## RCA

**Symptom:** `FW_SWITCH_FOCUS=1 bin/fw work-on T-1907` blocked by check-active-task.sh with "Task T-1907 has status 'captured'" — but the suggested resolution `bin/fw work-on T-1907` (without prefix) works.

**Root cause:** `is_bash_safe_command` in `agents/context/lib/safe-commands.sh` extracts the first whitespace-delimited token (`awk '{print $1}'`) and checks it against a case allowlist. Env-var prefixes (`KEY=val`) are valid bash syntax but break this extraction — the first token becomes `KEY=val` instead of the actual command name. The case-match fails, the safe-command path is skipped, and the captured-status check downstream blocks.

**Why structurally allowed:** T-1890's bypass-mechanism contract was tested via direct hook block-message verification, not end-to-end "does the prefix unblock the downstream `is_bash_safe_command` check?" The producer side (focus-drift hook) shipped the bypass; the consumer side (safe-commands check) never learned to handle the env-prefix shape.

**Prevention:**
1. Fix the extractor in `is_bash_safe_command` to skip env-var prefixes
2. Bats test that pins both forms — `cmd` and `KEY=val cmd` — return the same allow/deny verdict
3. (Future) the same fix shape applies elsewhere if any other hook does first-token base extraction — sweep needed

This is an L-399 / T-1890 class regression — exactly the producer/consumer parity gap that rule targets.

## Acceptance Criteria

### Agent
- [x] `is_bash_safe_command` in `agents/context/lib/safe-commands.sh` strips leading env-var prefixes (`KEY=val` syntax) before extracting the base command
- [x] `FW_SWITCH_FOCUS=1 bin/fw work-on T-1907` returns the same `is_bash_safe_command` verdict as bare `bin/fw work-on T-1907` (allow)
- [x] Multiple env-var prefixes are stripped (`FOO=1 BAR=2 fw work-on T-X` → base=fw)
- [x] No regression: non-prefix commands continue to be classified correctly
- [x] New bats test `tests/unit/safe_commands_env_prefix.bats` pins the behaviour with at least 4 cases (no-prefix, single-prefix, multi-prefix, prefix-with-path-stripped-command)

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

bats tests/unit/safe_commands_env_prefix.bats

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

### 2026-05-18T20:12:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1908-safe-commandssh-env-var-prefix-breaks-fw.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-8ef2a504
- **Timestamp:** 2026-05-18T20:14:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-18T20:14:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
