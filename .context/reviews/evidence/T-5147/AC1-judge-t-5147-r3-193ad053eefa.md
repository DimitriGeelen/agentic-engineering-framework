# Reviewer evidence — T-5147 AC#1

- dispatch: `judge-t-5147-r3-193ad053eefa`
- worker kind: `codex` (vendor `openai`, model `gpt-6-astra`)
- seat: `codex`
- reviewed revision: `6c3093dad0e8a527b82d85e722a1b29cc941ac97`
- recorded by: the dispatch runtime on the worker's behalf (T-3582)
- result.jsonl sha256: `448756538e473957602c97d1411d587cbeecc708f4d46b4e75b61d220fc4ea31`
- result.md sha256: `d5572e1063a739021981d1a14ab34a6cd67bc13e7e9f096c837db3df095ffe4b`

## The worker's verdict block

```
1. [AC] Board stays fast after a review and Awaiting review catches up
VERDICT: not-evaluated
WHY: The live endpoint http://192.168.10.107:3000/tasks was unreachable: curl returned exit 7, “Couldn't connect to server.” I could not observe either reload, a newly green task becoming ready within 20 seconds, or readiness accuracy against current verdicts. Static screenshots cannot establish those behaviors.

I inspected all four screenshots against the Visual Verification checklist. All five column headings are visible. At 1024, card controls are compressed and readiness labels are clipped, consistent with the checklist’s “clipped” entry. At 1440 and 1920, visible cards and readiness labels fit without apparent overlap. The supplied 1280-wide page capture also shows clipped readiness labels. Interaction reachability and off-screen cards could not be verified from these images.

GUIDANCE: Route to a reviewer with live browser access and current verdict evidence. Measure baseline, immediate post-verdict reload, and reload approximately 20 seconds later; verify the newly green task appears ready and displayed ready tasks have valid verdicts.

--evidence /tmp/tl-dispatch/judge-t-5147-r3-193ad053eefa/tmp/review-evidence/T-5147/01-tasks.png
--evidence /tmp/tl-dispatch/judge-t-5147-r3-193ad053eefa/tmp/review-evidence/T-5147/board@1024.png
--evidence /tmp/tl-dispatch/judge-t-5147-r3-193ad053eefa/tmp/review-evidence/T-5147/board@1440.png
--evidence /tmp/tl-dispatch/judge-t-5147-r3-193ad053eefa/tmp/review-evidence/T-5147/board@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```

## The worker's full output (result.md)

```
1. [AC] Board stays fast after a review and Awaiting review catches up
VERDICT: not-evaluated
WHY: The live endpoint http://192.168.10.107:3000/tasks was unreachable: curl returned exit 7, “Couldn't connect to server.” I could not observe either reload, a newly green task becoming ready within 20 seconds, or readiness accuracy against current verdicts. Static screenshots cannot establish those behaviors.

I inspected all four screenshots against the Visual Verification checklist. All five column headings are visible. At 1024, card controls are compressed and readiness labels are clipped, consistent with the checklist’s “clipped” entry. At 1440 and 1920, visible cards and readiness labels fit without apparent overlap. The supplied 1280-wide page capture also shows clipped readiness labels. Interaction reachability and off-screen cards could not be verified from these images.

GUIDANCE: Route to a reviewer with live browser access and current verdict evidence. Measure baseline, immediate post-verdict reload, and reload approximately 20 seconds later; verify the newly green task appears ready and displayed ready tasks have valid verdicts.

--evidence /tmp/tl-dispatch/judge-t-5147-r3-193ad053eefa/tmp/review-evidence/T-5147/01-tasks.png
--evidence /tmp/tl-dispatch/judge-t-5147-r3-193ad053eefa/tmp/review-evidence/T-5147/board@1024.png
--evidence /tmp/tl-dispatch/judge-t-5147-r3-193ad053eefa/tmp/review-evidence/T-5147/board@1440.png
--evidence /tmp/tl-dispatch/judge-t-5147-r3-193ad053eefa/tmp/review-evidence/T-5147/board@1920.png

Summary: 0 green, 0 amber, 0 red, 0 escalate, 1 not-evaluated
```
