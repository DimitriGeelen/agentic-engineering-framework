# Reviewer evidence — T-5172 AC#1

- dispatch: `judge-t-5172-r5-codex-f1affaa546b5`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `170ee2e9fb6a5b952be4b6e9c85a766104bf559a`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `cbf272b05771f6f0b9f95a8492a0132e5378661176508705671f05e0e7cec0bb`
- result.md sha256: `db0a84616494ece05954c3d81b1b26dd26854e21b01be92646bd683aac918964`

## The worker's verdict block

```
1. [AC] A file in a declared folder opens from a review page
VERDICT: not-evaluated
WHY: Inspected all five screenshots. The script shows syntax highlighting and line numbers at 1024, 1440, and 1920 pixels. The checklist’s code box remains within the page without visible overlap; at 1024, long lines extend beyond its visible content area. The config screenshot renders successfully. .framework.yaml:49 declares VIEWABLE_DIRS: scripts, and the code specifies overflow-x: auto. However, screenshots cannot establish sideways scrolling. The specified live URL was unreachable (curl error 7), and Chromium failed to launch because the sandbox denied setsockopt. I could not independently verify scrolling or interactive reachability.
GUIDANCE: Route to a reviewer with browser access to the specified URL to verify horizontal scrolling inside the code box and absence of page overflow at all three widths.

--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-f1affaa546b5/tmp/reviewer-evidence/T-5172/01-file-scripts-agent-listeners-sh.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-f1affaa546b5/tmp/reviewer-evidence/T-5172/02-config.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-f1affaa546b5/tmp/reviewer-evidence/T-5172/script-file@1024.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-f1affaa546b5/tmp/reviewer-evidence/T-5172/script-file@1440.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-f1affaa546b5/tmp/reviewer-evidence/T-5172/script-file@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] A file in a declared folder opens from a review page
VERDICT: not-evaluated
WHY: Inspected all five screenshots. The script shows syntax highlighting and line numbers at 1024, 1440, and 1920 pixels. The checklist’s code box remains within the page without visible overlap; at 1024, long lines extend beyond its visible content area. The config screenshot renders successfully. `.framework.yaml:49` declares `VIEWABLE_DIRS: scripts`, and the code specifies `overflow-x: auto`. However, screenshots cannot establish sideways scrolling. The specified live URL was unreachable (curl error 7), and Chromium failed to launch because the sandbox denied `setsockopt`. I could not independently verify scrolling or interactive reachability.
GUIDANCE: Route to a reviewer with browser access to the specified URL to verify horizontal scrolling inside the code box and absence of page overflow at all three widths.

--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-f1affaa546b5/tmp/reviewer-evidence/T-5172/01-file-scripts-agent-listeners-sh.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-f1affaa546b5/tmp/reviewer-evidence/T-5172/02-config.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-f1affaa546b5/tmp/reviewer-evidence/T-5172/script-file@1024.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-f1affaa546b5/tmp/reviewer-evidence/T-5172/script-file@1440.png
--evidence /tmp/tl-dispatch/judge-t-5172-r5-codex-f1affaa546b5/tmp/reviewer-evidence/T-5172/script-file@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
