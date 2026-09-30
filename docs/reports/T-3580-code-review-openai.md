VERDICT: red
FINDINGS:
  - severity: high
    where: lib/verdict_ledger.py:640
    what: The six worker-attribution requirements are unimplemented. Registration suffices; no signed completion binds a fresh worker session, reviewed revision, criterion digest, evidence hashes, exact verdict contents, or introducing commit to that worker. Any non-producer commit identity can introduce the row.
    fix: Require a signed worker completion containing all six bindings; verify it in record and _row_fault, including exact worker/commit identity equality and revision-bound criterion/evidence checks.

  - severity: high
    where: lib/reviewer/judge_cli.py:488
    what: Failed screenshots only downgrade judge's displayed result. The committed green remains eligible through satisfying_verdict and apply (lib/verdict_ledger.py:1128). Additionally, line 303 discards partial-capture errors, allowing missing pages to escape even the display check.
    fix: Persist per-criterion required pages and capture results in dispatch provenance; reject render greens in the shared ledger validator unless every required page has verified screenshot evidence. Preserve partial failures.

  - severity: high
    where: lib/reviewer/judge_cli.py:553
    what: Panel completion is not enforced by the ledger. If seat one commits green and seat two fails or writes nothing, judge reports unknown but apply can still accept seat one's green.
    fix: Bind rows to a review run with required seats and require valid completed greens from every required seat before satisfying_verdict permits application.

  - severity: medium
    where: lib/reviewer/judge_cli.py:122
    what: Rung selection omits IW-7's medium tier and most impact inputs. Consumer-facing code, blast 3–5, project objectives, cross-project exposure, and uncertainty can default to rung 1.
    fix: Implement the documented low/medium/high mapping using reversibility, components/consumer paths, audience, value and uncertainty; record the inputs and selection reason.

  - severity: medium
    where: lib/reviewer/judge_cli.py:52
    what: Seats labelled claude/codex/opencode all use the same default Claude dispatcher. T-3582 acknowledges this, but runtime output and verdict labels still advertise rung-5 panel independence.
    fix: Dispatch actual vendor-specific workers, or explicitly report single-vendor degraded review and prevent those rows from satisfying a three-vendor requirement.

  - severity: medium
    where: lib/reviewer/judge_cli.py:480
    what: Non-green rows bypass validation entirely. A malformed row containing only task, AC, dispatch ID and outcome amber is reported as amber rather than unknown.
    fix: Validate schema, provenance and committed attribution for every outcome before reporting it; map invalid rows to unknown.

  - severity: medium
    where: tests/unit/t3580_judge_cli_test.py:417
    what: The unseen-page negative control checks only judge's display, never apply or check-render. Panel tests count fake dispatches without proving vendor identity or complete-panel enforcement. FakeWorker supplies no signed completion yet its rows pass.
    fix: Add ledger-application negative controls for failed/partial captures, incomplete panels and each missing worker binding; verify actual dispatcher vendor arguments and malformed non-green handling.

OVERALL: The parent has no verdict-writing path and recognized hard classes take precedence, but attribution and ledger enforcement remain incomplete; this was a read-only review, with no tests executed because the suite writes files and creates commits.