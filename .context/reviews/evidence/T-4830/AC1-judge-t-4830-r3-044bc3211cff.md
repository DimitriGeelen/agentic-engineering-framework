# T-4830 Human AC#1 — Check works in the designer (reviewer judge-t-4830-r3-044bc3211cff)

Revision reviewed: b117430b087f46f3511b9931cb7d7df9daeda0f1
Method: headless Chromium (Playwright) driving the live designer at http://192.168.10.107:3000/designer/app,
1440x900. For each map: Open project… → click map card → ✓ Check → read #findings-state, .finding-row and
the /api/validate response.

## Result: all 16 project maps, HTTP 200 from POST /api/validate, never "could not check: HTTP 403"

| map | /api/validate | validator dock state |
|---|---|---|
| aef-audit-cron | 200 | 1 finding · 0 errors, 1 warning · 0 on the map |
| aef-dispatch-loop | 200 | 1 finding · 0 errors, 1 warning · 0 on the map |
| aef-existing-project-onboarding | 200 | 3 findings · 0 errors, 3 warnings · 1 on the map |
| aef-greenfield-onboarding | 200 | checked · no findings (clean result) |
| aef-inception-flow | 200 | 1 finding · 0 errors, 1 warning · 0 on the map |
| aef-session-lifecycle | 200 | 2 findings · 0 errors, 2 warnings · 0 on the map |
| aef-task-lifecycle | 200 | 4 findings · 0 errors, 4 warnings · 0 on the map |
| aef-tier0-escalation | 200 | 4 findings · 0 errors, 4 warnings · 1 on the map |
| draft-arc-lifecycle | 200 | 3 findings · 0 errors, 3 warnings · 0 on the map |
| draft-continuous-run-loop | 200 | 4 findings · 0 errors, 4 warnings · 0 on the map |
| draft-exception-handling | 200 | 1 finding · 0 errors, 1 warning · 0 on the map |
| draft-inception-readiness | 200 | 3 findings · 1 error, 2 warnings · 1 on the map |
| draft-task-creation | 200 | 3 findings · 0 errors, 3 warnings · 0 on the map |
| draft-t2584-scratch | 200 | 1 finding · 0 errors, 1 warning · 0 on the map |
| draft-knowledge-leveling | 200 | 1 finding · 0 errors, 1 warning · 0 on the map |
| draft-trigger-handling | 200 | 3 findings · 0 errors, 3 warnings · 0 on the map |

The browser's request carried Content-Type: application/json, same origin (Referer .../designer/app). The
response body matched the contract, e.g. {"errors":0,"findings":[{"location":"exclusiveGateway 'agt_gw_hv'",
"message":"gw_ambiguous: ...","rule":"W-XML-GW-AMBIGUOUS","severity":"WARN"},...],"ok":true,"warnings":3}.

## About "0 on the map"
Many maps show "N findings · 0 on the map". This is the designer's own design, not an AEF defect. The vendored
designer code has a set, FINDING_MARKER_EXCLUDED = {'W-XML-GW-AMBIGUOUS'} (T-325/T-962). Those findings are listed
in the dock but get no canvas marker, and every such row is still anchored (data-anchored=1). Findings that can
be marked do get markers: aef-existing-project-onboarding, aef-tier0-escalation and draft-inception-readiness
each report "1 on the map". So markers appear where the designer chooses to draw them, and a clean map shows
"checked · no findings".

## Screenshots
- A-checked-judge-t-4830-r3-044bc3211cff.png: aef-audit-cron after Check, with the Validator dock listing the finding
- M-draft-inception-readiness-judge-t-4830-r3-044bc3211cff.png: 1 error + 2 warnings, "1 on the map"
- M-aef-existing-project-onboarding-judge-t-4830-r3-044bc3211cff.png: 3 findings, "1 on the map"
- C-aef-greenfield-onboarding-judge-t-4830-r3-044bc3211cff.png: clean result, "checked · no findings"

Out of scope / not checked here: cross-origin refusal (Agent AC#4) and 832's reference tests.
