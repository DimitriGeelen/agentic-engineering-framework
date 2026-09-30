VERDICT: red
FINDINGS:

  - severity: high
    where: lib/verdict_ledger.py:438
    what: Completion attribution remains self-asserted through a public signing command. `complete` checks a removable environment variable and caller-writable exit file, derives the session from the dispatch ID, and signs matching rows from the shared ledger without establishing that the worker produced them. An ordinary caller can manufacture completion without reading the signing key. Duplicate-completion rejection only helps if the real runtime subsequently completes.
    fix: Require a runtime-authenticated completion tied to the launched worker session and its emitted verdict manifest; validate that manifest against ledger rows instead of constructing it from them. Add a negative control where a registered dispatch never runs but a caller supplies exit/result files and invokes `complete`; apply must refuse.

  - severity: high
    where: lib/reviewer/judge_cli.py:775
    what: Panel diversity counts backend IDs as vendors. Three registry entries with distinct IDs but the same `--worker-kind claude` dispatch three Claude workers, suppress the degradation warning, and satisfy `_panel_fault` because its vendor set contains three backend IDs.
    fix: Register the actual vendor identity with dispatch provenance, verify bindings against it, and count distinct verified vendors in the ledger. Add an application negative control with three backend aliases for the same worker kind.

  - severity: medium
    where: agents/termlink/termlink.sh:1190
    what: `wait` returns when `exit_code` exists, but runtime completion signing happens afterward. Judge can collect before the completion exists, report unknown, and stop further panel dispatches despite a successful worker. The runtime tests wait for all of run.sh to finish, so they miss this race.
    fix: Publish a runtime-finalized marker after completion signing succeeds or fails, and make review-dispatch waits require it. Test delayed signing through the actual wait-and-collect path.

OVERALL: The three previously weakened assertions now have specific coverage, and capture/revision enforcement improved, but attribution and vendor-diversity gaps still permit unsupported greens; this review was read-only and did not rerun tests.