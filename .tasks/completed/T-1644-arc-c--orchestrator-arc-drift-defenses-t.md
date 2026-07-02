---
id: T-1644
name: "Arc C — Orchestrator-arc drift defenses (T-1061 follow-up)"
description: >
  Ten absent structural defenses identified by W10 — without them new tools silently
  skip governance, constants drift, frame 0x8 wire format changes, task-type tags
  get typo'd, route-cache schema breaks restore, all undetected. Sequenced E first
  (durable register: open G-061 with five decay vectors), then A+C parallel (MCP-tool
  task_id audit in agents/audit/audit.sh + bundled regression tests: fallback chain,
  route_cache schema, governance frame golden, termlink list --json schema), then
  B/D/F (Watchtower /orchestrator blueprint; termlink spawn task-type tag-prefix validator;
  cross-repo fabric cards for orchestrator/router/fallback/frame). Each follow-up
  is small (≤4h), reversible, binary pass/fail. Source: docs/reports/T-1641-worker-10-defenses.md,
  docs/reports/T-1641-worker-06-directive-evidence.md.

status: work-completed
workflow_type: build
owner: agent
horizon: null
      audit, test]
components: [C-004, agents/audit/orchestrator-mcp-scan.sh, 
      web/blueprints/__init__.py, web/blueprints/orchestrator.py, 
      web/templates/orchestrator.html]
related_tasks: [T-1641, T-1063, T-1064, T-1065, T-1066]
arc_id: orchestrator-rethink
created: 2026-05-01T11:55:00Z
last_update: '2026-06-11T22:23:54Z'
date_finished: 2026-05-01T13:08:53Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 2
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=2 
      (components:substrate-edit); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1644: Arc C — Orchestrator-arc drift defenses (T-1061 follow-up)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Backfilled from delivered components (T-1644 shipped with placeholders, slipped P-010; CTL-012 surfaced it). -->
- [x] G-061 register entry created — five decay vectors documented (W10 sequencing E)
- [x] MCP-tool task_id audit shipped — `agents/audit/orchestrator-mcp-scan.sh` + audit integration (W10 A)
- [x] Bundled regression tests landed: fallback chain, route_cache schema, governance frame 0x8 golden, termlink list --json schema (W10 C, see related_tasks: T-1063/T-1064/T-1065/T-1066)
- [x] Watchtower `/orchestrator` blueprint + template registered (W10 B, T-1647 follow-up)
- [x] Cross-repo fabric cards for orchestrator/router/fallback/frame planted (W10 F, T-1652)

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

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

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

### 2026-05-01T11:55:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1644-arc-c--orchestrator-arc-drift-defenses-t.md
- **Context:** Initial task creation

### 2026-05-01T13:08:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-61d26567
- **Timestamp:** 2026-06-02T14:58:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — MCP-tool task_id audit shipped — `agents/audit/orchestrator-mcp-scan.sh` + audit integration (W10 A)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/audit/orchestrator-mcp-scan.sh in: MCP-tool task_id audit shipped — `agents/audit/orchestrator-mcp-scan.sh` + audit integration (W10 A)`

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `Cross-repo`
### 2026-05-01T13:08:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-05-01T18:58:37Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
