# Reviewer evidence — T-4947 AC#1

- dispatch: `judge-t-4947-r3-1ef6fa032d28`
- worker kind: `opencode` (vendor `zai`, model `zai-coding-plan/glm-5.3`)
- seat: `opencode`
- reviewed revision: `049665bfa374dbb69d8db942ab427f88fad60067`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `878eb6f4b1223986f30b00b75ae02c85102db44f6b3d6f116c3e60f3e252cdfc`
- result.md sha256: `e822aa2d8144f9b0b6589a16995a5b4aba3edfda8f13b3d2994d49b73f92379e`

## The worker's verdict block

```
1. [AC] Arc Closure section of /approvals still renders as before
VERDICT: not-evaluated
WHY: The criterion requires visually inspecting the Arc Closure section at http://192.168.10.107:3000/approvals, and capture was PARTIAL — no screenshot of /approvals exists in .context/working/judge-evidence/T-4947/ (only 02-approvals-content.png for /approvals/content and 03-approvals-continuous-state.png for /approvals/continuous-state). Additionally, my Read tool failed on both captured PNGs ("Cannot read image (this model does not support image input)"), so I could not view any screenshot at all, and I have no live browser access to the page. Two independent bars to green also hold: (1) the ledger refuses green on a page the reviewer did not see; (2) this is a render criterion for a render-touching task (web/blueprints/approvals.py) whose task file has no ## Visual Verification section (checked the full file — only the inert comment block is present). I verified nothing about the demo state lines on /approvals itself; code-level sanitization is covered by the task's Agent ACs and is not what this criterion asks.
GUIDANCE: Re-run this criterion with a reviewer that can view images and a complete capture set: capture /approvals (plus /approvals/content, /approvals/continuous-state) at every UX_SHOT_WIDTHS width via fw ux shots T-4947, and have the producer add the required ## Visual Verification checklist table (state/control/1024/1440/1920) to the T-4947 task file per the T-4213 gate. Then check each Arc Closure demo state line for raw fw gate text or --skip/FW_ bypass flags and that the page renders without errors.

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
I've confirmed the task file facts. Now let me read the two screenshots that were captured, since the brief requires citing every screenshot as evidence.
Note: my Read tool could not open either PNG (this model does not support image input), on top of the partial capture — so no screenshot evidence was viewable at all. Verification of the two gating facts:

- `.context/working/judge-evidence/T-4947/` contains only `02-approvals-content.png` and `03-approvals-continuous-state.png` — no capture of `/approvals`, the exact page the criterion names.
- The task file `.tasks/active/T-4947-approvals-arc-demo-check-renders-raw-sub.md` (read in full, 403 lines) has no `## Visual Verification` section — only the inert HTML comment template — despite the task touching render surface `web/blueprints/approvals.py`.

1. [AC] Arc Closure section of /approvals still renders as before
VERDICT: not-evaluated
WHY: The criterion requires visually inspecting the Arc Closure section at http://192.168.10.107:3000/approvals, and capture was PARTIAL — no screenshot of `/approvals` exists in `.context/working/judge-evidence/T-4947/` (only `02-approvals-content.png` for `/approvals/content` and `03-approvals-continuous-state.png` for `/approvals/continuous-state`). Additionally, my Read tool failed on both captured PNGs ("Cannot read image (this model does not support image input)"), so I could not view any screenshot at all, and I have no live browser access to the page. Two independent bars to green also hold: (1) the ledger refuses green on a page the reviewer did not see; (2) this is a render criterion for a render-touching task (web/blueprints/approvals.py) whose task file has no `## Visual Verification` section (checked the full file — only the inert comment block is present). I verified nothing about the demo state lines on `/approvals` itself; code-level sanitization is covered by the task's Agent ACs and is not what this criterion asks.
GUIDANCE: Re-run this criterion with a reviewer that can view images and a complete capture set: capture `/approvals` (plus `/approvals/content`, `/approvals/continuous-state`) at every UX_SHOT_WIDTHS width via `fw ux shots T-4947`, and have the producer add the required `## Visual Verification` checklist table (state/control/1024/1440/1920) to the T-4947 task file per the T-4213 gate. Then check each Arc Closure demo state line for raw `fw` gate text or `--skip`/`FW_` bypass flags and that the page renders without errors.

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
