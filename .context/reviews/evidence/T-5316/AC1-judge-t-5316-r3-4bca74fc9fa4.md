# Reviewer evidence — T-5316 AC#1

- dispatch: `judge-t-5316-r3-4bca74fc9fa4`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `6cd11e52c9dd075b0c3e8404f19362ee3b3f15d9`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `eab716285cef027e4019d62f608320cb2d43c1d1da79d20f1b63394cbe9a4486`
- result.md sha256: `70bcdb957c4ed409748036652faf29a5fa3c9b4133bd2687f4bc29251af00e80`

## The worker's verdict block

```
## AC1 Risk matrix scores, actor split and introduced column are sound
Vote: red
Evidence: "5 risk(s), 0 error(s)"
Location: command: cd "$TMPDIR/run" && python3 lib/risk_register.py --matrix docs/reports/T-5309-risk-matrix.md
Evidence: "the suffix must be the seat's own dispatch id and `not_attached` images never count, so a collision or over-cap image no longer counts as viewed"
Location: docs/reports/T-5309-risk-matrix.md:83
Evidence: "Risk 4 left the list on 2026-11-21: control (a) shipped as T-5324 (3900dfbbf), mitigated 1 × 3 = 3."
Location: docs/reports/T-5309-risk-matrix.md:119
Evidence: "attached: 20 not_attached: 1"
Location: command: python3 "$TMPDIR/risk4_repro.py"
Evidence: "not_attached hash among attached: False"
Location: command: python3 "$TMPDIR/risk4_repro.py"
Evidence: "image_viewed(not_attached path, distinct hash): True"
Location: command: python3 "$TMPDIR/risk4_repro.py"
Evidence: "out[Path(str(a[\"path\"])).name] = True"
Location: lib/vote_checker.py:382
Evidence: "if a == b:"
Location: lib/vote_checker.py:492
Evidence: "return True"
Location: lib/vote_checker.py:493
Rule: Check each mitigated value against the mitigation it names; every score must fit the scales.
Conclusion: Although the validator passes, risk 4.1's reduced likelihood and removal from operator acceptance rely on a claimed exclusion that a reproducible filename collision bypasses.
Guidance: Return risk 4.1 to the drafting agent: retain impact 3 and provisionally restore mitigated likelihood 2 (score 6), including risk 4 in operator acceptance, until the remaining route is fixed or a supported residual-likelihood assessment justifies 1. The reproduction uses 21 valid PNGs under allowed evidence paths; the first and last have the same basename in different directories and different content hashes, and the last is falsely counted without any logged image view. Preserve path identity or otherwise prevent this collision, add this regression case, and reassess the mitigation. Also reconcile line 89's contradictory assertion that no mitigation exists yet.
```

## The worker's full output (result.md)

```
===VERDICT===
format: verdict/1
task: T-5316
reviewer: independent-reviewer-r3
round: 1
vote: red
failed: [1]

## AC1 Risk matrix scores, actor split and introduced column are sound
Vote: red
Evidence: "5 risk(s), 0 error(s)"
Location: command: cd "$TMPDIR/run" && python3 lib/risk_register.py --matrix docs/reports/T-5309-risk-matrix.md
Evidence: "the suffix must be the seat's own dispatch id and `not_attached` images never count, so a collision or over-cap image no longer counts as viewed"
Location: docs/reports/T-5309-risk-matrix.md:83
Evidence: "Risk 4 left the list on 2026-11-21: control (a) shipped as T-5324 (3900dfbbf), mitigated 1 × 3 = 3."
Location: docs/reports/T-5309-risk-matrix.md:119
Evidence: "attached: 20 not_attached: 1"
Location: command: python3 "$TMPDIR/risk4_repro.py"
Evidence: "not_attached hash among attached: False"
Location: command: python3 "$TMPDIR/risk4_repro.py"
Evidence: "image_viewed(not_attached path, distinct hash): True"
Location: command: python3 "$TMPDIR/risk4_repro.py"
Evidence: "out[Path(str(a[\"path\"])).name] = True"
Location: lib/vote_checker.py:382
Evidence: "if a == b:"
Location: lib/vote_checker.py:492
Evidence: "return True"
Location: lib/vote_checker.py:493
Rule: Check each mitigated value against the mitigation it names; every score must fit the scales.
Conclusion: Although the validator passes, risk 4.1's reduced likelihood and removal from operator acceptance rely on a claimed exclusion that a reproducible filename collision bypasses.
Guidance: Return risk 4.1 to the drafting agent: retain impact 3 and provisionally restore mitigated likelihood 2 (score 6), including risk 4 in operator acceptance, until the remaining route is fixed or a supported residual-likelihood assessment justifies 1. The reproduction uses 21 valid PNGs under allowed evidence paths; the first and last have the same basename in different directories and different content hashes, and the last is falsely counted without any logged image view. Preserve path identity or otherwise prevent this collision, add this regression case, and reassess the mitigation. Also reconcile line 89's contradictory assertion that no mitigation exists yet.

## Counter-search
Searched: All five summary rows and actor tables, scales, baseline, mitigation explanations, attachment construction, image matching, panel closure logic, and existing T-5309/T-5324 tests.
Found: Arithmetic validation reports zero errors; all 23 image-proof and stem-match tests pass. T-5324 rejects arbitrary suffixes and filters explicitly excluded manifest entries, but subsequently discards directory identity and accepts equal stems. The existing tests do not prevent the reproduced over-cap collision. No additional concrete score or baseline-classification defect was established.

## Change-my-mind
A regression run where the distinct, over-cap same-basename image returns False, together with a reconciled risk-4 explanation and supported residual score; alternatively, a matrix that acknowledges this remaining route and retains its unmitigated score and operator-acceptance entry.
===END===
```
