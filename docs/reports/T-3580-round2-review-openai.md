VERDICT: red
FINDINGS:
  - severity: high
    where: lib/verdict_ledger.py:1198
    what: Worker attribution remains self-asserted. record derives a worker name from dispatch_id and signs a completion from its own newly constructed row; it never verifies an actual fresh worker session or completed dispatch result. An ordinary record call can manufacture that completion for a registered dispatch without explicitly forging a signature.
    fix: Have the worker runtime emit a signed dispatch result containing its actual session identity and completion state; require record and _row_fault to verify that result and its bindings instead of generating it from the submitted row.

  - severity: high
    where: lib/verdict_ledger.py:1204
    what: The reviewed revision is HEAD at record time, not a revision supplied by the completed review. If implementation changes during review without changing the criterion, the resulting verdict is silently attributed to the newer revision.
    fix: Capture the reviewed SHA before review, bind it into the worker result, and require record to use and verify that SHA; add a negative control where implementation changes between review and recording.

  - severity: high
    where: lib/reviewer/judge_cli.py:320
    what: Page discovery silently truncates required pages to six. For a criterion naming seven pages, the seventh is neither captured nor registered as required, so the ledger can accept green and apply it without that page ever being seen.
    fix: Preserve every required page in the signed run; if capture is capped, record remaining pages as uncaptured so ledger application refuses green. Add a seven-page application negative control.

  - severity: medium
    where: lib/verdict_ledger.py:1080
    what: satisfying_verdict reports a latest non-green outcome before validating its completion, attribution or guidance. A committed red with missing completion is reported as red through apply rather than invalid/unknown, although judge's collection path rejects it.
    fix: Run _fault before branching on outcome and report invalid rows as unknown consistently across consumers.

  - severity: medium
    where: lib/reviewer/judge_cli.py:485
    what: The worker command single-quotes reviewer-$FW_SIDECAR_AGENT_ID, preventing shell expansion. Following the brief literally submits an identity that record rejects. FakeWorker constructs the correct identity directly and therefore misses this defect.
    fix: Double-quote the reviewer argument and add a shell-expansion check against the actual generated command.

  - severity: medium
    where: tests/unit/test_t3581_round4.py:55
    what: The assertion now accepts “tampered” instead of requiring “guidance”. This masks loss of the missing-guidance check: the fixture invalidates the completion hash before guidance validation is reached.
    fix: Retain a separate tampering test; make the missing-guidance fixture carry a matching signed completion and require the no-guidance failure.

  - severity: medium
    where: tests/unit/test_t3579_verdict_ledger.py:808
    what: “introduced by producer” was weakened to “introduced by”, allowing the different-worker check to satisfy a test intended to prove producer exclusion.
    fix: Restore a producer-specific assertion and construct a fixture that passes exact-worker attribution while independently exercising producer exclusion.

  - severity: low
    where: tests/unit/test_t3579_verdict_ledger.py:479
    what: “no commit references” was weakened to “no commit”, allowing the no-HEAD check to replace coverage of missing task-specific producer provenance.
    fix: Keep separate tests for an empty repository and a repository with commits but no task producer; assert the specific refusal in each.

OVERALL: Read-only inspection confirms the three loosened older message assertions, improved ledger enforcement for registered captures and panels, hard-class precedence, visible rung reductions and honest T-3582 degradation, but attribution and unseen-page gaps remain; no files were modified or tests run.