# Reviewer evidence — T-5316 AC#1

- dispatch: `judge-t-5316-r3-0b1025f81dcf`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `70082ff140d9bd1db199d96b4108cb8f3086fcad`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `293274363432525591bd0997ddb2c050805fa994e2b5fa553a6475b51b487ac1`
- result.md sha256: `f3e0cd2a7d756eeaab9b692d0d8ee12f3c6f5fb0f4dd4323e55fae53e644fba8`

## The worker's verdict block

```
## AC1 Risk matrix scores, actor split and introduced column are sound
Vote: red
Evidence: "5 risk(s), 0 error(s)"
Location: command: cd "$TMPDIR/run" && python3 lib/risk_register.py --matrix docs/reports/T-5309-risk-matrix.md
Evidence: "Mitigation for 2.3: a rung-5 render criterion needs unanimous green from three vendors' seats, each verdict structured and checked; one seat swayed cannot close it, and swaying all three with one image is rare."
Location: docs/reports/T-5309-risk-matrix.md:59
Evidence: "Mitigation for 3.1 and 3.4: a wrong close needs the other two vendors' seats to be wrong green on the same criterion as well; a codex red keeps the criterion open."
Location: docs/reports/T-5309-risk-matrix.md:71
Evidence: "want = PANEL_SIZE if rung >= 5 else 1"
Location: lib/reviewer/judge_cli.py:1347
Evidence: "MIN_EVALUATING_SEATS = 2"
Location: lib/verdict_ledger.py:210
Evidence: "degradable = (review_policy.rung_number(run.get(\"rung\")) or 0) >= 5 and green_degraded_enabled(root)"
Location: lib/verdict_ledger.py:3724
Evidence: "| 3.4 | provider-host | OpenAI changes how `-i` images are passed or downscaled, silently, and the model sees less than the file | 2 | 3 | 6 | 1 × 3 | 3 |"
Location: docs/reports/T-5309-risk-matrix.md:68
Evidence: "    mitigated_likelihood: 2"
Location: docs/reports/T-5309-risk-matrix.md:178
Evidence: "    mitigated_impact: 2"
Location: docs/reports/T-5309-risk-matrix.md:179
Evidence: "no (same text, new medium; the seat is sandboxed: network off, writes only to the disposable export)"
Location: docs/reports/T-5309-risk-matrix.md:30
Evidence: "codex `vision: false` (T-5289), so codex was not seated on render criteria and no screenshot was sent to OpenAI by the review runtime"
Location: docs/reports/T-5309-risk-matrix.md:10
Rule: Every score must fit the scales, each mitigated value must follow its named mitigation, and no risk the change adds may be marked "no".
Conclusion: Although the arithmetic checker passes and all five actor categories are present for every risk, the mitigation assumptions overstate enforced panel protection, the provider-host residual contradicts its register entry, and risk 2 overlooks the newly countable codex image-injection route.
Guidance:
  Return the matrix to the drafting agent for these corrections:
  1. Risks 2.3, 3.1 and 3.4: distinguish single-seat reviews, full panels and panels closing with only two evaluating vendors; the implementation does not universally require three green vendors. For single-seat reviews, retain the existing unmitigated values of 2 × 3 = 6, 3 × 3 = 9 and 2 × 3 = 6 respectively unless another applicable control supports a reduction. Reassess panel residuals against the actual closure rules.
  2. Risk 3 provider-host register entry: reconcile lines 178–179 with row 3.4. The named panel mitigation reduces the chance of an incorrect result; it does not explain reducing that result's impact from moderate (3) to minor (2). Keep impact 3 and use the likelihood justified for the applicable review mode.
  3. Risk 2 Summary: change "Introduced by the change?" to PARTLY NEW. Screenshot injection existed for other seats, but this change exposes codex to image instructions and makes its render votes count against a baseline where it could not sit those criteria. Existing text exposure and filesystem isolation do not eliminate that additional review-integrity route. Update the Net and register descriptions and regenerate the operator-acceptance list.
```

## The worker's full output (result.md)

```
===VERDICT===
format: verdict/1
task: T-5316
reviewer: independent-reviewer
round: 1
vote: red
failed: [1]

## AC1 Risk matrix scores, actor split and introduced column are sound
Vote: red
Evidence: "5 risk(s), 0 error(s)"
Location: command: cd "$TMPDIR/run" && python3 lib/risk_register.py --matrix docs/reports/T-5309-risk-matrix.md
Evidence: "Mitigation for 2.3: a rung-5 render criterion needs unanimous green from three vendors' seats, each verdict structured and checked; one seat swayed cannot close it, and swaying all three with one image is rare."
Location: docs/reports/T-5309-risk-matrix.md:59
Evidence: "Mitigation for 3.1 and 3.4: a wrong close needs the other two vendors' seats to be wrong green on the same criterion as well; a codex red keeps the criterion open."
Location: docs/reports/T-5309-risk-matrix.md:71
Evidence: "want = PANEL_SIZE if rung >= 5 else 1"
Location: lib/reviewer/judge_cli.py:1347
Evidence: "MIN_EVALUATING_SEATS = 2"
Location: lib/verdict_ledger.py:210
Evidence: "degradable = (review_policy.rung_number(run.get(\"rung\")) or 0) >= 5 and green_degraded_enabled(root)"
Location: lib/verdict_ledger.py:3724
Evidence: "| 3.4 | provider-host | OpenAI changes how `-i` images are passed or downscaled, silently, and the model sees less than the file | 2 | 3 | 6 | 1 × 3 | 3 |"
Location: docs/reports/T-5309-risk-matrix.md:68
Evidence: "    mitigated_likelihood: 2"
Location: docs/reports/T-5309-risk-matrix.md:178
Evidence: "    mitigated_impact: 2"
Location: docs/reports/T-5309-risk-matrix.md:179
Evidence: "no (same text, new medium; the seat is sandboxed: network off, writes only to the disposable export)"
Location: docs/reports/T-5309-risk-matrix.md:30
Evidence: "codex `vision: false` (T-5289), so codex was not seated on render criteria and no screenshot was sent to OpenAI by the review runtime"
Location: docs/reports/T-5309-risk-matrix.md:10
Rule: Every score must fit the scales, each mitigated value must follow its named mitigation, and no risk the change adds may be marked "no".
Conclusion: Although the arithmetic checker passes and all five actor categories are present for every risk, the mitigation assumptions overstate enforced panel protection, the provider-host residual contradicts its register entry, and risk 2 overlooks the newly countable codex image-injection route.
Guidance:
  Return the matrix to the drafting agent for these corrections:
  1. Risks 2.3, 3.1 and 3.4: distinguish single-seat reviews, full panels and panels closing with only two evaluating vendors; the implementation does not universally require three green vendors. For single-seat reviews, retain the existing unmitigated values of 2 × 3 = 6, 3 × 3 = 9 and 2 × 3 = 6 respectively unless another applicable control supports a reduction. Reassess panel residuals against the actual closure rules.
  2. Risk 3 provider-host register entry: reconcile lines 178–179 with row 3.4. The named panel mitigation reduces the chance of an incorrect result; it does not explain reducing that result's impact from moderate (3) to minor (2). Keep impact 3 and use the likelihood justified for the applicable review mode.
  3. Risk 2 Summary: change "Introduced by the change?" to PARTLY NEW. Screenshot injection existed for other seats, but this change exposes codex to image instructions and makes its render votes count against a baseline where it could not sit those criteria. Existing text exposure and filesystem isolation do not eliminate that additional review-integrity route. Update the Net and register descriptions and regenerate the operator-acceptance list.

## Counter-search
Searched: All five Summary rows, all 25 actor rows, mitigation explanations, register proposals, evidence-copy and attachment code, image matching, vision gating, seat selection and ledger panel closure rules.
Found: Arithmetic and actor coverage pass; risks 1, 3 and 4 acknowledge added exposure, and the checker confirms the reported acceptance list. However, vision gating does not force every image review to rung 5, and the ledger permits fewer than three evaluating vendors. The register's different residual for risk 3 has no supporting mitigation explanation.

## Change-my-mind
A revised matrix that scores residuals for the actual single-seat and panel closure modes, consistently retains impact 3 for risk 3 unless a severity-reducing control is demonstrated, and marks risk 2's added codex image-injection route PARTLY NEW would resolve these findings.
===END===
```
