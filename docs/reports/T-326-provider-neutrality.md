# Provider Neutrality Audit: Agentic Engineering Framework

**Date:** 2026-03-05  
**Scope:** README.md, FRAMEWORK.md, CLAUDE.md, lib/init.sh, .claude/ directory, codebase mentions  
**Status:** DETAILED FINDINGS (5-line summary below, full report in body)

---

## SUMMARY (5 Lines)

1. **Framework IS portable:** Core task/git/handover machinery is pure bash, provider-agnostic. FRAMEWORK.md clearly distinguishes universal rules (everyone follows) from provider integration (CLAUDE.md/Cursor-specific).

2. **Documentation FAILS non-Claude users:** README.md omits Cursor/Copilot entirely, mentions only Claude. New users see "Claude Code integration" and assume Claude-only. FRAMEWORK.md exists but is hidden behind README — hard to discover for non-Claude arrivals.

3. **Init generates provider configs:** `fw init --provider cursor` creates `.cursorrules`, `--provider claude` creates CLAUDE.md (auto-loaded). But Cursor/Copilot users get NO hooks, NO context-aware enforcement — only static rules file.

4. **Enforcement is Claude-only:** Task gate (P-001), tier0 checks, budget monitoring, plan-mode blocking — all via `.claude/settings.json` hooks. Non-Claude agents cannot trigger structural enforcement and will bypass all gates silently.

5. **Non-Claude MVP:** Cursor user can do: (a) follow FRAMEWORK.md manually, (b) run `fw init/audit/handover` CLI, (c) use git hooks for commit validation. Cannot do: dynamic enforcement (task gate blocks writes), context budget protection, inception discipline.

---

## DETAILED FINDINGS

### 1. README Discovery Problem

**Current state:**
- Line 1: "A governance framework for systematizing how AI agents work"
- Line 5: "any file-based, CLI-capable AI agent can follow"
- Lines 80-85: **First mention of provider variants buried in Documentation section**

**Actual text:**
```
- **[FRAMEWORK.md](FRAMEWORK.md)** — Full operating guide (provider-neutral, ...)
- **[CLAUDE.md](CLAUDE.md)** — Claude Code integration + complete reference
```

**Problem for non-Claude users:**
- User reads lines 1-75, assumes framework is Claude-native ("Claude Code integration" in title area)
- FRAMEWORK.md link appears late, after all quickstart examples show `CLAUDE.md`
- Zero guidance on "if you use Cursor, read section X" or "Cursor-specific limitations"
- Install section mentions Python/Git but never mentions "also works with Copilot/Cursor"

**Evidence:** `fw init --provider cursor` exists (has code), but README doesn't document it. User must stumble into `lib/init.sh` to discover `--provider` flag.

---

### 2. FRAMEWORK.md vs CLAUDE.md Split

**FRAMEWORK.md strength:**
- Lines 9-11: **Explicitly addresses multiple providers:**
  ```
  - **Claude Code:** Reads `CLAUDE.md` (auto-loaded)
  - **Cursor/Copilot:** Can read this file directly or create `.cursorrules`
  - **Other LLMs:** Read this file as your operating guide
  ```
- Pages 1-4: Core principle, Authority Model, Task System (all provider-agnostic)
- Pages 4-6: Task lifecycle, Enforcement Tiers — **no mention of hooks/enforcement tech**
- Clear separation: **rules** (all agents) vs **implementation** (per-provider)

**CLAUDE.md extent:**
- 600+ lines of Claude Code-specific integration
- Hooks system (PreToolUse, PostToolUse, SessionStart, PreCompact)
- Skills (/plan, /resume, /explore, etc.)
- Context management (token budget, compaction, auto-restart)
- **Zero acknowledgment this is Claude-specific** — reads as universal law

**The split works** if users land on FRAMEWORK.md first, but:
- Framework homepage (README) leads to CLAUDE.md
- CLAUDE.md has no "if you're not using Claude Code, skip to FRAMEWORK.md" banner
- Non-Claude users hit CLAUDE.md walls and assume framework is broken for them

---

### 3. Init Provider Generation

**What `fw init` creates:**

| Provider | Config File | Contains |
|----------|-------------|----------|
| `claude` (default) | CLAUDE.md | 600-line governance guide (hooks + rules) |
| `cursor` | .cursorrules | ~80 lines: core principle + commands + session protocol |
| `generic` | CLAUDE.md | Same as claude (fallback) |

**lib/init.sh code (lines 268-286):**
```bash
case "$provider" in
    claude)
        generate_claude_md "$target_dir"
        echo "OK  CLAUDE.md"
        generate_claude_code_config "$target_dir"  # ← .claude/settings.json hooks
        ;;
    cursor)
        generate_cursorrules "$target_dir"
        echo "OK  .cursorrules"
        # ← NO hooks generated
        ;;
```

**What's generated:**
- **Claude:** CLAUDE.md + .claude/settings.json (10 hooks) + .claude/commands/ (resume.md, etc.)
- **Cursor:** .cursorrules only (~80 lines), **NO .cursorrules.json or hook equivalent**
- **Generic:** Same as Claude (assumes Claude Code)

**Critical gap for Cursor:**
- Cursor does NOT auto-load hook config. Even if .cursorrules said "run check-active-task.sh before Write", there's no mechanism.
- .cursorrules is **read-only guidance** — Cursor highlights rules violations but doesn't enforce them structurally.
- Users can ignore .cursorrules; enforcement depends on human discipline.

---

### 4. Enforcement Architecture

**Claude Code (`.claude/settings.json` hooks):**
- PreToolUse Write/Edit: `check-active-task.sh` blocks file edits without active task
- PreToolUse Bash: `check-tier0.sh` blocks destructive commands (rm -rf, hard reset, etc.)
- PreToolUse Write/Edit/Bash: `budget-gate.sh` blocks operations when context > 150K tokens
- PostToolUse: `checkpoint.sh`, `error-watchdog.sh`, `check-dispatch.sh` for monitoring
- SessionStart/PreCompact: Context injection/recovery hooks

**Cursor/Copilot/Others:**
- **NO hook system available** (Cursor uses LSP + file watching, not pre-operation gates)
- .cursorrules is a **static text file** — Cursor reads it, highlights violations, no structural enforcement
- Task gate (P-001) cannot trigger: users can Write files, Edit CLAUDE.md, call Bash without active task
- Tier 0 enforcement missing: `fw tier0 approve` won't block destructive commands because no hook can intercept them

**Practical impact:**
```
Claude user (with hooks):        Cursor user (without hooks):
fw work-on "fix bug"     →      fw work-on "fix bug" (CLI works)
  ✓ task created                  ✓ task created
  ✓ focus set                     ✓ focus set

Edit file without task:
  ✓ Blocked by PreToolUse         ✗ Allowed (no hook)
  "Create a task first"           Edit happens silently
```

---

### 5. .claude/ Structure Is Claude Code Only

**Location:** `.claude/` directory (dot-directory, hidden)

**Contents (generated by init.sh):**
- `.claude/settings.json` — 10 PreToolUse/PostToolUse/SessionStart hooks (Claude Code specific)
- `.claude/commands/resume.md` — `/resume` skill (Claude Code specific)
- `.claude/commands/new-project.md` — `/new-project` skill (Claude Code specific)
- `.claude/commands/explore.md` — `/explore` skill (Claude Code specific)

**For Cursor users:**
- .claude/ is ignored (Cursor doesn't read .claude/settings.json)
- Skills (/resume, /explore, etc.) are unavailable in Cursor
- Cursor users must manually run CLI equivalents: `fw resume status`, `fw context focus T-XXX`

**Not documented anywhere:** Cursor setup guide, Copilot setup guide, "if you're using tool X, here's what you can't do"

---

### 6. Minimum Viable Setup by Provider

#### Claude Code (Full Stack)
```bash
fw init . --provider claude
# Creates: CLAUDE.md, .claude/settings.json (10 hooks), .claude/commands/ (5 skills)
# Enforcement: All 4 tiers + context budget + auto-handover
# DX: Pre-tool gates, post-tool watchdog, /resume /explore /plan skills
```
✓ Everything works. Core Principle enforced structurally.

#### Cursor (Partial Stack)
```bash
fw init . --provider cursor
# Creates: .cursorrules (~80 lines of rules)
# Enforcement: Git commit-msg hook only (no Write/Edit/Bash hooks)
# DX: Must manually run fw CLI (fw work-on, fw git commit, fw audit, fw handover)
```
⚠️ Core Principle **NOT** enforced. Users must follow FRAMEWORK.md + .cursorrules voluntarily.

**Checklist for Cursor user:**
- [x] `fw init` creates task system, git hooks, FRAMEWORK.md
- [x] `fw work-on` creates task + sets focus (CLI works)
- [x] `git commit -m "T-XXX: ..."` validated by hook (hook works)
- [x] `fw audit` runs compliance checks (CLI works)
- [x] `fw handover` generates session context (CLI works)
- [ ] Dynamic task gate (Write/Edit blocked without task) — **Not possible without hooks**
- [ ] Context budget protection (auto-handover at 150K tokens) — **Not available**
- [ ] Plan-mode blocker — **Not available**
- [ ] Tier 0 approval gate — **Not available**
- [ ] `/resume`, `/explore`, `/plan` skills — **Not available**

#### GitHub Copilot (Minimal Stack)
- No `.cursorrules` equivalent (uses LSP, not LSP-aware task gates)
- Must use CLI-only: `fw work-on`, `fw git commit`, `fw audit`
- Same checklist as Cursor, minus .cursorrules guidance

#### Other LLMs (Aider, Devin, etc.)
- Not mentioned in codebase
- Would follow Cursor pattern: CLI-only, no hooks

---

### 7. Documentation Clarity Issues

**README.md problems:**
1. Line 41 says "Creates .context/, .tasks/, hooks, CLAUDE.md" — implies CLAUDE.md is universal
2. No mention of `--provider` flag in Quickstart section (lines 35-52)
3. "Cloud Code Integration" in title (line 5) suggests not for others
4. Links to CLAUDE.md before FRAMEWORK.md (line 80)

**FRAMEWORK.md strengths:**
1. Lines 9-11 explicitly name Cursor, Copilot, other LLMs
2. Never mentions hooks or Claude Code-specific features
3. All examples use `fw` CLI (provider-neutral)

**CLAUDE.md problems:**
1. No preamble: "This file is for Claude Code users only. For other providers, see FRAMEWORK.md."
2. Sections on "Instruction Precedence" (line 39), "Skills" (Skills section), "Plan Mode" assume Claude Code is available
3. New user reading CLAUDE.md thinks all rules require hooks to be enforceable

---

### 8. Onboarding Path Analysis

**User flows by provider:**

```
New Cursor User:
  README.md (discovers framework, mentions Claude)
    → "Is this for Cursor?" (confusion)
    → Searches codebase for "cursor" → finds FRAMEWORK.md, lib/init.sh
    → `fw init --provider cursor` (works)
    → Reads .cursorrules (100 lines)
    → Read FRAMEWORK.md for full rules (600 lines)
    → Manual discipline required

New Claude Code User:
  README.md (clear integration)
    → `fw init` (defaults to claude)
    → CLAUDE.md auto-loaded (600 lines, hooks + rules)
    → Pre-tool gates prevent mistakes
    → Structural enforcement out-of-box
```

**Time-to-productivity:**
- Claude: 5 min (init) + automatic discipline from hooks
- Cursor: 5 min (init) + 30 min (reading FRAMEWORK.md + .cursorrules) + ongoing manual discipline

---

### 9. What README SHOULD Say

**Current line 5:**
```
This is not a library. It's a set of structural rules, patterns, and enforcement 
mechanisms that any file-based, CLI-capable AI agent can follow.
```

**Should add:**
```
The framework works with **any** AI agent (Claude Code, Cursor, Copilot, Aider, Devin, 
manual CLI). 

**Claude Code users:** Full structural enforcement via hooks (write gates, context 
budgets, auto-handover). Start with CLAUDE.md.

**Other agents:** CLI-based governance + git hooks (commit validation). Manual discipline 
required. Start with FRAMEWORK.md.
```

---

### 10. Provider-Specific Artifacts

**Files only for Claude Code:**
- `.claude/settings.json` — Hooks (pre/post-tool use)
- `.claude/commands/resume.md` — /resume skill
- `.claude/commands/new-project.md` — /new-project skill
- `.claude/commands/explore.md` — /explore skill
- `.claude/commands/plan.md` — /plan skill
- `.claude/commands/start-work.md` — /start-work skill
- `.claude/commands/deploy-check.md` — /deploy-check skill
- `.claude/commands/rollback.md` — /rollback skill

**Files for all providers:**
- FRAMEWORK.md — Universal rules (everyone reads)
- .cursorrules — Cursor-specific guidance (if `--provider cursor`)
- .framework.yaml — Project config (all providers)
- .tasks/, .context/, .git/hooks/ — Directories (all providers)

**Files framework-side (never copied):**
- `lib/*.sh`, `agents/*/`, `bin/fw` — All stay in framework, executed in-place
- Providers cannot customize; must use `fw` CLI as-is

---

## CONCLUSION

**Provider neutrality claim: PARTIALLY TRUE**

✓ **Universal:** Task system, git hooks, CLI, FRAMEWORK.md rules, handover protocol
✗ **Claude-only:** Structural enforcement (hooks), skills (/resume, /explore, /plan), context budget gating

**Non-Claude viability:** Cursor/Copilot users CAN use the framework but:
1. Must read FRAMEWORK.md + .cursorrules (not auto-loaded)
2. Cannot trigger task gates (no write-before-task prevention)
3. Cannot protect context budget (no auto-handover, no token counting)
4. Cannot use skills (must call CLI instead: `fw resume status` vs `/resume`)
5. Must maintain discipline manually

**Recommendation:** Add Cursor/Copilot section to README with honest assessment: "Works, but enforcement is voluntary. All rules in .cursorrules and FRAMEWORK.md must be self-enforced."

