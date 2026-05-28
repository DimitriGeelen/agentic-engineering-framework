---
id: T-1542
name: "fw upgrade from inside a consumer crashes at step 4b/9 — detect bare-from-consumer
  case and route to upstream"
description: >
  Promoted from OBS-032. fw upgrade run from inside a consumer project (no target
  arg) crashes at 4b/9 because FRAMEWORK_ROOT resolves to the consumer's vendored
  copy and target defaults to cwd — both canonicalize to the same path. Workaround
  is to run from the framework repo with explicit target. Fix: detect this case
  early and re-exec against the real upstream framework, or fail fast with a clear
  message.

status: started-work
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
arc_id: project-shape-resilience
created: 2026-04-27T13:19:34Z
last_update: '2026-05-28T22:54:09Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 1
      D3: 4
      D4: 2
    rationale: D1=3 (body:test-or-audit-check); D2=1 (body:log-or-error-line); 
      D3=4 (body:framework-level-ux); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 1
      D3: 4
      D4: 2
      F1: 0
    rationale: D1=3 (body:test-or-audit-check); D2=1 (body:log-or-error-line); 
      D3=4 (body:framework-level-ux); D4=2 (body:env-class-handled); F1=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 1
      D3: 4
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=1 (body:log-or-error-line); 
      D3=4 (body:framework-level-ux); D4=2 (body:env-class-handled); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1542: fw upgrade from inside a consumer crashes at step 4b/9 — detect bare-from-consumer case and route to upstream

## Context

`fw upgrade` (no target arg) from inside a consumer project fails at step 4b/9 ("Vendored framework scripts") with "Source and target resolve to the same directory". When invoked via `consumer/.agentic-framework/bin/fw`, `FRAMEWORK_ROOT` resolves to `consumer/.agentic-framework` and the implicit target is the cwd → both canonicalize to the same path. `do_vendor` (`bin/fw:223-242`) already attempts a fallback via `FW_BIN_DIR/..`, but in the bare-from-consumer case `FW_BIN_DIR` is also inside the consumer's vendored copy — fallback fails and the upgrade aborts after partial progress through steps 1-4a.

Workaround today: always run from a framework repo with explicit target (`fw upgrade /path/to/consumer`). The fix is to detect the bare-from-consumer case in `do_upgrade` (or in `do_vendor`) early and either fail-fast with a copy-pasteable corrected command, or re-exec against a discoverable upstream framework path.

Origin: OBS-032 (S-2026-0427-0908 against `/opt/050-email-archive`).

## Acceptance Criteria

### Agent
- [x] `do_upgrade` (`lib/upgrade.sh`) detects bare-from-consumer invocation BEFORE step 1/9 and either: (a) re-execs against a discoverable upstream framework path, or (b) fails fast with a copy-pasteable corrected command (`fw upgrade /path/to/consumer` from a known framework repo) — chose (b)
- [x] If re-exec is chosen: upstream discovery uses an explicit, documented mechanism — N/A (chose fail-fast)
- [x] If fail-fast is chosen: error message names both paths involved and the exact command to run instead — `FRAMEWORK_ROOT`, `target_dir`, `Vendored copy` lines + `cd <upstream> && bin/fw upgrade <target>` suggestion (best-effort upstream from `~/.local/bin/fw` symlink, generic placeholder otherwise)
- [x] No partial-state damage on failure: steps 1-4a do not write changes if 4b will inevitably fail — guard fires before line 195 self-vendor; bats test asserts pre/post md5 of vendored file unchanged
- [x] Bats regression test reproduces the bare-from-consumer scenario and asserts the chosen behaviour — `tests/unit/test_upgrade_self_target_guard.bats` (4/4 pass)
- [x] Same-class sweep: any other `fw` subcommand whose source resolution can collapse to target gets the same guard (or is documented as not applicable) — `do_vendor` already has its own guard at `bin/fw:223` (T-680); `do_init` requires `.framework.yaml` absence so cannot collapse; no other subcommand performs cross-tree copy operations

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
# Bats regression test exists and passes (assertion, not optional) — content-asserted
test -f tests/unit/test_upgrade_self_target_guard.bats
bats tests/unit/test_upgrade_self_target_guard.bats 2>&1 | grep -q "^ok 4 "
# Existing upgrade-from-framework-repo path still works — content-asserted, not exit-only
bin/fw upgrade --help 2>&1 | grep -q "Sync framework improvements to consumer project"
# Guard-line presence in lib/upgrade.sh (T-1542 fix landed)
grep -q "FRAMEWORK_ROOT.*resolves\|self-target check\|bare-from-consumer" lib/upgrade.sh

## Decisions

### 2026-04-28 — Fail-fast vs re-exec
- **Chose:** (b) Fail-fast with copy-pasteable corrected command, before any state mutation.
- **Why:** Re-exec via "discoverable upstream" requires either silent path-walking (rejected by AC) or relying on `~/.local/bin/fw`. The shim is now project-detecting (T-665) — it resolves back to whichever consumer the user is standing in, including the same vendored copy we're trying to escape. So re-exec has no reliable target. Fail-fast is explicit, predictable, and matches existing framework patterns (T-609, T-1257 — copy-pasteable commands always preferred over magic).
- **Rejected:** Silent re-exec via `FW_BIN_DIR/..` walking — AC explicitly rejects "silent path-walking".
- **Rejected:** Letting `do_vendor`'s late guard handle it — that guard fires at step 4b, AFTER steps 1-4a have mutated CLAUDE.md, templates, seeds, hooks. Partial state is the worst outcome.

### 2026-04-28 — Best-effort upstream suggestion
- **Chose:** Probe `~/.local/bin/fw` only when it's a real symlink (legacy global install), not a shim. Fall back to generic `/path/to/agentic-engineering-framework` placeholder.
- **Why:** Shim files with `find_fw` resolve back to whichever project the human is currently in — useless as an "upstream" hint. Symlinks pre-T-665 still point at a real framework repo, which IS useful.
- **Rejected:** Probing `$FW_VENDOR_UPSTREAM` env var or `.framework.yaml: upstream_repo` — would require additional plumbing for a single-purpose hint; fail-fast still works without it.

## Updates

### 2026-04-27T13:19:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1542-fw-upgrade-run-from-inside-a-consumer-pr.md
- **Context:** Initial task creation

### 2026-04-28T17:18:57Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-28 — fail-fast guard implemented + bats coverage
- **Action:** Added bare-from-consumer detection in `lib/upgrade.sh:do_upgrade` after the existing self-target check (line 187) and BEFORE the self-vendor block at line 195.
- **Output:** `lib/upgrade.sh` (+44 lines), `tests/unit/test_upgrade_self_target_guard.bats` (new, 4 tests, 4/4 pass)
- **Context:** Detects when canonicalized `FRAMEWORK_ROOT` equals canonicalized `target_dir/.agentic-framework`. On match, prints both paths + a copy-pasteable corrected command and returns 1 with no mutation. Existing 12 lib_upgrade.bats tests still pass.

## Recommendation

**Recommendation:** GO

**Rationale:** Bare-from-consumer collapse fails fast at the door instead of corrupting state mid-upgrade. Both paths printed for diagnosis, copy-pasteable corrected command provided, no silent path-walking. Bats coverage proves the guard fires on the bare-from-consumer scenario, asserts pre/post md5 to confirm zero mutation, and the normal framework→consumer path still passes dry-run. Same-class sweep complete: `do_vendor`'s late guard is now defence-in-depth; `do_init` requires `.framework.yaml` absence so cannot collapse.

**Evidence:**
- `lib/upgrade.sh:192-235`: early guard in `do_upgrade`, fires before any mutation, prints `FRAMEWORK_ROOT` + `target_dir` + `Vendored copy` + suggested `cd <upstream> && bin/fw upgrade <target>`
- `tests/unit/test_upgrade_self_target_guard.bats`: 4/4 pass — fail-fast + paths reported + zero-mutation md5 check + normal-path no-false-positive
- `tests/unit/lib_upgrade.bats`: 12/12 still pass (no regression)
- `bin/fw upgrade --help` still works (existing verification command)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-ad02c9c8
- **Timestamp:** 2026-04-28T20:12:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-02T10:07:11Z — status-update [task-update-agent]
- **Change:** tags: +arc:project-shape-resilience
