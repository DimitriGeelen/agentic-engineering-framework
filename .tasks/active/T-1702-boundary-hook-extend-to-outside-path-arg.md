---
id: T-1702
name: "Boundary hook: extend to outside-path arguments + scope-tag fw doctor findings"
description: >
  G-065 fix: extend check-project-boundary.sh to detect Bash commands whose arguments
  resolve to paths outside PROJECT_ROOT (with allowlist for /tmp, /usr, /etc, /root/.local,
  ~/.claude), and tag fw doctor findings as scope:project vs scope:host. Origin: 2026-05-03
  housekeeping session — agent ran du/find/grep against /root/.agentic-framework after
  the cd was already blocked. Read-side cross-boundary access undetected for as long
  as the hook has existed.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-559]
arc_id: orchestrator-rethink
created: 2026-05-03T18:22:59Z
last_update: '2026-05-28T22:54:09Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F1: 1
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine); F1=1 (body/tag hits for 'F1': 1)"
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F1: 1
      F2: 0
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine); F1=1 (body/tag hits for 'F1': 1); F2=0 (no-signal)"
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

# T-1702: Boundary hook: extend to outside-path arguments + scope-tag fw doctor findings

## Context

Resolves G-065. The boundary hook (`agents/context/check-project-boundary.sh`, T-559) currently
matches only `cd <outside-path>`. Commands like `du /root/x`, `find /root/x`,
`grep -r ... /root/x`, `cat /root/x/file` pass through unchecked — read-side
cross-boundary access has been undetected for as long as the hook has existed.

Origin incident: 2026-05-03 housekeeping. Hook blocked `cd /root/.agentic-framework`;
agent switched to absolute-path `du`/`find`/`grep` against the same path. User caught.

Two work streams:
1. **Hook scope expansion** — match outside-path arguments, with allowlist
2. **`fw doctor` scope tagging** — distinguish `scope: project` from `scope: host`
   findings so agents don't bundle host-level warnings into project housekeeping

Related: T-559 (original boundary policy), G-065 (concerns.yaml), `feedback_path_isolation_strict.md` (memory).

## Acceptance Criteria

### Agent
- [x] `agents/context/check-project-boundary.sh` blocks Bash commands whose arguments
      resolve to absolute paths outside PROJECT_ROOT (not just `cd`).
      Test: `du /root/x` from PROJECT_ROOT exits non-zero with boundary message.
      **Verified:** Pattern 4 added; bats tests pass.
- [x] Allowlist exempts: `/tmp/`, `/usr/`, `/etc/`, `/root/.local/`, `$HOME/.claude/`,
      `/var/log/` (read-only system queries + shim + memory + log paths).
      Test: `cat /etc/hosts` and `ls /tmp/` pass through.
      **Verified:** Allowlist also includes `/var/lib`, `/var/run`, `/var/cache`,
      `/proc`, `/sys`, `/dev`, `/bin`, `/sbin`, `/lib`, `/lib64` (system paths
      commonly read by tooling — broader than original AC because reads are
      non-destructive).
- [x] Hook does not regress on existing in-scope commands.
      Test: `bin/fw doctor`, `git status`, `du -sh .` all run normally.
      **Verified:** all 7 existing unit tests pass; `bin/fw doctor` runs cleanly
      under the modified hook.
- [x] New unit tests in `tests/unit/` cover: outside-path detection, allowlist hits,
      multi-arg commands, quoted paths with spaces.
      **Verified:** `tests/unit/test_boundary_hook_arguments.bats` — 28 tests, all pass.
- [ ] `fw doctor` output includes a `scope:` field per finding (`project` or `host`),
      visible in JSON output (`fw doctor --json` if exists, else plain output).
      **DEFERRED to T-1707** — read-side bug fix is more urgent; doctor scoping
      is hygiene that doesn't gate G-065 closure for the read-side stream.
- [ ] Doctor warning text for host-scope findings includes "(host-level — handle from a
      session at that root)" so it's unambiguous when an agent reads the output.
      **DEFERRED to T-1707** — same rationale.
- [ ] `concerns.yaml` G-065 status updates from `watching` → `closed` with
      `closed_date` set, after both streams ship.
      **DEFERRED to T-1707** — closes when doctor scoping ships. Pattern 4
      ships Stream 1; Stream 2 (doctor scope tags) opens as T-1707.

### Human
- [ ] [REVIEW] Allowlist captures the right balance — strict enough to catch
      cross-project violations, permissive enough not to break normal shell hygiene.
      **Steps:**
      1. Review allowlist diff in `agents/context/check-project-boundary.sh`
      2. Try a representative session: editing files, running tests, checking logs
      3. Note any false positives (legitimate command blocked) or false negatives
         (cross-boundary access slipping through)
      **Expected:** No false positives in normal work; cross-project access blocked.
      **If not:** Note specific commands that misbehave; refine allowlist or matcher.

## Verification

bash -n agents/context/check-project-boundary.sh
bats tests/unit/check_project_boundary.bats
bats tests/unit/test_boundary_hook_arguments.bats

## Recommendation

**Recommendation:** GO — ship with caveat: Stream 1 (read-side block) ready for human
review; Stream 2 (doctor scope tags) deferred to T-1707, G-065 stays open until both ship.

**Rationale:**
The original incident that prompted G-065 was the agent running
`du /root/.agentic-framework`, `find /root/x`, `grep -r ... /root/x` after the
`cd` was already blocked. Pattern 4 closes that exact hole:

- 28 new bats tests cover TPs (du/find/grep/cat/ls/cp on outside paths),
  allowlist hits (/tmp, /etc, /usr, /var/log, /var/cache, /proc, /sys,
  /root/.local, /root/.claude, PROJECT_ROOT), multi-arg commands, and FP
  controls (quoted paths, heredoc bodies, regex literals).
- 7 existing bats tests still pass — no regression.
- Heredoc body stripping added so `cat > /tmp/x <<EOF\n/opt/other\nEOF`
  doesn't false-positive on body content.

The doctor scope-tagging stream is sizable (touches ~20+ checks across
do_doctor) and is hygiene rather than urgent bug fix. Splitting follows
"one bug = one task" — Stream 1 is the actual bug fix; Stream 2 is the
diagnostic ergonomics improvement.

**Evidence:**
- `agents/context/check-project-boundary.sh` Pattern 4 + heredoc strip — commit `91eeacdbb`
- `tests/unit/test_boundary_hook_arguments.bats` — 28/28 pass
- `tests/unit/check_project_boundary.bats` — 7/7 still pass (no regression)
- T-1707 filed for Stream 2 (captured, horizon: next, arc:orchestrator-rethink)

**G-065 closure:** stays open. Closes when T-1707 (doctor scope tags) ships.

**Pre-existing test note:** `tests/integration/check_project_boundary.bats`
test 16 "Bash redirect to /etc: blocked" was already failing on master before
this commit — `/etc/cron.d/` is whitelisted in Pattern 3 (T-603/T-1191) but
the test asserts block. Not introduced by this change; logged for separate
fix or test-correction.

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

### 2026-05-03T18:22:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1702-boundary-hook-extend-to-outside-path-arg.md
- **Context:** Initial task creation

### 2026-05-03T19:01:56Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

### 2026-05-03T21:58:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-8ace41f1
- **Timestamp:** 2026-05-13T18:17:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-project`
