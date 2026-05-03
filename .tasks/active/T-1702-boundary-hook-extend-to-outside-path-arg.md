---
id: T-1702
name: "Boundary hook: extend to outside-path arguments + scope-tag fw doctor findings"
description: >
  G-065 fix: extend check-project-boundary.sh to detect Bash commands whose arguments resolve to paths outside PROJECT_ROOT (with allowlist for /tmp, /usr, /etc, /root/.local, ~/.claude), and tag fw doctor findings as scope:project vs scope:host. Origin: 2026-05-03 housekeeping session — agent ran du/find/grep against /root/.agentic-framework after the cd was already blocked. Read-side cross-boundary access undetected for as long as the hook has existed.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: [T-559]
created: 2026-05-03T18:22:59Z
last_update: 2026-05-03T18:22:59Z
date_finished: null
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
- [ ] `agents/context/check-project-boundary.sh` blocks Bash commands whose arguments
      resolve to absolute paths outside PROJECT_ROOT (not just `cd`).
      Test: `du /root/x` from PROJECT_ROOT exits non-zero with boundary message.
- [ ] Allowlist exempts: `/tmp/`, `/usr/`, `/etc/`, `/root/.local/`, `$HOME/.claude/`,
      `/var/log/` (read-only system queries + shim + memory + log paths).
      Test: `cat /etc/hosts` and `ls /tmp/` pass through.
- [ ] Hook does not regress on existing in-scope commands.
      Test: `bin/fw doctor`, `git status`, `du -sh .` all run normally.
- [ ] New unit tests in `tests/unit/` cover: outside-path detection, allowlist hits,
      multi-arg commands, quoted paths with spaces.
- [ ] `fw doctor` output includes a `scope:` field per finding (`project` or `host`),
      visible in JSON output (`fw doctor --json` if exists, else plain output).
- [ ] Doctor warning text for host-scope findings includes "(host-level — handle from a
      session at that root)" so it's unambiguous when an agent reads the output.
- [ ] `concerns.yaml` G-065 status updates from `watching` → `closed` with
      `closed_date` set, after both streams ship.

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

# Hook still loads + parses
bash -n agents/context/check-project-boundary.sh
# Existing tests still pass
fw test unit 2>&1 | tail -5
# New boundary tests pass
bats tests/unit/test_boundary_hook_arguments.bats 2>&1 | tail -3 || echo "test file needs to exist"
# Doctor output includes scope tags
bin/fw doctor 2>&1 | grep -qE "scope: (project|host)" || bin/fw doctor 2>&1 | grep -q "host-level"

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
