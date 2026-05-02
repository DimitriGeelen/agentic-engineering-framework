---
id: consumer-upgrade-and-test
qid: 107/P-002
agent_id: 107
counter: 2
name: "Consumer upgrade and test"
description: "Cross-fleet: upgrade consumer via framework shim then run framework test suite — shape-aware, GitHub upstream"
kind: agent
tags: [fleet,upgrade,test]
variables: [host]
created: 2026-04-18T08:58:31Z
updated: 2026-05-02T10:35:00Z
---

You are on a framework-managed host ({{host}}). Run a consumer-only upgrade
(no cargo, no clones, no source-tree paths) and report results.

## Upstream

Canonical upstream is GitHub:

  https://github.com/DimitriGeelen/agentic-engineering-framework.git

OneDev is being migrated — do not retry against it during this window.

## Step 1 — Detect project shape

Decide which path to take BEFORE running upgrade:

  ls -la .framework.yaml .agentic-framework/bin/fw FRAMEWORK.md 2>&1

Branch on what you see:

  • `.framework.yaml` + `.agentic-framework/bin/fw` both present →
       `consumer-initialized` — proceed to Step 2.

  • `.framework.yaml` present, `.agentic-framework/` missing or stale →
       `consumer-vendored-skewed` — this is exactly what upgrade fixes.
       Proceed to Step 2.

  • neither `.framework.yaml` nor `.agentic-framework/` present →
       `consumer-uninitialized`. Run init first, pinned to GitHub:

         fw init --upstream https://github.com/DimitriGeelen/agentic-engineering-framework.git

       Then proceed to Step 2.

  • `FRAMEWORK.md` + `bin/fw` at root →
       `framework-repo` (NOT a consumer). This is a misdispatch.
       Stop and TermLink-reply with this corrected command for the
       dispatcher to send to the actual consumer host:

         .agentic-framework/bin/fw upgrade

## Step 2 — Capture pre-upgrade state

  fw_before=$(.agentic-framework/bin/fw version 2>/dev/null | head -1)
  upstream_before=$(grep -E "^upstream" .framework.yaml || echo "(not set)")

## Step 3 — Upgrade

  .agentic-framework/bin/fw upgrade

NEVER cd into `.agentic-framework/` to run upgrade — the
bare-from-consumer structural guard exists (T-1542), but this prompt
forbids the attempt outright.

## Step 4 — Capture post-upgrade state + verify bump

  fw_after=$(.agentic-framework/bin/fw version 2>/dev/null | head -1)
  echo "before: $fw_before"
  echo "after:  $fw_after"

If the version did not change AND the vendored copy was already current,
that is a no-op (acceptable). If upgrade reported success but version did
not change AND `.agentic-framework/` was stale, flag it as a finding.

## Step 5 — Test

  .agentic-framework/bin/fw test all

## Reporting

Report back with:

  - host, project shape detected, fw before, fw after
  - upgrade exit code + first/last 20 lines of upgrade output
  - test summary line (counts, passes, fails)

If upgrade failed, use this structured envelope INSTEAD of free-form
text (feeds T-1675 / T-1542 evidence loop):

  project_shape:
  fw_version_before:
  configured_upstream:
  step_that_failed:        (e.g. "step 4b/9: do_vendor")
  stderr_excerpt:          (first 30 lines)
  reproduction:            (the exact command you ran)

Do not try to fix framework bugs from a consumer install — that is a
dev-box task. Report findings instead.
