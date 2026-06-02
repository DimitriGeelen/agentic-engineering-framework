---
id: T-1890
name: "focus-drift bypass flag mismatch — hook recommends --switch-focus but downstream rejects (Unknown option)"
description: >
  focus-drift bypass flag mismatch — hook recommends --switch-focus but downstream rejects (Unknown option)

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [bug, hook-ux, focus-drift, meta-rca:T-1729, structural-gate, governance-bypass-prevention]
components: [agents/context/check-active-task.sh, agents/context/lib/decision.sh, C-002, agents/context/lib/pattern.sh, agents/task-create/update-task.sh, tests/unit/check_active_task_switch_focus.bats]
related_tasks: [T-1730, T-1731, T-1729]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T06:04:06Z
last_update: 2026-05-18T18:37:39Z
date_finished: 2026-05-18T06:11:46Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1890: focus-drift bypass flag mismatch — hook recommends --switch-focus but downstream rejects (Unknown option)

## Context

T-1730 introduced the focus-drift PreToolUse gate in `check-active-task.sh:248-320`. When the bash command targets a task ≠ focus, the hook blocks under agent control and instructs the agent to either (1) `fw context focus T-XXX` first or (2) "Append `--switch-focus` to the command (logged Tier 2)." The hook itself does scan BASH_CMD for the `--switch-focus` token and allows + logs the bypass — but it does NOT strip the token before the command runs. So when the agent follows option (2), the downstream consumer sees `--switch-focus` as an argument and rejects it.

Concretely:
- `bin/fw task update T-1855 --status work-completed --switch-focus` → `update-task.sh:882` prints "Unknown option: --switch-focus" and exits 1.
- `bin/fw context add-learning "…" --task T-XXX --switch-focus` → `agents/context/lib/learning.sh:34` prints "Unknown option: --switch-focus" and exits 1. Same in `pattern.sh:42` and `decision.sh:51`.
- `git commit -m "T-1737: …" --switch-focus` → `git` rejects unknown option, exit 129.

Last session (S-2026-0518-0009 closures of T-1854/T-1855/etc.) hit this and worked around by direct-invoke `bash agents/task-create/update-task.sh T-XXX --status work-completed` — the hook regex `(^|[[:space:]])(bin/)?fw[[:space:]]+task[[:space:]]+update` does not match `bash agents/...`, so the gate doesn't fire. That workaround circumvents the gate entirely; the bypass is silent, with no `.gate-bypass-log.yaml` entry.

## Acceptance Criteria

### Agent
- [x] `agents/task-create/update-task.sh` accepts `--switch-focus` as a silently-consumed no-op (no "Unknown option" exit). Verified by `bin/fw task update T-XXX --switch-focus --help` exits 0.
- [x] `agents/context/lib/learning.sh`, `pattern.sh`, `decision.sh` each accept `--switch-focus` as a silently-consumed no-op. Verified by `bin/fw context add-learning 'test' --task T-1890 --switch-focus` succeeding (or at least not failing on the `--switch-focus` token).
- [x] `agents/context/check-active-task.sh` recognises `FW_SWITCH_FOCUS=1` env-var prefix as an additional bypass mechanism (universal — works for `git commit` where `--switch-focus` flag cannot be added). Log entry distinguishes flag vs env-var via the `flag:` field.
- [x] Hook block message (focus-drift) recommends BOTH bypass mechanisms with their use cases: flag for fw commands, env var for git commit / other external tools.
- [x] Regression test `tests/unit/check_active_task_switch_focus.bats` covers:
  - flag bypass on `fw task update` (block → allow with log when `--switch-focus` present)
  - flag bypass passes update-task.sh option parser (end-to-end succeeds)
  - env-var bypass on `git commit ... T-X: ...` allowed + logged when `FW_SWITCH_FOCUS=1` prefix present
  - block message contains both mechanisms
- [x] [REVIEWER] Block message in `agents/context/check-active-task.sh` names both bypass mechanisms (`--switch-focus` flag for fw commands + `FW_SWITCH_FOCUS=1` env-var prefix for git/external) with one-line guidance for when to pick which. Re-classified from Human [REVIEW] by T-1894 — the original AC's "Expected" was a pure mechanical check; only "reads naturally cold" remains a Human judgment.

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# T-1890 verification:
bash -n agents/context/check-active-task.sh
bash -n agents/task-create/update-task.sh
bash -n agents/context/lib/learning.sh
bash -n agents/context/lib/pattern.sh
bash -n agents/context/lib/decision.sh
bats tests/unit/check_active_task_switch_focus.bats
# T-1894 re-class: block message names both bypass mechanisms with one-line guidance.
test "$(grep -c '\-\-switch-focus' agents/context/check-active-task.sh)" -ge 2
test "$(grep -c 'FW_SWITCH_FOCUS=1' agents/context/check-active-task.sh)" -ge 2
test "$(grep -cE 'Append --switch-focus' agents/context/check-active-task.sh)" -ge 1
test "$(grep -cE 'Prefix FW_SWITCH_FOCUS=1' agents/context/check-active-task.sh)" -ge 1

## RCA

**Symptom:** Agent runs `bin/fw task update T-XXX --status work-completed --switch-focus` after focus-drift block; downstream `update-task.sh` rejects `--switch-focus` as Unknown option, exit 1. Agent then escapes via direct-invoke `bash agents/task-create/update-task.sh T-XXX --status work-completed` — a path the hook regex does not match. Net effect: gate is silently circumvented, no audit trail.

**Root cause:** T-1730 introduced the focus-drift detection in `check-active-task.sh` and documented the bypass as a sentinel flag (`--switch-focus`), but the corresponding consumer-side acceptance was never wired into the downstream scripts. The hook is the producer of a contract; the consumers (`update-task.sh`, `agents/context/lib/{learning,pattern,decision}.sh`, and external `git commit`) were never updated to honour it. Producer/consumer split: contract shipped on one side only.

**Why structurally allowed:** No test pinned the end-to-end flag-bypass path. T-1730's bats tests cover the hook's block/allow logic in isolation (mocking the hook input) but not the post-hook execution of `update-task.sh` with the flag present. Result: the hook ships "working" in unit tests, the consumer ships "working" in its own unit tests, and the only place the broken end-to-end is observable is when an agent under CLAUDECODE=1 hits a focus-drift situation in real work — exactly the case that's hard to exercise in CI.

This is the same anti-pattern as L-306 (cross-codepath gate parity): when a gate or contract is introduced, every codepath that the contract talks to must be updated in lockstep. Missing one half is a silent capability loss.

**Prevention:** 
1. End-to-end bats test (`tests/unit/check_active_task_switch_focus.bats`) that exercises the full flag-bypass path: simulate a focus-drift, invoke `bin/fw task update T-X --status … --switch-focus`, assert exit 0 + bypass-log entry. Regression-pin the contract for both flag and env-var mechanisms.
2. Universal env-var path (`FW_SWITCH_FOCUS=1` prefix) closes the `git commit` case the flag mechanism fundamentally can't cover (git rejects unknown flags). Makes the bypass mechanism architecturally complete instead of pattern-1-only.
3. Block-message UX clarifies which mechanism to pick when, so the agent doesn't have to guess (and doesn't fall back to direct-invoke).

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

## Recommendation

**2026-05-18 T-1894 re-class note:** A mechanical sub-claim of this task's Human  AC has been split into a new Agent AC (with verification command in ). Only the genuine taste/judgment claim remains Human. See T-1894 for the classification audit and CLAUDE.md §AC Classification Guidance for the rule.

**Recommendation:** GO

**Rationale:** End-to-end focus-drift bypass contract is now complete and pinned by tests. Both mechanisms work:
- `--switch-focus` flag — consumed silently by `update-task.sh`, `learning.sh`, `pattern.sh`, `decision.sh` (the four downstream consumers of the three patterns the hook gates beyond git commit).
- `FW_SWITCH_FOCUS=1` env-var prefix — universal, including git commit which fundamentally cannot accept the flag because git rejects unknown options.

Block message now names both mechanisms with one-line guidance on when to pick which, so the agent doesn't have to guess and fall back to direct-invoke (the silent-bypass anti-pattern that motivated this fix).

**Evidence:**
- `agents/context/check-active-task.sh:271-329` — dual-mechanism detection + log entry + updated block message
- `agents/task-create/update-task.sh:881` — `--switch-focus` no-op branch
- `agents/context/lib/learning.sh:33-35`, `pattern.sh:41-43`, `decision.sh:50-52` — same no-op pattern, three consumers
- `tests/unit/check_active_task_switch_focus.bats` — 9/9 pass:
  - block-without-bypass (regression sanity)
  - `--switch-focus` flag allows + logs with `flag: '--switch-focus'`
  - `FW_SWITCH_FOCUS=1` allows + logs with `flag: 'FW_SWITCH_FOCUS=1'`
  - `FW_SWITCH_FOCUS=1 git commit ...` works (where flag fundamentally cannot)
  - block message contains both mechanism names
  - all four downstream consumers accept `--switch-focus` without Unknown-option exit
- `tests/unit/focus_drift_gate.bats` — 14/14 still pass (legacy flag-only path preserved)
- `tests/unit/check_active_task_memory_exempt.bats` — 6/6 still pass
- `tests/unit/context_focus.bats` — 19/19 still pass

**Why no Human-judgment ACs beyond block-message reading-clarity:**
The mechanism contract (does flag work, does env var work, does git commit case unblock) is fully deterministic and pinned by bats. Only the block-message wording is genuinely subjective — left as one `[REVIEW]` Human AC.

**Follow-up candidates (do NOT block T-1890 closure):**
- L-306-class learning: when a gate introduces a new bypass contract, add the consumer-side acceptance in the same task. The "producer ships, consumer assumes" split is the recurring anti-pattern.

## Decisions

### 2026-05-18 — flag + env-var dual-mechanism rather than env-var-only
- **Chose:** Keep `--switch-focus` flag support AND add `FW_SWITCH_FOCUS=1` env-var prefix.
- **Why:** Backward compat (the bypass log already has multi-day flag entries from real agent usage on T-1730/T-1740/T-1744/T-1687); env-var-only would have orphaned that pattern. The two-mechanism approach also matches the underlying topology — flag for fw commands (parser participation), env var for everything else (universal, no parser participation needed).
- **Rejected:** env-var-only — would have meant teaching every agent to drop a working pattern. Also rejected: flag-only — fundamentally broken for the git commit pattern the hook itself gates.


## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-18T06:04:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1890-focus-drift-bypass-flag-mismatch--hook-r.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0f48bf8b
- **Timestamp:** 2026-06-02T15:00:18Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `bats tests/unit/check_active_task_switch_focus.bats`
### 2026-05-18T06:11:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
