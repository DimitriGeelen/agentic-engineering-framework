# T-3694 Review Brief

**Task:** Design-conformance gate (finish): T-3691 closed with items 3 and 5 deferred to non-existent owners — audit FAIL/doctor WARN on unowned or orphaned register rows, stale-keystone WARN on /approvals

**Context:** T-3691 closed with deferred items 3 and 5 to T-3692 and T-3693. The issue: T-3691 described deferring items 3-5 to T-3692/T-3693 in its description, but these are split tasks. Also, the sidecar register has T-3561 (completed) owning R6 (partial status) — a violation of the gate contract.

## Acceptance Criteria Matrix

| # | AC | Verification method | Evidence location |
|---|----|--------------------|-------------------|
| 1 | `fw audit` (structure section) FAILs when register row has no owner_task, non-existent owner_task, or owner completed while row status is not built | Test fixture + live audit | tests/governance/test_register_requirements_gate.bats + agents/audit/audit.sh |
| 2 | `fw doctor` WARNs on same register row conditions | Test fixture + live doctor | tests/governance/test_register_requirements_gate.bats + lib/doctor.sh |
| 3 | Register rows R2-R5 in docs/architecture/sidecar-target-architecture.md are re-pointed from T-3684 to T-3693 | File inspection | docs/architecture/sidecar-target-architecture.md lines 190-216 |
| 4 | Stale keystone detection: audit WARNs on captured task that owns unbuilt register row or is arc keystone/slice 1 and has stayed captured >3 days | Test + live audit | tests/governance/ + agents/audit/audit.sh |
| 5 | Stale keystone appears on Watchtower /approvals page with task link and days-captured count | UI inspection | web/blueprints/approvals.py + render test |
| 6 | Close gate refuses when closing task's body/result defers its own description items or ACs to non-existent or unrelated task | Test fixture (negative control) | tests/governance/test_register_requirements_gate.bats |
| 7 | Tests for all gates (liveness/negative control/bypass paths) | Test suite | tests/governance/test_register_requirements_gate.bats |
| 8 | All verification commands pass (audit/doctor clean, tests green, vendor/watchtower current) | Verification block | .tasks/active/T-3694-*.md ## Verification |

## Scope Fence

This task implements:
- **Item 3 (Audit FAIL/Doctor WARN):** register row validation in audit and doctor
- **Item 5 (Stale keystone WARN):** captured task monitoring + /approvals rendering
- **Close gate hole:** prevent deferral to non-existent/unrelated tasks

Deferred to owners (no work here):
- T-3693 owns building R2-R5 (S1-finish task for arc-011 sidecar)
- lib/sidecar/ and hooks are owned by T-3693 (not touched here)

## Key Files Modified

| File | Purpose | Scope |
|------|---------|-------|
| docs/architecture/sidecar-target-architecture.md | Update R2-R5 owner from T-3684 to T-3693 | 4 rows (lines ~193, ~200, ~207, ~214) |
| agents/audit/audit.sh | Add check_register_requirements_gate() call in structure section | 1 function call |
| lib/doctor.sh | Add register row validation warning | ~20 lines |
| agents/task-create/update-task.sh | Enhance close gate to check for self-deferred items | ~30 lines |
| tests/governance/test_register_requirements_gate.bats | Tests (fixtures already exist from T-3691) | Extend existing test |
| web/blueprints/approvals.py | Add stale keystone section to /approvals page | ~40-50 lines |
| tests/web/test_approvals.py | Test stale keystone rendering | ~20 lines |

## Deferral Contract

The directive states: "Item 3 must flag the sidecar register now: T-3561 is completed while R2-R5 are unbuilt; re-point those rows to T-3693 (the S1-finish task) so the audit goes green for the right reason."

- Currently: R2-R5 owned by T-3684 (captured); R6 owned by T-3561 (completed, partial status) — both violations
- After fix: R2-R5 owned by T-3693 (active S1-finish); R6 still owned by T-3561 (audit will flag as violation until R6 is built or ownership changes)

## Control and Treatment

**Control (should pass audit):**
- Any register row with owner_task pointing to an existing active/completed task + compatible status
- Example: R1 (T-3402 built, status: built) ✓

**Treatment (should fail audit):**
- Row with no owner_task field
- Row with owner_task pointing to non-existent task (e.g., "T-9999")
- Row with owner_task pointing to completed task while status is not built
- Task closing while its description defers items to non-existent task

**Fixtures created in tests/governance/test_register_requirements_gate.bats:**
- Liveness check: current register against live task corpus
- Negative control: insert invalid row, verify audit FAILs
- Bypass path: close with `--skip-register-requirements "reason"`, verify logged Tier-2

## Expected Implementation

**Audit structure section:**
```bash
check_register_requirements() {
  # Inspect docs/architecture/sidecar-target-architecture.md
  # For each register row:
  #   - Verify owner_task exists in .tasks/
  #   - If owner is completed, verify row status is built
  #   - If any check fails, emit FAIL
}
```

**Doctor warnings:**
```bash
doctor_register_rows() {
  # Same logic as audit, emit WARN instead of FAIL
  # Run in doctor's "health" section
}
```

**Close gate enhancement:**
```bash
check_deferral_to_owned_tasks() {
  # When closing a task, parse description/ACs for references
  # Pattern: "deferred to T-XXXX" or similar
  # Verify T-XXXX exists and is active/related
  # Refuse if pointing to non-existent or unrelated task
}
```

**Stale keystone detection:**
```bash
stale_keystones() {
  # Find captured tasks that:
  #   - Own unbuilt register rows, OR
  #   - Are arc keystones/slice 1 per .context/arcs/*.yaml
  #   - Have stayed captured > 3 days (compare created vs now)
  # Emit WARN with days captured
}
```

**Watchtower /approvals enhancement:**
```python
def render_approvals():
  # Add "Stale Keystones" section
  # List each stale keystone with: task ID (link), name, arc slug, days captured
  # Render cleanly with task-page navigation
```
