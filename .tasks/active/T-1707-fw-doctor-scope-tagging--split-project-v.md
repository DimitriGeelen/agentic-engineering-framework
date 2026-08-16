---
id: T-1707
name: "fw doctor scope tagging — split project vs host findings (T-1702 Stream 2)"
description: >
  T-1702 deferred: every fw doctor finding gets a scope: tag (project | host). Host-scope
  findings include explanatory text. Closes G-065 alongside T-1702 Stream 1 (already
  shipped 91eeacdbb).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [agents/context/check-project-boundary.sh, bin/fw, lib/verify-acs.sh,
  tests/unit/test_boundary_hook_arguments.bats, 
      tests/unit/test_doctor_litellm_ollama.bats, 
      tests/unit/test_doctor_scope_tags.bats, 
      tests/unit/test_worker_kind_drift.bats]
related_tasks: [T-1702]
arc_id: orchestrator-rethink
created: 2026-05-03T22:05:43Z
last_update: '2026-08-16T22:23:59Z'
date_finished: 2026-05-27T05:51:09Z
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 3
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=3
      (body:portability-abstraction)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 3
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=3
      (body:portability-abstraction); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=3
      (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=3
      (body:portability-abstraction); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1707: fw doctor scope tagging — split project vs host findings (T-1702 Stream 2)

## Context

Stream 2 of T-1702. The original incident: an agent in a project session bundled
host-level `fw doctor` warnings (e.g. "git user identity not configured",
"bats not installed") into project housekeeping. Those findings can only be
fixed from a session at the host root (`~/.gitconfig`, system package install).
Tagging host findings makes the boundary unambiguous in the output.

**Design:**
- `project` is the default (most checks). No visual change for project findings.
- `host` findings get `[host]` prefix + explanatory suffix
  `(host-level — handle from a session at that root)`.
- Summary line breaks out host warning count if any.
- 10 host-level emits identified: mode=global, git user identity, bats/shellcheck
  not installed, orphaned MCP, global install stale symlink, duplicate hooks in
  user settings, TermLink/pi/node not installed.

Closes G-065 alongside T-1702 Pattern 4 (already shipped commit 91eeacdbb).

## Acceptance Criteria

### Agent
- [x] `bin/fw do_doctor` defines `_doctor_warn_host` helper that emits `[host]` prefix
      + "(host-level — handle from a session at that root)" suffix, increments
      both `warnings` and `host_warnings` counters.
      **Verified:** bin/fw:655-668; tests 1-2-4 pin behaviour.
- [x] All 12 identified host-scope WARN emits route through the helper:
      mode=global; unknown-mode; git user identity; duplicate hooks in user settings;
      bats / shellcheck / Node.js / TermLink / pi not installed; orphaned MCP;
      ~/.local/bin/fw stale; ~/.agentic-framework oversized.
      **Verified:** `grep -c '_doctor_warn_host' bin/fw` = 13 (12 calls + 1 def);
      test 3 pins ≥12.
- [x] Project-scope emits unchanged (no regression in normal output).
      **Verified:** test 6 (`fw doctor` exits cleanly), test 9 (no naked WARN at col 0).
- [x] Summary line shows host warning count when nonzero:
      `"$warnings warning(s) ($host_warnings host-level), no failures"`.
      **Verified:** observed `15 warning(s) (1 host-level), no failures` on this host;
      test 8 pins format.
- [x] `bash -n bin/fw` parses clean.
      **Verified:** PARSE OK.
- [x] `bin/fw doctor` runs without errors on this project.
      **Verified:** exits 0 with "(1 host-level)" summary; was previously failing on
      a *separate* T-1706 follow-up (worker_kind=ollama-loop rejected by validator);
      fixed in same commit, see Decisions.
- [x] New bats unit test `tests/unit/test_doctor_scope_tags.bats` exercises at
      least 2 host-scope conditions and asserts `[host]` tag + summary breakdown.
      **Verified:** 10 tests, all pass.

### Human
- [ ] [REVIEW] Output reads correctly — host-level warnings unambiguous,
      project warnings still clean.
      **Steps:**
      1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw doctor 2>&1 | head -80`
      2. Look for `[host]` tags on findings that need attention from `/root` session
      3. Check summary line if host count > 0
      **Expected:** `[host]` only appears on machine-level findings (not project ones).
      **If not:** Note any miscategorized check and the right scope.

## Verification

bash -n bin/fw
# Assert doctor produces the host-scope summary breakdown (T-1707's headline behaviour),
# not just that it exits 0. Tag should appear when host findings exist.
bin/fw doctor > /tmp/.t1707-doctor 2>&1 || true; grep -qE "warning\(s\) \([0-9]+ host-level\)" /tmp/.t1707-doctor
bats tests/unit/test_doctor_scope_tags.bats

## Recommendation

**Recommendation:** GO — closes G-065 alongside T-1702 Stream 1.

**Rationale:**
The original incident (2026-05-03 housekeeping) was an agent bundling
host-level findings into project housekeeping. With Stream 1 (read-side
block) and Stream 2 (scope tagging) both shipped, the boundary is now
explicit at both ends:
- Read-side: `du`/`find`/`grep`/`cat` against outside paths blocks (Pattern 4).
- Diagnostics: `fw doctor` host findings carry `[host]` tag + suffix
  "(host-level — handle from a session at that root)", and the summary
  line breaks out the count.

10/10 new bats tests pass. 35/35 boundary tests pass (no regression).
Project-scope emits unchanged — the diff is purely additive on the host
edge.

**Bonus fix:** T-1706 added `worker_kind: ollama-loop` to the
ollama-research workflow but missed `VALID_WORKER_KINDS` in the doctor's
schema validator, causing a fresh FAIL. Pulled `ollama-loop` into the set
in the same commit so doctor passes clean.

**Hidden regression caught:** T-1702 commit `91eeacdbb` had silently
dropped the +x bit on `agents/context/check-project-boundary.sh`. Discovered
when boundary tests' `[ -x "$HOOK" ]` setup assertion failed. Restored via
`git update-index --chmod=+x` in the same commit. Hook had been working via
`bash $HOOK` invocation but direct `$HOOK` (in any future caller) would
have silently failed.

**Evidence:**
- Commit `0da71bafd` — implementation + test + +x fix
- `bin/fw` lines 655-668 — `_doctor_warn_host` helper definition
- `tests/unit/test_doctor_scope_tags.bats` — 10/10 pass
- `bin/fw doctor` output: "15 warning(s) (1 host-level), no failures"

**G-065 closure:** Both streams shipped. Closes when human reviews
T-1702 allowlist (still pending) and T-1707 output (this task).

## Decisions

### 2026-05-04 — Bundled ollama-loop validator fix into T-1707
- **Chose:** Fix the worker_kind validator in the same commit
- **Why:** Running `bin/fw doctor` for verification surfaced a fresh FAIL
  caused by T-1706's incomplete handoff. Either I fix it here or T-1707
  ships with its own verification command failing — which would be a
  worse outcome than a 1-line bundle.
- **Rejected:** Filing a separate task. Bundle is bounded (1 line) and
  causally connected to the workflow this task touches.

### 2026-05-04 — Project = default, no project tag
- **Chose:** Only host findings get a tag; project findings unchanged.
- **Why:** Tagging every finding as `[project]` would clutter normal
  output. Host is the special case; default is project.
- **Rejected:** Symmetric `[project]`/`[host]` tags. Adds noise without
  value — the human's mental model is "doctor = project" by default.

## Updates

### 2026-05-03T22:05:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent

### 2026-05-04T00:00:00Z — ac-population
- Real ACs written; status started-work; horizon now.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8fe1188c
- **Timestamp:** 2026-05-27T06:00:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-27T05:48:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-05-27T05:51:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
