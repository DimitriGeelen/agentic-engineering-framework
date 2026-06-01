---
id: T-1634
name: "fw upgrade no-args: read upstream URL from .framework.yaml + git-fetch instead of local source"
description: >
  T-1633 child 1/2. Add upstream URL field to .framework.yaml seeded by fw init/vendor. fw upgrade with no args clones upstream to tempdir, uses as source for vendor+sync, bumps version, cleans up. Zero local-path knowledge required. T-1542 guard remains as defensive safety net.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [from-T-1633, upgrade, upstream]
components: [lib/paths.sh, lib/upgrade.sh, tests/unit/lib_paths.bats]
related_tasks: [T-1633, T-1542]
arc_id: project-shape-resilience
created: 2026-05-01T10:30:30Z
last_update: 2026-05-14T14:10:11Z
date_finished: 2026-05-14T14:10:11Z
---

# T-1634: fw upgrade no-args: read upstream URL from .framework.yaml + git-fetch instead of local source

## Context

Reported by penelope, claude-002-cpn, termlink-agent during fw-upgrade-incident-2026-05-14. When a consumer runs `fw upgrade` from inside its project root (no args), the framework currently errors out — it can't find a framework source dir from the consumer perspective. T-1542 added a defensive guard that explains the situation; T-1634 (this task) is the actual fix: when called bare-from-consumer AND `.framework.yaml` has an `upstream_repo:` field, clone the upstream to a tempdir, use it as the upgrade source, then clean up. Closes the loop so the three sibling fixes (T-1822/T-1824/T-1825) can actually reach consumers without manual re-vendor.

## Acceptance Criteria

### Agent
- [x] `lib/upgrade.sh` bare-from-consumer path: clones upstream to `mktemp -d -t fw-upstream-XXXXXX`, traps `EXIT INT TERM HUP` for cleanup, hands off to the temp clone's `bin/fw upgrade $target_dir [args...]`. Replays `--force` and `--dedupe-user-hooks`; does NOT replay `--from-upstream` (already-resolved).
- [x] `lib/init.sh` upstream seeding preserved — line 209-237 untouched; consumer .framework.yaml files continue to get seeded with `upstream_repo:` from the framework's git remote (no behavior change).
- [x] `fw upgrade --from-upstream <url>` explicit flag added: parsed at line 130-133, takes precedence over `.framework.yaml` upstream_repo, used for first-time upgrades / manual override.
- [x] Missing-upstream error message rewritten with 3 remediation paths: (1) add `upstream_repo:` to .framework.yaml, (2) inline `--from-upstream URL`, (3) cd to upstream checkout. Preserves T-1542 guard fields (FRAMEWORK_ROOT, target_dir, Vendored copy:).
- [x] `tests/unit/upgrade_auto_clone.bats` adds 7 tests: --help, flag parsing, no-upstream error message shape, dry-run plan, --from-upstream override, GitHub-shorthand normalisation, live file:// clone with stub upstream.
- [x] Existing tests pass: 23/23 across lib_upgrade.bats (12), upgrade_auto_clone.bats (7), test_upgrade_self_target_guard.bats (4).
- [x] No regression of T-1542 guard: the 4 self-target-guard tests still pass — error path preserves `FRAMEWORK_ROOT:`, `target_dir:`, `Vendored copy:`, `Source and target collapse`, `No changes made.`, and `bin/fw upgrade $target_dir` recommendation.

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

bash -n lib/upgrade.sh
bash -c 'out=$(bin/fw test unit -- tests/unit/upgrade_auto_clone.bats 2>&1); echo "$out" | grep -q "^not ok" && exit 1; [ "$(echo "$out" | grep -c "^ok ")" -eq 7 ]'
bash -c 'out=$(bin/fw test unit -- tests/unit/test_upgrade_self_target_guard.bats 2>&1); echo "$out" | grep -q "^not ok" && exit 1; [ "$(echo "$out" | grep -c "^ok ")" -eq 4 ]'
bash -c 'out=$(bin/fw test unit -- tests/unit/lib_upgrade.bats 2>&1); echo "$out" | grep -q "^not ok" && exit 1; [ "$(echo "$out" | grep -c "^ok ")" -eq 12 ]'
grep -q "from-upstream" lib/upgrade.sh
grep -q "Bare-from-consumer detected — auto-cloning upstream" lib/upgrade.sh

## RCA

<!-- Not bug-class (feature task — adds new code path, no bug to RCA). -->

## Evolution

### 2026-05-14 — substantive fix changed shape: hand-off, not in-process re-source
- **What changed:** Original task spec said "clones upstream and uses as source for vendor+sync". Two possible implementation shapes emerged: (a) in-process — clone, then re-source upstream's lib/upgrade.sh and call do_upgrade with new FRAMEWORK_ROOT; or (b) hand-off — clone, then invoke upstream's `bin/fw upgrade $target_dir [args...]` as a subprocess. Chose (b) because: (i) cleaner process isolation, (ii) the upstream's bin/fw runs with the upstream's CLAUDE.md / hooks / governance, (iii) trap-based cleanup is reliable when the parent shell controls the lifecycle. Hand-off also matches the user mental model — "upgrade me from the upstream" is functionally the same as "go run that upstream's fw on my repo".
- **Plan impact:** No source-as-library coupling. Replay only the flags that affect the upgrade itself (`--force`, `--dedupe-user-hooks`), not `--from-upstream` (already resolved).
- **Triggered:** No new sub-task. The hand-off shape was reached directly during implementation — recorded here so future readers understand why it's not source-and-call.

### 2026-05-14 — file:// URL normalisation bug caught by live-clone test
- **What changed:** First test pass: 6/7. The live-clone test failed because `file://...` URLs were misclassified as GitHub-shorthand and rewritten to `https://github.com/file:///...git`. The URL-protocol regex only allowed `http(s)/ssh/git://`. Added `file` to the recognised prefix set.
- **Plan impact:** None — caught and fixed before commit. But it shows the value of the live-clone test (the 5 mocked tests would have green-lit a bug that would have broken consumers using local-path upstreams, e.g., offline mirrors).
- **Triggered:** None directly, but reinforces a learning candidate: "URL-protocol whitelists in shell are easy to forget non-standard prefixes — prefer a live-clone test over a regex-shape test."

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-01T10:30:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1634-fw-upgrade-no-args-read-upstream-url-fro.md
- **Context:** Initial task creation

### 2026-05-02T10:07:11Z — status-update [task-update-agent]
- **Change:** tags: +arc:project-shape-resilience

### 2026-05-14T14:04:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-0ce5492d
- **Timestamp:** 2026-05-14T14:10:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-14T14:10:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
