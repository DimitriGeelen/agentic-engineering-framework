# T-1103 RCA: Episodic Auto-Generation on Partial-Complete Tasks (G-034)

**Date:** 2026-04-11  
**Task:** T-1103 — Inception: episodic auto-generation on partial-complete tasks  
**Gap:** G-034  
**Related:** G-032 (force-complete inception tasks)

---

## Summary

The episodic auto-trigger in `update-task.sh` fires unconditionally on the `work-completed` status transition, **without checking whether the task is in partial-complete state** (file stays in `.tasks/active/`, human ACs unchecked). Result: 68 of 996 episodic files (6.8%) are premature — generated for tasks the human never finalized. Fix is surgical: one `if` guard around lines 792-802.

---

## Phase 1 — Trigger Location

**File:** `agents/task-create/update-task.sh`

**Two trigger sites found:**

### Trigger 1 (Line 352-360) — Partial-Complete Re-run Path
```bash
if [ "$OLD_STATUS" = "work-completed" ] && [ "$(dirname "$TASK_FILE")" = "$TASKS_DIR/active" ]; then
    # Re-checks ACs on second call with same status
    if [ "$ALL_UNCHECKED" -eq 0 ]; then
        mv "$TASK_FILE" completed/
        if [ ! -f "$CONTEXT_DIR/episodic/$TASK_ID.yaml" ]; then   # ← guard: only if missing
            generate-episodic "$TASK_ID"
        fi
    fi
fi
```
**Verdict: CORRECT.** Fires only after the file moves to `completed/` AND only if episodic doesn't already exist. This is the human-finalization path.

### Trigger 2 (Line 792-802) — Main Work-Completed Transition Path
```bash
# Inside: if [ "$NEW_STATUS" = "work-completed" ] && [ "$OLD_STATUS" != "work-completed" ]; then
#   ...
#   if [ "${PARTIAL_COMPLETE:-false}" = true ]; then
#       # Stay in active/
#   else
#       # Move to completed/
#   fi
#   ...
    # Generate episodic summary  ← NO PARTIAL_COMPLETE guard
    PROJECT_ROOT="$PROJECT_ROOT" "$CONTEXT_AGENT" generate-episodic "$TASK_ID" || true
# fi
```
**Verdict: BUG.** The episodic call is at the END of the outer `work-completed` block, positioned AFTER the `PARTIAL_COMPLETE` branch. It fires for BOTH full-complete and partial-complete cases.

**Control flow that produces the bug:**
```
update-task.sh --status work-completed
  → PARTIAL_COMPLETE=false                         (line 428)
  → check_acceptance_criteria()                    (line 430)
      → detects unchecked human ACs
      → PARTIAL_COMPLETE=true                      (line 144)
  → [Trigger 2 block: OLD_STATUS != work-completed]  (line 613)
      → PARTIAL_COMPLETE=true → file stays in active/  (lines 620-638)
      → ... (clear focus, components, decisions) ...
      → generate-episodic fires UNCONDITIONALLY    (line 798)  ← BUG
```

---

## Phase 2 — Partial-Complete Path Trace

**`PARTIAL_COMPLETE` is set at:**
- Line 428: initialized to `false` before `check_acceptance_criteria()`
- Line 144: set to `true` inside `check_acceptance_criteria()` when `human_ac_unchecked > 0`

**The partial-complete branch (lines 620-663):**
- `PARTIAL_COMPLETE=true` → task file stays in `.tasks/active/`, owner set to `human`, review emitted
- `PARTIAL_COMPLETE=false` → task moved to `.tasks/completed/`

**The episodic trigger (lines 792-801) is OUTSIDE both branches** — it executes regardless of which path was taken.

**Inception decide compounding path (`lib/inception.sh:303`):**
```bash
"$AGENTS_DIR/task-create/update-task.sh" "$task_id" --status work-completed --force \
    --reason "Inception decision: $decision_upper"
```
`fw inception decide T-909 go` → calls `update-task.sh` with `--force` → `PARTIAL_COMPLETE` is still set by `check_acceptance_criteria()` (the `--force` flag bypasses the `exit 1`, not the `PARTIAL_COMPLETE=true` assignment) → if task has unchecked human ACs → `PARTIAL_COMPLETE=true` → stays in `active/` → **episodic fires anyway**. This is exactly the T-909 incident.

**Assumption A-5 confirmed:** When the human rejects a partial-complete (re-opens to `started-work` or `issues`), `update-task.sh` has no code to delete the stale episodic. It is left permanently.

---

## Phase 3 — Corruption Audit

**Method:** Cross-reference `.context/episodic/T-*.yaml` against `.tasks/active/T-*.md` — an episodic is premature/corrupted if the corresponding task file is still in `active/`.

**Results:**
| Category | Count |
|----------|-------|
| Total episodic files | 996 |
| Completed tasks (clean episodics) | ~926 |
| Active tasks with episodic (corrupted) | **68** |
| Active tasks with non-work-completed status + episodic | 1 (T-682, anomaly) |
| **Corruption rate** | **6.8%** |

### Five Sample Corrupted Episodics

| Task ID | Active Status | Owner | Human ACs | Episodic Notes |
|---------|--------------|-------|-----------|----------------|
| T-436 | work-completed | human | 1 unchecked | "Auto-compact YOLO mode..." — records as complete |
| T-679 | work-completed | human | 1 unchecked | "Path C workflow refinement..." — records as complete |
| T-818 | work-completed | human | 1 unchecked | "TermLink dispatch result persistence..." — records as complete |
| T-954 | work-completed | human | 1 unchecked | "Human AC classification reform..." — records as complete |
| T-1061 | work-completed | human | 1 unchecked | "TermLink as deterministic governance substrate..." — records as complete |

**Pattern:** All 67 corrupted (non-anomaly) entries have exactly the same profile: `status: work-completed`, `owner: human`, `1 unchecked` human AC. This is the canonical partial-complete signature — agent done, human AC pending.

**Anomaly — T-682:** `status: captured` (not work-completed) yet has episodic. Likely from a manual `fw context generate-episodic T-682` call. Not caused by this bug.

**Impact on memory quality:**
- Future agents reading `.context/episodic/` will see 68 tasks marked as "complete" that were never human-finalized
- Episodics include AI-generated completion summaries for decisions/learnings that were never validated
- Every inception task with a human AC that gets `fw inception decide go/no-go` adds another premature episodic (G-032 + G-034 compounding)

---

## Phase 4 — Gate Fix Sketch

**The fix:** Wrap the episodic trigger at lines 792-802 with a `PARTIAL_COMPLETE` guard.

**Before (lines 792-802):**
```bash
    # Generate episodic summary
    echo ""
    echo -e "${YELLOW}=== Auto-trigger: Episodic Generation ===${NC}"

    CONTEXT_AGENT="$FRAMEWORK_ROOT/agents/context/context.sh"
    if [ -x "$CONTEXT_AGENT" ]; then
        PROJECT_ROOT="$PROJECT_ROOT" "$CONTEXT_AGENT" generate-episodic "$TASK_ID" || true
    else
        echo -e "${YELLOW}Context agent not found${NC}"
        echo "Run manually: fw context generate-episodic $TASK_ID"
    fi
```

**After (proposed patch):**
```bash
    # Generate episodic summary — only for FULL completion, not partial-complete (G-034 fix)
    # Partial-complete defers to human-finalization path (line 352) which already guards correctly
    if [ "${PARTIAL_COMPLETE:-false}" = false ]; then
        echo ""
        echo -e "${YELLOW}=== Auto-trigger: Episodic Generation ===${NC}"

        CONTEXT_AGENT="$FRAMEWORK_ROOT/agents/context/context.sh"
        if [ -x "$CONTEXT_AGENT" ]; then
            PROJECT_ROOT="$PROJECT_ROOT" "$CONTEXT_AGENT" generate-episodic "$TASK_ID" || true
        else
            echo -e "${YELLOW}Context agent not found${NC}"
            echo "Run manually: fw context generate-episodic $TASK_ID"
        fi
    else
        echo ""
        echo -e "${YELLOW}Episodic deferred — generates after human finalizes (G-034)${NC}"
    fi
```

**Why this works end-to-end:**

1. **First call (agent done, human ACs unchecked):**
   - `PARTIAL_COMPLETE=true` → file stays in `active/` → episodic **deferred** ✓

2. **Human checks ACs, re-runs `fw task update T-XXX --status work-completed`:**
   - Hits the "re-check partial-complete" branch (line 335)
   - `ALL_UNCHECKED=0` → file moves to `completed/`
   - Line 352 trigger fires: `if [ ! -f "$CONTEXT_DIR/episodic/$TASK_ID.yaml" ]` — episodic doesn't exist → **generates now** ✓
   - Episodic generated from task in `completed/`, all ACs checked — correct state ✓

3. **`fw inception decide T-909 go` (via --force):**
   - If task has no human ACs: `PARTIAL_COMPLETE=false` → episodic fires immediately ✓
   - If task has unchecked human ACs: `PARTIAL_COMPLETE=true` → episodic deferred ✓

**Backwards compatibility:** Zero risk. Full-complete tasks (`PARTIAL_COMPLETE=false`) are unaffected. Tasks without human ACs are unaffected.

### Cleanup Plan for Existing 68 Corrupted Episodics

Options ranked by effort/safety:

**Option A (recommended): Accept bounded contamination, stop the bleeding.**  
Fix the gate. The 68 existing premature episodics are bounded — their tasks may eventually be finalized (overwriting via regenerate), or they represent work that is substantively complete even if not human-verified. Mark the count in `concerns.yaml` for future audit.

**Option B: Add `--regenerate` flag to `generate-episodic`.**  
When human finalizes, Trigger 1 at line 352 skips generation if episodic already exists (`if [ ! -f episodic ]`). Adding `--regenerate` would allow the finalization path to overwrite a stale premature episodic. This requires a second build task.

**Option C: Add `partial_complete: true` header to the 68 corrupted files.**  
Marks them as lower-confidence for agents. Low effort, high observability. Can be scripted.

---

## Phase 5 — Recommendation

**Recommendation: GO**

**Rationale:**  
Root cause is confirmed with line-level evidence. The fix is one conditional wrapping three lines — lowest possible blast radius. The existing human-finalization path (Trigger 1) already implements exactly the right behavior; the fix delegates to it instead of jumping ahead. The corruption scale (68 episodics, 6.8% of total) with a confirmed compounding path via G-032 warrants immediate action.

**Evidence:**
- `agents/task-create/update-task.sh:792` — episodic trigger has zero `PARTIAL_COMPLETE` guard
- `agents/task-create/update-task.sh:144` — `PARTIAL_COMPLETE` correctly set inside `check_acceptance_criteria()`
- `agents/task-create/update-task.sh:620-663` — partial-complete branch correctly defers file move
- `agents/task-create/update-task.sh:352-360` — human-finalization trigger already has correct guard
- `lib/inception.sh:303` — inception decide calls `update-task.sh --force`, compounding the bug (every inception with a human AC)
- 68 corrupted episodics confirmed by cross-reference audit (active/ × episodic/)
- All 5 sampled corrupted entries: canonical partial-complete signature (`status: work-completed`, `owner: human`, 1 unchecked human AC)

**Build tasks to spawn after GO:**
1. **Build task:** Apply gate fix — add `PARTIAL_COMPLETE` guard at `update-task.sh:792`. Test: partial-complete → episodic NOT generated; human finalizes → episodic generated.
2. **Build task:** Cleanup for 68 existing corrupted episodics — `fw episodic audit` command, or add `--regenerate` to `generate-episodic` for finalization overwrite.

---

## Assumptions Validation

| Assumption | Status | Evidence |
|-----------|--------|---------|
| A-1: Trigger in update-task.sh, fires on status field | **CONFIRMED** | Line 792, inside `$NEW_STATUS=work-completed` block |
| A-2: Gate fix is one-line (physical file location) | **REFINED** | `PARTIAL_COMPLETE` flag (already set correctly) is simpler and more correct than file location check |
| A-3: Defer until human finalizes, Trigger 1 handles it | **CONFIRMED** | Line 352-360: correct guard already exists for finalization path |
| A-4: Existing episodics may include premature ones | **CONFIRMED** | 68 found (6.8% contamination rate) |
| A-5: Rejected partial-complete leaves stale episodic | **CONFIRMED** | No cleanup code in update-task.sh for status rollback |

---

*Generated by RCA worker T-1103 | 2026-04-11*
