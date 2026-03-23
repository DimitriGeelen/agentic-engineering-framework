# T-011: Framework Ingestion Learnings

## Context

The Agentic Engineering Framework v1.2.6 was initialized on the OpenClaw evaluation project — a 523K LOC TypeScript monorepo with 2,998 source files, 81 extensions, and 51 skills.

---

## What Worked

### 1. Task Governance (Excellent)

The "nothing gets done without a task" principle worked perfectly. Every edit, commit, and research artifact is traceable to a task ID. The PreToolUse hook blocking Write/Edit without an active task is an effective structural enforcement.

**Evidence:** 14 tasks created, all with T-XXX commit references, full traceability.

### 2. Commit Cadence Enforcement (Good after coaching)

Initial session had only 1 commit for massive work. After supervisor coaching, commit-after-every-task became habitual. The framework's commit-msg hook enforcing T-XXX references works well.

**Learning:** The framework should enforce minimum commit cadence, not just message format. A PostToolUse hook warning after N edits without a commit would catch this structurally.

### 3. Inception Workflow (Excellent)

The inception template (problem statement → exploration plan → scope fence → go/no-go) prevented scope creep on all 6 evaluation tasks. Each stayed focused on one question.

**Evidence:** T-007 through T-012 all followed the template cleanly, each produced a focused research artifact.

### 4. Episodic Memory Generation (Good)

Auto-generation on task completion captures duration, commits, ACs checked. Useful for future reference.

### 5. fw CLI (Good)

`fw work-on`, `fw task update`, `fw inception decide`, `fw fabric register` — all worked as documented. The CLI is the right abstraction level for agent interaction.

---

## What Broke or Struggled

### 1. Fabric Registration at Scale (Critical)

`fw fabric register <dir>` recursively registers ALL files. On OpenClaw this produced 2,734 component cards — useless noise. The pickup prompt said "30-50 key components" but the tool defaulted to bulk registration.

**Root cause:** No size guard on directory registration. No warning when registering >100 files.
**Fix needed:** Add `--max-files N` flag with default 50. Warn when directory scan finds >100 files.

### 2. enrich.py Variable Name Bug (Blocking)

`enrich.py:586` referenced `framework_root` but main() defined `project_root`. NameError blocked all enrichment.

**Root cause:** Variable rename in main() wasn't propagated to the call site.
**Fix applied:** Changed `framework_root` → `project_root` on line 586.

### 3. enrich.py TypeScript Support (Missing)

The enrichment engine only supports `.sh`, `.py`, and `.html` imports. On a TypeScript project, it detected zero edges. All 52 edges had to be added manually.

**Root cause:** enrich.py was built for the framework's own (bash/python) codebase, not consumer projects.
**Fix needed:** Add TypeScript/JavaScript import detection (`import ... from`, `require()`) to the enrichment engine.

### 4. Multiple Tasks Starting Simultaneously (Agent Discipline)

Initial session started 8 tasks simultaneously (T-003 + T-007–T-012 all in `started-work`). The framework doesn't structurally prevent this.

**Root cause:** `fw inception start` auto-sets status to `started-work`. No gate preventing multiple started tasks.
**Fix needed:** Option A: `fw inception start` should set status to `captured`, not `started-work`. Option B: Add a max-started-tasks check.

### 5. Garbage Task Creation (Agent Discipline)

T-013 was created as a placeholder "task name" — useless. No structural prevention.

**Fix needed:** `fw task create` should validate that name is not a template placeholder.

### 6. Handover Committed Under Wrong Task

When generating a handover, it committed under T-012 (the last active inception task) rather than T-005 (the handover task). The handover agent doesn't respect current focus.

**Fix needed:** Handover commits should use a dedicated "handover" tag or use the focused task ID.

### 7. Human-Owned Inception Tasks Block Agent Completion

All inception tasks (T-007–T-012) were created with `owner: human` by default. The agent can do all the research and make the GO decision, but can't complete the task. This creates orphaned tasks that need manual cleanup.

**Root cause:** `fw inception start` defaults to human ownership.
**Fix suggestion:** Add `--owner agent` option, or make the default configurable.

---

## Onboarding Task Assessment

| Task | Helpful? | Notes |
|------|----------|-------|
| T-001: Orientation | Yes | `fw doctor` is a good first step |
| T-002: First commit | Yes | Validates git hooks work |
| T-003: Register components | Partially | The "5-10" AC was too small; pickup prompt said 30-50; needs alignment |
| T-004: Task lifecycle | Yes | Creating a real child task was the right approach |
| T-005: First handover | Yes | Validates session end protocol |
| T-006: Add learning | Yes | Simple but effective |

**Overall:** Onboarding tasks are helpful. T-003 needs clearer guidance on component count for large projects.

---

## CLAUDE.md Merge Assessment

The CLAUDE.md file merges OpenClaw's original project guidelines (lines 1-215) with framework governance (lines 216+). At 1015 lines, it's long but functional. The instruction precedence model (framework > user > skills) works.

**Issue:** Some OpenClaw-specific rules (e.g., "use Bun for TypeScript execution") conflict with framework rules (e.g., "use fw CLI for all operations"). The agent must navigate these contextually.

**Suggestion:** Consider a `FRAMEWORK.md` separate from `CLAUDE.md` to reduce merge confusion.

---

## Summary: Framework Improvement Backlog

| Priority | Issue | Type | Effort |
|----------|-------|------|--------|
| P1 | Add `--max-files` guard to fabric register | Bug prevention | Low |
| P2 | Add TypeScript import detection to enrich.py | Feature gap | Medium |
| P3 | Prevent multiple tasks in started-work | Structural enforcement | Low |
| P4 | Validate task name is not placeholder | Input validation | Trivial |
| P5 | Fix handover commit task attribution | Bug | Low |
| P6 | Add `--owner` option to inception start | UX improvement | Trivial |
| P7 | Add commit cadence warning hook | Structural enforcement | Medium |
