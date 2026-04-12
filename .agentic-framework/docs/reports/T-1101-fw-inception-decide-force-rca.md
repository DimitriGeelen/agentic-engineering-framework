# T-1101 RCA: `fw inception decide` Silent `--force` Bypass (G-032 CRITICAL)

**Generated:** 2026-04-11  
**Task:** T-1101 (inception, RCA-only)  
**Trigger:** /opt/termlink T-909 transcript — `fw inception decide T-909 go` printed
`Completing human-owned task (--force bypass)` and `3/3 agent AC unchecked (--force bypass)`
without the user passing `--force`.

---

## Executive Summary

`lib/inception.sh:303` silently passes `--force` to `update-task.sh` whenever
`fw inception decide` records a go or no-go decision. This bypasses **three structural
gates simultaneously**: the sovereignty gate (R-033), the agent acceptance criteria gate
(P-010), and the verification gate (P-011). The comment at line 299 cites T-637 with the
premise that this bypass is safe because "inception decide itself required Tier 0 approval."
The premise is **partially true but logically unsound**: Tier 0 approval for the DECISION
command does not constitute authorization to skip AC verification or verification commands.

**Recommendation: GO** — Remove `--force` from `lib/inception.sh:303`. Add a
`--skip-sovereignty` flag to `update-task.sh` to replace it (surgical bypass, R-033 only).
Historical backwards-compat cost: zero (0/98 completed inception tasks had unchecked ACs).

---

## Phase 1: T-637 Reconstruction — What Problem Was Being Solved?

### T-637 Background

**Task name:** "Frictionless inception completion — Watchtower approval auto-completes
inception tasks without second manual command"

**Created:** 2026-03-27  
**Context (from task file):**

> `fw inception decide T-XXX go` requires Tier 0 (human authority exercised via Watchtower
> or CLI). But after the decision is recorded, `inception.sh` calls `update-task.sh
> --status work-completed` WITHOUT `--force`, hitting the sovereignty gate (R-033) because
> inception tasks have `owner: human`. This requires a SECOND manual command — redundant
> since the human already approved. Fix: pass `--force` when the inception decide itself
> required Tier 0 approval.

### T-637 Was Solving a Real Problem

The sovereignty gate (R-033) in `update-task.sh:33-49` blocks completion of any task with
`owner: human` unless `--force` is passed. Inception tasks default to `owner: human`
(`lib/inception.sh:59`). When the human ran `fw inception decide T-XXX go`, `inception.sh`
internally called `update-task.sh --status work-completed` (no `--force`), which hit R-033
and blocked with:

```
ERROR: Cannot complete human-owned task
Sovereignty gate (R-033): owner is human.
```

The human then had to run a second command manually. T-637 added `--force` to avoid this.

### The Logical Flaw

T-637's comment reads:

```bash
# --force bypasses sovereignty gate (R-033) because inception decide itself
# required Tier 0 approval — human authority was already exercised (T-637)
```

The factual claim is **confirmed**: `fw inception decide` IS Tier 0 gated.
`check-tier0.sh:145` contains:

```python
(r'\bfw\s+inception\s+decide\b',
 'INCEPTION DECISION: GO/NO-GO decisions require human authority. Present your
  recommendation and rationale, then ask the human to run:
  fw inception decide T-XXX go|no-go --rationale "..."'),
```

This was added by T-557 (still in `.tasks/active/`; agent ACs verified, task
never formally completed).

**The flaw:** Tier 0 approval for the `fw inception decide` command authorizes the DECISION
(commitment of resources, GO/NO-GO). It does NOT authorize skipping acceptance criteria
verification or verification commands. These are independent concerns:

| Gate | Question | Who authorizes |
|------|----------|----------------|
| R-033 (sovereignty) | Has the human authorized completing this task? | YES — human ran the command |
| P-010 (AC gate) | Are all agent acceptance criteria satisfied? | Agent (must check their own work) |
| P-011 (verification) | Do the verification shell commands pass? | Deterministic — machine-checked |

`--force` bypasses ALL THREE. T-637 only needed to bypass R-033.

**In other words:** T-637 used a sledgehammer (global `--force`) when it needed a scalpel
(sovereignty-only bypass).

### T-637 Was Completed in 1 Minute

The episodic shows: `wall_clock_minutes: 1, commits: 1`. No Decisions section was filled in.
No alternatives were recorded as considered. The fast completion suggests no analysis of
what `--force` bypasses beyond R-033.

---

## Phase 2: Call Site Audit

### Primary Affected Location

**`lib/inception.sh:299-303`** (the smoking gun):

```bash
# --force bypasses sovereignty gate (R-033) because inception decide itself
# required Tier 0 approval — human authority was already exercised (T-637)
if [ "$decision" = "go" ] || [ "$decision" = "no-go" ]; then
    echo ""
    "$AGENTS_DIR/task-create/update-task.sh" "$task_id" --status work-completed --force --reason "Inception decision: $decision_upper" 2>&1
fi
```

**Mirror:** `.agentic-framework/lib/inception.sh:299-303` (identical content)

### Secondary Call Sites (read-only, not affected)

| File | Location | Purpose |
|------|----------|---------|
| `check-tier0.sh:145` | Tier 0 pattern | Blocks agent from calling `fw inception decide` via Bash tool |
| `lib/review.sh:127` | Review emit | Suggests `fw inception decide` command to human after review |
| `agents/git/lib/hooks.sh:126-127` | Commit hook | Reminds about `fw inception decide` in commit message |
| `agents/audit/audit.sh:1655` | Audit check | Verifies inception tasks have a recorded decision |

None of these depend on `--force` behavior. Removing `--force` from `lib/inception.sh:303`
affects no other call site.

### Who Calls `fw inception decide` in Practice?

Based on CLAUDE.md (`§Copy-Pasteable Commands` and `§Inception Discipline`):
- The **human** runs `fw inception decide` directly in their terminal
- The agent is **blocked** from running it via the Bash tool (check-tier0.sh Tier 0 gate)

This means the Tier 0 gate (added by T-557) correctly prevents the agent from calling the
command, so the bypass only activates after human-authorized invocation. However, the human
authorizing the GO decision ≠ authorizing the agent's incomplete ACs.

---

## Phase 3: Patch Sketch

### The Correct Fix — Add `--skip-sovereignty` to `update-task.sh`

The root cause is that `--force` is too blunt. The right fix is a surgical flag:

**`agents/task-create/update-task.sh`** — add flag parsing (near line 265):

```bash
--skip-sovereignty) SKIP_SOVEREIGNTY=true; shift ;;
```

Initialize near line 254:

```bash
SKIP_SOVEREIGNTY=false
```

Modify `check_human_sovereignty()` (lines 33-49):

```bash
check_human_sovereignty() {
    local current_owner
    current_owner=$(grep "^owner:" "$TASK_FILE" | head -1 | sed 's/owner:[[:space:]]*//')
    if [ "$current_owner" = "human" ]; then
        if [ "$FORCE" = true ] || [ "$SKIP_SOVEREIGNTY" = true ]; then
            echo -e "${YELLOW}WARNING: Completing human-owned task (sovereignty bypass)${NC}"
        else
            # ... existing error block ...
        fi
    fi
}
```

**`lib/inception.sh:299-303`** — replace `--force` with `--skip-sovereignty`:

```bash
# Complete task if go or no-go (not defer).
# --skip-sovereignty: Human running fw inception decide T-XXX go is authority
# over the task's completion (sovereignty gate, R-033). This does NOT bypass
# the AC gate (P-010) or verification gate (P-011) — those remain enforced.
if [ "$decision" = "go" ] || [ "$decision" = "no-go" ]; then
    echo ""
    "$AGENTS_DIR/task-create/update-task.sh" "$task_id" --status work-completed --skip-sovereignty --reason "Inception decision: $decision_upper" 2>&1
fi
```

### What This Preserves

- **T-637's UX intent:** No second command needed after `fw inception decide`
- **Sovereignty gate:** Human running the command = sovereignty exercised (bypassed correctly)
- **P-010 (AC gate):** RESTORED — unchecked agent ACs now block completion
- **P-011 (verification gate):** RESTORED — failing verification commands now block completion

### What Breaks

Nothing breaks for any historically completed inception task (see Phase 4).

For FUTURE inception tasks: if the agent hasn't checked all ACs before the human runs
`fw inception decide`, the command will fail with:

```
ERROR: Cannot complete — 3/3 agent AC unchecked:
  - [ ] Problem statement validated
  - [ ] Assumptions tested
  - [ ] Recommendation written with rationale
```

This is the **correct** behavior. The fix surfaces incomplete work rather than hiding it.

### Alternative: Don't Auto-Complete At All (Option C)

Remove lines 301-304 entirely. The human runs `fw task update T-XXX --status work-completed`
separately after verifying ACs. This is more aligned with CLAUDE.md §Inception Discipline
but reverts T-637's UX improvement.

**Rejected for now:** The `--skip-sovereignty` approach is strictly better — it preserves
the UX while restoring the missing gate checks.

---

## Phase 4: Backwards-Compat Audit

### Methodology

Audited all 98 completed inception tasks in `.tasks/completed/` using Python:
- Extracted `## Acceptance Criteria` section for each
- Separated Agent ACs from Human ACs (for tasks using the split format)
- Counted checked vs. unchecked checkboxes

### Results

| Category | Count | Interpretation |
|----------|-------|----------------|
| Total inception tasks | 98 | Full population |
| No ACs at all | 4 | Gate wouldn't fire — not affected |
| All ACs checked | 94 | Would have passed normally without `--force` |
| Unchecked ACs (--force bypassed) | **0** | No historical bypass violation |

**Backwards-compat cost: zero.** No historical inception task had unchecked ACs when
`fw inception decide` was run. The patch would not have changed any historical outcome.

### Verification Command Audit

24/98 inception tasks had real verification commands (not just empty section):
- All are file existence checks: `test -f docs/reports/T-XXX-*.md`
- These would pass if the reports were written (which they were — tasks are completed)
- No evidence of verification failures being bypassed historically

### Owner Distribution

| Owner | Count |
|-------|-------|
| human | 56 |
| agent | 38 |
| other | 4 |

56/98 (57%) had `owner: human` and would have hit the sovereignty gate. T-637 was
solving a real problem for the majority of inception flows. But the fix was too broad.

### Sample Spot-Check (5 tasks with verified ACs)

| Task | ACs | Status |
|------|-----|--------|
| T-109 | 6/6 checked | Would pass without --force |
| T-110 | 4/4 checked | Would pass without --force |
| T-111 | 4/4 checked | Would pass without --force |
| T-118 | 4/4 checked | Would pass without --force |
| T-120 | 3/3 checked | Would pass without --force |

Pattern holds universally across the population.

---

## Phase 5: Compound Effect Analysis (G-032 + G-034)

The T-1101 task notes a compounding risk: G-032 (premature task completion via --force) can
combine with G-034 (premature episodic generation) to produce **false long-term memory**.

When `fw inception decide` completes a task with unchecked ACs:
1. `update-task.sh` moves the task to `.tasks/completed/`
2. `update-task.sh` triggers `context.sh generate-episodic`
3. The episodic YAML is written with `enrichment_status: complete`
4. The unchecked ACs are immortalized as "outcomes" in the episodic

The episodic for T-909 (if it exists) would record the decision as final, even though agent
ACs were never verified. This is a second-order harm: the primary fix (removing `--force`)
also prevents the false episodic from being generated.

Check `.context/episodic/T-1093.yaml` for evidence of this pattern in the current session.

---

## Assumption Validation

| Assumption | Status | Evidence |
|------------|--------|---------|
| A-1: T-637 had a legitimate problem (sovereignty gate friction) | **VALIDATED** | T-637 task context confirms real UX issue; 56/98 inception tasks owned by human |
| A-2: Non-bypass solution exists (split decision from completion) | **VALIDATED** | `--skip-sovereignty` flag provides surgical bypass; preserves T-637's UX |
| A-3: Removing --force will break existing inception flows | **REFUTED** | 0/98 completed inception tasks had unchecked ACs |
| A-4: Compounding effect (G-032 + G-034) is real | **VALIDATED** | T-909 incident: 3/3 unchecked ACs + episodic generation triggered |

---

## Recommendation

**Recommendation: GO**

**Rationale:** The fix is unambiguous, the backwards-compat cost is zero, and the T-909
incident proves the bug is actively harmful in production. T-637's original intent
(no second command after human approval) is fully preserved by the surgical
`--skip-sovereignty` approach. The `--force` flag was the wrong tool for R-033-only bypass.

**Evidence:**

- `lib/inception.sh:303` — confirmed `--force` is passed without user knowledge
- `check-tier0.sh:145` — confirms `fw inception decide` IS Tier 0 gated (premise partially true)
- `update-task.sh:277` — help text confirms `--force` bypasses "acceptance criteria + verification gates"
- Audit: **0/98** completed inception tasks had unchecked ACs → backwards compat cost is zero
- T-909 incident: `3/3 agent AC unchecked (--force bypass)` printed in live session transcript
- T-637 comment ("human authority was already exercised") only applies to R-033 (sovereignty), NOT P-010 or P-011
- T-637 completed in 1 minute with no decision alternatives recorded → insufficient analysis of `--force` scope

**Scope of work for descendant build task:**

1. Add `SKIP_SOVEREIGNTY=false` and `--skip-sovereignty` flag parsing to `update-task.sh`
2. Modify `check_human_sovereignty()` to check `$SKIP_SOVEREIGNTY || $FORCE` for the bypass path
3. Replace `--force` with `--skip-sovereignty` at `lib/inception.sh:303`
4. Mirror the same change to `.agentic-framework/lib/inception.sh:303`
5. Update the comment at `lib/inception.sh:299` to accurately describe the bypass
6. Update `update-task.sh --help` to document `--skip-sovereignty`
7. Add a bats test: `fw inception decide T-XXX go` with unchecked ACs → blocked with AC error
8. Update G-032 in `concerns.yaml` from OPEN to RESOLVED after the fix

**Estimated scope:** 1 build task, ~40 lines changed, no database or API dependencies.

---

*Generated by T-1101 RCA worker. Phase execution: 5/5 complete.*
*Report path: `docs/reports/T-1101-fw-inception-decide-force-rca.md`*
