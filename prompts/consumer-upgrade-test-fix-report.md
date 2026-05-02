---
id: consumer-upgrade-test-fix-report
qid: 107/P-003
agent_id: 107
counter: 3
name: "Consumer upgrade + test + fix + report"
description: "Full cross-fleet upgrade+test+fix loop — shape-aware, GitHub upstream, structured failure envelope"
kind: agent
tags: [fleet,upgrade,test,fix,report]
variables: [host,upstream_agent]
created: 2026-04-18T18:57:33Z
updated: 2026-05-02T10:35:00Z
---

Task for {{host}} agent:

Please upgrade the Agentic Engineering Framework on this machine, run the
full test suite, fix any issues you find, and report back via TermLink.

## Upstream

Canonical upstream is GitHub:

  https://github.com/DimitriGeelen/agentic-engineering-framework.git

OneDev is being migrated — do not retry against it during this window.

## STEP 1 — Detect project shape

  ls -la .framework.yaml .agentic-framework/bin/fw FRAMEWORK.md 2>&1

Branch on what you see:

  • `consumer-initialized` (yaml + shim) → proceed to STEP 2.

  • `consumer-vendored-skewed` (yaml present, shim missing or stale) →
       proceed; this is the case upgrade exists to fix. Capture state
       before/after as evidence.

  • `consumer-uninitialized` (neither yaml nor `.agentic-framework/`) →
       run init first, pinned to GitHub, then proceed:

         fw init --upstream https://github.com/DimitriGeelen/agentic-engineering-framework.git

  • `framework-repo` (FRAMEWORK.md + bin/fw at root) → MISDISPATCH.
       Stop and TermLink-reply with the corrected command for the
       dispatcher to send to the actual consumer host:

         .agentic-framework/bin/fw upgrade

## STEP 2 — Snapshot pre-upgrade state

  fw_before=$(.agentic-framework/bin/fw version 2>/dev/null | head -1)
  upstream_before=$(grep -E "^upstream" .framework.yaml || echo "(not set)")

## STEP 3 — Upgrade framework (consumer-only, no source-tree paths)

  .agentic-framework/bin/fw upgrade

NEVER cd into `.agentic-framework/` first. The bare-from-consumer
structural guard exists (T-1542), but this prompt forbids the attempt
outright.

## STEP 4 — Verify framework health

  .agentic-framework/bin/fw doctor

## STEP 5 — Run full test suite

  .agentic-framework/bin/fw test all

## STEP 6 — Fix all issues you hit. Classify each:

  • Framework bugs   → create a task locally, document the repro, push
       upstream via `termlink remote push` or a bug-report pickup
       envelope to {{upstream_agent}}.
  • TermLink bugs    → same pattern, push to the termlink upstream.
  • Environmental    → document in a local task, skip upstream.

NEVER edit files in a vendored framework source tree. A consumer
install has no `/opt/999-...` or `/opt/termlink` — those are dev-box
paths. If a fix requires framework source edits, that is a dev-box
task; report it as a finding instead of attempting it locally.

## STEP 7 — Report summary back

  - host, project shape detected
  - fw version before / after
  - upstream URL (configured + effective)
  - test counts per suite (unit / integration / web / lint) — pass / fail
  - issues hit + fixes attempted (with commit SHAs if any)
  - learnings worth capturing upstream

If upgrade failed, use this structured envelope INSTEAD of free-form
text (feeds T-1675 / T-1542 evidence loop):

  project_shape:
  fw_version_before:
  configured_upstream:
  step_that_failed:        (e.g. "step 4b/9: do_vendor")
  stderr_excerpt:          (first 30 lines)
  reproduction:            (the exact command you ran)

Proceed autonomously. Ask only on sovereignty gates or destructive actions.
