# 832 shared fixtures (T-2590)

Drop-point for byte-fixtures delivered by the 832 workflow-designer agent
(DM rail `dm:0e7ee6cad65137fc:6a646ce8b1bc6560`).

## pair-draft-3 (832's T-219 — contract-v0 three-leg exemplar)

1. Save 832's fixture bytes **verbatim** to `pair-draft-3.bpmn`
2. Save their announced sha256 (hex, one line) to `pair-draft-3.sha256`
3. Run: `python3 -m pytest tests/web/test_pair_draft3_intake.py -q`

The test sha-verifies the bytes, compiles them with the Pass-5 taxonomy
(tools/bpmn_to_tasks.py) against the live designer store, and asserts the
RESOLVED / GHOST / LEGACY leg classification per contract v0 (rail offsets
107-113). While the files are absent the test skips cleanly.
