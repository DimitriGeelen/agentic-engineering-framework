# Reviewer evidence — T-5344 AC#1

- dispatch: `judge-t-5344-r3-85ef8ceda528`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `cff85fe1812a39bd687561e56a67849b20198bf0`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `c8c9e57a35e5993403975ef99baf01506022bf2d77f17fad1021e0ef3ef7c7b3`
- result.md sha256: `f2f9b6d86c7f00d001caa9475f6f027db5cf3c8b8e488939afee7327dc6b43c7`

## The worker's verdict block

```
## AC1 Config budget row appearance
Vote: not-evaluated
Evidence: image: .context/working/judge-evidence/T-5344/01-config.png region 0,0,249,2048
Location: .context/working/judge-evidence/T-5344/01-config.png region 0,0,249,2048
Rule: The brief explicitly requires not-evaluated for this render criterion because the task has no `## Visual Verification` section.
Conclusion: I opened the supplied config screenshot, but the missing Visual Verification section and its required state-by-width evidence prevent completing the mandated visual review.
Guidance: Add the task’s `## Visual Verification` checklist and supply screenshots for every listed state at every configured width, showing PREPUSH_RANGE_TEST_BUDGET beside UNIT_SUITE_FLAKE_RETRY_MAX with default 120 and a readable description.
```

## The worker's full output (result.md)

```
===VERDICT===
format: verdict/1
task: T-5344
reviewer: independent-reviewer
round: 1
vote: not-evaluated
failed: [1]

## AC1 Config budget row appearance
Vote: not-evaluated
Evidence: image: .context/working/judge-evidence/T-5344/01-config.png region 0,0,249,2048
Location: .context/working/judge-evidence/T-5344/01-config.png region 0,0,249,2048
Rule: The brief explicitly requires not-evaluated for this render criterion because the task has no `## Visual Verification` section.
Conclusion: I opened the supplied config screenshot, but the missing Visual Verification section and its required state-by-width evidence prevent completing the mandated visual review.
Guidance: Add the task’s `## Visual Verification` checklist and supply screenshots for every listed state at every configured width, showing PREPUSH_RANGE_TEST_BUDGET beside UNIT_SUITE_FLAKE_RETRY_MAX with default 120 and a readable description.

## Counter-search
Searched: The supplied config screenshot and the brief’s visual-evidence inventory.
Found: The screenshot shows a rendered configuration table, but the brief explicitly identifies the missing Visual Verification section and does not supply the required state-by-width evidence.

## Change-my-mind
A completed Visual Verification checklist with all required screenshots showing one PREPUSH_RANGE_TEST_BUDGET row, default 120, readable description, and intact surrounding table layout.
===END===
```
