---
id: T-1681
name: "tl-dispatch run.sh never updates meta.json post-exit — status:running stays
  forever"
description: >
  Discovered in T-1680. agents/termlink/dispatch/run.sh writes exit_code, finished_at,
  result.md and calls record-outcome — but does NOT update meta.json. meta.json is
  written by spawn code with status=running and stays that way forever. fw termlink
  dispatch_status surface is misleading post-exit. Fix: append a meta.json rewrite
  step in run.sh after record-outcome (atomic via mv), or change dispatch_status to
  read exit_code file instead.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [termlink, dispatch, observability]
components: [agents/termlink/termlink.sh]
related_tasks: []
created: 2026-05-02T14:30:23Z
last_update: '2026-08-16T22:24:41Z'
date_finished: 2026-05-02T15:16:47Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:55Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=1 (body/components:prompt-incidental); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=1 (body/components:prompt-incidental); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1681: tl-dispatch run.sh never updates meta.json post-exit — status:running stays forever

## Context

Discovered in T-1680 / T-1682. `tl-dispatch` workers write `exit_code`, `finished_at`, `result.md` and call `record-outcome` after exit — but `meta.json` (created at spawn time with `status: running`) is never rewritten. So `fw termlink dispatch_status` reports `running` forever. Headline mechanic of the orchestrator-rethink arc is unaffected; only the dispatch-status CLI surface is misleading.

Fix: append a `meta.json` rewrite step in `run.sh` (after `record-outcome`) that updates `status` (`done` if exit==0 else `failed`), `exit_code`, and `ended` timestamp. Atomic via tmp+mv. Pinned by unit test.

## Acceptance Criteria

### Agent
- [x] `agents/termlink/termlink.sh` run.sh heredoc updates `$WDIR/meta.json` post-exit using `jq` + atomic mv: status=`done`/`failed`, exit_code=$EXIT_CODE, ended=$finished_at. Skipped silently if `jq` is missing (best-effort, same pattern as `result.md` extraction).
- [x] Existing unit tests pass: `pytest tests/unit/test_route_cache_record.py tests/unit/test_route_cache_resolve.py tests/unit/test_orchestrator_learned_routing.py tests/unit/test_termlink_dispatch_task_type.py -q` (47 tests green pre-patch).
- [x] New regression test pins the meta.json update lines in the heredoc — same pattern as `test_dispatch_run_sh_calls_record_outcome` (greps the heredoc block, asserts the canonical lines exist).
- [x] Live-verified: a real dispatch with a cheap prompt (sufficient timeout) produces a `meta.json` with `status: done` and `exit_code: 0` post-exit, captured as evidence file under the orchestrator-rethink-demo directory.

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

python3 -m pytest tests/unit/test_route_cache_record.py tests/unit/test_route_cache_resolve.py tests/unit/test_orchestrator_learned_routing.py tests/unit/test_termlink_dispatch_task_type.py -q
grep -q "T-1681" agents/termlink/termlink.sh
test -f docs/reports/orchestrator-rethink-demo/meta-T1681-postpatch-evidence.json
python3 -c "import json; d=json.load(open('docs/reports/orchestrator-rethink-demo/meta-T1681-postpatch-evidence.json')); assert d['status']=='done', d; assert d['exit_code']==0, d; assert d.get('ended'), d; print('post-patch meta.json pinned: status=done exit_code=0 ended=' + d['ended'])"

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

### 2026-05-02T14:30:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1681-tl-dispatch-runsh-never-updates-metajson.md
- **Context:** Initial task creation

### 2026-05-02T15:13:55Z — status-update [task-update-agent]
- **Change:** horizon: later → now

### 2026-05-02T15:13:55Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-385e3f8e
- **Timestamp:** 2026-06-02T14:59:06Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `agents/termlink/termlink.sh` run.sh heredoc updates `$WDIR/meta.json` post-exit using `jq` + atomic mv: status=`done`/`failed`, exit_code=$EXIT_CODE, ended=$finished_at. Skipped silently if `jq` is m
  - **AC-verify-mismatch** (narrow, heuristic) — `path=WDIR/meta.json in: `agents/termlink/termlink.sh` run.sh heredoc updates `$WDIR/meta.json` post-exit using `jq` + atomic mv: status=`done`/`failed`, exit_code=$EXIT_CODE,`
### 2026-05-02T15:16:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
