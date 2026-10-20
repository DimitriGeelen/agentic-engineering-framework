# T-4407 AC1 — reviewer judge-t-4407-r3-9966adebb79a (revision a54bc6b19)

Criterion: sidecar-waiting error card on /approvals shows `exit N: <reason>` and no bypass-instruction lines.

## Visual evidence (state approvals-waiting-error, captured from http://127.0.0.1:3947/approvals, capture.json ts 2026-10-20T20:44:39Z)
Full-page shots are 32–36k px tall; the card was located with OCR ("Nobody has taken these" at y=30938 @1024, 29437 @1440, 28505 @1920) and inspected as crops.

At all three widths (1024, 1440, 1920) the "Messages waiting for a recipient / Nobody has taken these" section shows one card:
- heading: "[ERROR] The waiting list could not be read" ([ERROR] in danger colour)
- line: "exit 2: sidecar receiver unreachable on 127.0.0.1:7811 (connection refused) — run `fw sidecar waiting` in this project." — matches the Expected text verbatim
- no "--skip-" or "re-run with" text on the card; text sits inside the card border with ample margin at every width; no clipping or overlap with the section header or the following "Ready for you" section.

Checklist: | approvals-waiting-error | error card | ok | ok | ok |

Minor: the section is mid-page (above "Ready for you"), not "near the bottom" as step 2 says; the Expected outcome is unaffected.

## Code read (revision a54bc6b19)
web/blueprints/approvals.py:642-647 — on non-zero exit, stderr is passed through web.shared.operator_facing_stderr BEFORE the [-300:] tail cut (commit a303395da, T-4407), so a reason followed by bypass lines keeps the reason and drops the bypass lines; the except path sanitizes again. web/templates/_approvals_content.html:505-509 renders waiting_error inside .approval-card with the "— run fw sidecar waiting" suffix.

## Live page (judge capture 04-approvals-content.png = /approvals/content)
Live sidecar is healthy: the section lists 178 waiting messages and no error card, OCR finds no "could not be read", "--skip-" or "re-run with" anywhere — the expected normal state (step 3).

## Verdict: not-evaluated
On substance everything I could see meets the criterion (error card text exact, no bypass lines, unclipped at 1024/1440/1920). But the judge capture of the required page /approvals failed (Page.goto timeout 30000ms on http://192.168.10.107:3000/approvals), and the ledger refused a green: "required page '/approvals' has no verified screenshot". Per the brief, a criterion that depends on a page I did not see is not-evaluated, not amber/red.
Needed: re-run the judge capture so /approvals gets a verified screenshot, then re-dispatch a reviewer; the evidence above should carry straight over.
