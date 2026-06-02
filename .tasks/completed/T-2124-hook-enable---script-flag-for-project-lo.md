---
id: T-2124
name: "hook-enable --script flag for project-local hooks"
description: >
  hook-enable --script flag for project-local hooks

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
created: 2026-05-30T21:04:15Z
last_update: 2026-05-30T21:04:15Z
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

# T-2124: hook-enable --script flag for project-local hooks

## Context

Add `--script <abs-path>` to `fw hook-enable` so consumer projects can register project-local hook scripts (outside the framework tree) without editing settings.json directly. Upstream fix request from 025-WokrshopDesigner (T-493/C-006). Code change is additive — existing `--name` behavior unchanged. See `/opt/025-WokrshopDesigner/.context/working/upstream-fix-request-c006.md`.

## Acceptance Criteria

### Agent
- [x] `--script /abs/path` registers `{"type":"command","command":"/abs/path"}` directly (not via `fw hook <name>`)
- [x] `--name` and `--script` together → exit 2 with "use --name or --script, not both"
- [x] `--script relative/path` → exit 2 with "must be absolute"
- [x] `--script /nonexistent` → exit 2 with "script not found"
- [x] `--script /non-executable` → exit 2 with "script not executable"
- [x] Idempotency: re-running same `(event, matcher, script)` is a no-op ("already registered")
- [x] `--dry-run` shows JSON containing script path without writing
- [x] Existing `--name` behavior unchanged (regression)

## Verification

# Create test script and settings file
printf '#!/bin/bash\nexit 0\n' > /tmp/test-hook-2124.sh && chmod +x /tmp/test-hook-2124.sh && echo '{"hooks":{}}' > /tmp/settings-2124.json
# dry-run shows script path in JSON
out=$(bash bin/hook-enable.sh --event PreToolUse --matcher Bash --script /tmp/test-hook-2124.sh --file /tmp/settings-2124.json --dry-run 2>&1); echo "$out" | grep -q '"command": "/tmp/test-hook-2124.sh"'
# mutual exclusion error
out=$(bash bin/hook-enable.sh --event PreToolUse --matcher Bash --name foo --script /tmp/test-hook-2124.sh --file /tmp/settings-2124.json 2>&1); echo "$out" | grep -q "not both"
# relative path error
out=$(bash bin/hook-enable.sh --event PreToolUse --matcher Bash --script relative/path.sh --file /tmp/settings-2124.json 2>&1); echo "$out" | grep -q "absolute"
# missing file error
out=$(bash bin/hook-enable.sh --event PreToolUse --matcher Bash --script /tmp/no-such-script-2124.sh --file /tmp/settings-2124.json 2>&1); echo "$out" | grep -q "not found"
# not-executable error
printf '#!/bin/bash\nexit 0\n' > /tmp/test-hook-noexec-2124.sh; out=$(bash bin/hook-enable.sh --event PreToolUse --matcher Bash --script /tmp/test-hook-noexec-2124.sh --file /tmp/settings-2124.json 2>&1); echo "$out" | grep -q "not executable"
# existing --name behavior still works (dry-run)
out=$(bash bin/hook-enable.sh --event PreToolUse --matcher Bash --name budget-gate --file /tmp/settings-2124.json --dry-run 2>&1); echo "$out" | grep -q '"command"'

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

### 2026-05-30 — vendored copy gap
- **What changed:** `bin/fw hook-enable` routes to `.agentic-framework/bin/hook-enable.sh` (vendored copy), not `bin/hook-enable.sh` directly. The previous worker only patched the source; the vendored copy needed syncing too.
- **Plan impact:** Required one extra `cp` step; otherwise no scope change.
- **Triggered:** Sync of vendored copy before tests passed.

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

### 2026-05-30T21:04:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2124-hook-enable---script-flag-for-project-lo.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5f2e43b6
- **Timestamp:** 2026-06-02T15:01:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
