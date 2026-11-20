# Reviewer evidence — T-5303 AC#1

- dispatch: `judge-t-5303-r5-codex-8471300cab08`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `a81da63256267e5645337a6a5e13c6b454dc87fa`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `ecab4c3e9e1e137de19a3af9dac6871ffd48c9514bcff0819a84450887e6ebc3`
- result.md sha256: `ba5f19ab95a6f4cdd79084ac901687a8d48609428c4a0e002487db3eb23162bc`

## The worker's verdict block

```
## AC1 Watchtower pages render as before
Vote: green
Evidence: image: .context/working/judge-evidence/T-5303/01-root.png region 0,0,1280,104
Location: .context/working/judge-evidence/T-5303/01-root.png region 0,0,1280,104
Evidence: image: .context/working/judge-evidence/T-5303/02-approvals.png region 0,0,1280,104
Location: .context/working/judge-evidence/T-5303/02-approvals.png region 0,0,1280,104
Evidence: image: .context/visual/T-5303/home-header@1024.png region 0,0,1024,166
Location: .context/visual/T-5303/home-header@1024.png region 0,0,1024,166
Evidence: image: .context/visual/T-5303/home-header@1440.png region 0,0,1440,104
Location: .context/visual/T-5303/home-header@1440.png region 0,0,1440,104
Evidence: image: .context/visual/T-5303/home-header@1920.png region 0,0,1920,104
Location: .context/visual/T-5303/home-header@1920.png region 0,0,1920,104
Evidence: image: .context/visual/T-5303/approvals-header@1024.png region 0,0,1024,166
Location: .context/visual/T-5303/approvals-header@1024.png region 0,0,1024,166
Evidence: image: .context/visual/T-5303/approvals-header@1440.png region 0,0,1440,104
Location: .context/visual/T-5303/approvals-header@1440.png region 0,0,1440,104
Evidence: image: .context/visual/T-5303/approvals-header@1920.png region 0,0,1920,104
Location: .context/visual/T-5303/approvals-header@1920.png region 0,0,1920,104
Evidence: image: .context/visual/T-5303/approvals-footer@1024.png region 0,0,1024,97
Location: .context/visual/T-5303/approvals-footer@1024.png region 0,0,1024,97
Evidence: image: .context/visual/T-5303/approvals-footer@1440.png region 0,0,1440,97
Location: .context/visual/T-5303/approvals-footer@1440.png region 0,0,1440,97
Evidence: image: .context/visual/T-5303/approvals-footer@1920.png region 0,0,1920,97
Location: .context/visual/T-5303/approvals-footer@1920.png region 0,0,1920,97
Rule: Every framework menu element and footer text must be present without clipping or overlap at 1024, 1440 and 1920 px; the second-row theme toggle at 1024 px is explicitly permitted.
Conclusion: Both pages show the logo, Work, Knowledge, Architecture, Govern, Docs, search, settings and theme toggle unobscured at every required width, with the permitted second-row toggle at 1024 px, and all three footer captures show complete, separated version and bug-report text.
```

## The worker's full output (result.md)

```
===VERDICT===
format: verdict/1
task: T-5303
reviewer: codex
round: 1
vote: green
failed: []

## AC1 Watchtower pages render as before
Vote: green
Evidence: image: .context/working/judge-evidence/T-5303/01-root.png region 0,0,1280,104
Location: .context/working/judge-evidence/T-5303/01-root.png region 0,0,1280,104
Evidence: image: .context/working/judge-evidence/T-5303/02-approvals.png region 0,0,1280,104
Location: .context/working/judge-evidence/T-5303/02-approvals.png region 0,0,1280,104
Evidence: image: .context/visual/T-5303/home-header@1024.png region 0,0,1024,166
Location: .context/visual/T-5303/home-header@1024.png region 0,0,1024,166
Evidence: image: .context/visual/T-5303/home-header@1440.png region 0,0,1440,104
Location: .context/visual/T-5303/home-header@1440.png region 0,0,1440,104
Evidence: image: .context/visual/T-5303/home-header@1920.png region 0,0,1920,104
Location: .context/visual/T-5303/home-header@1920.png region 0,0,1920,104
Evidence: image: .context/visual/T-5303/approvals-header@1024.png region 0,0,1024,166
Location: .context/visual/T-5303/approvals-header@1024.png region 0,0,1024,166
Evidence: image: .context/visual/T-5303/approvals-header@1440.png region 0,0,1440,104
Location: .context/visual/T-5303/approvals-header@1440.png region 0,0,1440,104
Evidence: image: .context/visual/T-5303/approvals-header@1920.png region 0,0,1920,104
Location: .context/visual/T-5303/approvals-header@1920.png region 0,0,1920,104
Evidence: image: .context/visual/T-5303/approvals-footer@1024.png region 0,0,1024,97
Location: .context/visual/T-5303/approvals-footer@1024.png region 0,0,1024,97
Evidence: image: .context/visual/T-5303/approvals-footer@1440.png region 0,0,1440,97
Location: .context/visual/T-5303/approvals-footer@1440.png region 0,0,1440,97
Evidence: image: .context/visual/T-5303/approvals-footer@1920.png region 0,0,1920,97
Location: .context/visual/T-5303/approvals-footer@1920.png region 0,0,1920,97
Rule: Every framework menu element and footer text must be present without clipping or overlap at 1024, 1440 and 1920 px; the second-row theme toggle at 1024 px is explicitly permitted.
Conclusion: Both pages show the logo, Work, Knowledge, Architecture, Govern, Docs, search, settings and theme toggle unobscured at every required width, with the permitted second-row toggle at 1024 px, and all three footer captures show complete, separated version and bug-report text.

## Counter-search
Searched: All eleven screenshots, checking each menu control, the narrow-width second row, active Govern background, and both footer lines for missing content, edge clipping or overlap.
Found: No missing or overlapping controls; the 1024 px theme toggles remain fully inside their headers, and footer text fits at every width; screenshots establish visual placement, not interactive behavior.

## Change-my-mind
A required-width screenshot showing any named menu control missing, clipped or overlapped, or either footer line truncated or overlapping, would change this vote.
===END===
```
