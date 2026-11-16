# Reviewer evidence — T-5172 AC#1

- dispatch: `judge-t-5172-r5-codex-1c26b8773c45`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `1c8d7d309699d1539c6b6a7bef1f2ca463b915ae`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `ca88b9fb809a3a56268255a7a647a64190e08dc80a0b8d497df2b509aad738d8`
- result.md sha256: `4e8d2bb3a90153e4b112a56f26f316f8e048b9b3745f63fd50ced975f6d1579a`

## The worker's verdict block

```
1. [AC] A file in a declared folder opens from a review page
VERDICT: not-evaluated
WHY: Inspected all five screenshots and the Visual Verification checklist. The script displays syntax highlighting and line numbers at 1024, 1440, and 1920 px; the code box stays within the page without visible overlap. At 1024 px, long lines extend beyond the visible code area. Source CSS specifies horizontal scrolling, but screenshots cannot establish scroll reachability. The required live URL failed to connect (curl exit 7), preventing independent verification of that behavior. The config screenshot shows a rendered settings page.
GUIDANCE: A reviewer with access to http://192.168.10.107:3000/file/scripts/agent-listeners.sh must verify horizontal scrolling reveals the long-line endings without widening the page.

--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1c26b8773c45/tmp/review-evidence/T-5172/01-file-scripts-agent-listeners-sh.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1c26b8773c45/tmp/review-evidence/T-5172/02-config.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1c26b8773c45/tmp/review-evidence/T-5172/script-file@1024.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1c26b8773c45/tmp/review-evidence/T-5172/script-file@1440.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1c26b8773c45/tmp/review-evidence/T-5172/script-file@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] A file in a declared folder opens from a review page
VERDICT: not-evaluated
WHY: Inspected all five screenshots and the Visual Verification checklist. The script displays syntax highlighting and line numbers at 1024, 1440, and 1920 px; the code box stays within the page without visible overlap. At 1024 px, long lines extend beyond the visible code area. Source CSS specifies horizontal scrolling, but screenshots cannot establish scroll reachability. The required live URL failed to connect (curl exit 7), preventing independent verification of that behavior. The config screenshot shows a rendered settings page.
GUIDANCE: A reviewer with access to http://192.168.10.107:3000/file/scripts/agent-listeners.sh must verify horizontal scrolling reveals the long-line endings without widening the page.

--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1c26b8773c45/tmp/review-evidence/T-5172/01-file-scripts-agent-listeners-sh.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1c26b8773c45/tmp/review-evidence/T-5172/02-config.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1c26b8773c45/tmp/review-evidence/T-5172/script-file@1024.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1c26b8773c45/tmp/review-evidence/T-5172/script-file@1440.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-1c26b8773c45/tmp/review-evidence/T-5172/script-file@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
