# Reviewer evidence — T-5236 AC#1

- dispatch: `judge-t-5236-r5-antigravity-cf86bac6643a`
- worker kind: `antigravity` (vendor `google`, model `worker default`)
- seat: `antigravity`
- reviewed revision: `6949f1077eaf81ff22c3eb9689c3a14f5941efeb`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.md sha256: `e2dfe8c98faba635ca5985dcb63f7df4e35fdde831aeb62c71821dbecf1972ef`

## The worker's verdict block

```
1. [AC] [REVIEW] The "Hub profiles to fix" cards on the approvals page tell you who, which hub, how many messages wait, and the fix, at a glance
VERDICT: amber
WHY: Inspected all supplied screenshots (.context/visual/T-5236/hub-profiles@1024.png, .context/visual/T-5236/hub-profiles@1440.png, .context/visual/T-5236/hub-profiles@1920.png, .context/working/judge-evidence/T-5236/02-approvals.png, .context/working/judge-evidence/T-5236/03-approvals-content.png, .context/working/judge-evidence/T-5236/04-approvals-continuous-state.png), .context/visual/T-5236/hub-profiles.capture.json, and web/templates/_approvals_content.html (lines 566-590). Visually, at all three widths (1024, 1440, 1920), both cards render clearly, unclipped, reachable, and without overlap, and satisfy the Expected format ("User root on host dimitrimintdev has no profile for hub demo-ring20-hub — 1 message waiting · since 2026-11-18T15:05" with the hubs.toml lines to add, and "User root on host dimitrimintdev has a broken profile demo-lab for hub demo-lab-hub — 1 message waiting · since 2026-11-18T15:06" with Fix (one command, prepared — run it yourself): bash /opt/999-Agentic-Engineering-Framework/.context/runme/hub-profile-root-demo-lab-hub/runme.sh and It runs termlink fleet reauth demo-lab.). However, Step 1 of the criterion as written has two literal issues: (1) it names the old demo notices (demo-hub-t5236 missing, demo-dash-t5236 broken) instead of the retaken demo notices shown in the screenshots and ## Visual Verification (demo-ring20-hub missing, demo-lab-hub broken with profile demo-lab), and (2) it wraps /opt/999-Agentic-Engineering-Framework/.context/visual/T-5236/ in backticks with a leading /, which lib/reviewer/judge_cli.py:_criterion_pages() parses as a required Watchtower HTTP route (HTTP 404), marking page capture PARTIAL and causing lib/verdict_ledger.py:_run_fault (unseen-page) to refuse any green verdict.
GUIDANCE: Update Step 1 of Human AC#1 in .tasks/active/T-5236-missing-hubstoml-profile-keep-retrying-a.md to use the relative path .context/visual/T-5236/ (no leading / inside backticks, so _criterion_pages does not treat a filesystem path as a Watchtower URL route) and update the demo notice names to demo-ring20-hub (missing) and demo-lab-hub (broken, profile demo-lab).
PROPOSED RESTATEMENT: [REVIEW] The "Hub profiles to fix" cards on the approvals page (.context/visual/T-5236/hub-profiles@1024.png, @1440.png, @1920.png, taken with temporary demo notices demo-ring20-hub missing and demo-lab-hub broken) tell you who, which hub, how many messages wait, and the fix, at a glance
The visual evidence in hub-profiles@1024.png, hub-profiles@1440.png, and hub-profiles@1920.png meets the restated criterion across all three widths.

Summary: 0 green, 1 amber, 0 red, 0 escalate, 0 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] [REVIEW] The "Hub profiles to fix" cards on the approvals page tell you who, which hub, how many messages wait, and the fix, at a glance
VERDICT: amber
WHY: Inspected all supplied screenshots (`.context/visual/T-5236/hub-profiles@1024.png`, `.context/visual/T-5236/hub-profiles@1440.png`, `.context/visual/T-5236/hub-profiles@1920.png`, `.context/working/judge-evidence/T-5236/02-approvals.png`, `.context/working/judge-evidence/T-5236/03-approvals-content.png`, `.context/working/judge-evidence/T-5236/04-approvals-continuous-state.png`), `.context/visual/T-5236/hub-profiles.capture.json`, and `web/templates/_approvals_content.html` (lines 566-590). Visually, at all three widths (1024, 1440, 1920), both cards render clearly, unclipped, reachable, and without overlap, and satisfy the Expected format ("User root on host dimitrimintdev has no profile for hub demo-ring20-hub — 1 message waiting · since 2026-11-18T15:05" with the `hubs.toml` lines to add, and "User root on host dimitrimintdev has a broken profile `demo-lab` for hub demo-lab-hub — 1 message waiting · since 2026-11-18T15:06" with `Fix (one command, prepared — run it yourself): bash /opt/999-Agentic-Engineering-Framework/.context/runme/hub-profile-root-demo-lab-hub/runme.sh` and `It runs termlink fleet reauth demo-lab.`). However, Step 1 of the criterion as written has two literal issues: (1) it names the old demo notices (`demo-hub-t5236` missing, `demo-dash-t5236` broken) instead of the retaken demo notices shown in the screenshots and `## Visual Verification` (`demo-ring20-hub` missing, `demo-lab-hub` broken with profile `demo-lab`), and (2) it wraps `/opt/999-Agentic-Engineering-Framework/.context/visual/T-5236/` in backticks with a leading `/`, which `lib/reviewer/judge_cli.py:_criterion_pages()` parses as a required Watchtower HTTP route (`HTTP 404`), marking page capture PARTIAL and causing `lib/verdict_ledger.py:_run_fault` (`unseen-page`) to refuse any `green` verdict.
GUIDANCE: Update Step 1 of Human AC#1 in `.tasks/active/T-5236-missing-hubstoml-profile-keep-retrying-a.md` to use the relative path `.context/visual/T-5236/` (no leading `/` inside backticks, so `_criterion_pages` does not treat a filesystem path as a Watchtower URL route) and update the demo notice names to `demo-ring20-hub` (missing) and `demo-lab-hub` (broken, profile `demo-lab`).
PROPOSED RESTATEMENT: [REVIEW] The "Hub profiles to fix" cards on the approvals page (`.context/visual/T-5236/hub-profiles@1024.png`, `@1440.png`, `@1920.png`, taken with temporary demo notices `demo-ring20-hub` missing and `demo-lab-hub` broken) tell you who, which hub, how many messages wait, and the fix, at a glance
The visual evidence in `hub-profiles@1024.png`, `hub-profiles@1440.png`, and `hub-profiles@1920.png` meets the restated criterion across all three widths.

Summary: 0 green, 1 amber, 0 red, 0 escalate, 0 not-evaluated
```
