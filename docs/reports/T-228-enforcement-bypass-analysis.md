# T-228: Enforcement Bypass Analysis

## Purpose
Systematic audit of all framework enforcement mechanisms to identify bypass vectors, assess severity, and propose strengthening measures.

## Enforcement Surface Map

### Layer 1: Claude Code Hooks (settings.json)
| Hook | Event | Matcher | Script | Purpose |
|------|-------|---------|--------|---------|
| Task gate | PreToolUse | Write\|Edit | check-active-task.sh | Block file edits without active task |
| Tier 0 | PreToolUse | Bash | check-tier0.sh | Block destructive commands |
| Budget gate | PreToolUse | Write\|Edit\|Bash | budget-gate.sh | Block at critical context |
| Checkpoint | PostToolUse | * | checkpoint.sh | Warnings + auto-handover |
| Error watchdog | PostToolUse | Bash | error-watchdog.sh | Investigate errors |
| Dispatch guard | PostToolUse | Task\|TaskOutput | check-dispatch.sh | Warn on large sub-agent results |

### Layer 2: Git Hooks (.git/hooks/)
| Hook | Purpose |
|------|---------|
| commit-msg | Require T-XXX reference, inception gate (2 commits), research artifact (C-001) |
| post-commit | Warn on bypass, reset tool counter, handover staleness |
| pre-push | Run audit, block on failures |

### Layer 3: Behavioral Rules (CLAUDE.md)
Agent behavioral rules (task discipline, inception protocol, verification gate, etc.) — enforced by agent compliance, not structurally.

---

## Bypass Vectors Identified

### B-001: `--no-verify` on git commits [SEVERITY: HIGH]
- **What:** `git commit --no-verify` skips ALL git hooks (commit-msg, post-commit)
- **Impact:** Bypasses task reference requirement, inception gate, research artifact enforcement, bypass detection logging, tool counter reset
- **Current mitigation:** post-commit warns and asks to log bypass. But `--no-verify` skips post-commit too!
- **Evidence:** The commit-msg hook itself tells agents about `--no-verify` as an escape: "Emergency bypass: git commit --no-verify"
- **Severity:** HIGH — complete bypass of git-layer enforcement

### B-002: Task gate exempt paths too broad [SEVERITY: MEDIUM]
- **What:** check-active-task.sh exempts `*/.context/*`, `*/.tasks/*`, `*/.claude/*`, `*/.git/*`
- **Impact:** Agent can freely write to any file under these directories without a task
- **Risk scenario:** Agent could write arbitrary content to `.context/` or modify `.claude/settings.json` to disable hooks
- **Current mitigation:** None — by design these are "framework operations"
- **Severity:** MEDIUM — the agent could modify its own enforcement config

### B-003: Tier 0 keyword pre-filter gaps [SEVERITY: MEDIUM]
- **What:** Fast-path grep only checks specific keywords. Commands not matching the pre-filter skip Python entirely
- **Examples that bypass:**
  - `find / -delete` (no `rm` keyword)
  - `> important-file.txt` (truncation via redirect, no keywords)
  - `dd if=/dev/zero of=/dev/sda` (not in pattern list)
  - `chmod -R 000 /` (permission denial via chmod)
  - `mv critical-dir /dev/null` (move to null)
  - `pkill -9 -u root` (kill all user processes)
- **Severity:** MEDIUM — Tier 0 is not comprehensive for all destructive patterns

### B-004: Budget gate stale cache exploitation [SEVERITY: LOW]
- **What:** budget-gate.sh only re-reads transcript every 5th call. Between checks, cached status is used.
- **Impact:** 4 tool calls between checks could be used when status is stale
- **Current mitigation:** Stale critical still blocks (line 104). Status max age 90s.
- **Severity:** LOW — limited window, critical state persists

### B-005: Hook configuration modifiable at runtime [SEVERITY: HIGH]
- **What:** `.claude/settings.json` is under exempt path `.claude/*` in check-active-task.sh
- **Impact:** Agent can Edit `.claude/settings.json` to remove hooks entirely
- **Critical detail:** Hooks snapshot at session start — edits take effect next session
- **Severity:** HIGH — agent could remove its own enforcement for the next session (delayed action)

### B-006: `defaultMode: dontAsk` + broad allowlists [SEVERITY: MEDIUM]
- **What:** User settings allow `Bash(*)`, `Write(*)`, `Edit(*)` with `defaultMode: dontAsk`
- **Impact:** No human approval needed for any tool call. The human never sees a confirmation prompt.
- **Current mitigation:** PreToolUse hooks provide structural enforcement
- **Severity:** MEDIUM — fully dependent on hook layer working correctly

### B-007: Python parse failures fail open [SEVERITY: LOW]
- **What:** All gate scripts have `except: print('')` or `except: pass` patterns. If Python fails, the hook allows the action.
- **Examples:** check-active-task.sh line 32-36, check-tier0.sh line 33-40, budget-gate.sh
- **Impact:** If python3 is unavailable or JSON is malformed, ALL gates pass
- **Severity:** LOW — python3 is always available in this environment

### B-008: No enforcement on Read/Glob/Grep tools [SEVERITY: LOW]
- **What:** PreToolUse only gates Write|Edit and Bash. Read tools are completely ungated.
- **Impact:** Agent can read any file (secrets, credentials, private data) without task context
- **Severity:** LOW — reading is non-destructive, but could leak sensitive data

### B-009: PostToolUse hooks are advisory only [SEVERITY: MEDIUM]
- **What:** PostToolUse hooks (checkpoint, error-watchdog, dispatch-guard) exit 0 always — they cannot block
- **Impact:** Error watchdog warns but cannot prevent agent from ignoring errors. Dispatch guard warns about large results but cannot prevent context floods.
- **Severity:** MEDIUM — advisory-only means enforcement depends on agent compliance

### B-010: Pre-push audit can be bypassed [SEVERITY: LOW]
- **What:** `git push --no-verify` skips pre-push hook entirely
- **Impact:** Code can be pushed without passing audit
- **Current mitigation:** Remote CI/CD (if any) would catch — but this framework has no remote enforcement
- **Severity:** LOW — push is a human-supervised action

### B-011: inception gate counts existing commits but not staged [SEVERITY: LOW]
- **What:** commit-msg hook counts `git log --grep="$TASK_REF"` for inception limit. But amend commits would not increase count.
- **Impact:** `git commit --amend` could be used to bypass the 2-commit inception limit
- **Severity:** LOW — amend is a Tier 0 candidate anyway (though not currently detected)

### B-012: Agent can invoke tools not covered by hooks [SEVERITY: MEDIUM]
- **What:** Tools like WebFetch, WebSearch, NotebookEdit, MCP tools have NO PreToolUse hooks
- **Impact:** Agent could interact with external services, create notebooks, use MCP without task context
- **Severity:** MEDIUM — depends on which MCP servers are configured

### B-013: Heredoc/quote stripping in Tier 0 may have edge cases [SEVERITY: LOW]
- **What:** check-tier0.sh strips heredocs and quotes to avoid false positives, but regex-based stripping is inherently fragile
- **Impact:** Crafted commands with nested quotes or unusual heredoc syntax might fool the stripper
- **Severity:** LOW — the agent isn't adversarial by design

---

## Severity Summary

| Severity | Count | Vectors |
|----------|-------|---------|
| HIGH | 2 | B-001, B-005 |
| MEDIUM | 5 | B-002, B-003, B-006, B-009, B-012 |
| LOW | 6 | B-004, B-007, B-008, B-010, B-011, B-013 |

## Proposed Mitigations

### For HIGH severity:

**B-001 (--no-verify bypass):**
1. Add `--no-verify` detection to check-tier0.sh — treat it as a Tier 0 destructive pattern
2. Make the bypass-log.yaml a pre-push check — block push if unlogged bypasses exist
3. Consider: framework wrapper `fw git commit` that strips `--no-verify` unless `fw tier0 approve` was used

**B-005 (hook config modifiable):**
1. Add `.claude/` to Tier 0 detection — any Edit/Write to `.claude/settings.json` requires approval
2. Or: add a specific exempt-path exclusion for settings.json in check-active-task.sh
3. Add integrity check: pre-push hook validates settings.json hasn't been tampered with

### For MEDIUM severity:

**B-003 (Tier 0 pattern gaps):**
- Add patterns: `find.*-delete`, `dd if=`, `chmod.*000`, `mkfs`, `pkill`, `mv.*\/dev\/null`
- Add `>` redirect truncation detection (harder — very common in legitimate use)

**B-009 (PostToolUse advisory only):**
- Promote critical error-watchdog patterns to PreToolUse (detect likely-failing commands before execution)
- This is architecturally limited — PostToolUse sees results, PreToolUse can only see intent

**B-012 (uncovered tools):**
- Extend task gate matcher to `Write|Edit|WebFetch|NotebookEdit` (tools that produce side effects)

## Dialogue Log

(Session just started — to be filled as discussion progresses)
