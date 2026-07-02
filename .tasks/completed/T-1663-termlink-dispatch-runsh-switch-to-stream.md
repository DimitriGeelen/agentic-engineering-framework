---
id: T-1663
name: "TermLink dispatch run.sh: switch to stream-json + raise default timeout — text-format
  + 30min loses forensic trail on real cross-repo work"
description: >
  TermLink dispatch run.sh: switch to stream-json + raise default timeout — text-format
  + 30min loses forensic trail on real cross-repo work

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/termlink/termlink.sh]
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-01T21:29:18Z
last_update: '2026-06-11T22:23:55Z'
date_finished: 2026-05-01T21:33:01Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:55Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=1 
      (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1663: TermLink dispatch run.sh: switch to stream-json + raise default timeout — text-format + 30min loses forensic trail on real cross-repo work

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `agents/termlink/termlink.sh` worker template invokes `claude -p` with `--output-format stream-json --verbose`, writing to `result.jsonl` not `result.md`.
- [x] After clean exit, `result.md` is populated by extracting `.result` from the final `type=result` event in `result.jsonl` (`jq -r 'select(.type=="result") | .result // empty'`).
- [x] On watchdog timeout, `result.jsonl` retains the partial stream (every line that was written before SIGTERM) — proven by inspecting after kill.
- [x] `fw termlink result <name>` continues to work for clean-exit dispatches (reads `result.md` as before).
- [x] Existing dispatch unit tests still pass (`tests/unit/test_termlink_dispatch_task_type.py`).
- [x] Smoke test: spawn a quick dispatch (`echo "say ok" | claude...` equivalent), verify both `result.jsonl` is non-empty (line-delimited JSON) and `result.md` contains the final text. Verified via `t1663-smoke`: result.jsonl 10.8KB stream, result.md "ok", exit 0.

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
bash -n agents/termlink/termlink.sh
grep -q 'output-format stream-json --verbose' agents/termlink/termlink.sh
grep -q 'result.jsonl' agents/termlink/termlink.sh
python3 -m pytest tests/unit/test_termlink_dispatch_task_type.py -q

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

**Rationale:** Two L-340 incidents on U-005 dispatches showed `--output-format text` buffers everything into result.md until the worker is finished, so a watchdog SIGTERM at timeout leaves zero forensic trail. Switching to `stream-json --verbose` produces line-delimited JSON streamed live to `result.jsonl`; `result.md` is now the post-processed final-text artifact extracted on clean exit (backward-compat with `fw termlink result`). On timeout, result.jsonl retains the partial trail.

Default timeout was NOT raised here despite the task title mentioning it — raising the default for everyone has cross-fleet consequences (workers hold sockets, tmux panes, model-server slots for longer). The cleaner pattern is per-call `--timeout 1800` for known-heavy tasks, captured in L-340.

**Evidence:**
- `t1663-smoke` dispatch: exit 0, result.jsonl 10.8KB streamed events, result.md "ok" extracted via jq, `fw termlink result t1663-smoke` returns "ok".
- 11/11 dispatch unit tests pass.
- `bash -n agents/termlink/termlink.sh` clean.
- Verification block: 4/4 commands pass.

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

### 2026-05-01T21:29:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1663-termlink-dispatch-runsh-switch-to-stream.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2d92dc5f
- **Timestamp:** 2026-06-02T14:58:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-01T21:33:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-05-02T05:17:14Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
