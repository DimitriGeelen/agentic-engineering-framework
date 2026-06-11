---
id: T-1560
name: "Pipefail-trap sweep follow-up: lib/upgrade.sh + lib/dispatch.sh"
description: >
  Pipefail-trap sweep follow-up: lib/upgrade.sh + lib/dispatch.sh

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-27T18:45:36Z
last_update: '2026-06-11T22:23:51Z'
date_finished: 2026-04-27T18:46:54Z
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

# T-1560: Pipefail-trap sweep follow-up: lib/upgrade.sh + lib/dispatch.sh

## Context

T-1557 fixed the foundation pipefail-trap class in lib/yaml.sh, lib/config.sh, and
lib/inception.sh. Two more bare-assignment sites remain in the same class:

- `lib/upgrade.sh:90` — `removed_list=$(echo "$result" | grep '^REMOVED|' | head -1 | sed ...)`
  Function explicitly guards against empty $removed_list at line 92 — but
  set -e -o pipefail kills the function before reaching line 92 when grep
  finds no match (the legitimate "no duplicates" case).
- `lib/dispatch.sh:147` — `hostname=$(ssh ... | grep "^hostname " | head -1 | awk ...)`
  Inside a `while read host` loop. SSH config Host entries that lack a
  `HostName` directive (aliases) trigger empty grep result; without the
  guard, set -e kills the loop body.

This finishes the sweep started in T-1557. Same recipe (`{ ... || true; } |
head | sed`).

## Acceptance Criteria

### Agent
- [x] lib/upgrade.sh:90 wrapped with `|| true` guard following the T-1557 recipe
- [x] lib/dispatch.sh:147 wrapped with `|| true` guard following the T-1557 recipe
- [x] Existing yaml_pipefail.bats remains green (no regression)
- [x] Smoke run: `bin/fw dispatch hosts` exits cleanly even when ssh config has alias-only entries

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

bats tests/unit/yaml_pipefail.bats
bash -c "set -e -o pipefail; source lib/upgrade.sh 2>/dev/null; echo ok"
bin/fw dispatch hosts > /dev/null 2>&1 && echo ok

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

### 2026-04-27T18:45:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1560-pipefail-trap-sweep-follow-up-libupgrade.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a6e890b1
- **Timestamp:** 2026-06-02T14:58:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T18:46:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
