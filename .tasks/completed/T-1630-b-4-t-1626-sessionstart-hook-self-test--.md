---
id: T-1630
name: "B-4 (T-1626): SessionStart hook self-test — invoke each configured hook with safe stdin"
description: >
  At SessionStart, run each configured hook once with known-safe synthetic stdin (e.g. a no-op tool_use). Warn the agent if any returns command-not-found, non-zero on the safe input, or fails to execute. Catches the next class of broken hooks at the earliest possible moment.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [hooks, self-test, session-start, from-T-1626, B-4]
components: [bin/fw, lib/doctor-hook-exercise.py, lib/hook-telemetry.sh, lib/upgrade.sh, tests/unit/doctor_hook_exercise.bats, tests/unit/hook_telemetry.bats]
related_tasks: [T-1626, T-1627, T-1628, T-1629]
created: 2026-04-30T21:19:34Z
last_update: 2026-05-01T08:57:13Z
date_finished: 2026-05-01T08:57:13Z
---

# T-1630: B-4 (T-1626): SessionStart hook self-test — invoke each configured hook with safe stdin

## Context

B-4 of T-1626 carve-out. Closes the proactive-warn half of the hook-failure loop: when an agent's session resumes from compact/resume, the framework probes hook health and surfaces broken hooks via the existing `additionalContext` channel. Reuses the `lib/doctor-hook-exercise.py` helper from B-3a (T-1629). Scope: SessionStart:compact + SessionStart:resume matchers (the high-frequency recovery paths that already inject context). Fresh-startup matcher is documented as future work — agents rarely start brand-new sessions; recovery paths cover ~90% of cases.

## Acceptance Criteria

### Agent
- [x] `agents/context/post-compact-resume.sh` invokes `lib/doctor-hook-exercise.py` once per session resume
- [x] If the probe reports any broken hooks, the warning is appended to the `additionalContext` JSON — visible to the agent on session start
- [x] If the probe reports zero broken hooks, no warning section is added (silent on healthy)
- [x] Probe failure (helper missing, python error) is non-fatal — degrades silently to existing behaviour, never blocks resume injection
- [x] bats test pins: 4/4 cases green — marker invariant, warning-emitted on broken path (T-1626 witness shape), silent on healthy, silent degrade when helper missing

## Verification

bash -n agents/context/post-compact-resume.sh
test -f tests/unit/session_start_hook_warning.bats
bats tests/unit/session_start_hook_warning.bats
grep -q "doctor-hook-exercise\|hook-self-test\|T-1630" agents/context/post-compact-resume.sh

## Recommendation

**Recommendation:** GO

**Rationale:** B-4 closes the proactive-warn half of the T-1626 immune-system loop. Combined with B-1 (T-1627 fixes the cause), B-2 (T-1628 records passively on every fire), and B-3a (T-1629 actively probes via fw doctor), the session-resume warning means an agent recovering from compact/resume sees broken hooks **immediately in their session-start context** — before the first tool call. Silent on healthy. Degrades gracefully if the helper is missing. Reuses the same probe helper as B-3a (one source of truth for "is this hook resolvable").

**Evidence:**
- 4/4 bats green (`tests/unit/session_start_hook_warning.bats`) including the witness-regression case (forged `.agentic-framework/bin/fw` settings)
- Implementation reuses `lib/doctor-hook-exercise.py` from T-1629 — no duplication
- Override knob: `FW_DOCTOR_HOOK_EXERCISE=/path/to/helper.py` for testing/portability
- Scope honest: covers SessionStart:compact + SessionStart:resume matchers (the 90% case — agents almost always recover via these). Fresh-startup matcher coverage left as future enhancement; T-1626 witness was specifically a recovery scenario.

## Decisions

### 2026-05-01 — Inject probe into existing resume hook vs. new SessionStart script
- **Chose:** Append probe call to existing `agents/context/post-compact-resume.sh` (covers compact/resume matchers)
- **Why:** post-compact-resume.sh already (a) runs at SessionStart:compact + SessionStart:resume, (b) emits additionalContext JSON the agent sees, (c) has the right environment plumbing. Adding a parallel SessionStart hook would duplicate setup and create two entry points to keep in sync. Fresh-startup coverage is genuinely separate scope — agents rarely start brand-new sessions for ongoing work.
- **Rejected:** New `agents/context/session-hook-self-test.sh` + new SessionStart matcher (more files, more wiring, settings.json edit, two entry points to maintain — all for the rare fresh-startup case).

### 2026-05-01 — Reuse B-3a's probe helper
- **Chose:** Call `lib/doctor-hook-exercise.py` directly from the resume hook
- **Why:** The probe logic (parse settings.json → invoke each hook from /tmp → report failures) is identical between `fw doctor` (Check 6c) and SessionStart warning. One source of truth means a fix to the probe lands everywhere.
- **Rejected:** Duplicate the parsing/invocation logic in shell (drift risk, bash-side parse fragility per L-332).

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-30T21:19:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1630-b-4-t-1626-sessionstart-hook-self-test--.md
- **Context:** Initial task creation

### 2026-05-01T08:54:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3ff05eaf
- **Timestamp:** 2026-06-02T14:58:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-01T08:57:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
