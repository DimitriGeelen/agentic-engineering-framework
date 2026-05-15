# Project-Shape-Resilience Arc — Demo Evidence

**Arc:** project-shape-resilience
**Anchor:** T-1675 (umbrella) / parent fix: T-1542
**Status:** in-progress (awaiting human closure)
**Generated:** 2026-05-14

This document is the wire-evidence artefact for `fw arc close project-shape-resilience --demo docs/reports/T-1542-project-shape-resilience-arc-demo.md`. It maps the arc's headline mechanic onto specific bats tests that demonstrate it firing.

## Headline Mechanic

> Agent or human runs any `fw` verb in any of the 4 project shapes (framework / consumer-init / consumer-fresh / consumer-vendored-skewed) and observes a sensible response — success, clean refusal with right guidance, or graceful default — never silent error fall-through.

## The 4 Shapes — Mapped to Wire-Evidence

### Shape 1: framework — fw verb run from inside the framework repo

| What | Evidence |
|------|----------|
| Test file | `tests/unit/test_upgrade_self_target_guard.bats` |
| Tests proving headline | 4/4 ok |
| Specific firing | Test 1: "bare-from-consumer invocation fails fast with copy-pasteable command" — agent runs `fw upgrade` from inside `.agentic-framework/`, sees clean refusal naming both paths + corrected command |
| Sibling tasks | T-1542 (detection), T-1822 (cwd-trap fix) |

### Shape 2: consumer-init — fresh consumer just bootstrapped

| What | Evidence |
|------|----------|
| Test file | `tests/unit/upgrade_fresh_machine_simulation.bats` |
| Tests proving headline | 3/3 ok in ~12s |
| Specific firing | Test 1: "vendored bin/fw runs --version in scrubbed env" — bin/fw works under `env -i PATH=/usr/local/bin:/usr/bin:/bin HOME=$tmp` (no developer-environment leakage) |
| Sibling tasks | T-1635 (this test), T-1257 (CLAUDE.md fw-path rule) |

### Shape 3: consumer-fresh — vendored consumer running its own bin/fw against itself

| What | Evidence |
|------|----------|
| Test files | `tests/unit/upgrade_fresh_machine_simulation.bats` + `tests/unit/upgrade_auto_clone.bats` |
| Tests proving headline | 3/3 + 7/7 ok |
| Specific firing | fresh-machine test 3: "dry-run plan shows bare-from-consumer + auto-clone handoff plan" — agent runs `proj/.agentic-framework/bin/fw upgrade proj`, system detects bare-from-consumer, reads `upstream_repo` from `.framework.yaml`, plans the clone-to-tempdir + re-exec hand-off |
| auto-clone test 7: live file:// clone actually completes the hand-off |
| Sibling tasks | T-1634 (auto-clone), T-1542 (detection) |

### Shape 4: consumer-vendored-skewed — vendored copy diverged from upstream

| What | Evidence |
|------|----------|
| Test files | `tests/unit/upgrade_auto_clone.bats` tests 3-7 |
| Tests proving headline | 5/5 ok |
| Specific firing | Test 3: "bare-from-consumer with NO upstream_repo and NO --from-upstream — clear 3-path remediation" — graceful refusal with three concrete remediation paths instead of silent crash |
| Test 6: "GitHub shorthand (owner/repo) in upstream_repo is normalised" — graceful default for non-URL syntax |
| Sibling tasks | T-1634 (auto-clone path), T-1673 (fabric drift orphan check for cross-repo cards) |

## Cross-Cutting Tests

These bats files exercise project-shape behaviour across multiple shapes:

| File | Tests | Subject |
|------|-------|---------|
| `tests/unit/lib_upgrade.bats` | 12 | core upgrade flow (framework → consumer) |
| `tests/unit/lib_paths.bats` | varies | path resolution under vendored / framework-repo / global modes |
| `tests/unit/test_upgrade_self_target_guard.bats` | 4 | self-target / bare-from-consumer detection |
| `tests/unit/upgrade_auto_clone.bats` | 7 | upstream URL resolution + auto-clone hand-off |
| `tests/unit/upgrade_fresh_machine_simulation.bats` | 3 | end-to-end fresh-machine simulation (env -i + minimal PATH) |

## What "Silent Error Fall-Through" Looked Like Before This Arc

Before the arc, `fw upgrade` invoked from inside a consumer's `.agentic-framework/`:
1. Resolved `FRAMEWORK_ROOT` to the vendored copy
2. Resolved `target_dir` to cwd (= the consumer's `.agentic-framework/`)
3. Both canonicalised to the same path
4. `do_vendor` quietly performed a self-copy operation that corrupted mid-stream at step 4b/9 (origin OBS-032, T-1542)
5. The agent and user only knew something broke when the session became unresponsive

Now: the same invocation is caught BEFORE any mutation (T-1542 guard at `lib/upgrade.sh:192`), with a clear message naming both paths, OR auto-routed to the upstream framework via clone-to-tempdir + re-exec (T-1634).

## Arc Children — Final Status

| Task | Title | Status |
|------|-------|--------|
| T-1257 | Fix context-blind fw path rule in CLAUDE.md | work-completed |
| T-1542 | fw upgrade bare-from-consumer detect+route | started-work (human-owned; arc anchor) |
| T-1634 | fw upgrade --from-upstream + auto-clone | work-completed |
| T-1635 | fresh-machine simulation guard (slim slice) | work-completed |
| T-1673 | fabric drift orphan check for cross-repo cards | work-completed |
| T-1675 | Project-shape conflation umbrella | work-completed |
| T-1822 | fix project-boundary cwd-trap (vendored .agentic-framework/) | work-completed |
| T-1823 | web/test_app.py consumer-vs-framework data-shape bleed | work-completed |

## Suggested Decision Text (for `fw arc close ... --decision "..."`)

> The 4 project shapes (framework / consumer-init / consumer-fresh / consumer-vendored-skewed) are each covered by deterministic bats tests that fire the arc's headline mechanic — `fw` verbs either succeed cleanly, refuse with actionable guidance, or auto-route to a sensible default. The "silent error fall-through" class that motivated the arc (OBS-032 / T-1542 origin: session-fatal mid-upgrade crashes from path collapse) is now structurally impossible via T-1542's pre-mutation guard + T-1634's auto-clone hand-off. CLAUDE.md codifies the "Consumer-Facing Command Hygiene" rule so future commands inherit the discipline. Live full-upgrade docker variant deferred to a release-gate follow-up.
