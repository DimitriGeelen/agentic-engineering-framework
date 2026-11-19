# T-5248: upgrade feedback loop

Research artefact for inception T-5248 (filed 2026-11-19, split from T-4649 at the
operator's suggestion: "build in a feedback loop for any projects that does upgrades ...
maybe that's increasing our scope too much").

## Evidence

- 2026-11-19, 055 (msg 485934c1, via the T-4649 consultation): a local fix was LOST SILENTLY
  at their 2026-11-02 upgrade (their T-342, arc page Purpose block; AEF T-3564 replaced the
  section), unnoticed because its tripwires were parked. Ask: `fw upgrade` lists every vendored
  file that differs from the baseline it installed, marked "upstream has an equivalent" or
  "will be lost", and the project confirms before replacement.
- 2026-11-19, 832 (msg afd1515b): 44 declared local changes re-applied by hand at every
  upgrade; at be.60, 37 were overwritten and 3 needed a hand merge.
- Today `fw upgrade` writes no report (screen output only); the `aef-upgrade-report` message
  type in lib/message_router.py is deferred.

## Dialogue Log

- 2026-11-19 (T-4649 walkthrough): operator proposed the loop and sending reports to GitHub
  or an email address; agent raised that GitHub is public (no paths, host details or names)
  and proposed the full report over the sidecar for our own projects, an opt-in cleaned-up
  summary for outside users. **Operator, verbatim:** "yes, send the consultation and file the
  inception".
