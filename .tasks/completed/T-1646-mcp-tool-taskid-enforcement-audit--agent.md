---
id: T-1646
name: "MCP-tool task_id enforcement audit — agents/audit/orchestrator-mcp-scan.sh"
description: >
  W10 #1, ranked highest-impact drift defense. Currently 4 of 75 MCP tools enforce
  check_task_governance; the other 71 (incl. mutators inject/run/remote_exec/batch_exec/send/kv_set)
  are ungated. Without a CI lint, every new MCP tool is a fresh chance to forget the
  gate — direct G-011 recurrence vector. Build agents/audit/orchestrator-mcp-scan.sh:
  probes /opt/termlink (via fw termlink interact termlink-agent) for the current MCP-handler
  list in tools.rs; verifies each handler function either calls check_task_governance()
  or is on a justified exempt-list (read-only ping/list/version/etc.); writes baseline
  counts + drift delta to .context/audits/orchestrator-LATEST.yaml; integrate into
  agents/audit/audit.sh as a new section; FAIL on regression (gated handlers count
  drops from baseline).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [from-T-1641, t-1061-followup, drift-defense, audit, termlink]
components: []
related_tasks: [T-1641, T-1644, T-1063]
arc_id: orchestrator-rethink
created: 2026-05-01T12:04:15Z
last_update: '2026-08-16T22:24:39Z'
date_finished: 2026-05-01T12:12:54Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1646: MCP-tool task_id enforcement audit — agents/audit/orchestrator-mcp-scan.sh

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `.context/audits/orchestrator-mcp-baseline.yaml` exists with classification of all 75 MCP tools (4 gated + 29 mutators_ungated + 42 readonly_exempt = 75) and counts verify via `python3 -c "import yaml; d=yaml.safe_load(open('.context/audits/orchestrator-mcp-baseline.yaml')); assert len(d['gated']['tools'])+len(d['mutators_ungated']['tools'])+len(d['readonly_exempt']['tools'])==d['baseline_count']==75"`
- [x] `agents/audit/orchestrator-mcp-scan.sh` exists, executable, exits 0 against the live /opt/termlink baseline (`bash agents/audit/orchestrator-mcp-scan.sh; test $? -eq 0`)
- [x] Audit script writes `.context/audits/orchestrator-LATEST.yaml` with status, counts, and findings (file exists after run, contains `status:` key, contains `gated_current:` key)
- [x] Audit script integrated into `agents/audit/audit.sh` so `bin/fw audit` includes it (grep for `orchestrator-mcp-scan` in `agents/audit/audit.sh`)
- [x] T-1166 deprecation status annotated in baseline for tools migrated to `channel.*` (termlink_broadcast, termlink_inbox_*, etc.) — comment explains they are deprecated-but-present

<!-- All ACs are Agent-verifiable (deterministic shell commands). No Human section. -->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
test -f .context/audits/orchestrator-mcp-baseline.yaml
test -x agents/audit/orchestrator-mcp-scan.sh
python3 -c "import yaml; d=yaml.safe_load(open('.context/audits/orchestrator-mcp-baseline.yaml')); assert len(d['gated']['tools'])+len(d['mutators_ungated']['tools'])+len(d['readonly_exempt']['tools'])==d['baseline_count']==75, 'baseline count mismatch'"
bash agents/audit/orchestrator-mcp-scan.sh
test -f .context/audits/orchestrator-LATEST.yaml
grep -q "status:" .context/audits/orchestrator-LATEST.yaml
grep -q orchestrator-mcp-scan agents/audit/audit.sh

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

### 2026-05-01T12:04:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1646-mcp-tool-taskid-enforcement-audit--agent.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1cedb0bb
- **Timestamp:** 2026-06-02T14:58:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-01T12:12:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** All 5 Agent ACs satisfied; verification gate runs the 7 commands (cluster: baseline exists, script exists+executable, baseline count math holds, audit runs clean, LATEST yaml emitted, status key present, audit.sh integrated). Live audit reports 4/75 gated as the documented baseline.

### 2026-05-01T18:58:37Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
