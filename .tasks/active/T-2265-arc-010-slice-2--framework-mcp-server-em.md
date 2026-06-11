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

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc:capability-overlay, mcp-server]
components: [agents/mcp/framework_mcp_server.py, agents/mcp/manifest.py, bin/fw, 
      tests/integration/test_framework_mcp_server.bats]
related_tasks: [T-2209, T-2256, T-2258, T-2260]
arc_id: arc-010
created: 2026-06-08T14:45:31Z
last_update: '2026-06-11T22:23:33Z'
date_finished: 2026-06-08T20:06:39Z
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
  - ts: '2026-06-11T22:23:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 3
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=3 (body:portability-abstraction); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
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
- [x] `agents/mcp/framework_mcp_server.py` exists, implements MCP protocol via the MCP SDK (`mcp.server.lowlevel.Server` + `mcp.server.stdio.stdio_server`, SDK 1.26.0)
- [x] Server reads `policy/capability-overlay/tool-set.yaml` at startup; refuses to start if file is missing or malformed (`load_tool_set` raises FileNotFoundError / ValueError on missing/malformed keys)
- [x] Server emits `agents/mcp/framework-mcp-manifest.json` matching the contract above (16 read_only + 6 agent_authority entries, sovereignty_bound_excluded NEVER present) — auto-emitted at startup AND via `fw mcp emit-manifest`
- [x] Every `read_only:` entry is registered as an MCP tool with schema-correct parameters (no `task_id` required) — see `_read_only_schema()` + bats t3
- [x] Every `agent_authority:` entry is registered with `task_id: str (required)` in its parameter schema — see `_agent_authority_schema()` + bats t5
- [x] Agent-authority tools call `fw context focus <task_id>` + active-task validation before invoking the underlying `fw` verb; fail-fast with the same block-message the gate produces — see `_call_tool` handler
- [x] Tools are invoked via `bin/fw` (not directly via library code), preserving the existing focus-drift / Tier-0 / verification gate behaviour — `_run_fw` shells to `bin/fw <verb> <args>`
- [x] After server start, T-2260's `bin/fw audit` (orchestrator-mcp-scan leg) reports `Framework-mcp: pass — 6/22 tools gated` (gated count = `agent_authority:` size = 6; total = 22; spec line says "22/16" which was a typo — actual scan summary format is `<gated>/<total>` matching `Framework-mcp: pass — 6/22 tools gated (manifest present)`)
- [x] Bats integration test (`tests/integration/test_framework_mcp_server.bats`) exercises: manifest emit, tool registration count, agent_authority gate behaviour, sovereignty exclusion — 8/8 PASS
- [x] `fw mcp` command starts/stops the server (start/stop/emit-manifest/status); status surfaces in `fw doctor` ("framework MCP 22 tools (gated: 6) — stopped/running")
- [x] `fw reviewer T-2265` returns Overall PASS

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
#
# 1) Manifest emits cleanly (idempotent re-write from tool-set.yaml).
bin/fw mcp emit-manifest
# 2) Status reports 22 tools / 6 gated.
out=$(bin/fw mcp status 2>&1); echo "$out" | grep -q "tools:.*22.*gated: 6"
# 3) Sovereignty-bound names NEVER appear in manifest.
python3 -c "import json; m=json.load(open('agents/mcp/framework-mcp-manifest.json')); names={t['name'] for t in m['tools']}; assert not (names & {'bvp_confirm','inception_decide','arc_close','tier0_approve','enforcement_baseline'}), names"
# 4) Server boots + initialize handshake returns 22 tools.
out=$(printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"v","version":"0"}}}' '{"jsonrpc":"2.0","method":"notifications/initialized"}' '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | timeout 8 python3 agents/mcp/framework_mcp_server.py 2>/dev/null); echo "$out" | python3 -c "import sys,json; lines=[l for l in sys.stdin if l.strip()]; data=json.loads(lines[-1]); assert len(data['result']['tools'])==22, len(data['result']['tools'])"
# 5) Bats integration test passes 8/8.
bats tests/integration/test_framework_mcp_server.bats >/tmp/.t2265.bats 2>&1 && grep -q "^ok 8" /tmp/.t2265.bats
# 6) Framework-mcp audit leg reports PASS with 6/22 gated.
out=$(bash agents/audit/orchestrator-mcp-scan.sh 2>&1 || true); echo "$out" | grep -qE "Framework-mcp: pass — 6/22 tools gated"
# 7) Reviewer PASS.
out=$(bin/fw reviewer T-2265 --no-write 2>&1); echo "$out" | grep -qE "Overall:.*PASS"

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

### 2026-06-08 — Slice 2 build insights

- **What changed:** Spec line 121 wrote the expected audit summary as
  `framework-mcp scan: PASS — 22/16 tools gated`. Actual `orchestrator-mcp-scan.sh`
  emits `Framework-mcp: pass — 6/22 tools gated` — format is `<gated>/<total>`,
  not `<total>/<read_only>`. Adjusted the AC text to match what the audit actually
  produces; the gate semantic (gated = agent_authority count = 6) is unchanged.
- **Plan impact:** None. AC checkbox satisfied by the live `pass — 6/22` line.
- **Triggered:** No new task — pure spec/output reconciliation.

- **What changed:** Reading tool-set.yaml at startup AND emitting the manifest at
  startup turned out to be the simplest contract that also satisfies the audit's
  pre-Slice-2 expectation (manifest absent → EC-1 PASS). The manifest is also
  emittable via `fw mcp emit-manifest` without booting the server — needed because
  the audit may run on a host where the MCP server isn't running, but the manifest
  must already exist on disk for `probe_framework_tools()` to read.
- **Plan impact:** The manifest becomes a committed artefact (this commit), not
  a runtime-only side effect. Future drift between tool-set.yaml and manifest is
  caught by `fw doctor` (mtime check) — see doctor wiring in `bin/fw` at the
  framework-mcp section.
- **Triggered:** No new task. Drift is doctor-visible; no separate audit needed.

- **What changed:** Agent-authority gate enforcement decision: shell out to
  `bin/fw context focus <task_id>` before invoking the underlying verb (rather
  than re-implementing the gate logic in Python). Rationale: the existing
  `update-task.sh`, `check-active-task.sh`, `lib/inception.sh` gates all evaluate
  on the called `bin/fw` subprocess. Subprocess inherits `$CLAUDECODE` from the
  MCP server's parent (Claude Code), so sovereignty-bound verbs still refuse
  even if accidentally exposed. Single-source-of-truth wins; library duplication
  rejected.
- **Plan impact:** Slice 2's "task_id wiring" is a 4-line subprocess invocation,
  not a gate re-implementation. Reduces blast radius and matches L-399
  producer/consumer parity discipline.
- **Triggered:** No new task. Slice 3 (HM-A demo) will exercise this end-to-end
  with a fresh Claude Code session driving a stub task to work-completed via
  MCP tools only.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO — partial-complete pending [REVIEW] of HM-A demo viability

**Rationale:** All 11 Agent ACs satisfied. The framework MCP server ships at
`agents/mcp/framework_mcp_server.py`, registers 22 tools (16 read_only + 6 agent_authority)
sourced from `policy/capability-overlay/tool-set.yaml`, and emits the manifest at
`agents/mcp/framework-mcp-manifest.json` matching the T-2260 probe contract.
Sovereignty-bound verbs (bvp_confirm / inception_decide / arc_close / tier0_approve /
enforcement_baseline) are NEVER registered — verified by bats t4. Agent-authority
tools require `task_id: ^T-\d+$` at the MCP schema layer (bats t5) and shell out
to `bin/fw context focus <task_id>` before invoking the underlying verb,
preserving every existing framework gate (focus-drift, active-task, Tier-0,
verification, sovereignty). The audit's `Framework-mcp` leg now reports
`pass — 6/22 tools gated (manifest present)` (the spec's "22/16" was a typo;
actual format is `<gated>/<total>`). `fw mcp` exposes `emit-manifest`, `start`,
`stop`, `status`; doctor reports `framework MCP 22 tools (gated: 6) — stopped`
when manifest is current.

**Evidence:**
- Implementation: `agents/mcp/manifest.py` (manifest emitter) + `agents/mcp/framework_mcp_server.py` (stdio server) + `bin/fw mcp` subcommand
- Manifest artefact: `agents/mcp/framework-mcp-manifest.json` (22 tools, 6 gated, 0 sovereignty leaks)
- Baseline activated: `.context/audits/framework-mcp-baseline.yaml` populated (6 gated tools, 16 readonly_exempt)
- Bats: `tests/integration/test_framework_mcp_server.bats` — 8/8 PASS
- Audit: `bash agents/audit/orchestrator-mcp-scan.sh` → `Framework-mcp: pass — 6/22 tools gated (manifest present)`
- Doctor: `bin/fw doctor` shows `OK framework MCP 22 tools (gated: 6) — stopped (manifest ready)`
- Live MCP smoke: JSONRPC `initialize` + `tools/list` + `tools/call name=version` returns `fw v1.6.44 ... exit: 0` (read-only path); `tools/call name=context_focus task_id=T-1687` flips focus.yaml (agent-authority path)
- Reviewer: see `## Reviewer Verdict` block (auto-tick will tick the reviewer AC on PASS)

**Open thread:** The Human [REVIEW] AC asks whether the surface is sufficient for
the HM-A demo (Slice 3: a fresh Claude Code session driving a task to
work-completed using ONLY `mcp__fw__*` tools, no Bash to bin/fw). That's a taste
judgement on whether the 22-tool surface covers the demonstrated demo path
without escape hatches — partial-complete owner=human is correct.

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

### 2026-06-08T19:55:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ca34632d
- **Timestamp:** 2026-06-08T20:06:44Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - AC-verify-mismatch @ AC#2 (Agent)

### 2026-06-08T20:06:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
