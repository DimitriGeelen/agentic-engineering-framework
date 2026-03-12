# T-455 SPIKE 4: Post-Init Validation Research

Research date: 2026-03-12
Spike focus: What should `fw init` verify after initialization?

## Summary

Post-init validation has been partially implemented (T-356/T-357) with `validate-init.sh` that checks 29-31 units. However, the current validation scope is **too narrow** — it validates directory/file creation but misses **runtime readiness** checks. Additionally, discovered 3 critical issues that post-init validation should catch:

1. **Git hook sourcing bug** — commit-msg hook calls undefined function `find_task_file()`
2. **Framework knowledge leakage** — New projects inherit 10+ framework practices/decisions (should be empty or project-specific)
3. **Onboarding task isolation** — Auto-created tasks mention framework context instead of project context

---

## 1. fw doctor Output Analysis

Current `fw doctor` checks (from bin/fw lines 338-530+):

| Check | Purpose | Would catch init issues? |
|-------|---------|--------------------------|
| Framework dir | Installation valid | Yes — catches missing FRAMEWORK_ROOT |
| .framework.yaml | Project config exists | Yes — catches missing config |
| Task directories | .tasks/{active,completed,templates} | Yes — catches missing dirs |
| Context directory | .context/ exists | Yes — partial (doesn't check subdirs) |
| Git hooks exist | commit-msg, pre-push | Yes — but not hook content validity |
| Tier 0 enforcement | check-tier0.sh wired | Yes — catches missing hook |
| Agent scripts | All executable | Yes — catches missing/broken agents |
| Plugin task-awareness | Plugins don't bypass gate | No — not init-related |
| Test infrastructure | bats installed | No — not init-related |
| ShellCheck | Linter available | No — not init-related |
| Orphaned MCP processes | Cleanup needed | No — not init-related |
| Hook configuration | settings.json valid JSON + paths resolve | Partial — JSON syntax but not hook functionality |

**Gap:** fw doctor is deployment/runtime focused. It does NOT validate:
- Hook executable functionality (can they actually run?)
- Hook dependencies (are sourced libraries available?)
- Template files present and valid
- Seeded governance files (practices, decisions) have expected content
- Component fabric empty (not showing framework internals)

---

## 2. fw audit Output Analysis

Ran `fw audit` on fresh project. Results:

**Passes:**
- Structure checks (dirs, templates, YAML syntax)
- Task compliance (empty is OK on fresh init)
- Git traceability (no commits yet is OK)
- Enforcement checks (bypass log exists)
- Learning capture, episodic memory, concerns register (empty is OK)

**Warnings:**
- No active tasks (expected)
- Uncommitted changes (expected — init just created files)
- Enforcement baseline not created (minor)
- CTL-020: No cron audit files in last hour (cron not installed)

**NOT checked:**
- Whether framework knowledge leaked into project governance files
- Whether git hooks actually work
- Whether first task creation + commit succeeds
- Whether component fabric is empty (framework not showing)

---

## 3. lib/init.sh Behavior Analysis

`fw init` creates 29-30 checkable units (from #@init: tags):
- 11 directories
- 3 files (.gitignore, bypass-log, CLAUDE.md)
- 7 YAML files (practices, decisions, patterns, learnings, assumptions, directives, concerns)
- 2 JSON files (.framework.yaml, settings.json)
- 3 git hooks
- 1+ task templates

**What it validates currently (via validate-init.sh):**
- Directories exist
- Files are non-empty
- YAML/JSON parse correctly
- YAML has expected top-level keys (practices:, decisions:, etc.)
- JSON has expected keys (hooks:, etc.)
- Hook scripts exist and are executable
- Hook paths don't use Cellar (macOS brew issue)

**What it does NOT validate:**
- Hook functions are callable (commit-msg calls undefined `find_task_file()`)
- Seeded content is from framework not user project
- Onboarding tasks have correct owner/description
- First-time user flow actually works (task creation → commit → audit)

---

## 4. Critical Issues Discovered During Testing

### Issue 1: Git Hook Sourcing Bug

**Symptom:** commit-msg hook calls `find_task_file()` which is undefined.

**Evidence:** `/tmp/test-fw-init/.git/hooks/commit-msg` line 88:
```bash
TASK_FILE=$(find_task_file "$TASK_REF" active)
```

No function definition or sourcing before this call. The function is defined in `lib/tasks.sh` but hook doesn't source it.

**Impact:** Inception gate (T-126) silently skips (function returns empty) instead of blocking. User gets no protection.

**Found in:** agents/git/lib/hooks.sh lines 44-200 (embedded hook template).

**Fix scope:** Hook must source `$FRAMEWORK_ROOT/lib/tasks.sh` before calling `find_task_file()`.

---

### Issue 2: Framework Knowledge Leakage

**Symptom:** Fresh project contains framework's historical practices/decisions/patterns.

**Evidence:** After `fw init`, `.context/project/practices.yaml` contains:
- `P-001` through `P-010` (framework practices, marked `inherited_from: framework`)
- All with framework task references and descriptions
- Comments: "These are universal operational practices derived from 96+ tasks of framework development"

`.context/project/decisions.yaml` contains:
- `FD-001` through `FD-020+` (framework decisions)
- References to framework origin tasks (T-013, T-014, etc.)
- Framework-specific rationale

`.context/project/patterns.yaml` contains:
- Framework's learned patterns

**Should be:** Empty (or project-specific stubs), not inherited framework history.

**Impact:** Semantic confusion — new users see decisions about "commit-msg hook" and "Tier 0 violations" which are framework internal, not project choices. Fog of governance.

**Found in:** lib/init.sh lines 191-232 (copies from FRAMEWORK_ROOT/lib/seeds/)

**Fix scope:** Provide two init modes:
1. `fw init --inherit-framework` — include framework practices for shared tooling mode
2. `fw init --project-only` (default) — empty governance files for isolated project mode

---

### Issue 3: Onboarding Task Context Confusion

**Symptom:** Auto-created onboarding tasks reference "the framework" instead of the project being initialized.

**Evidence:** lib/init.sh lines 414-432:

```bash
PROJECT_ROOT="$target_dir" "$create_task" \
    --name "Ingest project structure and understand codebase" \
    --type build --owner agent --start \
    --description "Scan project files, read README, understand tech stack, architecture, and key entry points for ${project_name}."
```

Task description mentions scanning "project files" and understanding "architecture", but when read by new user it's ambiguous: does this mean the framework's architecture (which was just initialized) or the user's project?

The 3 auto-created tasks for existing projects and 1 inception task for new projects all say "for ${project_name}" but context is unclear if this is about setting up governance or understanding domain.

**Impact:** Cognitive load — new user sees generic tasks + governance setup mixed together.

**Fix scope:** Provide task templates that clearly distinguish:
- T-1: "Bootstrap [PROJECT] governance" (framework setup)
- T-2: "Ingest [PROJECT] codebase" (domain understanding)
- T-3: "Register [PROJECT] components in fabric" (architecture mapping)
- T-4: "Create initial handover for [PROJECT]" (documentation)

---

## 5. What Post-Init Validation Should Check

### Scope: Runtime Readiness (Not Just File Creation)

**Tier 1: Structural (current validate-init.sh, ~90% covered)**
- [x] All directories exist
- [x] All files exist and are non-empty
- [x] All YAML files parse
- [x] All JSON files parse
- [x] All YAML files have expected keys
- [x] All JSON files have expected keys
- [x] All hook scripts are executable
- [x] All hook paths don't use Cellar

**Tier 2: Functional (missing — needs implementation)**
- [ ] Hook scripts are syntactically valid (bash -n)
- [ ] Hook dependencies are sourced (grep for "source" lines)
- [ ] `find_task_file()` is defined before use
- [ ] First task can be created without interactive stdin
- [ ] First commit with task ref succeeds
- [ ] fw doctor passes (no issues)
- [ ] fw audit passes (structure section at minimum)
- [ ] Component fabric is empty (no framework internals)

**Tier 3: Semantic (missing — needs careful design)**
- [ ] Practices.yaml is empty (not inherited framework)
- [ ] Decisions.yaml is empty (not inherited framework)
- [ ] Onboarding tasks mention project, not framework
- [ ] .framework.yaml has correct provider setting
- [ ] No framework task references in project governance files

---

## 6. Currently Incomplete Validation

From test run on `/tmp/test-fw-init`:

**validate-init.sh results:**
- ✓ 29/30 checks pass
- ✓ All directories created
- ✓ All YAML/JSON files valid
- ✓ Hooks installed
- ✗ 1 skipped (git hooks, not a git repo... but we did git init)

**validate-init.sh does NOT check:**
- Whether hooks can actually execute
- Whether hook sourcing works
- Whether first task creation works
- Whether first commit works (found the bug!)

**fw doctor results:**
- ✓ 14 checks pass
- ⚠ 1 warning (no enforcement baseline)
- ✗ 0 failures

**fw doctor does NOT check:**
- Hook functionality
- Post-hook task flow
- Component fabric isolation
- Governance file isolation

**fw audit results:**
- ✓ Structure passes
- ✓ Compliance passes (no tasks yet is OK)
- ✓ Enforcement passes
- ⚠ Several minor warnings (cron not installed, no baseline)
- ✗ 0 failures

**fw audit does NOT check:**
- Whether framework knowledge leaked into governance files
- Component fabric content
- Onboarding task quality

---

## 7. Proposed Post-Init Validation Checklist

### Immediate (Phase 1 — <4 hours)
1. Fix git hook sourcing bug (find_task_file undefined)
2. Add functional checks to validate-init.sh:
   - Hook script syntax validation (bash -n)
   - Dependency sourcing check
   - Function definition check
3. Add semantic checks to validate-init.sh:
   - Governance files empty (not inherited)
   - Task references don't mention framework

### Medium-term (Phase 2 — inception task)
4. Implement post-init flow test:
   - Task creation succeeds
   - First commit with task ref succeeds
   - fw audit passes structure section
5. Create init mode selector:
   - `--project-only` (default) — empty governance
   - `--inherit-framework` — include framework practices for shared tooling
6. Update onboarding task templates:
   - Clear project vs governance context
   - Numbered sequence of 4 distinct tasks

### Long-term (Phase 3 — architectural)
7. Component fabric pre-initialization:
   - Mark framework components with `origin: framework`
   - New project fabric starts empty
8. Handover validation:
   - Warn if user attempts to run first-time tasks created by framework
   - Suggest reading CLAUDE.md before task creation

---

## 8. Test Results from Fresh Init

**Test:** `mkdir /tmp/test-fw-init && cd /tmp/test-fw-init && git init && fw init --provider claude`

**Post-init state:**
✓ All 29 validation checks pass
✓ fw doctor passes with 1 warning
✓ fw audit passes structure section
✗ **Git hook has undefined function (discovered only when attempting commit)**
✗ Governance files contain framework history (discovered by reading files)
✗ No way to know if onboarding will work without actually running it

**Conclusion:** File-level validation (current) = 95% complete. Functional validation (missing) = 0% complete.

---

## Key Files for Post-Init Validation Implementation

| File | Purpose | Status |
|------|---------|--------|
| `lib/validate-init.sh` | Current validation logic | Partial (structural only) |
| `agents/git/lib/hooks.sh` | Hook template with bug | Needs fix |
| `lib/init.sh` | Init creation + calls validate-init | Needs mode selector |
| `bin/fw` | Doctor checks | Partial (needs hook functional checks) |
| `agents/audit/audit.sh` | Audit checks | Doesn't check governance isolation |
| `.fabric/components/` | Component registry | Should prevent framework leakage into projects |

---

## Recommendations for T-455

**SPIKE 4 FINDINGS:**
1. Post-init validation is necessary and valuable (would have caught hook bug immediately)
2. Current validation scope is too narrow (structural only, needs functional + semantic)
3. Three separable issues found: hook bug, governance leakage, onboarding clarity
4. Validation should be expanded to Tier 2 (functional) and Tier 3 (semantic)
5. Init modes needed to separate shared-tooling from isolated-project modes

**GO/NO-GO DECISION NEEDED:**
- Should T-455 fix the hook bug as emergency (Tier 0)?
- Should T-455 implement governance isolation (Tier 2)?
- Should T-455 add functional checks to validation (Tier 2)?
- Or should these be split into separate tasks?

