# T-1714 — Substrate bypass: fw termlink dispatch ducks under fw resolver dispatch

**Status:** captured / awaiting inception decision
**Origin:** session 2026-05-04, prompted by T-1700 AC4.3 honest-fail surfacing.

The task file `.tasks/active/T-1714-substrate-bypass-fw-termlink-dispatch-du.md`
carries the full content. This artifact captures the dialogue trail that
led to filing and verification of claims at filing time, per C-001.

## Dialogue Log

**2026-05-04** — Conversation context: T-1700 ready to close as
SHIP-WITH-CAVEAT. Agent flagged AC4.3 (outcome rows in
`dispatch-outcomes.jsonl`) as still honest-open: harness uses
`fw termlink dispatch` directly, never goes through `fw resolver
dispatch`, so no envelope row gets written.

**Human:** "can we rca incept this ??? this keeps happening !!!"

**Agent interpretation:** the substrate bypass is structural, not
isolated to T-1700; this is RCA-worthy + worth incepting a structural
fix rather than just patching the harness.

**Action:** filed T-1714 as inception with full RCA section inline
(Symptom / Root cause / Why structurally allowed / Prevention).

## Verification of claims at filing time

- `lib/resolver.py:cmd_dispatch` — confirmed writes envelope row to
  `.context/dispatches.jsonl` with workflow_id, workflow_sha, task_type,
  worker_kind, model, prompt_template, template_sha. Read at HEAD.
- `agents/termlink/termlink.sh:cmd_dispatch` lines 494-636 — confirmed
  writes only `<wdir>/meta.json`, no envelope write. Read at HEAD.
- `tools/t1700-ollama-harness.sh` — confirmed invokes
  `fw termlink dispatch --task-type ollama-research`, NOT
  `fw resolver dispatch`. Read at HEAD.
- `fw orchestrator status` (post-T-1712 fix) — shows 3 real dispatches,
  all from resolver path during T-1696/T-1697/T-1698 development.
  T-1700 harness's 13 real dispatches are absent. Live verified.

## Cross-references

- See task file for full RCA, assumptions, exploration plan, scope fence,
  go/no-go criteria, Recommendation block.
- Related: T-1684 (G-064 candidate consumer #2 — daily health-check cron),
  T-1685 (audit-refactor NO-GO/DEFER — prior G-064 attempt),
  T-1700 (the SHIP-WITH-CAVEAT that exposed the bypass).
- Recommendation: GO (see task file §Recommendation).
