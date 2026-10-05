# T-3747 — pre-push red triage, round 5

2026-10-05, unpushed range `d18b0ba01..HEAD` (T-3855 sidecar cross-hub, T-3850/T-3851 vendor
preserve + visibility, T-3860 reindex disk guard, T-3840 sidecar ledger). Starting point: `fw audit
--section structure` with 3 FAILs (dead-negation lint, `tests/lint` invariant, 19 new unit reds).
Method: run each red alone. A red that fails alone is traced to its commit and fixed. A red that
passes alone and has no change in range touching its path is judged load-only and given a task.

## Verdicts

| # | Red | Verdict | Cause | Fix / owner |
|---|-----|---------|-------|-------------|
| 1+2 | Dead-negation lint + `tests/lint` invariant | regression fixed | T-3850 `t3850_vendor_preserve_locals.bats` had six `! echo "$output" \| grep -q …` assertions (bash ignores `!` for errexit) | `fe772013b`: `[[ "$output" != *'…'* ]]`. Lint 13/13, file green |
| 3a | audit cluster: `audit_trend_window` ×2, `audit_stale_arc_warning` ×6, `audit_null_timestamp` ×2, `audit_seed_corpus_refs`, `audit_corpus_lint_findings` ×2 | regression fixed | T-3855 `056481049` added `has_inbox()` → FAIL "Sidecar inbox with nothing to wake it". It counted `.context/sidecar/hub-id` and a bare `outbox/` as an inbox. Audit's own read-only sidecar checks (ledger, DM-stale) derive the address, which writes the `hub-id` cache and creates an empty `outbox/` in the project being audited. So every scratch project failed on side effects of the audit itself. Reproduced: a bare scratch repo gave `audit --section structure` exit 2 with that single FAIL | `0572aa9d3`: only `inbox-state.json`, `watcher/enabled.json` or a real file in `outbox/` count. Vendor `39151d82b`. Scratch audit now exits 1 (WARN only). 5 files, 28/28 green; `test_sidecar_cross_hub_t3855.py` 29/29 |
| 3b | `fw_init_atomic` "an interrupted init is recoverable by re-running fw init" | regression fixed | T-3850 `3698a44c1` made `fw vendor` refuse when it would delete files it did not write. The killed first init left an rsync temp file (`docs/reports/arc-012-review/.SYNTHESIS.md.XXXXXX`) in the partial copy. The recovery init's `do_vendor` read that file as a consumer local and refused | `be6e0c7f6`: `lib/init.sh` passes `--allow-delete-locals` only when resuming under the `.fw-init-incomplete` marker. Everything there came from the interrupted copy; the debris is still backed up and the Tier-2 bypass logged. The no-marker / no-FRAMEWORK.md case keeps the refusal. Vendor `42c0d0e34`. `fw_init_atomic` 5/5; `t3850` + `upgrade_fresh_machine_simulation` 24/24 |
| 3c | `t3110_worktree_corpus_commit_guard` "guard emits nothing at all on a source-only commit" | load-only | Passes alone (22/22). First red on 10-05. The test runs a real `git commit` through the hook chain and asserts status 0. No change in range touches the guard | T-3869 (filed) |
| 3d | `t3511_parked_merge_guard` "CONTROL: clean merge of a LIVE task's branch succeeds" | load-only | Passes alone (13/13). Runs a real `git merge` through the hook chain; same class as round 4's 3e | T-3845 (existing) |
| 3e | `t3662` "allocation skips a foreign holder" | load-only (flaky even at moderate load) | 3 runs of the file at load average 7–8: tests 2+3 red, then tests 2+3 red, then all green. A standalone `watchtower.sh start` in a temp project passes its health check in about 2 s at idle. The fixed 5 s health window is exceeded under load. The only `web/` change in range (`web/embeddings.py`, T-3860) is lazy-imported, not on the startup path | T-3797 (existing) |
| 3f | `test_task_pair_acd_gate` "T-1442/T-1485 historic regression" | load-only | Passes alone 3/3 repeats (file 8/8). First red on 10-05. Reads a live-repo completed-task fixture | T-3870 (filed) |

## Load-only reds (for the operator)

- `t3110_worktree_corpus_commit_guard.bats`: main checkout: guard emits nothing at all on a source-only commit (T-3869)
- `t3511_parked_merge_guard.bats`: CONTROL: clean merge of a LIVE task's branch succeeds (T-3845)
- `t3662_watchtower_port_allocation.bats`: allocation skips a foreign holder (and sibling test 3, same flake) (T-3797)
- `test_task_pair_acd_gate.bats`: T-1442/T-1485 historic regression (T-3870)

## Side observations

- `VERSION` and `.agentic-framework/VERSION` were pre-staged in the index as `1.8.2 → 1.8.1` and got
  swept into the first commit of this round. That was caught and amended out before any further
  commit, so no committed change touches VERSION. The working-tree `VERSION` now reads `1.8.21`,
  written by something outside this worker. It was left untouched and is **worth a look before
  tagging v1.8.2**.
- The scratch-project audit also emitted host-level WARNs (a DM rail `dm:s3t5-…` unread for 26.6 days):
  host state reaching a project audit. These are WARNs, not FAILs; not in scope here.
