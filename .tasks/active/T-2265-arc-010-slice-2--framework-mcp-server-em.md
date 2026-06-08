---
id: T-2265
name: "arc-010 Slice 2 — framework MCP server: emit manifest + register tools from
  tool-set.yaml"
description: >
  arc-010 Slice 2 of 4: ship the framework MCP server process. Reads
  `policy/capability-overlay/tool-set.yaml`, emits the manifest at
  `agents/mcp/framework-mcp-manifest.json` (the file T-2260's
  `probe_framework_tools()` already waits for), and registers an MCP tool
  for every entry in `read_only:` (16) + `agent_authority:` (6). Entries in
  `sovereignty_bound_excluded:` (5) are NEVER registered. Each agent_authority
  tool requires `task_id` in its schema and routes through the framework's
  task-gate / focus / budget enforcement before invoking the underlying
  `fw` verb.

  Anchored by T-2209 (capability-overlay inception, GO).
  Pre-stage spec: docs/reports/T-2256-or-2-scan-extension-draft.md §5.
  Tool-set source-of-truth: policy/capability-overlay/tool-set.yaml (T-2258).
  Drift-scan consumer: agents/audit/orchestrator-mcp-scan.sh (T-2260).
  Downstream: Slice 3 (HM-A demo agent), Slice 4 (Watchtower frontend MCP migration).

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [arc:capability-overlay, mcp-server]
components: [agents-mcp]
related_tasks: [T-2209, T-2256, T-2258, T-2260]
arc_id: arc-010
created: 2026-06-08T14:45:31Z
last_update: 2026-06-08T15:58:46Z
date_finished:
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
  - ts: '2026-06-08T15:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-08T15:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 3
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=3 (body:portability-abstraction); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2265: arc-010 Slice 2 — framework MCP server: emit manifest + register tools from tool-set.yaml

## Context

T-2260 (Slice 1B) wired the audit scan's `probe_framework_tools()` to expect a
manifest at `agents/mcp/framework-mcp-manifest.json`. Pre-Slice-2 the manifest
is absent → scan emits `pass — 0/0 tools gated (manifest absent)` cleanly
(EC-1). Slice 2 produces the manifest by standing up the MCP server process.

**Design references** (read these before starting):
- `docs/reports/T-2256-or-2-scan-extension-draft.md` §5 — wiring options;
  Option B selected (single Python implementation, two baselines).
- `policy/capability-overlay/tool-set.yaml` — three classes:
  - `read_only:` (16 entries) — passive verbs; expose unconditionally
  - `agent_authority:` (6 entries) — state-changing; require `task_id` param,
    gate enforcement (focus/active-task/budget) BEFORE invoking underlying verb
  - `sovereignty_bound_excluded:` (5 entries) — §ACD-gated or `$CLAUDECODE=1`-gated;
    NEVER expose; surfacing requires auth model the framework doesn't have
- `.tasks/completed/T-2209-capability-overlay-arc--mcp-subsystem--c.md` —
  arc inception, §11 IW dispositions, headline-mechanic HM-A.

**Manifest contract** (T-2260 probe expects):
```json
{
  "tools": [
    {"name": "fw_task_list",        "gated": false},
    {"name": "fw_task_update",      "gated": true},
    ...
  ]
}
```
- `name`: stable MCP tool name (snake_case mirror of `fw <verb>`)
- `gated`: true when the tool requires task_id + framework-gate enforcement,
  false for read-only verbs

**Scope fence:**
- IN: MCP server process, manifest emission, 16 read_only + 6 agent_authority
  tool implementations, schema_status field consumption, task_id parameter
  wiring for agent_authority, `mcp__fw__` tool prefix.
- OUT: Slice 3 (HM-A demo), Slice 4 (Watchtower MCP frontend), agents/
  self-vendor drift (T-2264 sibling extension).

## Acceptance Criteria

### Agent
- [ ] `agents/mcp/framework-mcp-server.py` (or equivalent) exists, implements MCP protocol via the MCP SDK
- [ ] Server reads `policy/capability-overlay/tool-set.yaml` at startup; refuses to start if file is missing or malformed
- [ ] Server emits `agents/mcp/framework-mcp-manifest.json` matching the contract above (16 read_only + 6 agent_authority entries, sovereignty_bound_excluded NEVER present)
- [ ] Every `read_only:` entry is registered as an MCP tool with schema-correct parameters (no `task_id` required)
- [ ] Every `agent_authority:` entry is registered with `task_id: str (required)` in its parameter schema
- [ ] Agent-authority tools call `fw context focus <task_id>` + active-task validation before invoking the underlying `fw` verb; fail-fast with the same block-message the gate produces
- [ ] Tools are invoked via `bin/fw` (not directly via library code), preserving the existing focus-drift / Tier-0 / verification gate behaviour
- [ ] After server start, T-2260's `bin/fw audit` (orchestrator-mcp-scan leg) reports `framework-mcp scan: PASS — 22/16 tools gated` (gated count = `agent_authority:` size, not read_only)
- [ ] Bats integration test (`tests/integration/test_framework_mcp_server.bats`) exercises: manifest emit, tool registration count, agent_authority gate behaviour, sovereignty exclusion
- [ ] `fw mcp` (or equivalent) command starts/stops the server; status surfaces in `fw doctor`
- [ ] `fw reviewer T-2265` returns Overall PASS

### Human
- [ ] [REVIEW] HM-A demo viable from this surface
  **Steps:**
  1. Start the framework MCP server.
  2. Spawn a fresh Claude Code session with the `mcp__fw__*` tools registered (per `.mcp.json`).
  3. Hand the agent a stub task and observe whether it can drive that task through to `work-completed` using ONLY `mcp__fw__*` tools (no Bash to `bin/fw`).
  **Expected:** Agent completes the task end-to-end via MCP tools. Auto-tick fires on Agent ACs; close gate runs; episodic generates.
  **If not:** Note the first tool that failed (missing in manifest, wrong schema, gate misroute, focus drift). The failure mode informs Slice 3 (HM-A demo) scope vs Slice 2 follow-on patches.

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

### 2026-06-08T14:45:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2265-arc-010-slice-2--framework-mcp-server-em.md
- **Context:** Initial task creation

### 2026-06-08T14:47:27Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)

### 2026-06-08T15:58:46Z — status-update [task-update-agent]
- **Change:** horizon: later → next
