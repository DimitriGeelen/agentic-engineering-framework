Now let me look at the CLI wiring, the gate ordering in update-task.sh, judge_verdict, and `_render_surface` in delegation_cli.
Tests pass as claimed. Let me empirically confirm the load-bearing forgery vector (self-review under a different string, and a hand-appended ledger line) in a sandbox under `/tmp/opencode` — no writes to the repo.
Confirmed. Now the hand-appended ledger line (no `record` call at all):
```
VERDICT: red
FINDINGS:
  - severity: high
    where: lib/verdict_ledger.py:293-297 (record), :244 (--reviewer is a free string)
    what: The independence guarantee is self-asserted. Nothing binds `--reviewer` to a real
          independent process, session, or dispatch — no authentication, no provenance, no
          signature. The check only proves the reviewer STRING differs from derived producer
          strings (git author/committer/Co-Authored-By + `producer:` frontmatter). I verified
          end-to-end in a sandbox: an agent that committed work as "Claude Sonnet 5.5" recorded
          a green as `--reviewer "independent-reviewer-session-7"`, apply() ticked the criterion
          and flipped owner human→agent, and R-033 then let the close through — zero refusal
          rows, zero bypass-log entries. Two quieter evasions: (a) record before any commit
          exists (producer set empty; the apply-time re-check at :374 only compares strings,
          so a pseudonym still passes); (b) commit work via `git commit --no-verify` without
          referencing the task id — producers() (:196-229) derives from `--grep=task_id`, so
          the producer set stays empty and even the agent's true name passes. The docstring
          honestly discloses identity-vs-role (:47-50), but the effect is that R-033 — a
          sovereignty gate — is now satisfiable by unauthenticated agent-written data, where
          the old path required three LOUD, logged bypasses.
    fix: Not fixable by string comparison alone. Minimum to lift to amber: (1) bind reviewer
          identity to a provenance channel the producer cannot write — slice 3's dispatch
          (verdict rows must carry the dispatch id from `fw reviewer judge`, and apply rejects
          rows whose dispatch id equals a producer dispatch; producers() already extracts
          dispatch ids from `dispatch+TXXXX-xx@aef.local` emails); (2) at apply, resolve the
          commit that introduced each satisfying row (`git log --all -S"<id>" --
          .context/reviews/verdicts.jsonl`) and refuse when it is missing, uncommitted, or
          authored by a producer identity; (3) log every `record` invocation with the invoking
          session env (TERMINK/Claude session id), not just the asserted reviewer string.
          Until at least (1) or (2) lands, keep `fw reviewer verdict record` human-gated
          (Tier-0-style) and get explicit operator acceptance of the residual gap — accepting
          it is itself a sovereignty/risk call, which T-3557 reserves for the human.

  - severity: high
    where: lib/verdict_ledger.py:363-377 (satisfying), :119-123 (_append)
    what: Ledger rows are trusted at read time on five fields only (task, ac, ac_digest,
          outcome==green, reviewer≠producer). A hand-appended JSONL line — no judgement block,
          no record-time class check, no evidence check, no refusal trace — is honoured
          identically to a real record. Verified: appending a fabricated green for a taste
          criterion ticked it and handed ownership to the agent. The one protection (apply
          re-classifies, so operator-only criteria stay refused — test at
          test_t3579_verdict_ledger.py:182) does not extend to provenance. Detection: none
          automated — `fw audit` does not read .context/reviews at all (grep confirms no
          consumer outside verdict_ledger.py), and the only artefact, the applied.jsonl
          verdict-apply row, is indistinguishable from a legitimate one. Tier-1 hooks do not
          restrict writes to .context/reviews (any focused task authorises it).
    fix: Validate row shape at read (require judgement.contract=="judge_verdict/1" and
          judgement.judge==row.reviewer); add the introducing-commit provenance check above;
          add an `fw audit` line that cross-checks every verdicts.jsonl row against its
          introducing commit and flags rows whose introducer is a producer of the task or is
          uncommitted. Accept + document only if the operator explicitly signs off on
          honour-system ledger rows.

  - severity: medium
    where: lib/verdict_ledger.py:389-405 (render_verdicts) vs agents/task-create/update-task.sh:569
    what: The P-013 render gate is satisfied by a green on ANY human criterion — unlike
          apply(), render_verdicts does not re-classify. Two consequences: (a) a green on an
          unrelated taste criterion satisfies the render gate while the render [REVIEW]
          criterion itself is amber; (b) since the digest covers only the checkbox line
          (delegation.py Criterion.title), a criterion body edited after the verdict to
          carry tier0/act-in-the-world vocabulary keeps its digest and still satisfies the
          render gate even though apply would now refuse to tick it. apply() has the classify
          filter (:438-440); the read side of the same gate does not.
    fix: In render_verdicts, run the same `classify(...) != REVIEWER_JUDGES → skip` filter as
          apply, and restrict to the criterion(s) that made the task render-surface (or at
          minimum require the verdict's criterion to carry the [REVIEW] prefix). Add a
          negative-control test: green on AC#1 (non-render), amber on the render AC → gate
          must not pass.

  - severity: low
    where: lib/verdict_ledger.py:126-139 (_read)
    what: A torn/unparseable final line is skipped silently, so latest-record-wins (:375) can
          fail OPEN: corrupt or truncate exactly the deciding red line and an earlier green
          resurrects. The tolerance is deliberate but this direction is the wrong one for a
          withdrawal record.
    fix: When a non-blank unparseable line is dropped, append a refusal row (class
          "torn-ledger-line") and treat any (task,ac,digest) that appeared before it as
          undecided — or accept + document with the wording: "a torn ledger line invalidates
          only itself; an attacker who can corrupt the file can already append a green, so
          this tolerance buys availability, not safety."

  - severity: low
    where: tests/unit/test_t3579_verdict_ledger.py (gaps)
    what: Negative controls exist for class refusal, producer refusal (5 identity variants),
          digest edit/stale digest, missing evidence, non-green-no-guidance, later-producer
          withdrawal, forged operator-only row — good. Missing: no-task, task-closed,
          already-ticked, no-reviewer, no-rung refusals; no torn-line test; no
          render-gate-with-unrelated-green test (finding 3); no test that a hand-appended row
          WITHOUT a judgement block is refused (it currently isn't — finding 2).
    fix: Parametrize the five uncovered refuse() branches; add the two tests above.

  - severity: low
    where: lib/verdict_ledger.py:302-304, :450-452
    what: Evidence paths accept absolute paths (`root / "/etc/passwd"` → Path("/etc/passwd")
          exists), so "under the repo" is not enforced; and evidence existence is not
          re-checked at apply, so paths can dangle after record. Cosmetic for integrity, but
          the record's audit claim ("evidence path(s) not found under the repo") overstates.
    fix: Reject `os.path.isabs(e)` and any path resolving outside root (resolve +
          is_relative_to); accept + document the no-recheck-at-apply as the recorded-at-record-
          time contract.

OVERALL: The mechanics are unusually well-built — dual-time producer check, class re-derived
at both record and apply with risk-first precedence, T-1985 digest invalidation everywhere,
latest-red-withdraws-green, escalate never greenwashes, malformed rows and unknown outcomes
fail closed, tests pass with real negative controls — but the one property the whole path
stands on (independence) is an unauthenticated self-asserted string over an honour-system
JSONL file with no audit consumer, and I closed a human-owned task with its own producer's
hands, silently, in under a minute; not safe as the normal close path until reviewer identity
is bound to provenance the producer cannot write (dispatch id or introducing-commit check)
and the ledger is under audit — the mechanism is fine, the trust model is not yet.
```
