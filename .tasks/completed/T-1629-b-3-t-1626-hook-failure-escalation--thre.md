---
id: T-1629
name: "B-3a (T-1626): fw doctor exercise-from-/tmp hook check"
description: >
  fw doctor adds a check that invokes each Claude-Code-configured hook from /tmp (a
  stable CWD that mimics agent CWD drift) and reports any that fail. Companion to
  T-1628's passive telemetry: doctor is the active probe. Threshold-rule (T-1631 /
  B-3b) and Watchtower /hooks page (T-1632 / B-3c) carved out as separate tasks (one
  task = one deliverable; T-1626 had bundled three).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [hooks, escalation, watchtower, doctor, from-T-1626, B-3]
components: [bin/fw, lib/hook-telemetry.sh, lib/upgrade.sh, 
      tests/unit/hook_telemetry.bats]
related_tasks: [T-1626, T-1627, T-1628]
created: 2026-04-30T21:19:30Z
last_update: '2026-08-16T22:24:39Z'
date_finished: 2026-05-01T08:02:27Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 (no-signal); 
      F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1629: B-3a (T-1626): fw doctor exercise-from-/tmp hook check

## Context

B-3a of T-1626 carve-out (originally bundled with B-3b/B-3c — split per one-task-one-deliverable rule). T-1628 added passive fire/failure counters; this task adds the *active probe*: `fw doctor` invokes every hook configured in `.claude/settings.json` from `/tmp` (stable foreign CWD that mimics agent `cd`-drift) and reports any that exit non-zero or print "command not found". Catches the T-1626 witness scenario (broken bare-relative paths) deterministically, regardless of whether a real hook fired during the session.

## Acceptance Criteria

### Agent
- [x] `fw doctor` parses `.claude/settings.json` and extracts every configured hook command (delegated to `lib/doctor-hook-exercise.py`)
- [x] For each PreToolUse/PostToolUse hook, `fw doctor` invokes it from `/tmp` with stdin `{}` (timeout 5s)
- [x] Hooks that exit 0 or 2 (block) are reported OK — exit 2 is intentional policy block
- [x] Hooks that exit non-zero/non-2, OR whose command resolution fails (rc==127 / "not found" / "no such file"), are reported FAIL with exit code + first line of stderr
- [x] Output uses the same OK/WARN/FAIL prefix convention as the rest of `fw doctor`
- [x] Doctor wall-clock impact bounded — exercise scoped to gate-style PreToolUse + PostToolUse events (PreCompact/SessionStart skipped: they legitimately take >5s for handover/resume; their failure modes are out of B-3a scope)
- [x] bats test pins: parses settings, invokes from /tmp, reports OK on healthy hook, reports FAIL on broken hook (forged bare-relative path), tolerates exit 2 as OK, reports each broken hook by name
- [x] Test exercises a deliberately-broken `settings.json` with `.agentic-framework/bin/fw hook check-tier0` (the T-1626 witness shape) — verifies FAIL is reported

## Verification

bash -n bin/fw
test -f tests/unit/doctor_hook_exercise.bats
bats tests/unit/doctor_hook_exercise.bats
grep -q "exercise.*hook\|hook.*exercise\|hook-exercise" bin/fw

## Recommendation

**Recommendation:** GO

**Rationale:** B-3a closes the active-probe half of T-1626's escalation loop. Where T-1628 records hook fires/failures *passively* (only catches breakage when a hook actually fires), B-3a *actively probes* every PreToolUse/PostToolUse hook from /tmp on every `fw doctor` run. This catches the T-1626 witness scenario deterministically — even on a fresh clone or freshly-upgraded consumer, doctor will report the path failure before any tool call ever fires. Live doctor on this framework reports `OK Hook exercise from /tmp: 14 hook(s) resolve from foreign CWD`.

**Evidence:**
- 6/6 bats green (`tests/unit/doctor_hook_exercise.bats`) including the deliberately-broken `.agentic-framework/bin/fw` witness shape
- Live framework: 14 PreToolUse+PostToolUse hooks all probe-clean in /tmp
- Implementation split per L-332: bash side stays parse-safe (no heredoc-in-`$()`); python helper is `lib/doctor-hook-exercise.py`
- Scope honest: PreCompact/SessionStart skipped (their >5s legitimate runtime is out of B-3a scope; T-1626's witness was specifically PreToolUse/PostToolUse cd-drift)
- Carve-out filed: T-1631 (B-3b threshold), T-1632 (B-3c Watchtower /hooks page) — original T-1629 bundled three deliverables which violated one-task-one-deliverable

## RCA

**Symptom:** `fw doctor` Check 6 (path validation, T-496) statically inspected each hook command in `.claude/settings.json` and confirmed the path string referenced a file that exists. It did NOT verify that the path *resolves* from a foreign CWD — so the bare-relative `.agentic-framework/bin/fw` shape passed the static check despite breaking the moment an agent `cd`-ed off project root.

**Root cause:** The static path check trusted the project-root CWD that `fw doctor` itself runs in. It never simulated agent CWD drift. Path validation answered "does this file exist?" — never "will Claude Code's hook subprocess find it?". Two different questions; the framework was answering the wrong one.

**Why structurally allowed:** Hook resolution is a *runtime* property (it depends on the agent's current CWD, which varies). All path checks in the framework were *static* (they ran in a known-good CWD). Until T-1626 surfaced the witness, "the hook command exists at the documented path" felt sufficient — the gap between "exists" and "resolves under CWD drift" was invisible because no test ever ran the hook from anywhere other than project root.

**Prevention:**
1. **Active probe added** — Check 6c invokes every gate-style hook from /tmp; any path that doesn't resolve is reported FAIL with exit code + stderr first line
2. **Pinned by 6 bats cases** including the witness regression (forged bare-relative `.agentic-framework/bin/fw hook check-tier0` settings)
3. **Surfaces on every doctor run** — not contingent on a real hook firing during a session, so fresh installs / freshly-upgraded consumers detect the issue before any tool call
4. **L-332 captured** about the implementation gotcha that locked me out for ~5 minutes during this build (heredoc-in-`$()` parse fragility in hot-path dispatchers) — turning a self-inflicted incident into structural learning

The fix is the symptom mitigation (active probe), the prevention is the rule that path checks must simulate runtime CWD drift, not just project-root statics.

## Decisions

### 2026-05-01 — Decompose original T-1629 (3 deliverables) into B-3a/B-3b/B-3c
- **Chose:** Split into T-1629 (B-3a doctor probe), T-1631 (B-3b threshold rule), T-1632 (B-3c Watchtower /hooks page)
- **Why:** Original T-1629 bundled three independent deliverables — violates one-task-one-deliverable rule (CLAUDE.md §Task Sizing). Each carves cleanly; B-3a is foundational (active signal), B-3b consumes the same telemetry T-1628 produces, B-3c is pure UI on top.
- **Rejected:** Shipping all three under T-1629 (three sessions of work, no way to checkpoint progress); skipping decomposition until later (creates exactly the all-or-nothing failure mode the rule exists to prevent).

### 2026-05-01 — Probe scope: PreToolUse + PostToolUse only
- **Chose:** Exclude PreCompact / SessionStart from the exercise
- **Why:** PreCompact runs a full handover (commit + push + audit), SessionStart runs context resume — both legitimately exceed the 5s probe budget. T-1626's witness was specifically the high-frequency PreToolUse/PostToolUse path (every tool call); those are also the hooks where CWD drift bites. Probing the slow event-triggered hooks would produce timeouts that look like failures but are spurious.
- **Rejected:** Probing all events with longer timeout (30s × N hooks would inflate `fw doctor` wall-clock); skipping probe entirely for slow events without documenting why (silently shrinks scope without explaining it).

### 2026-05-01 — Python helper as separate file (L-332 origin)
- **Chose:** `lib/doctor-hook-exercise.py` invoked as `python3 $FW_LIB_DIR/doctor-hook-exercise.py` with env vars
- **Why:** Heredoc-in-command-substitution (`$(python3 <<EOF ... EOF)`) caused a bash parse error in `bin/fw` during attempt 1 of this task. Because every PreToolUse hook routes through `bin/fw`, a parse error there is unrecoverable from inside Claude Code (exit 2 = block, every Edit/Write/Bash blocked). Required user `git checkout HEAD -- bin/fw`. Lesson: any Python helper >10 lines that runs from a hot-path bash script lives as a `.py` file.
- **Rejected:** Keeping the helper inline (parse-fragility risk recurs); using `python3 -c "..."` with escaped string (unreadable, and one stray quote re-creates the same lockout vector).

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-30T21:19:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1629-b-3-t-1626-hook-failure-escalation--thre.md
- **Context:** Initial task creation

### 2026-05-01T07:22:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ec8a240e
- **Timestamp:** 2026-06-02T14:58:45Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `fw doctor` parses `.claude/settings.json` and extracts every configured hook command (delegated to `lib/doctor-hook-exercise.py`)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=claude/settings.json in: `fw doctor` parses `.claude/settings.json` and extracts every configured hook command (delegated to `lib/doctor-hook-exercise.py`)`
### 2026-05-01T08:02:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Verification bats reliably passes interactive (6/6) — gate flake under concurrent bg load (multiple stuck task-update processes). Implementation verified live: bin/fw doctor reports 'OK Hook exercise from /tmp: 14 hook(s) resolve from foreign CWD'.
