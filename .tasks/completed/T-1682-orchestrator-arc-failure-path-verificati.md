---
id: T-1682
name: "orchestrator arc failure-path verification — induce haiku:build timeout, observe
  cache failure increment + surface shift"
description: >
  orchestrator arc failure-path verification — induce haiku:build timeout, observe
  cache failure increment + surface shift

status: work-completed
workflow_type: test
owner: agent
horizon:
tags: [orchestrator-rethink, verification, termlink, failure-path]
components: []
related_tasks: [T-1669, T-1678, T-1680]
created: 2026-05-02T14:32:04Z
last_update: '2026-06-11T22:23:55Z'
date_finished: 2026-05-02T14:34:11Z
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
---

# T-1682: orchestrator arc failure-path verification — induce haiku:build timeout, observe cache failure increment + surface shift

## Context

T-1680 verified the success-path half of the headline_mechanic (route_cache successes increment, surface rate climbs). This task verifies the failure-path half — induce a watchdog timeout on a haiku:build dispatch, observe `failures` increment and the rendered success rate fall. Closes the "preferences shift as the route_cache learns" half of the §ACD headline_mechanic.

## Acceptance Criteria

### Agent
- [x] Dispatch with `--timeout 3` and a long prompt forces a SIGTERM kill before claude can complete. Verified: `arctest-fail-1507529` exit_code=143, stderr.log contains TIMEOUT marker.
- [x] Worker meta.json shows resolver still picks haiku (highest pre-test rate) — failure-path test must use the same model success-path uses, to prove the cache record-outcome is symmetric. Verified: meta.json shows `model=haiku source=route_cache`.
- [x] Cache `model_stats[haiku:build].failures` increments by exactly 1 (1f → 2f). Verified by direct read.
- [x] Cache `model_stats[haiku:build].last_used` updates to the post-failure timestamp (was 12:41:38Z, now 14:32:30Z). Verified by direct read.
- [x] `/orchestrator` re-fetched renders new haiku-for-build success rate `82%` (was 90%). Verified: `grep -c "82%" /tmp/orch-page-postfail.html` returns 2.
- [x] Cache snapshot saved as `docs/reports/orchestrator-rethink-demo/cache-06-2026-05-02-1432Z-failure-path.json`.
- [x] README.md §Failure-path verification appended with procedure, delta table, surface-confirmation evidence.
- [x] Resolver still picks haiku for build post-failure (no model-swap event needed — failure-path verification is about the cache writing failures correctly, not about displacement). Verified: resolver trace post-test still yields `haiku|true|route_cache` for build.

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

test -f docs/reports/orchestrator-rethink-demo/cache-06-2026-05-02-1432Z-failure-path.json
grep -q "Failure-path verification (T-1682" docs/reports/orchestrator-rethink-demo/README.md
python3 -c "import json; ms=json.load(open('docs/reports/orchestrator-rethink-demo/cache-06-2026-05-02-1432Z-failure-path.json'))['model_stats']; assert ms['haiku:build']['failures']==2, ms['haiku:build']; assert ms['haiku:build']['successes']==9, ms['haiku:build']; print('cache-06 haiku:build pinned: 9s/2f')"
bash -c "source agents/termlink/termlink.sh; out=\$(_resolve_dispatch_model_and_fallback '' 'build'); [ \"\$out\" = 'haiku|true|route_cache' ] && echo 'resolver still picks haiku' || (echo \"unexpected: \$out\"; exit 1)"

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

### 2026-05-02T14:32:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1682-orchestrator-arc-failure-path-verificati.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0a0a0a09
- **Timestamp:** 2026-06-02T14:59:06Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#5 (Agent)** — `/orchestrator` re-fetched renders new haiku-for-build success rate `82%` (was 90%). Verified: `grep -c "82%" /tmp/orch-page-postfail.html` returns 2.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tmp/orch-page-postfail.html in: `/orchestrator` re-fetched renders new haiku-for-build success rate `82%` (was 90%). Verified: `grep -c "82%" /tmp/orch-page-postfail.html` returns 2.`
### 2026-05-02T14:34:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
