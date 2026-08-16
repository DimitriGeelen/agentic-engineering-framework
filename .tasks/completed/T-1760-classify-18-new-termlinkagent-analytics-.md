---
id: T-1760
name: "classify 18 new termlink_agent_* analytics tools (T-1755 maintenance)"
description: >
  classify 18 new termlink_agent_* analytics tools (T-1755 maintenance)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: ["drift-defense", "termlink-mcp"]
components: [".context/audits/orchestrator-mcp-baseline.yaml"]
related_tasks: ["T-1755", "T-1646"]
arc_id: orchestrator-rethink
created: 2026-05-06T06:03:41Z
last_update: '2026-08-16T22:24:43Z'
date_finished: 2026-05-06T06:07:06Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:58Z'
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
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=3 (body:portability-abstraction); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:43Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 3
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=3 (body:portability-abstraction); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1760: classify 18 new termlink_agent_* analytics tools (T-1755 maintenance)

## Context

`fw audit` flagged `[WARN] Orchestrator-arc MCP scan: drift detected` after T-1755+follow-up landed 136-baseline classification. 18 new `termlink_agent_*` analytics tools surfaced (upstream TermLink shipping rapidly). All have read-shaped names matching T-1755's classification convention (analytics/stats verbs, _summary/_rate/_volume/_depth nouns). Per the established naming-convention rule, classify into `readonly_exempt` and bump baseline 136→154.

## Acceptance Criteria

### Agent
- [x] All 18 tools added to `readonly_exempt:` in `.context/audits/orchestrator-mcp-baseline.yaml`
- [x] `baseline_count: 154` (was 136); `readonly_exempt.count: 108`
- [x] `last_verified: 2026-05-06`
- [x] `bash agents/audit/orchestrator-mcp-scan.sh` reports no `new_unclassified_tools` (status: pass)
- [x] YAML still parses

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

cd /opt/999-Agentic-Engineering-Framework && python3 -c "import yaml; d=yaml.safe_load(open('.context/audits/orchestrator-mcp-baseline.yaml')); assert d['baseline_count']==154, d['baseline_count']; assert str(d['last_verified'])=='2026-05-06', str(d['last_verified'])"
cd /opt/999-Agentic-Engineering-Framework && bash agents/audit/orchestrator-mcp-scan.sh 2>&1 | grep -q "WARN: NEW:" && (echo "FAIL: still flagging new tools"; exit 1) || echo "drift clean"

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

### 2026-05-06 — third batch of upstream TermLink shipments in one day
- **What changed:** T-1755 landed 59 tools (commit 2088d2cff). T-1755 follow-up landed 2 more (4c2afd1d0). T-1760 lands 18 more — same day. Upstream is shipping termlink_agent_* primitives at a noticeable cadence. The pattern is settling: agents/handlers added in batches to /opt/termlink, surfacing here as "new unclassified" until classified.
- **Plan impact:** None for this task (mechanical maintenance). For the arc longer-term: consider a more rapid auto-classification path for naming-convention-clear cases — currently every batch needs a manual edit + commit. T-1755's classification rule could be encoded as a heuristic the scan applies before flagging.
- **Triggered:** No new task filed; logged as observation for future arc planning.

## Recommendation

**Recommendation:** GO

**Rationale:** Mechanical baseline maintenance per the established T-1755 rule. 18 tools, all read-shaped names, classified into `readonly_exempt`. Drift now passes (`status: pass`).

**Evidence:**
- `bash agents/audit/orchestrator-mcp-scan.sh`: was `(warn) NEW: 18 unclassified` → now `(pass)` with `Readonly exempt (baseline): 108`
- Baseline counts updated: 136 → 154 total; readonly 90 → 108
- All 18 tool names match T-1755's read-shape convention (no action verbs)

## Decisions
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

## Updates

### 2026-05-06T06:03:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1760-classify-18-new-termlinkagent-analytics-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-26e2c06a
- **Timestamp:** 2026-06-02T14:59:34Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 11
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && bash agents/audit/orchestrator-mcp-scan.sh 2>&1 | grep -q "WARN: NEW:" && (echo "FAIL: still flagging new tools"; exit 1) || echo "drift clean"`
### 2026-05-06T06:07:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
