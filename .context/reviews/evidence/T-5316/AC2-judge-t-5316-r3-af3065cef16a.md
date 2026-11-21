===VERDICT===
format: verdict/1
task: T-5316
reviewer: reviewer-judge-t-5316-r3-af3065cef16a:reviewer
round: 1
vote: amber
failed: [2]

## AC2 T-5300 risk matrix scores, actor split and introduced column are sound
Vote: amber
Evidence: "6 risk(s), 0 error(s)"
Location: command: python3 lib/risk_register.py --matrix docs/reports/T-5300-risk-matrix.md
Evidence: "Mitigated impact stays 3: no detection-and-recovery control exists yet that would make the loss a delay only (T-5329 would add the count) | 2 | 3 | 6 | 2 × 3 | 6 |"
Location: docs/reports/T-5300-risk-matrix.md:54
Evidence: "The harm drops to a delay (minor), not a wrong result."
Location: docs/reports/T-5300-risk-matrix.md:60
Evidence: "A late completion of a withdrawn attempt is `done_conflict`, so no wrong result is recorded; what remains is a wasted run (minor)."
Location: docs/reports/T-5300-risk-matrix.md:72
Rule: criterion step 3: "Check ... each mitigated value against the mitigation it names"
Conclusion: The check passes and the scores, actor coverage and Exists/Introduced columns hold, but the mitigation paragraph for 2.1 still claims the impact drops to minor while the row and the acceptance list keep it at 3, so the mitigated value contradicts the mitigation text the operator is told to read.
Guidance: Fix the risk 2 mitigation paragraph (docs/reports/T-5300-risk-matrix.md:60) so it agrees with row 2.1: delete or reword "The harm drops to a delay (minor), not a wrong result." to say the impact stays moderate (3) until a detection control (T-5329) lets the submitter notice and re-allocate; scores and the acceptance list need not change. Secondary, check while there: the risk 3 mitigation (line 72) drops 3.1/3.4 impact to 2 because done_conflict refuses the late completion, but a job that runs anyway can still act on its own (an AEF judge seat records verdict rows and commits itself; lib/verdict_ledger.py does not consult lib/dispatch_records.py state); state that the reduction assumes a run's only effect is its completion record, or justify it.

## Counter-search
Searched: every row's L and I against the Scales table; the Exists/Introduced columns against the wc/0.3.3 baseline; lib/dispatch_records.py for OUTCOMES and the withdraw writers; lib/ for any reader of dispatch-record state that would gate a late run's side effects.
Found: all scores are on the scales and multiply correctly; all five actors are scored per risk; risk 1 "no" is defensible (T3w does less than T2+T3 with the same credential); risks 2, 3, 5 NEW and 4 PARTLY NEW match the baseline; "withdrawn" is in OUTCOMES (dispatch_records.py:49). The only inconsistency is the risk 2 paragraph; the risk 3 side-effect point is unverified either way.

## Change-my-mind
Line 60 reworded to agree with the 2 × 3 row (or the row lowered with a named control that actually makes the loss a delay), with the acceptance list consistent with whichever is chosen.
===END===
