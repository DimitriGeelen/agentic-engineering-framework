---
id: T-2460
name: "Slice 1C-wiring (T-2458): fw init/upgrade add fw MCP server to consumer .mcp.json"
description: >
  Slice 1C-wiring (T-2458): fw init/upgrade add fw MCP server to consumer .mcp.json

status: work-completed
workflow_type: build
owner: agent
horizon:
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
created: 2026-06-22T10:06:04Z
last_update: '2026-08-16T22:25:06Z'
date_finished: 2026-06-22T10:12:55Z
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
bvp_scores_proposed:
  - ts: '2026-08-16T22:25:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 5
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=5 (body:class-neutral); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2460: Slice 1C-wiring (T-2458): fw init/upgrade add fw MCP server to consumer .mcp.json

## Context

Slice 1C-wiring of T-2458 (GO). The enabling server fix (T-2459) made the vendored `fw` MCP server work
against a consumer project; this slice makes `fw init`/`upgrade` actually **wire** it into a consumer's
`.mcp.json` so consumers receive it (RC-1, the CRITICAL root cause). Without this, "other AEF projects"
cannot use the MCP at all.

**Design (matches the existing context7/playwright/termlink pattern — servers are hardcoded inline in both
`lib/init.sh` and `lib/upgrade.sh`):**
- Add a `fw` server entry: `{"command": "python3", "args": [".agentic-framework/agents/mcp/framework_mcp_server.py"]}`.
- **Path is consumer-relative** (`.agentic-framework/agents/mcp/…`), NOT the framework's own `agents/mcp/…`.
  `fw init`/`upgrade` only ever target consumers; Claude Code launches the server with cwd = consumer root,
  so the relative path resolves. (The framework's OWN `.mcp.json` keeps `agents/mcp/…`, set by T-2268.)
- **Key `fw`** → tools surface as `mcp__fw__*` (L-467: prefix derives from the mcpServers KEY).
- Sites: `init.sh` create template + message; `upgrade.sh` `recommended_servers` + BOTH defaults maps
  (merge-missing path ~L1503, create-new path ~L1525) + the "WOULD CREATE/CREATED" messages.

**Out of scope (separate follow-ons):**
- `mcp` python dep guarantee / graceful-degrade in consumer envs (a missing `mcp` pkg makes only the `fw`
  server fail to start, like a missing `npx` for context7 — does not break wiring).
- OBS-088 (consumer's stale vendored `bin/fw` mis-resolves project root) — orthogonal to `.mcp.json` wiring;
  resolved by `fw upgrade` re-vendoring the fixed `bin/fw` (the T-2389/2390/2391 fixes are already on master).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `fw init` writes a `.mcp.json` whose `mcpServers` includes a `fw` entry =
      `python3 .agentic-framework/agents/mcp/framework_mcp_server.py` (alongside context7/playwright/termlink)
      → `lib/init.sh` template + message; t2460 t5.
- [x] `fw upgrade` adds the `fw` entry to a consumer `.mcp.json` that lacks it (merge-missing path, preserving
      existing servers) AND includes it in the create-new path; `recommended_servers` lists `fw`
      → t2460 t1 (WOULD CREATE incl. fw) + t2 (WOULD ADD names fw) + t6 (source pins). **Real-apply proven:**
      consumer `{context7}` → after `do_upgrade` = `[context7, fw, playwright, termlink]`, fw args =
      `.agentic-framework/agents/mcp/framework_mcp_server.py`, context7 preserved.
- [x] The wired args path is consumer-relative (`.agentic-framework/agents/mcp/framework_mcp_server.py`) and
      resolves to an existing server script under a synthetic `.agentic-framework/` layout → t2460 t3 + t4.
- [x] `tests/unit/upgrade_fresh_machine_simulation.bats` stays green (T-1633 consumer-facing hygiene gate)
      → 3/3 green.
- [x] No regression: existing init/upgrade + mcp tests green; new wiring bats covers init-create, upgrade-create,
      upgrade-merge-missing → t2460 6/6, test_framework_mcp_server 9/9 (server tools/list=22, name-parity),
      fresh-machine 3/3. No unit test pins the old 3-server message/count.

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
#
# FRAMEWORK_ROOT pinned to cwd + PROJECT_ROOT unset for hermeticity (L-490).
out=$(env -u PROJECT_ROOT FRAMEWORK_ROOT="$(pwd)" bats tests/unit/t2460_mcp_fw_wiring.bats 2>&1); echo "$out" | grep -qE "^ok 6 " && ! echo "$out" | grep -q "^not ok"
out=$(env -u PROJECT_ROOT FRAMEWORK_ROOT="$(pwd)" bats tests/unit/upgrade_fresh_machine_simulation.bats 2>&1); echo "$out" | grep -qE "^ok 3 " && ! echo "$out" | grep -q "^not ok"

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

### 2026-06-22T10:06:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2460-slice-1c-wiring-t-2458-fw-initupgrade-ad.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0e01e737
- **Timestamp:** 2026-06-22T10:13:06Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — The wired args path is consumer-relative (`.agentic-framework/agents/mcp/framework_mcp_server.py`) and
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agentic-framework/agents/mcp/framework_mcp_server.py in: The wired args path is consumer-relative (`.agentic-framework/agents/mcp/framework_mcp_server.py`) and`

### 2026-06-22T10:12:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
