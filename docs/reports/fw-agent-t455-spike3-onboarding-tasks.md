# T-455 SPIKE 3: Post-Init Onboarding Tasks — What Should Be Auto-Created?

**Research Date:** 2026-03-12  
**Status:** Complete findings  
**Sources:** lib/init.sh (lines 382-444), T-294 inception report, task templates, create-task.sh

---

## CURRENT STATE: What `fw init` Actually Creates

From `lib/init.sh:382-444`, the framework currently auto-creates **3-4 tasks** based on project type:

### Mode Detection Logic
- **Existing Project** (has code): Detected by presence of `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `pom.xml`, `setup.py` OR presence of `src/`, `lib/`, `app/` directories
- **Greenfield Project** (no code): Everything else

### Mode A: Existing Project (has code)
**Currently creates 3 tasks (lines 412-431):**

1. **T-001: "Ingest project structure and understand codebase"** (build, owner: agent, tags: onboarding)
   - Description: "Scan project files, read README, understand tech stack, architecture, and key entry points"
   - Status: started-work (focus is set)

2. **T-002: "Register key components in fabric"** (build, owner: agent, tags: onboarding)
   - Description: "Use fw fabric register to map key source files and their dependencies"
   - Status: captured
   - Note: Depends on T-001 (conceptually)

3. **T-003: "Create initial project handover"** (build, owner: agent, tags: onboarding)
   - Description: "Document current project state, tech stack, and key decisions in first handover"
   - Status: captured
   - Note: Final task of intro sequence

### Mode B: Greenfield Project (no code)
**Currently creates 1 task (lines 435-441):**

1. **T-001: "Define project goals and architecture"** (inception, owner: human, tags: inception)
   - Description: "Define problem statement, goals, constraints, and initial architecture"
   - Status: started-work (focus is set)
   - Next step: `fw inception decide T-001 go` (per printed message)

---

## ANALYSIS: Gaps and Opportunities

### Gap 1: Mode A Missing Validation Steps
After the 3 tasks, the user has:
- Codebase understanding (T-001 ✓)
- Component fabric registered (T-002 ✓)
- First handover (T-003 ✓)

**What's missing for Mode A:**
- No task to **run `fw doctor` and fix errors** — framework health check
- No task to **run first audit** to establish baseline governance metrics
- No task to **execute first governed commit + handover cycle** to prove the loop works

**Why it matters:** T-294 O-009 finding — audit fails on brand-new projects with 1 FAIL + 9 WARNs (false positives). User has no guidance on what's an error vs. expected for day 1.

### Gap 2: Mode B Lacks Build Sequencing
After inception decision (go/no-go), user has:
- Problem statement (inception ✓)
- Go/no-go decision ✓

**What's missing for Mode B:**
- No guidance on **what build tasks come next** — user sees "now go build" with no structure
- No skeleton project setup (README, basic structure, tech stack)

**Why it matters:** User must create build tasks themselves or guess what "implementation" means.

### Gap 3: Both Modes Skip Framework Orientation
Neither mode creates a task to:
- Understand framework concepts (task system, horizon, acceptance criteria, verification gates)
- Understand when to use which workflow type (build vs. refactor vs. inception)
- Know how to use `fw` CLI (only printed help messages, no interactive learning task)

**Current approach:** Printed help + README (if it exists). T-294 finding: new users hit jargon wall (horizon, inception, episodic memory, healing loop, antifragility).

### Gap 4: Task Batch Creation Not Supported
The `create-task.sh` script can only create **one task at a time** (line 121: `TASK_ID=$(generate_id)`). To auto-create 5 tasks during init, `init.sh` calls the script 5 times (see lines 415-431 for pattern).

**Issue:** Each invocation:
- Regenerates ID by scanning `.tasks/` (O(n) per task, O(n²) for batch)
- Runs validation, template substitution, output
- No batch API

**Implication:** For init to create more tasks, either (a) extract batch-create logic, or (b) accept slower init time.

---

## PROPOSED POST-INIT TASK STRUCTURE

### MODE A: Existing Project (5-7 starter tasks)

**Phase 1: Framework Orientation (1 task)**
- T-004: "Get up to speed on agentic governance framework"
  - Type: inception
  - Owner: human
  - Description: "Understand what task system is, why horizon/verification gates exist, when to use build vs. inception vs. refactor. Read docs/walkthrough/, CLAUDE.md Task System section, watch 2-min YouTube walkthrough (if exists). Document 3 'aha!' moments."
  - Acceptance Criteria (Human):
    - [ ] [RUBBER-STAMP] Watched framework overview (FRAMEWORK.md or video)
    - [ ] [RUBBER-STAMP] Read CLAUDE.md Task System section
    - [ ] [REVIEW] Understand 3+ framework concepts in own words
  - Verification: None (inception)
  - Workflow: This primes the pump before governance kicks in
  - Horizon: now
  - Rationale: If users don't understand the task system, they'll fight it. Inception is safe ground for learning.

**Phase 2: Governance Proof (2 tasks)**
- T-005: "Run fw doctor and fix any critical errors"
  - Type: build
  - Owner: agent
  - Description: "Execute `fw doctor` and remediate any failures. Report findings and actions taken."
  - Acceptance Criteria (Agent):
    - [ ] Ran `fw doctor` and captured output
    - [ ] Fixed all FAIL entries (or documented why unfixable)
    - [ ] Verified fixes with `fw doctor` re-run
  - Verification: 
    ```
    fw doctor
    grep -q "FAIL\|ERROR" .context/audits/latest.txt || true
    ```
  - Horizon: now (immediate validation)

- T-006: "Establish audit baseline and review governance status"
  - Type: build
  - Owner: human
  - Description: "Run `fw audit` to see governance baseline. Review metric output. Understand what 'passing' looks like for this project."
  - Acceptance Criteria (Human):
    - [ ] [RUBBER-STAMP] Run `fw audit` and reviewed output
    - [ ] [REVIEW] Understand what governance metrics mean for this project (commit traceability, task coverage, etc.)
    - [ ] [RUBBER-STAMP] Capture baseline metrics in project notes for future comparison
  - Verification: None (output verification in Human AC)
  - Horizon: now

**Phase 3: Hands-On Cycle (2-3 tasks)**
- T-007: "Make first governed commit under new framework"
  - Type: build
  - Owner: agent OR human (split AC)
  - Description: "Create a small, trivial code change (e.g., update a comment, add a TODO). Commit using `fw git commit -m 'T-007: [description]'`. Verify commit message includes task reference."
  - Acceptance Criteria (Agent):
    - [ ] Made at least one code change (file edit)
    - [ ] Committed via `fw git commit -m "T-007: ..."`
    - [ ] Git log shows commit with task reference
    - [ ] Bypass log is empty (no `--no-verify`)
  - Acceptance Criteria (Human):
    - [ ] [RUBBER-STAMP] Reviewed commit in git log (format looks right)
  - Verification:
    ```
    git log --oneline -1 | grep -q "T-007:"
    ! grep -q "T-007" .context/bypass-log.yaml
    ```
  - Horizon: next (after doctrine task)

- T-008: "Create and update a task through one complete cycle"
  - Type: build
  - Owner: human
  - Description: "Create a real task for a small bugfix or feature. Move it through: captured → started-work → (edit task file) → work-completed. Observe framework behavior at each step."
  - Acceptance Criteria (Human):
    - [ ] [RUBBER-STAMP] Created task using `fw work-on` or `fw task create`
    - [ ] [RUBBER-STAMP] Modified at least one file related to the task
    - [ ] [RUBBER-STAMP] Updated task status to work-completed
    - [ ] [REVIEW] Reviewed framework's behavior at each stage (gates, validations, feedback)
  - Horizon: next

- T-009: "Generate first handover and understand session continuity"
  - Type: build
  - Owner: human
  - Description: "Run `fw handover --commit` to create a session checkpoint. Review the handover document. Understand what it contains and why session continuity matters."
  - Acceptance Criteria (Human):
    - [ ] [RUBBER-STAMP] Generated handover via `fw handover --commit`
    - [ ] [RUBBER-STAMP] Reviewed handover document (`.context/handovers/LATEST.md`)
    - [ ] [REVIEW] Understand 2+ benefits of session continuity (context preservation, state recovery, knowledge capture)
  - Verification:
    ```
    test -f .context/handovers/LATEST.md
    grep -q "Where We Are" .context/handovers/LATEST.md
    ```
  - Horizon: next (final task in intro)

**Task Dependencies (visual):**
```
T-004 (orientation)
  ↓
T-005 (health check)
  ↓
T-006 (baseline audit)
  ↓
T-007 (first commit) ← T-008 (task cycle) ← T-009 (handover)
           ↓                    ↓                    ↓
        [proof of task system working]
```

**Ordering:** T-004 → T-005 → T-006 → then T-007, T-008, T-009 in parallel or sequence based on user preference.

---

### MODE B: Greenfield Project (4-6 tasks)

**Phase 1: Framework Orientation (same as Mode A)**
- T-004: "Get up to speed on agentic governance framework" (inception)

**Phase 2: Go Decision → Build Sequencing (1 task)**
- T-005: "After inception decision: outline first 3-5 build tasks"
  - Type: inception (or build if converted from inception decision)
  - Owner: human
  - Description: "After T-001 GO decision, plan the first major work items. Outline 3-5 build/refactor tasks that will drive initial implementation. Document in task Context."
  - Acceptance Criteria (Human):
    - [ ] [REVIEW] Outlined 3-5 first-phase work items as task stubs
    - [ ] [RUBBER-STAMP] Each task has a clear 1-2 sentence description
    - [ ] [REVIEW] Ordering makes sense (dependencies, critical path)
  - Rationale: Inception leaves user with a decision but no plan. This bridges to build phase.

**Phase 3: Skeleton Setup (1-2 tasks)**
- T-006: "Create project skeleton and initial README"
  - Type: build
  - Owner: agent
  - Description: "Set up basic project structure (src/, tests/, docs/ directories). Create initial README.md with project title, problem statement, and getting-started link."
  - Acceptance Criteria (Agent):
    - [ ] Directory structure exists (src/, tests/, docs/)
    - [ ] README.md created with title, problem statement, and links to CLAUDE.md
    - [ ] Git status shows new files ready to commit
  - Verification:
    ```
    test -d src && test -d tests && test -d docs
    test -f README.md
    grep -q "problem statement\|Problem Statement" README.md
    ```

- T-007: "Set up build/tooling infrastructure"
  - Type: build
  - Owner: human
  - Description: "Based on tech stack decision from inception, set up initial tooling: build tool (make/cargo/npm), test framework, CI config skeleton. Choose what's needed."
  - Acceptance Criteria (Human):
    - [ ] [REVIEW] Chose build tool and justified choice in task notes
    - [ ] [RUBBER-STAMP] Tool is configured and can run at least one test/build command
    - [ ] [RUBBER-STAMP] Config files checked in
  - Horizon: next

**Phase 4: Hands-On Cycle (same as Mode A: T-008, T-009, T-010)**
- (Reuse T-008, T-009, T-010 from Mode A, renumbered to avoid collision)

---

## TECHNICAL FEASIBILITY

### Can `fw init` Create More Tasks?

**Current approach (lines 382-444):**
```bash
if [ "$has_code" = true ]; then
    PROJECT_ROOT="$target_dir" "$create_task" \
        --name "Task 1" \
        --type build --owner agent --start ...
    
    PROJECT_ROOT="$target_dir" "$create_task" \
        --name "Task 2" ...
    
    # Repeat for each task
fi
```

**Issue:** Each call to `create_task` regenerates ID by scanning all existing tasks (O(n) per task creation). For 7 tasks, that's O(7n) total scans.

**Solution:** Either:
1. **Accept slower init** — Most users won't notice 0.5-1s delay for 7 task creations
2. **Extract `generate_id()` function** — Move to lib, call once, cache next ID
3. **Batch API** — Create multiple tasks in one call (more complex)

**Recommendation:** Option 1 (accept slowdown) or Option 2 (cache ID) — both are &lt;1 hour of work. Option 3 is over-engineered for one-time init.

### Interactive Task Creation During Init?

**Current:** `fw init` prints "Next steps:" (lines 449-453) and exits. Tasks are auto-created silently.

**Proposed:** Add `--interactive` flag to `fw init`:
```bash
fw init --provider claude --interactive
```

This would:
1. Run standard init
2. Ask: "Create onboarding tasks now? (Y/n)"
3. If yes: create tasks based on mode
4. Ask: "Start first task? (Y/n)"

**Feasibility:** Easy (10-20 lines of bash). Better UX but optional.

---

## TEMPLATE REQUIREMENTS

### Templates Currently Available
- `.tasks/templates/default.md` ✓ (used for build/refactor/test/decommission)
- `.tasks/templates/inception.md` ✓ (used for inception)

**No changes needed** — existing templates are sufficient.

### Task Content Details

For each proposed task, the **Context section should contain:**
- 1-2 sentence summary
- Link to relevant doc (e.g., "CLAUDE.md § Task System")
- If depends on prior task, reference it

**Example (T-004):**
```markdown
## Context

Framework orientation task. Understand task system, horizons, verification gates, and governance principles before working on real tasks.

See: CLAUDE.md § "Task System" + CLAUDE.md § "Enforcement Tiers"
Related: T-294 (inception that motivated these starter tasks)
```

---

## VERIFICATION REQUIREMENTS (P-011)

### Which Tasks Need Verification Commands?

From CLAUDE.md § Verification Gate:
- Verification section contains shell commands that MUST pass before task completion
- Used to verify code compiles, tests pass, files parse, endpoints respond
- For documentation/learning tasks: verification often not needed

**Recommendation:**

| Task | Needs Verification? | What To Verify |
|------|-------------------|-----------------|
| T-004 (orientation) | No | Inception task, acceptance criteria are human-checkable |
| T-005 (doctor) | **Yes** | `fw doctor` outputs no FAIL entries |
| T-006 (audit) | No | Audit output is human-reviewed, not auto-verified |
| T-007 (first commit) | **Yes** | Git log shows commit with T-007 reference |
| T-008 (task cycle) | **Yes** | Task file exists with status `work-completed` |
| T-009 (handover) | **Yes** | `.context/handovers/LATEST.md` exists and contains required sections |
| T-005 (skeleton) [B] | **Yes** | Directory structure exists, README present |
| T-006 (tooling) [B] | No | Build tool is human-configured, acceptance is review-based |

---

## IMPLEMENTATION PRIORITY

### Quick Wins (easy, high-impact)
1. Add T-005 + T-007 (validation + proof tasks) to Mode A — these directly address T-294 O-009
2. Use existing templates (no new template work needed)
3. Slightly modify `init.sh` lines 412-444 to add 2-3 more tasks

### Medium Effort (moderate complexity)
1. Add framework orientation task (T-004) — well-scoped learning task
2. Add Mode B handoff task (T-005 in greenfield) — bridges inception to build

### Higher Effort (scope creep risk)
1. Interactive `--interactive` flag — nice-to-have, not essential
2. Batch task creation optimization — premature optimization
3. Custom templates per task — not needed, default template works for all

---

## RISK ASSESSMENT

### Risk: Task Overload
**Problem:** Creating 7 tasks at init time might overwhelm new users.

**Mitigation:**
- Set horizons strategically: Phase 1 (T-004) is `now`, Phase 2 (T-005/T-006) is `now`, Phase 3 (T-007+) is `next` or `later`
- Frame as "guided checklist" not "mandatory queue"
- Print message: "Created 5 onboarding tasks. Start with T-004 (orientation). See `.tasks/active/` for details."

### Risk: False Audit Positives
**Problem:** T-294 O-009 — audit fails on brand-new projects with 9 WARNs.

**Mitigation:**
- T-005 task forces user to run `fw doctor` and fix errors early
- T-006 task documents why audit shows warnings (pre-framework commits have no T-XXX, cron audit not run yet, etc.)
- This is **addressed by adding these tasks**, not by changing audit

### Risk: Scope Creep During Init
**Problem:** If `init` tries to do too much (create 7 tasks + run doctor + run audit), startup time balloons.

**Mitigation:**
- Keep `init.sh` focused on file creation + task scaffolding
- Put *execution* (doctor, audit, handover) in tasks themselves
- Init stays fast (&lt;2s), onboarding tasks handle validation

---

## SUMMARY: PROPOSED CHANGES

### Mode A (Existing Project) — 7 Tasks
| ID | Name | Type | Owner | Horizon | Purpose |
|---|------|------|-------|---------|---------|
| T-004 | Get up to speed on framework | inception | human | now | Jargon/concept primer |
| T-005 | Run doctor and fix errors | build | agent | now | Health check + proof |
| T-006 | Establish audit baseline | build | human | now | Governance metrics |
| T-007 | Make first governed commit | build | agent | next | Proof that task system works |
| T-008 | Complete first task cycle | build | human | next | Hands-on workflow learning |
| T-009 | Generate first handover | build | human | next | Session continuity proof |

### Mode B (Greenfield) — 6 Tasks
| ID | Name | Type | Owner | Horizon | Purpose |
|---|------|------|-------|---------|---------|
| T-004 | Get up to speed on framework | inception | human | now | Same as Mode A |
| T-005 | Outline first 3-5 build tasks | inception | human | next | Bridge inception → build |
| T-006 | Create project skeleton | build | agent | next | Minimal structure |
| T-007 | Set up build/tooling | build | human | next | Tech stack proof |
| T-008 | Complete first task cycle | build | human | next | Same as Mode A T-008 |
| T-009 | Generate first handover | build | human | next | Same as Mode A T-009 |

### Implementation Effort
- **Code changes:** ~50-100 lines in `lib/init.sh` (add 4-6 more task creation calls)
- **No new templates** (use default.md + inception.md)
- **No CLI changes** (uses existing `create-task.sh`)
- **Est. time:** 1-2 hours (design + implementation + testing)

### Recommendation
**Implement Mode A (7 tasks) first** — highest ROI for existing-project users, directly addresses T-294 findings. Mode B can follow in a separate task if greenfield onboarding needs deeper investigation.

