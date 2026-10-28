# Reviewer evidence — T-4831 AC#1

- dispatch: `judge-t-4831-r3-b323e90bed1b`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `a56c934a7af266fac277857d58c2a4327dd1580b`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `cab794cd4726f391d98c637d406bf399d135616259533779529a1cd9cac43000`
- result.md sha256: `53abdd43bc1584abf8f5a4e743d0d0c373500f57343bb5239233a84f74459223`

## The worker's verdict block

```
1. [AC] Live tasks appear on the task-lifecycle map
VERDICT: not-evaluated
WHY: All four supplied screenshots failed to open because the files are absent: 01-designer-app.png, 02-api-instances-template-aef-task-lifecycle.png, 03-api-health.png, and 04-api-lens-definition.png under .context/working/judge-evidence/T-4831/. I could not inspect the overlay, picker count, status placement, or other maps. Evidence copies and screenshot hashes therefore cannot be supplied. The brief also reports no ## Visual Verification section with checklist states at configured widths. The partial capture excludes /api/field-catalog, /api/instances, /api/validate, /api/save, /api/list, /api/thumb, /api/versions, /api/version, and /api/delete; none were evaluated.
GUIDANCE: Supply the four screenshots and complete visual verification evidence. Route to a reviewer able to inspect the live lifecycle map, compare its instances and counts with the template API response, and verify other maps show no instances or errors.

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] Live tasks appear on the task-lifecycle map
VERDICT: not-evaluated
WHY: All four supplied screenshots failed to open because the files are absent: `01-designer-app.png`, `02-api-instances-template-aef-task-lifecycle.png`, `03-api-health.png`, and `04-api-lens-definition.png` under `.context/working/judge-evidence/T-4831/`. I could not inspect the overlay, picker count, status placement, or other maps. Evidence copies and screenshot hashes therefore cannot be supplied. The brief also reports no `## Visual Verification` section with checklist states at configured widths. The partial capture excludes `/api/field-catalog`, `/api/instances`, `/api/validate`, `/api/save`, `/api/list`, `/api/thumb`, `/api/versions`, `/api/version`, and `/api/delete`; none were evaluated.
GUIDANCE: Supply the four screenshots and complete visual verification evidence. Route to a reviewer able to inspect the live lifecycle map, compare its instances and counts with the template API response, and verify other maps show no instances or errors.

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
