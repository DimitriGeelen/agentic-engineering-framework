# T-4355 Human AC#1 — reviewer judge-t-4355-r3-4cad042acfec (revision fc39f161)

## Checked
- Screenshot 01-config.png (/config, 1280 wide, browser reported no console/page errors).
  The row FW_ABSENT_COMPONENTS is shown with an empty Current and an empty Default. Its description reads:
  "Optional components this project leaves out on purpose, space- or comma-separated: termlink node bats
  shellcheck pi ollama litellm. fw doctor reports each as OK (absent by choice) instead of WARN; a workflow
  that needs one still WARNs, and an unknown name WARNs (T-4355, GitHub #98)".
- The same text is in lib/config.sh:265 and web/blueprints/config.py:22 (default "").
- On the page the row is labelled FW_ABSENT_COMPONENTS, while the criterion calls it ABSENT_COMPONENTS. Every
  setting on this page carries the FW_ prefix, so this is how the page names settings, not a defect.

## Substance
The content meets the Expected clause: the row is present, the default is empty, the description lists the
components that can be named, and it says that a needed one ("a workflow that needs one") or a misspelled one
("an unknown name") still warns.

## Why not-evaluated
The dispatch's visual-evidence gate failed because the task file has no "## Visual Verification" section.
That means there is no checklist of states, and no screenshots at every UX_SHOT_WIDTHS width. Under the brief
I must not return green on a render criterion in this state. My only evidence is a single-width capture, so
I cannot vote on how the page renders across widths.
