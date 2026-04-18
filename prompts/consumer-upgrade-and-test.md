---
id: consumer-upgrade-and-test
qid: 107/P-002
agent_id: 107
counter: 2
name: "Consumer upgrade and test"
description: "Cross-fleet: upgrade consumer via framework shim then run framework test suite"
kind: agent
tags: [fleet,upgrade,test]
variables: [host]
created: 2026-04-18T08:58:31Z
updated: 2026-04-18T08:58:31Z
---

You are on a framework-managed host ({{host}}). Run a consumer-only upgrade (no cargo, no clones, no source-tree paths):

  .agentic-framework/bin/fw upgrade
  .agentic-framework/bin/fw test all

If .agentic-framework/bin/fw upgrade surfaces failures, report them as findings — do not try to fix framework bugs from a consumer install (that is a dev-box task).

Report back: full upgrade output + the test summary line (counts, passes, fails).
