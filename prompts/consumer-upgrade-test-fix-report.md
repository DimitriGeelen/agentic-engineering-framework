---
id: consumer-upgrade-test-fix-report
qid: 107/P-003
agent_id: 107
counter: 3
name: "Consumer upgrade + test + fix + report"
description: "Full 6-step cross-fleet upgrade+test+fix loop — consumer-install safe"
kind: agent
tags: [fleet,upgrade,test,fix,report]
variables: [host,upstream_agent]
created: 2026-04-18T18:57:33Z
updated: 2026-04-18T18:57:33Z
---

Task for {{host}} agent:

Please upgrade the Agentic Engineering Framework on this machine, run the full
test suite, fix any issues you find, and report back via TermLink.

STEP 1 — Upgrade framework (consumer-only, no source-tree paths):
  .agentic-framework/bin/fw upgrade

STEP 2 — Verify framework health:
  .agentic-framework/bin/fw doctor

STEP 3 — Run full test suite:
  .agentic-framework/bin/fw test all

STEP 4 — Fix all issues you hit. Classify each:
  • Framework bugs -> create a task, fix, commit, push upstream via
    `termlink remote push` or a bug-report pickup envelope to {{upstream_agent}}
  • TermLink bugs -> same pattern, push to the termlink upstream
  • Environmental (this host only) -> document in a local task, skip upstream

STEP 5 — NEVER edit files in a vendored framework source tree. A consumer
install has NO `/opt/999-...` or `/opt/termlink` — those are dev-box paths.
If a fix requires framework source edits, that is a dev-box task, not a
fleet task; report it as a finding instead of attempting it locally.

STEP 6 — Report summary back:
  - fw version before / after
  - Test counts per suite (unit / integration / web / lint) — pass / fail
  - Issues hit + fixes attempted (with commit SHAs if any)
  - Learnings worth capturing upstream

Proceed autonomously. Ask only on sovereignty gates or destructive actions.
