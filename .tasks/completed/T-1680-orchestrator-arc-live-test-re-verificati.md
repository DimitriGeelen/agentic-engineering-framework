---
id: T-1680
name: "orchestrator arc live-test re-verification — 2026-05-02 operator-request"
description: >
  orchestrator arc live-test re-verification — 2026-05-02 operator-request

status: work-completed
workflow_type: test
owner: agent
horizon: null
components: []
related_tasks: [T-1669, T-1678]
created: 2026-05-02T14:28:25Z
last_update: '2026-06-11T22:23:55Z'
date_finished: 2026-05-02T14:30:53Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:55Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-ORCH=1 
      (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1680: orchestrator arc live-test re-verification — 2026-05-02 operator-request

## Context

Operator ("test test test the orchestrator arc") requested live re-verification of the orchestrator-rethink headline mechanic 5h after the original demo (T-1669) and 1.5h after the static "still firing" pin (T-1678). Captures cache-05 + observability gap discovery.

## Acceptance Criteria

### Agent
- [x] Three real `fw termlink dispatch` invocations spawn without `--model`, one per task_type (build/design/inception). Verified: workers `arctest-build-1004230`, `arctest-design-1007117`, `arctest-inception-1007117` spawned 12:41:30Z–12:41:40Z.
- [x] Each worker's `meta.json` shows `resolution_source: route_cache` and the model predicted by `_resolve_dispatch_model_and_fallback`. Verified: build→haiku, design→sonnet, inception→opus.
- [x] All three workers exit 0 with non-empty `result.md`. Verified: exit_code files = 0, results = `build` / `Design workflow loaded...` / `inception`.
- [x] Cache `model_stats` rows for the three (model:task_type) keys grow `successes` by exactly +1 each, with `last_used` timestamps in the dispatch window. Verified: haiku:build 8s/1f→9s/1f, sonnet:design 5s/0f→6s/0f, opus:inception 7s/1f→8s/1f, last_used 12:41:38Z / 12:41:53Z / 12:41:46Z.
- [x] Cache snapshot saved as `docs/reports/orchestrator-rethink-demo/cache-05-2026-05-02-1241Z-live-test.json`.
- [x] `/orchestrator` page re-fetched after worker exits renders updated success rates: `haiku 90% (build)`, `sonnet 100% (design)`, `opus 89% (inception)`. Verified via grep on `/tmp/orch-page-post.html`.
- [x] README §Live-test verification appended with procedure, delta table, and surface-confirmation evidence.
- [x] Observability gap discovered (worker `meta.json` never updated post-exit by `run.sh`) captured as a follow-up task.

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

test -f docs/reports/orchestrator-rethink-demo/cache-05-2026-05-02-1241Z-live-test.json
grep -q "Live-test verification (T-1680" docs/reports/orchestrator-rethink-demo/README.md
python3 -c "import json; d=json.load(open('docs/reports/orchestrator-rethink-demo/cache-05-2026-05-02-1241Z-live-test.json')); ms=d['model_stats']; assert ms['haiku:build']['successes']==9, ms['haiku:build']; assert ms['sonnet:design']['successes']==6, ms['sonnet:design']; assert ms['opus:inception']['successes']==8, ms['opus:inception']; print('cache-05 success counts pinned: 9/6/8')"

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

### 2026-05-02T14:28:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1680-orchestrator-arc-live-test-re-verificati.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9e8017a2
- **Timestamp:** 2026-06-02T14:59:05Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#6 (Agent)** — `/orchestrator` page re-fetched after worker exits renders updated success rates: `haiku 90% (build)`, `sonnet 100% (design)`, `opus 89% (inception)`. Verified via grep on `/tmp/orch-page-post.html`.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tmp/orch-page-post.html in: `/orchestrator` page re-fetched after worker exits renders updated success rates: `haiku 90% (build)`, `sonnet 100% (design)`, `opus 89% (inception)`.`
### 2026-05-02T14:30:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
