---
id: T-1542
name: "fw upgrade from inside a consumer crashes at step 4b/9 — detect bare-from-consumer case and route to upstream"
description: >
  Promoted from OBS-032. fw upgrade run from inside a consumer project (no target
  arg) crashes at 4b/9 because FRAMEWORK_ROOT resolves to the consumer's vendored
  copy and target defaults to cwd — both canonicalize to the same path. Workaround
  is to run from the framework repo with explicit target. Fix: detect this case
  early and re-exec against the real upstream framework, or fail fast with a clear
  message.

status: captured
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-27T13:19:34Z
last_update: 2026-04-27T13:19:34Z
date_finished: null
---

# T-1542: fw upgrade from inside a consumer crashes at step 4b/9 — detect bare-from-consumer case and route to upstream

## Context

`fw upgrade` (no target arg) from inside a consumer project fails at step 4b/9 ("Vendored framework scripts") with "Source and target resolve to the same directory". When invoked via `consumer/.agentic-framework/bin/fw`, `FRAMEWORK_ROOT` resolves to `consumer/.agentic-framework` and the implicit target is the cwd → both canonicalize to the same path. `do_vendor` (`bin/fw:223-242`) already attempts a fallback via `FW_BIN_DIR/..`, but in the bare-from-consumer case `FW_BIN_DIR` is also inside the consumer's vendored copy — fallback fails and the upgrade aborts after partial progress through steps 1-4a.

Workaround today: always run from a framework repo with explicit target (`fw upgrade /path/to/consumer`). The fix is to detect the bare-from-consumer case in `do_upgrade` (or in `do_vendor`) early and either fail-fast with a copy-pasteable corrected command, or re-exec against a discoverable upstream framework path.

Origin: OBS-032 (S-2026-0427-0908 against `/opt/050-email-archive`).

## Acceptance Criteria

### Agent
- [ ] `do_upgrade` (`lib/upgrade.sh`) detects bare-from-consumer invocation BEFORE step 1/9 and either: (a) re-execs against a discoverable upstream framework path, or (b) fails fast with a copy-pasteable corrected command (`fw upgrade /path/to/consumer` from a known framework repo)
- [ ] If re-exec is chosen: upstream discovery uses an explicit, documented mechanism (e.g. `~/.local/bin/fw` shim resolution, env var, config file) — not silent path-walking
- [ ] If fail-fast is chosen: error message names both paths involved and the exact command to run instead
- [ ] No partial-state damage on failure: steps 1-4a do not write changes if 4b will inevitably fail
- [ ] Bats regression test reproduces the bare-from-consumer scenario and asserts the chosen behaviour
- [ ] Same-class sweep: any other `fw` subcommand whose source resolution can collapse to target gets the same guard (or is documented as not applicable)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Bare-from-consumer invocation produces a guarded, actionable failure (or successful re-exec)
# — no partial mutation of consumer state when source==target. Specific assertions filled in
# by the implementer based on (a) re-exec or (b) fail-fast choice.
#
# Bats regression test exists and passes.
test -f tests/unit/test_upgrade_self_target_guard.bats && bats tests/unit/test_upgrade_self_target_guard.bats || echo "regression test expected once AC done"
# Existing upgrade-from-framework-repo path still works.
bin/fw upgrade --help >/dev/null

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-27T13:19:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1542-fw-upgrade-run-from-inside-a-consumer-pr.md
- **Context:** Initial task creation
