The tier split is justified, but the proposed 950–975-file selection does **not yet establish a sub-10-minute gate**. The priority is to make execution complete and reproducible, then optimise cost while preserving evidence that each regression test detects its target defect.

1. **Introduce explicit tiers with runtime headroom and completeness checks.** Highest immediate impact: the top 30 files consume 52.6% of measured time; 100 consume 81.7%. Keep fast regression checks in pre-push and run **both tiers** nightly. Select by risk and demonstrated runtime, not tests/second alone. The proposed budgets predict 597–600 seconds under ideal packing—effectively no margin. Initially target roughly 7–8 minutes on the actual six-worker gate host, then validate repeated runs. Require every discovered test to have a tier; reject unexplained collection loss, skips, and missing results. Timeouts must block approval as incomplete execution, never count as determined test verdicts.

2. **Replace repeated full doctor/audit invocations with focused checks plus a few real integration tests.** Bats consumes 95.5% of measured time; `doctor_designer_pin_drift.bats` has median 900 seconds, `t2243_doctor_self_vendor_templates.bats` 866, and `t2290_doctor_mcp_content_check.bats` 635. Extract callable production checks and exercise minimal positive/negative fixtures. Preserve nightly CLI wiring checks. `fw_doctor_vendored_drift.bats` already demonstrates the benefit of focused execution, although its `awk` extraction from `bin/fw` is brittle: a production function would provide a stronger interface. Keep critical defect checks in pre-push after making them cheap.

3. **Make isolation an enforced runner property, supported by the shared helper.** The measurement flags roughly 190 files for review, with documented live-state failures and sidecar interference. `tests/test_helper.bash` currently creates a temporary directory but does not automatically set `PROJECT_ROOT` or change cwd. Its default teardown does not call `tripwire_assert`, and file-local setup/teardown functions can replace the defaults. Provide explicit fixture constructors and mandatory lifecycle enforcement; isolate project state, locks, reports, registries, and relevant environment variables. `guard_project_root` accepting any `/tmp/*` path does not prove ownership or prevent symlink escape. Validate canonical paths against each test’s allocated root. Use lint as supplementary detection, with narrow exceptions for tests deliberately exercising inherited environments.

4. **Repair measurement and runner accounting before tuning concurrency.** Evidence: 81 completed runs become only 42 daily reports; 351 Python files were scanned but only 315 measured; 204 intermittent reds lack revision attribution. Store immutable per-run reports with commit/tree identity, selected manifest, collected test IDs, skips, setup failures, worker count, and actual command duration. `unit-suite.sh` discovers only `test_*.py`; investigate excluded files, including the report’s `t2974_greenfield_operator_prose.py`, before calling nightly “full.” It also accepts pytest exit 5 as nonfailure: unexpected empty collection should fail. Benchmark six versus twelve workers without overlapping suites, then consider longest-first scheduling within each tier.

5. **Make defect reproduction the prerequisite for pruning or assertion changes.** The suite grew from 623 to 860 Bats files and 201 to 315 measured Python files in six weeks; duplication is plausible, but counts do not establish redundancy. For each changed regression test, record its origin bug, decisive fixture, expected assertion failure, and retained replacement. Reintroduce the defect using a historical revision or targeted mutation: require failure for the intended reason and passage with the fix. Delete a duplicate only after its replacement catches that defect. `fabric_coverage_single_source.bats` already has useful discrimination controls: recursive paths, excluded files, and injected corruption. Preserve those controls.

**Where the measurement and plan need correction**

The four “bimodal” files do not establish four hangs. Short execution can mean skipped work, an early setup failure, or an older/newer implementation. `audit.bats` explicitly skips on lock exit 75; `fabric_coverage_single_source.bats` skips when audit reports contention. Their quick samples may represent *less coverage*, not healthy performance.

`fw_doctor_vendored_drift.bats` now uses a throwaway fixture and explicitly documents its previous live-doctor implementation. Its historical 1–900-second range must be split by revision before drawing concurrency conclusions.

The hf/base runs used two trees and shared the host. They are neither a controlled same-revision flakiness experiment nor a clean six-versus-twelve-worker comparison. The 0.95 median duration ratio cannot rule out contention. Likewise, median-sum budgeting is a planning estimate, not a conservative tail-latency guarantee.

Moving slow tests nightly does not repair nightly determinacy. Its acceptance criteria must include complete discovery, zero unexplained skips/timeouts, and revision-matched results. The 44-entry baseline, including one expired entry and 32 expiring together, needs owned remediation; baseline acceptance must remain visibly distinct from passing assertions.

**Main refactor risks and early detection**

- **Fixture or mock removes the bug-triggering condition:** require targeted mutations and explicit fixture preconditions before merging each conversion.
- **Focused check passes while CLI wiring breaks:** retain small real entrypoint integration tests covering dispatch, environment, exit codes, and report output.
- **Tiering silently drops coverage:** compare discovery, collection, execution, and tier manifests on every run; nightly must execute their full union.
- **Shared helper introduces leakage or overrides test intent:** run representative files alone, in shuffled order, and concurrently with hostile inherited environment values. Preserve explicit opt-outs for environment-behaviour tests.
- **Reporting produces false completeness:** exercise runner controls for empty collection, collection error, timeout, interruption, skip, and missing output. `LAST-COMPLETE.yaml` currently can include per-file timeouts because its condition excludes run-level incompleteness but does not explicitly exclude `files_timed_out`.

**Likely real defects or coverage failures**

`t2332_bvp_propose_queue.bats` hard-codes `/opt/999-Agentic-Engineering-Framework`, queries live Watchtower, conditionally skips on live proposals, and calls `curl -sf` without a timeout. That is a concrete portability/isolation defect and plausible unbounded-wait source.

In `audit.bats`, “audit exits 0 for all-pass sections” accepts exit 2 when summary markers exist. It no longer verifies the named contract. “audit --quiet suppresses terminal output” contains no output-suppression assertion. These are present detection gaps, independent of speed.

Finally, audit’s dependence on the suite report it helps generate creates the documented feedback loop. Test audit-report interpretation using synthetic reports in private roots. Investigate remaining 900-second cases with per-command timings and process/lock snapshots before labelling them deadlocks.

This review used the reports and source inspection only; no files were modified or tests executed.