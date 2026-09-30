VERDICT: red
FINDINGS:
  - severity: high
    where: lib/verdict_ledger.py:1271
    what: Panel requirements remain optional outside judge. A real review dispatch can record a non-render green with a lower `--rung` and no `--run-id`; `_run_fault` accepts it and `_panel_fault` returns success without a run. The ledger never checks the task’s required IW-7 rung or an existing incomplete panel. A producer can request a single review and apply it to a task requiring three vendors, without forging signatures.
    fix: Compute required review strength in shared policy code, enforce it at record/apply, and require dispatches to be bound to their authorized run before launch. Permit reductions only through a validated, recorded ceiling decision. Add an application negative control for an unbound lower-rung review of a high-impact task.

  - severity: medium
    where: lib/verdict_ledger.py:511
    what: A signed start still does not establish that a reviewer ran. Public registration supplies the caller a secret; Python `start()` accepts that secret without runtime authentication, and `complete()` signs fabricated exit/result files and ledger rows. `tests/unit/t3580_round5_test.py:215` explicitly calls `_never_ran`, then start/complete, and expects apply to tick. A producer impersonating the worker can therefore manufacture completion without reading the signing key. This is within the documented same-user residual, but the claimed never-run protection is incomplete.
    fix: Issue completion capabilities through the spawning runtime rather than caller-accessible registration, authenticate start/completion in the shared implementation, and replace this control with a refusal test plus a positive control that actually launches a worker.

  - severity: low
    where: lib/verdict_ledger.py:378
    what: Vendor verification trusts the working-tree registry, including uncommitted declarations of worker kinds the dispatcher cannot launch. The three-vendor positive control uses exactly such a registry. It proves mapping consistency, not three independently executed vendors.
    fix: Validate vendor provenance against an approved registry revision and launchable runtime adapters; add a negative control for uncommitted or unsupported vendor declarations.

OVERALL: Read-only inspection confirms the three round-2 assertion gaps were restored and ordinary same-kind panels fail closed, but ledger-level rung bypass prevents approval; tests were not rerun.