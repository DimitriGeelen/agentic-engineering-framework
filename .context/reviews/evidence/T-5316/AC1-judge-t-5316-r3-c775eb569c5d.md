===VERDICT===
format: verdict/1
task: T-5316
reviewer: reviewer-judge-t-5316-r3-c775eb569c5d:reviewer
round: 1
vote: green
failed: []

## AC1 T-5309 risk matrix scores, actor split and introduced column are sound
Vote: green
Evidence: "5 risk(s), 0 error(s)"
Location: command: python3 lib/risk_register.py --matrix docs/reports/T-5309-risk-matrix.md
Evidence: "| 3 | An attached image is counted as viewed although the model did not examine it | review integrity |"
Location: docs/reports/T-5309-risk-matrix.md:31
Evidence: "a, b = Path(a).stem.lower(), Path(b).stem.lower()"
Location: lib/vote_checker.py:491
Evidence: "AREAS = (\".context/working/judge-evidence/\", \".context/visual/\")"
Location: lib/review_seat_evidence.py:35
Evidence: "want = PANEL_SIZE if rung >= 5 else 1"
Location: lib/reviewer/judge_cli.py:1347
Rule: criterion: "the check prints 0 error(s); every score fits the scales; every actor that can plausibly cause the risk is scored; no risk the change adds is marked \"no\", and none it does not add is marked NEW"
Conclusion: The check prints 0 errors, every Summary L/I equals its highest actor row and fits the Scales, all five fixed actors are scored for each risk, the code confirms the cited controls and residual routes (path-blind stem match, evidence AREAS, single-seat runs below rung 5), and the NEW / PARTLY NEW / no columns match the Baseline (codex vision false, render votes only on logged views).

## Counter-search
Searched: every Summary row against its actor table (max L, max I); each mitigated value against the control it names (2.3, 3.1, 3.4 single-seat worst case; 4.1 after T-5324); risk 3 "no"/NEW and risk 5 "no" against the Baseline; lib/vote_checker.py _stem_match/image_viewed/attached_images for the T-5324 fix and remaining basename route; lib/verdict_ledger.py MIN_EVALUATING_SEATS = 2 for the two-vendor close.
Found: no score or column error. Non-scoring stale text only: the R-NEW-4 register description (line 201) still says an over-cap or shared-prefix image "is marked viewed", which T-5324 has closed (the remaining route is same basename in different directories, T-5333); the Net acceptance bullet for risk 4 (line 118) words the title differently from the check output and has a sentence about risks 2 and 3 run onto it. Risk 5 "no" is defensible: in the baseline the seat's own log in the same dispatch dir was an equally same-user-writable input that made a vote count.

## Change-my-mind
A code path where a cited image with no dispatch-id-suffixed or same-stem attached counterpart is still counted viewed (would raise 4.1), or a rung 1/3 plan that cannot seat codex alone on an image run (would make the single-seat worst case wrong).
===END===
Notes (non-blocking, for the drafting agent): update the R-NEW-4 description at docs/reports/T-5309-risk-matrix.md:201 and its proposal at line 223 to the post-T-5324 state (same-basename collision, T-5333); copy the risk 4 acceptance line at line 118 verbatim from the check output and move the risk 2/3 panel sentence to its own line.
