# Reviewer evidence — T-5172 AC#1

- dispatch: `judge-t-5172-r5-codex-65cd2d59abda`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `9032563a310bdf79fc76a7f4e0b3aebde804258d`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `7e36fc5e28b1b235580854db968408cd80f85ae9bdde5c0789aadac45ba28ee0`
- result.md sha256: `c8f0338571fb1b0dc3da3c8254cfb94fbcb118b5a37612715aae6217943b4f7e`

## The worker's verdict block

```
1. [AC] A file in a declared folder opens from a review page
VERDICT: not-evaluated
WHY: Inspected all five screenshots and the Visual Verification checklist. At 1024, 1440 and 1920 pixels, the script displays syntax highlighting and line numbers within a bounded code box, without visible overlap. At 1024, long lines extend beyond the visible code area. Source CSS specifies overflow-x: auto, but screenshots cannot establish that hidden text is reachable by scrolling. The required live URL failed to connect from this sandbox (curl error 7), preventing interaction verification. The supplied config screenshot was also inspected.
GUIDANCE: A reviewer with browser access to the required URL must verify horizontal scrolling reveals the long-line endings while the page itself remains within the viewport.

--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-65cd2d59abda/tmp/reviewer-evidence/T-5172/01-file-scripts-agent-listeners-sh.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-65cd2d59abda/tmp/reviewer-evidence/T-5172/02-config.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-65cd2d59abda/tmp/reviewer-evidence/T-5172/script-file@1024.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-65cd2d59abda/tmp/reviewer-evidence/T-5172/script-file@1440.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-65cd2d59abda/tmp/reviewer-evidence/T-5172/script-file@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] A file in a declared folder opens from a review page
VERDICT: not-evaluated
WHY: Inspected all five screenshots and the Visual Verification checklist. At 1024, 1440 and 1920 pixels, the script displays syntax highlighting and line numbers within a bounded code box, without visible overlap. At 1024, long lines extend beyond the visible code area. Source CSS specifies `overflow-x: auto`, but screenshots cannot establish that hidden text is reachable by scrolling. The required live URL failed to connect from this sandbox (curl error 7), preventing interaction verification. The supplied config screenshot was also inspected.
GUIDANCE: A reviewer with browser access to the required URL must verify horizontal scrolling reveals the long-line endings while the page itself remains within the viewport.

--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-65cd2d59abda/tmp/reviewer-evidence/T-5172/01-file-scripts-agent-listeners-sh.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-65cd2d59abda/tmp/reviewer-evidence/T-5172/02-config.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-65cd2d59abda/tmp/reviewer-evidence/T-5172/script-file@1024.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-65cd2d59abda/tmp/reviewer-evidence/T-5172/script-file@1440.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-65cd2d59abda/tmp/reviewer-evidence/T-5172/script-file@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
