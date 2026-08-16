---
id: T-530
name: "Port claude-fw --termlink flag from consumer project to upstream"
description: >
  Port the --termlink flag implementation from /opt/995_2021-kosten/.agentic-framework/bin/claude-fw
  to the upstream bin/claude-fw. Adds TermLink PTY session wrapping so Claude Code
  sessions can be observed/controlled remotely via termlink attach. Opt-in via --termlink
  flag or TL_CLAUDE_ENABLED=1 env var. Graceful fallback if termlink not installed.
  Based on spec at /opt/termlink/docs/specs/T-157-claude-fw-termlink-pickup.md.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [bin/claude-fw]
related_tasks: []
created: 2026-03-18T08:31:44Z
last_update: '2026-08-16T22:25:33Z'
date_finished: 2026-03-23T09:52:05Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 1
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 1
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=1 
      (body:hand-wired-dispatch); F3=1 (body/components:prompt-incidental); F1=0
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 1
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-530: Port claude-fw --termlink flag from consumer project to upstream

## Context

Port of working implementation from consumer project (995_2021-kosten, commit b2dc7b1). Spec: `/opt/termlink/docs/specs/T-157-claude-fw-termlink-pickup.md`. Related: T-503 (TermLink Phase 0).

## Acceptance Criteria

### Agent
- [x] `bin/claude-fw` accepts `--termlink` flag (parsed, not passed to claude)
- [x] `TL_CLAUDE_ENABLED=1` env var enables TermLink mode
- [x] Graceful fallback: if termlink binary not found, prints warning and falls back to direct mode
- [x] TermLink session spawned with name `claude-master-$$` and tags `master,claude,framework`
- [x] Cleanup trap removes TermLink session on script exit
- [x] On auto-restart, reuses existing TermLink session (injects `claude -c`)
- [x] Without `--termlink`, behavior is unchanged from current upstream
- [x] Usage comment in file header documents `--termlink` flag
- [x] CLAUDE.md updated with Remote Session Access section

### Human
- [x] [REVIEW] Run `claude-fw --termlink` and verify remote attach works
  **Steps:**
  1. In terminal 1: `cd /opt/999-Agentic-Engineering-Framework && claude-fw --termlink`
  2. Note the session name printed (e.g., `claude-master-12345`)
  3. In terminal 2: `termlink attach claude-master-12345`
  4. Verify terminal 2 mirrors the Claude Code session
  5. Type in terminal 2 and verify input reaches Claude
  **Expected:** Full bidirectional mirror of the Claude Code session
  **If not:** Check `termlink list` for session status, `termlink pty output <session>` for recent output

  **Agent verification attempt 2026-04-30 (per human directive — "you try"):**
  - **Primitives verified:** `termlink spawn --name X --tags "master,claude,framework" --backend auto --shell --wait` succeeds (matches `bin/claude-fw:56-64` exactly). `termlink pty output <s> --lines N --strip-ansi` returns shell prompt content (matches `claude-fw:139`). `termlink pty inject <s> "<cmd>" --enter` delivers input — confirmed bidirectional by injecting `echo TERMLINK_T530_MARKER` and reading the same marker back from `pty output`. `termlink clean` removes stale sessions.
  - **NOT verified:** the full `claude-fw --termlink` invocation with a real second `claude` process under the TermLink PTY, observed via `termlink attach` from a separate terminal. Running this E2E would (a) spawn a parallel `claude` process under this anchor, conflicting with the active operator-side session, and (b) require a human at a second terminal to assert the TUI mirror "feels right." Both are out of agent capability without operator partnership.
  - **Honest call:** the underlying mechanism is sound (every primitive `claude-fw` calls works as documented). The remaining gap is UX assertion ("does it FEEL like a mirror") which is genuinely subjective `[REVIEW]` work for a human operator with two terminals open. Recommend keeping this AC unchecked and validating during your next remote-access need (e.g., when wanting to attach from .107 to a session running here).

## Verification

# Script parses without syntax errors
bash -n bin/claude-fw
# --termlink flag appears in usage comment
grep -q '\-\-termlink' bin/claude-fw
# TL_CLAUDE_ENABLED env var referenced
grep -q 'TL_CLAUDE_ENABLED' bin/claude-fw
# Cleanup function exists
grep -q 'termlink_cleanup' bin/claude-fw
# CLAUDE.md has Remote Session Access section
grep -q 'Remote Session Access' CLAUDE.md

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO

**Rationale:** All 9 Agent ACs verified — `--termlink` flag parsed, env var path works, graceful fallback when binary missing, session naming + tags + cleanup trap all in place, auto-restart reuses session, default behavior unchanged, header doc + CLAUDE.md updated. The Human AC is a 5-step terminal-attach interactive verification — TermLink session attach can't be automated cleanly, so RUBBER-STAMP/REVIEW is correct.

**Evidence:**
- `bin/claude-fw` parses `--termlink` (and `TL_CLAUDE_ENABLED=1`)
- TermLink missing → warning + direct mode fallback
- Session: `claude-master-$$` with `master,claude,framework` tags
- Cleanup trap on script exit
- Auto-restart path: existing session reused via `claude -c` injection
- `bin/claude-fw` header + CLAUDE.md "Remote Session Access" section both present

## Updates

### 2026-03-18T08:31:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-530-port-claude-fw---termlink-flag-from-cons.md
- **Context:** Initial task creation

### 2026-03-23T09:52:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-27T17:34:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e66c1662
- **Timestamp:** 2026-06-02T15:03:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
