# Reviewer evidence — T-5316 AC#2

- dispatch: `judge-t-5316-r3-e49c0dd0f805`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `0b4c1242b6898f456ce934a08d146807fdb5aa34`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `39ec74147249c3f856c8eafa46a1180972bf299d9f867d94530873da2c038d9b`
- result.md sha256: `9e2a56bf1f201a574f2bb03997c651eb8d94b3a1d4976122c21da9ba902e5074`

## The worker's verdict block

```
## AC2 Risk matrix scores, actor split and introduced column are sound
Vote: amber
Evidence: "6 risk(s), 0 error(s)"
Location: command: cd "$TMPDIR/run" && python3 lib/risk_register.py --matrix docs/reports/T-5300-risk-matrix.md
Evidence: "18 passed in 2.55s"
Location: command: cd "$TMPDIR/run" && python3 -m pytest -q tests/unit/test_t5312_withdraw.py
Evidence: "no (a new verb for an existing credential; it can do less than T2+T3)"
Location: docs/reports/T-5300-risk-matrix.md:29
Evidence: "Evidence for T3/T3b/T5/T7b is the signed completion of §6.5, so a reconciler cannot assert more than the supervisor persisted."
Location: docs/specs/shared-worker-contract-transitions.md:435-436
Evidence: "if not self._bound(record, att, evidence):"
Location: lib/dispatch_records.py:532
Evidence: "return (isinstance(evidence, dict) and signature_valid(evidence, self.key)"
Location: lib/dispatch_records.py:369
Evidence: "self._move(att, \"done\", writer, \"T3w\", evidence_digest=digest, actor=actor, reason=reason)"
Location: lib/dispatch_records.py:580
Rule: Every actor's explanation must support its score and baseline comparison; "no risk the change adds is marked \"no\"".
Conclusion: Arithmetic, actor coverage and most mitigation assessments hold, but risk 1 incorrectly equates possession of attempt credentials with the additional signed evidence needed for baseline T3 completion, overlooking the new credential-only terminal capability.
Guidance: Return risk 1's Summary row and actor explanations to the drafting agent: retain baseline availability abuse as existing, but mark the credential-only terminal capability PARTLY NEW, or split it into an explicitly introduced sub-risk. A credential thief without host control or the signing key cannot necessarily perform T3 failed or stop the supervisor. Retaining L=1, I=3 for outsider row 1.3 is reasonable; the needed correction is its capability explanation and the introduced column, not an arbitrary score increase. Distinguish credential theft from full host compromise in rows 1.4–1.5, and qualify row 4.3's claim that a channel reader can complete an attempt. Re-run the acceptance calculation after correcting the classification.
```

## The worker's full output (result.md)

```
===VERDICT===
format: verdict/1
task: T-5316
reviewer: rung-3-termlink-single-reviewer
round: 1
vote: amber
failed: [2]

## AC2 Risk matrix scores, actor split and introduced column are sound
Vote: amber
Evidence: "6 risk(s), 0 error(s)"
Location: command: cd "$TMPDIR/run" && python3 lib/risk_register.py --matrix docs/reports/T-5300-risk-matrix.md
Evidence: "18 passed in 2.55s"
Location: command: cd "$TMPDIR/run" && python3 -m pytest -q tests/unit/test_t5312_withdraw.py
Evidence: "no (a new verb for an existing credential; it can do less than T2+T3)"
Location: docs/reports/T-5300-risk-matrix.md:29
Evidence: "Evidence for T3/T3b/T5/T7b is the signed completion of §6.5, so a reconciler cannot assert more than the supervisor persisted."
Location: docs/specs/shared-worker-contract-transitions.md:435-436
Evidence: "if not self._bound(record, att, evidence):"
Location: lib/dispatch_records.py:532
Evidence: "return (isinstance(evidence, dict) and signature_valid(evidence, self.key)"
Location: lib/dispatch_records.py:369
Evidence: "self._move(att, \"done\", writer, \"T3w\", evidence_digest=digest, actor=actor, reason=reason)"
Location: lib/dispatch_records.py:580
Rule: Every actor's explanation must support its score and baseline comparison; "no risk the change adds is marked \"no\"".
Conclusion: Arithmetic, actor coverage and most mitigation assessments hold, but risk 1 incorrectly equates possession of attempt credentials with the additional signed evidence needed for baseline T3 completion, overlooking the new credential-only terminal capability.
Guidance: Return risk 1's Summary row and actor explanations to the drafting agent: retain baseline availability abuse as existing, but mark the credential-only terminal capability PARTLY NEW, or split it into an explicitly introduced sub-risk. A credential thief without host control or the signing key cannot necessarily perform T3 failed or stop the supervisor. Retaining L=1, I=3 for outsider row 1.3 is reasonable; the needed correction is its capability explanation and the introduced column, not an arbitrary score increase. Distinguish credential theft from full host compromise in rows 1.4–1.5, and qualify row 4.3's claim that a channel reader can complete an attempt. Re-run the acceptance calculation after correcting the classification.

## Counter-search
Searched: All six Summary rows, all thirty actor rows, mitigation paragraphs, writer-authentication rules, completion signature validation, withdrawal implementation, production call sites and withdrawal tests.
Found: Risks 2–4 correctly retain residual scores of 6, 6 and 8; the reader and withdrawal controls have supporting code and passing tests. Baseline T2 does allow credential-based interference, supporting an existing availability risk. However, a scratch-copy probe accepted T2 with attempt credentials, rejected unsigned T3 failed with forbidden_transition, and accepted T3w without a completion signature; baseline interference does not establish the claimed equivalence of terminal capabilities.

## Change-my-mind
A corrected matrix explicitly classifying credential-only terminal withdrawal as partly new, or evidence that baseline holders of only nonce, supervisor token and generation could produce an accepted terminal completion without an additional signing credential, trusted evidence channel or host control.
===END===
```
