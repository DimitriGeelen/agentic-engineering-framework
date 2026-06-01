---
id: T-1725
name: "fw test playwright SKIP misleading + fw doctor missing playwright checks"
description: >
  fw test playwright SKIP misleading + fw doctor missing playwright checks

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-05-04T20:16:30Z
last_update: 2026-05-04T20:49:19Z
date_finished: 2026-05-04T20:49:19Z
---

# T-1725: fw test playwright SKIP misleading + fw doctor missing playwright checks

## Context

`fw test all` emits a misleading SKIP for Playwright in vendored consumers — it conflates
two distinct failure modes (pip package missing vs `tests/playwright/` directory missing)
into one message that suggests installing the wrong thing. Consumers commonly have
`@playwright/mcp@latest` configured in `.mcp.json` (auto-installed by `lib/upgrade.sh:899`)
and read the SKIP as "I have playwright, why is it complaining?" The MCP server (npm,
agent-driven) and pytest-playwright (pip, regression suite) are different concerns —
both are needed, neither substitutes.

Additionally, `fw doctor` doesn't check for either, so the gap is invisible until the
user runs `fw test all` and sees the SKIP.

## Acceptance Criteria

### Agent
- [x] `bin/fw test all` Playwright section emits separate, actionable messages for the two failure modes (pip missing vs tests/playwright/ absent), and looks in `$PROJECT_ROOT/tests/playwright/` first then `$FRAMEWORK_ROOT/tests/playwright/`.
- [x] `fw doctor` adds two checks: (a) Playwright pip package (`python3 -c "import playwright"`) with install hint, (b) Playwright MCP server present in `.mcp.json`. Both as WARN (not FAIL) when missing.
- [x] Both checks emit GREEN OK on the framework repo (where pip + MCP are both present).
- [x] No regression in existing `fw doctor` output (still passes `fw doctor` overall).
- [x] Existing `fw test all` invocation produces at most one Playwright message line (no doubling from the changed code path).

## Verification

# Confirm the old conflated SKIP message is gone from source
test "$(grep -c 'SKIP: playwright not installed or tests/playwright/ missing' bin/fw)" = "0"
# Confirm both new doctor checks emit the OK line on framework repo
bin/fw doctor 2>&1 | grep -E "OK[^[:alnum:]].*Playwright pip package" >/dev/null
bin/fw doctor 2>&1 | grep -E "OK[^[:alnum:]].*Playwright MCP server" >/dev/null
# Confirm the new SKIP cases exist in source (split into two distinct messages)
grep -q "SKIP: pytest-playwright not installed" bin/fw
grep -q "SKIP: no tests/playwright/ found" bin/fw
# Confirm fw doctor runs cleanly end-to-end
bin/fw doctor

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

## Recommendation

**Recommendation:** GO

**Rationale:** The fix is a minimal, mechanical change that disambiguates a misleading SKIP (one message conflating pip-package-missing and tests-dir-missing into a single hint that suggests installing the wrong thing) and makes the playwright dual-surface (pip + MCP) visible in `fw doctor` so the gap surfaces during health checks rather than only during test runs. No behaviour change for fully-installed environments; consumers get an actionable install hint instead of confusing noise.

**Evidence:**
- `bin/fw:5292-5310` — Playwright section in `fw test all` now branches on three cases: pip-missing (actionable hint, names the pip-vs-MCP distinction), tests-dir-absent (clean SKIP), both-present (runs from `$PROJECT_ROOT/tests/playwright/` first, fallback to framework).
- `bin/fw:1037-1055` — `fw doctor` now reports two new lines: "Playwright pip package (test runner)" and "Playwright MCP server (agent UI verification)", each with its own install hint when missing.
- `fw doctor` shows GREEN OK on both new lines on this framework repo.
- `fw test playwright` (direct path, untouched) still runs — 447 tests collected.
- Existing `tests/integration/fw_test_cmd.bats` only exercises `fw test playwright` and `fw test --playwright` flags, not the `all` branch I changed.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-04T20:16:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1725-fw-test-playwright-skip-misleading--fw-d.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-afae4229
- **Timestamp:** 2026-05-04T20:51:33Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 4
     - evidence: `bin/fw doctor 2>&1 | grep -E "OK[^[:alnum:]].*Playwright pip package" >/dev/null`
  2. **empty-output-success** (partial, heuristic) @ Verification:line 5
     - evidence: `bin/fw doctor 2>&1 | grep -E "OK[^[:alnum:]].*Playwright MCP server" >/dev/null`

### 2026-05-04T20:49:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
