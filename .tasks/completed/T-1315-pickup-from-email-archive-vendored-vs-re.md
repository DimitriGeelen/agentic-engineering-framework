---
id: T-1315
name: "Pickup from email-archive: vendored-vs-repo mode blind spot RCA (sourced T-1043)"
description: >
  Inception request from /opt/050-email-archive (T-1043) about systemic vendored-mode blind spots. Two incidents reported: bin/fw path miss (resolved via CLAUDE.md T-1257 update we shipped) and PROJECT_ROOT env leak (resolved by T-1310 we shipped today). Three options proposed (symlink, path-aware CLAUDE.md rule, structural session preflight). Proposal artifact at docs/proposals/T-1315-from-email-archive-vendored-mode-blindspot.md.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: [agents/task-create/update-task.sh]
related_tasks: []
created: 2026-04-18T20:33:25Z
last_update: 2026-04-22T11:14:38Z
date_finished: 2026-04-22T11:14:26Z
---

# T-1315: Pickup from email-archive: vendored-vs-repo mode blind spot RCA (sourced T-1043)

## Problem Statement

Email-archive (vendored framework consumer at `/opt/050-email-archive`) reports a systemic blind spot: framework guidance and tooling assume agents run from inside the framework's own repo, but most real runs are from vendored consumers. Two manifestations in 36 hours:
- **Incident A:** CLAUDE.md "use `bin/fw`" rule sent agent to a non-existent path in vendored layout (consumer has `.agentic-framework/bin/fw` only).
- **Incident B:** Stale `PROJECT_ROOT` env var leaked across sessions, causing T-1288/T-1289 to be created in framework repo instead of email-archive.

Research artifact: `docs/reports/T-1315-closure.md`. Full proposal: `docs/proposals/T-1315-from-email-archive-vendored-mode-blindspot.md`. Same class as T-1316 (T-1044 verification CWD bug) — vendored-vs-repo mode blind spot.

## Assumptions

1. Incident A (`bin/fw` path miss) is **already fixed** by CLAUDE.md update T-1257 (context-aware `fw` path, "framework repo: `bin/fw`; consumer: `.agentic-framework/bin/fw`") shipped 2026-04-18.
2. Incident B (`PROJECT_ROOT` env leak) is **already fixed for the Watchtower** by T-1310 (Python-side `_resolve_project_root` env > discovered > FRAMEWORK_ROOT) shipped 2026-04-18.
3. The remaining gap is **structural enforcement** at session start (preflight): nothing today validates `PROJECT_ROOT` against `pwd` for shell-level callers, so an agent invoking `fw work-on` directly could still write to the wrong project on env leak. Bash-side `paths.sh` does walk-up discovery but `fw` shim trusts env when set.

## Exploration Plan

Status mapping (already-shipped vs still-open work):

| Email-archive Option | Status | Our task |
|---|---|---|
| Option 1: install-time `bin/fw` symlink | Possible alternative | Not chosen — supersedes the consumer layout convention; consumers of the consumer would inherit the symlink. Risky. |
| Option 2: path-aware CLAUDE.md rule (use `$FW`) | **Partially done** via T-1257 (context-aware path guidance: `bin/fw` vs `.agentic-framework/bin/fw`) | T-1257 done; `$FW` env var not added |
| Option 3: structural session preflight (re-derive PROJECT_ROOT, fingerprint env, hooks verify against it) | **Partially done** via T-1310 (Python side); shell side unchanged | Open: shell-side `fw` shim should also detect env-vs-pwd mismatch and warn/refuse |

Spikes still warranted:
- FS3a — Survey: how many shell sites in `bin/`, `lib/`, `agents/` trust `PROJECT_ROOT` env without verifying against `pwd`? (Build a list.)
- FS3b — Spike: add an early `_validate_project_root()` to `lib/paths.sh` that warns if `$PROJECT_ROOT` is set AND `.framework.yaml` at `$PROJECT_ROOT` is missing OR doesn't match the walk-up-from-pwd discovery. Don't refuse yet — just emit to stderr.
- FS3c — Decide go/no-go on the `$FW` env-var convention (Option 2 piece we haven't shipped).

## Technical Constraints

- Shell-side fix must not break `bin/fw` invocations from cron, systemd, CI (where `pwd` may be `/` or `$HOME` and env is the only signal).
- Warnings should be opt-in-strict via `FW_STRICT_PROJECT_ROOT=1`, default to permissive.
- No new dependencies.

## Scope Fence

**IN (this inception):** Decide whether to add shell-side env-vs-pwd validation, and whether to ship the `$FW` convention. Spike FS3a + FS3b only.

**OUT:** Full restructuring of CLAUDE.md to use templated `$FW` examples (Option 3 full version). Rewriting all consumer CLAUDE.md files. Multi-root discovery.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (T-1257 + T-1310 already shipped, mapped to email-archive's Options 2 + 3)
- [x] Recommendation written with rationale (DEFER pending email-archive retest)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** DEFER (with credit)

**Rationale:** Two of the three concrete failure modes email-archive identified are **already fixed** in commits shipped today (T-1257, T-1310). The remaining gap (shell-side env-vs-pwd validation) is structural but not blocking — no incident has hit it after T-1310 closed the Python-side leak. Spending another 1-2 sessions on a shell-side preflight is real cost; recurrence risk after T-1310 is low. Recommend: **acknowledge the pickup with the fixes shipped, ask email-archive to retest, defer the shell-side work to a follow-up if a fresh incident appears.**

**Evidence:**
- T-1257 (CLAUDE.md context-aware path rule) directly addresses Incident A.
- T-1310 (`_resolve_project_root`) directly addresses Incident B for the Watchtower (where the original incident occurred).
- No equivalent leak has been observed for shell-side `fw` callers in our episodic memory.
- `lib/paths.sh` already has walk-up discovery for shell — only the env-precedence guard is missing.

**Alternative if email-archive sees recurrence after retesting:** Promote FS3b spike to a build task (~1 session), add `_validate_project_root` to `lib/paths.sh`, gated by `FW_STRICT_PROJECT_ROOT`.

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

**Decision**: DEFER

**Rationale**: Recommendation: DEFER (with credit)

Rationale: Two of the three concrete failure modes email-archive identified are already fixed in commits shipped today (T-1257, T-1310). The remaining gap (shell-side env-vs-pwd validation) is structural but not blocking — no incident has hit it after T-1310 closed the Python-side leak. Spending another 1-2 sessions on a shell-side preflight is real cost; recurrence risk after T-1310 is low. Recommend: acknowledge the pickup with the fixes shipped, ask email-archive to retest, defer the shell-side work to a follow-up if a fresh incident appears.

Evidence:
- T-1257 (CLAUDE.md context-aware path rule) directly addresses Incident A.
- T-1310 (`_resolve_project_root`) directly addresses Incident B for the Watchtower (where the original incident occurred).
- No equivalent leak has been observed for shell-side `fw` callers in our episodic memory.
- `lib/paths.sh` already has walk-up discovery for shell — only the env-precedence guard is missing.

Alternative if email-archive sees recurrence after retesting: Promote FS3b spike to a build task (~1 session), add `_validate_project_root` to `lib/paths.sh`, gated by `FW_STRICT_PROJECT_ROOT`.

**Date**: 2026-04-18T22:49:20Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-18T20:44:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-18T22:49:20Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER (with credit)

Rationale: Two of the three concrete failure modes email-archive identified are already fixed in commits shipped today (T-1257, T-1310). The remaining gap (shell-side env-vs-pwd validation) is structural but not blocking — no incident has hit it after T-1310 closed the Python-side leak. Spending another 1-2 sessions on a shell-side preflight is real cost; recurrence risk after T-1310 is low. Recommend: acknowledge the pickup with the fixes shipped, ask email-archive to retest, defer the shell-side work to a follow-up if a fresh incident appears.

Evidence:
- T-1257 (CLAUDE.md context-aware path rule) directly addresses Incident A.
- T-1310 (`_resolve_project_root`) directly addresses Incident B for the Watchtower (where the original incident occurred).
- No equivalent leak has been observed for shell-side `fw` callers in our episodic memory.
- `lib/paths.sh` already has walk-up discovery for shell — only the env-precedence guard is missing.

Alternative if email-archive sees recurrence after retesting: Promote FS3b spike to a build task (~1 session), add `_validate_project_root` to `lib/paths.sh`, gated by `FW_STRICT_PROJECT_ROOT`.

### 2026-04-22T11:14:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
