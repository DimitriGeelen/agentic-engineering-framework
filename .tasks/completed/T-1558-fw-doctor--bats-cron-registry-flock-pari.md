---
id: T-1558
name: "fw doctor + bats: cron-registry flock parity check (T-1556 prevention #3 +
  #5)"
description: >
  fw doctor + bats: cron-registry flock parity check (T-1556 prevention #3 + #5)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw, tests/unit/cron_flock_parity.bats]
related_tasks: []
created: 2026-04-27T18:36:53Z
last_update: '2026-06-11T22:23:51Z'
date_finished: 2026-04-27T18:42:22Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1558: fw doctor + bats: cron-registry flock parity check (T-1556 prevention #3 + #5)

## Context

T-1556 RCA listed two pending prevention items:
- #3 — regression test on registry/generated crontab parity for flock count
- #5 — audit doctor flock_count parity check (not just file diff)

The T-1556 regression destroyed all 9 orphan-prevention wrappers in production
between T-1555's `fw cron install` and the T-1556 fix — detection was visual,
not structural. This ships both items as one small build: extend `fw doctor`'s
cron section with a flock count comparison, plus a regression bats.

## Acceptance Criteria

### Agent
- [x] `fw doctor` warns when the registry's `command:` fields show a higher flock count than the deployed crontab (parity violation)
- [x] `fw doctor` is silent (no warning) when registry and deployed crontab have equal flock counts
- [x] New regression bats `tests/unit/cron_flock_parity.bats` pins the count-mismatch detection invariant
- [x] Fail-soft semantics: missing registry → no warning; missing deployed file → existing warning fires unchanged; no new false positives


## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

bats tests/unit/cron_flock_parity.bats
bin/fw doctor > /tmp/.t1558-doctor 2>&1 && grep -E "Cron registry" /tmp/.t1558-doctor > /dev/null && rm -f /tmp/.t1558-doctor

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

### 2026-04-27T18:36:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1558-fw-doctor--bats-cron-registry-flock-pari.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-090cafa2
- **Timestamp:** 2026-06-02T14:58:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -f`
### 2026-04-27T18:42:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
