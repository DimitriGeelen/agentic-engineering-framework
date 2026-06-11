---
id: T-1695
name: "fw orchestrator improve CLI stub — reserve namespace, exit with v2-pending
  message"
description: >
  Per CONTEXT.md (ADR-0003 v2-readiness): ship a stub 'fw orchestrator improve' that
  exits 0 with 'v2: not yet implemented; data is being captured at .context/dispatches.jsonl
  and .context/dispatch-blobs/'. Reserves the CLI namespace so it can't be claimed
  by an unrelated feature; gives operators visibility into the v2 path. Trivial build
  task — ~15 lines.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [cli]
components: [bin/fw]
related_tasks: [T-1687]
arc_id: orchestrator-rethink
created: 2026-05-02T22:56:20Z
last_update: '2026-06-11T22:23:56Z'
date_finished: 2026-05-03T07:58:18Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1695: fw orchestrator improve CLI stub — reserve namespace, exit with v2-pending message

## Context

Per CONTEXT.md (ADR-0003 v2-readiness): ship `fw orchestrator improve` as a CLI stub that exits 0 with the message "v2: not yet implemented; data is being captured at .context/dispatches.jsonl and .context/dispatch-blobs/". Reserves the namespace so unrelated features can't claim it; gives operators visibility into the v2 self-improvement path. Trivial — ~15 LOC.

## Acceptance Criteria

### Agent
- [x] `bin/fw orchestrator improve` is wired into the fw command router
- [x] Running it exits 0
- [x] Output mentions "v2", "not yet implemented", AND the data paths (`.context/dispatches.jsonl`, `.context/dispatch-blobs/`)
- [x] Appears in `fw orchestrator --help` (or `fw help orchestrator`) output
- [x] Does NOT actually read or analyze any dispatch data (it's a stub)

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
bin/fw orchestrator improve | grep -q "v2"
bin/fw orchestrator improve | grep -q "dispatches.jsonl"
bin/fw orchestrator improve

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

## Recommendation

**Recommendation:** GO

**Rationale:** All five Agent ACs satisfied. Reserves the `fw orchestrator` namespace per ADR-0003 v2-readiness. Pure inline case-statement in `bin/fw` (no new file, no library — matches the "trivial stub" sizing). Operator running it gets a clear pointer at the v1 telemetry paths and the v2 deferral.

**Evidence:**
- `bin/fw orchestrator improve | grep -q "v2"` → ✓
- `bin/fw orchestrator improve | grep -q "dispatches.jsonl"` → ✓
- `bin/fw orchestrator improve` exits 0 → ✓
- `bin/fw orchestrator --help` lists `improve` → ✓
- Stub does no data analysis (just `cat <<EOF`) → ✓ by inspection

## Decisions

## Updates

### 2026-05-02T22:56:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1695-fw-orchestrator-improve-cli-stub--reserv.md
- **Context:** Initial task creation

### 2026-05-03T07:56:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d58dab6b
- **Timestamp:** 2026-06-02T14:59:10Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#3 (Agent)** — Output mentions "v2", "not yet implemented", AND the data paths (`.context/dispatches.jsonl`, `.context/dispatch-blobs/`)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/dispatches.jsonl in: Output mentions "v2", "not yet implemented", AND the data paths (`.context/dispatches.jsonl`, `.context/dispatch-blobs/`)`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 9
     - evidence: `bin/fw orchestrator improve | grep -q "v2"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 10
     - evidence: `bin/fw orchestrator improve | grep -q "dispatches.jsonl"`
### 2026-05-03T07:58:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
