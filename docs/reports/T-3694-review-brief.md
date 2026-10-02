# T-3694 Review Brief

**Task:** `.tasks/active/T-3694-design-conformance-gate-finish-t-3691-cl.md`. It finishes
T-3691, which closed with its own items 3 (audit FAIL / doctor WARN on register rows) and
5 (stale-keystone WARN + /approvals) "deferred to separate tasks (T-3692, T-3693)". T-3692
is an unrelated bug, and T-3693 did not exist at that moment.

**Contract:** T-3691 description items 1-5. This task builds items 3 and 5 and closes the
hole that let T-3691 pass its own close gate.

**Built across two workers.** The first worker (commits fdc58c205, 3f51e86ea, 057fa1cc6,
85229a7f9) wrote an audit check hardcoded to one doc and re-pointed R2-R5 to T-3693. That
check is replaced here. The re-point is partly corrected (see AC3).

## Design: one predicate, four consumers

`lib/design_register.py` holds every rule. Each consumer calls it:

| Consumer | Where | Subcommand / function |
|---|---|---|
| `fw audit` structure section | `agents/audit/audit.sh:4338-4379` | `violations` (FAIL), `stale-keystones` (WARN) |
| `fw doctor` | `bin/fw:2405-2422` | `violations` (WARN) |
| Watchtower /approvals | `web/blueprints/approvals.py:786` `_load_stale_keystones`, template `web/templates/_approvals_content.html:272` | `stale_keystones()` |
| close gate | `agents/task-create/update-task.sh:934` `check_register_requirements` (`close-check`), `:1007` `check_self_deferral` (`self-deferral`), called at `:2222` | |

Register docs are found two ways. The first is through an arc's `design_doc:` or the new
`register_docs:` (`lib/design_register.py:146`). The second is any `docs/**/*.md` that carries
a fenced `register:` block (`:171`). Arcs are resolved by filename, `id:` or `slug:`
(`:155`).

## AC → evidence

### AC1: `fw audit` FAILs on a row with no owner, a missing owner, or a completed owner of an unbuilt row
- Predicate: `lib/design_register.py:187` `register_violations`. It uses `is_live` (`:100`): in `active/` and not work-completed.
- Through the real `agents/audit/audit.sh --section structure` on a fixture root:
  `tests/governance/test_t3694_conformance_gate.bats` "audit FAILs: owner completed while its row is not built (the T-3561 shape)" (asserts exit 2 and the `[FAIL]` line), "audit FAILs: row with no owner_task", and the control "audit control: re-pointed to an active owner → PASS" (asserts the PASS line and zero FAIL lines for this check).
- The parametrised module tests cover all three treatments plus a control: `tests/unit/test_t3694_design_register.py::test_violations_treatment_fails`, `::test_violations_control_clean`.
- Live, against the sidecar register at three points in its history (captured output):
  ```
  docs/architecture/sidecar-target-architecture.md: R6: owner T-3561 is completed but row status is 'partial' (not built)
  rc=1 (register as T-3691 left it, 4dc757ee4)
  ...R6: owner T-3561 is completed...
  rc=1 (after previous worker's R2-R5 re-point, 85229a7f9)
  rc=0 (now)
  ```
  The full live `bin/fw audit --section structure` run printed
  `[PASS] Design-conformance register: every row has a live or finished-and-built owner` and `[PASS] Stale keystones: none captured >3 days`.
- Note: the brief said "T-3561 is completed while R2-R5 are unbuilt". In the actual register, R2-R5 were on T-3684 (captured, existing). The completed-owner violation was R6 on T-3561, and the check FAILs on exactly that.

### AC2: `fw doctor` WARNs on the same conditions
- `bin/fw:2405-2422`. It uses `|| _reg_rc=$?` because doctor runs under errexit. The first version without it killed doctor silently partway through; the test caught that.
- Tests: "doctor WARNs on a register row whose owner does not exist" and "doctor control: OK on a register whose owner is active". Both run the real `bin/fw doctor --quick` on a fixture root.

### AC3: register re-pointed to real owners
- `docs/architecture/sidecar-target-architecture.md` §7 now reads: R2, R4, R6 → T-3693; R3, R5 → T-3684; R12 → T-3688. Each row's `evidence:` names the owner AC or description it relies on.
- **This deviates from the literal instruction ("R2-R5 → T-3693"). Rationale (task file, Decisions):** T-3693's ACs build the ready-flag hooks (R4), inject-when-ready (R2) and the sender state ledger (R6). Its ACs say nothing about the 30 s tick (R3) or the urgent bypass (R5), and T-3684's description names both. R12 was on T-3690 (legacy-address retirement), but T-3688's description says "Gap row R12".
- No row points at T-3692: `tests/unit/test_t3694_design_register.py::test_live_register_has_no_owner_on_unrelated_t3692`, and a Verification line.
- Every owner exists: R1 T-3402, R8 T-3405, R9 T-3406, R10/R11/R13 T-3561 are completed with status built. T-3684, T-3685, T-3688 and T-3693 are active. `python3 lib/design_register.py violations` exits 0.

### AC4: stale keystone audit WARN
- `lib/design_register.py:238` `stale_keystones`. It flags a captured, active task captured for more than N days (default 3) that either (a) owns a non-built register row, (b) is named by an arc's `keystone_task` / `keystone` / `slice_1` / `slice_1_task`, or (c) has an `arc_id` and a name containing "keystone", "slice 1" or "S1". "Captured since" is the last `→ captured` transition in `## Updates`, falling back to `created` (`:230`).
- Through the real audit: "audit WARNs on a keystone captured >3 days; PASS once started".
- Module tests: `::test_stale_keystone_owner_of_unbuilt_row` (9.5 d flagged, 2.5 d and started-work not), `::test_stale_keystone_built_row_does_not_count`, `::test_stale_keystone_by_arc_field_and_by_name`, `::test_stale_keystone_uses_last_demotion_not_created`, `::test_stale_keystone_cli_exit_codes`.

### AC5: /approvals line
- Loader `web/blueprints/approvals.py:786`. Context key at `:869` and `:906`. Template section `web/templates/_approvals_content.html:266-292`: linked task id, "captured N days" badge, arc link, name, reasons.
- `::test_approvals_renders_stale_keystone` runs the real loader, real predicate and real template through the Flask test client against a fixture root. Only `PROJECT_ROOT` is redirected. `::test_approvals_no_section_when_fresh` is the control.
- Live: `bin/fw watchtower restart` done. `bin/fw watchtower current` prints `current: Watchtower pid 3452877 is newer than every file under web/`. `curl -sf $(bin/fw watchtower url)/approvals` returns 200. There is no live section today because no qualifying task has been captured for more than 3 days. The operator's rendering check is the `[REVIEW]` Human AC.

### AC6: close gate refuses self-deferral to a missing, inactive or unrelated task, with a T-3691 fixture
- `lib/design_register.py:340` `self_deferrals`. Deferral shapes are matched at `:303`/`:311`. A target counts only within 100 chars after the verb, plus "follow-up" anywhere. Scanned: the task's own result. Skipped: Context, RCA, Updates, Reviewer Verdict, comments and code (`:298`, `:324`). Each target must exist, be active, and mention the closing id.
- Gate: `agents/task-create/update-task.sh:1007`. Bypass `--skip-self-deferral --reason` is operator-only: it was added to `_BYPASS_AGENT_REFUSED` and `_BYPASS_REASON_REQUIRED` (`:97-98`). There is no env-var form.
- Fixture: `tests/fixtures/t3694/T-3691-as-closed.md` is T-3691's own file with status reset to started-work.
- Tests: "T-3691 reproduction: close REFUSED when deferral targets are missing/unrelated" runs the real `update-task.sh`. It asserts non-zero exit, "T-3693 does not exist" and "T-3692 never mentions T-3691", and that the task stays in `active/`. "T-3691 control: same text closes once both targets are active and name it" is the control. "self-deferral: agent cannot waive the gate" covers the bypass refusal.
- **Mutation check:** with the `check_self_deferral` call disabled, the reproduction test goes `not ok`. With it restored, it goes `ok`.
- Measured false-positive rate: run over the 129 completed T-35xx/T-36xx tasks, the predicate flagged 4. All four name targets that never mention the closer. Run retroactively, completed targets also read "not active".

### AC7: close gate refuses an owner closing on an unbuilt row, and arc resolution by id
- `lib/design_register.py:371` `close_check`. `update-task.sh:934` now calls it.
- Tests: "register gate: owner closing while its row is partial REFUSED (T-3561 shape)", "register gate control: owner closes once its row is built", "register gate: arc resolved by id (not filename)".
- arc-011 now links the register: `.context/arcs/parallel-execution-aef.yaml:12` `register_docs:`. Before this, the T-3691 gate looked up `.context/arcs/011.yaml` / `arc-011.yaml`, found neither, and returned early for every arc-011 slice.

### AC8: tests
- `tests/governance/test_t3694_conformance_gate.bats`: 12/12 ok, 0 skipped.
- `tests/unit/test_t3694_design_register.py`: 20 passed.
- `tests/governance/test_register_requirements_gate.bats` (T-3691's suite): 5/5 ok. **On T-3691's own code its treatment tests 2 and 3 were red**: its matcher knew "deferred" but not "defers". This was reproduced on an archive of 85229a7f9. Fixed in `close_check`. That suite's control assertions were also vacuous (`[ "$status" -eq 0 ] || echo ...`) and are now real. Its fixture had the control's closing task own an unbuilt row, which is now refused, so that row was re-pointed in the fixture.
- `bats tests/lint/`: 117 ok. The only red is `no-untracked-test-files`, for this task's two new test files (resolved by commit) and `tests/integration/t3693_sidecar_e2e_test.py` (T-3693's worker, not this task).

### AC9: verification
The task's `## Verification` block runs:
- the three suites, guarded against fail markers and skips
- the live `violations`
- no T-3692 owner
- `bash -n` on the three scripts
- `bin/fw vendor self --check`
- `bin/fw watchtower current`
- the /approvals curl

## Scope fence

Nothing in this task is deferred. Not touched: `lib/sidecar/` and the hooks (T-3693's worker
owns them). Rows R2-R15 stay unbuilt because building them is the sidecar slices' work.
Each row's owner is an active task whose own text names that row (AC3).

## Known limits
- The self-deferral relatedness test is a back-reference: the target file must mention the closer. A target that mentions the closer only incidentally passes.
- Keystone-by-name matches "keystone", "slice 1" and "S1" only on tasks that have `arc_id`. Arcs can also name keystones explicitly (`keystone_task:`), but no arc does so today.
