---
id: T-038
name: "Upgrade framework loop detection with OpenClaw's 4-detector pattern"
description: >
  Inception: Evaluate replacing the framework's loop-detect.ts (270 LOC, 3 basic detectors)
  with OpenClaw's extracted pattern (624 LOC, 4 detectors with graduated thresholds,
  configurable settings, and warning key dedup).

status: captured
workflow_type: inception
owner: human
horizon: now
tags: [framework-improvement, extracted-pattern, loop-detection]
components: []
related_tasks: [T-036, T-024]
created: 2026-03-27T18:54:49Z
last_update: 2026-03-27T18:54:49Z
date_finished: null
---

# T-038: Upgrade framework loop detection with OpenClaw's 4-detector pattern

## Problem Statement

The framework's loop detector (`lib/ts/src/loop-detect.ts`, 270 LOC) has 3 basic detectors with
hardcoded thresholds (WARNING=5, CRITICAL=10). OpenClaw's version (624 LOC) is significantly more
sophisticated with 4 detectors, graduated thresholds, result-outcome hashing for no-progress
detection, and warning key deduplication. The framework already experienced the "23 handover commits
in sprechloop" incident (referenced in `checkpoint.sh:116`) partly because the loop detector
couldn't distinguish "same tool, same args, same result" from "same tool, same args, different result."

**For:** Framework users (agents running under the framework)
**Why now:** Pattern extracted and tested via T-036; current detector has known blind spots.

## Key Artifacts

| Artifact | Location | Description |
|----------|----------|-------------|
| Extracted pattern | `docs/extracted/tool-loop-detection.ts` | Zero-dep standalone, 300 LOC |
| OpenClaw original | `src/agents/tool-loop-detection.ts` | Full 624 LOC with all detectors |
| OpenClaw tests | `src/agents/tool-loop-detection.test.ts` | Comprehensive test suite |
| Framework current | `.agentic-framework/lib/ts/src/loop-detect.ts` | 270 LOC, 3 detectors |
| Framework shell wrapper | `.agentic-framework/agents/context/loop-detect.sh` | PostToolUse hook |
| Evaluation report | `docs/reports/EVALUATION-SUMMARY.md` | Tier 1 recommendation |
| Framework fixes analysis | `.context/episodic/T-024.yaml` | Framework improvement recommendations |

## Comparison: Current vs OpenClaw

| Feature | Framework (current) | OpenClaw (extracted) |
|---------|--------------------|-----------------------|
| Detectors | 3 (generic_repeat, ping_pong, no_progress) | 4 (+global_circuit_breaker) |
| No-progress | Simple "same result streak" | Result hashing with tool-specific extractors |
| Ping-pong | Fixed alternation check | Full alternating-tail with progress evidence |
| Circuit breaker | None | Global absolute cap (prevents runaway) |
| Thresholds | Hardcoded (5/10) | Configurable per-instance |
| Warning dedup | None (same warning repeated) | Warning keys prevent flooding |
| State | JSON file per session | In-memory state object (adaptable) |

## Assumptions

- A-001: The framework's PostToolUse hook interface is compatible with the new detector signature
- A-002: Adding result-outcome hashing won't add meaningful latency (<10ms per call)
- A-003: Configurable thresholds are valuable (different tool types need different sensitivity)

## Exploration Plan

1. **Spike 1 (1h):** Map the integration surface — what changes in loop-detect.sh and the hook JSON contract
2. **Spike 2 (1h):** Port the extracted pattern into `lib/ts/src/loop-detect.ts`, preserving the file-based state persistence
3. **Spike 3 (30min):** Test with real PostToolUse JSON payloads from a session transcript

## Technical Constraints

- Must remain a single-file TypeScript module (compiled via esbuild to CJS)
- Must read PostToolUse JSON from stdin, output to stderr
- Exit codes: 0=allow, 2=block (Claude Code PreToolUse semantics)
- Performance: <100ms per invocation (current target)
- State file: `.context/working/.loop-detect.json`

## Scope Fence

**IN:** Replace loop-detect.ts with upgraded version, update shell wrapper if needed
**OUT:** Changing the hook architecture, adding new hooks, modifying budget-gate.sh

## Acceptance Criteria

- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Integration surface is clean (no hook contract changes needed)
- Performance stays under 100ms
- At least 2 of 3 new features add value (configurable thresholds, circuit breaker, warning dedup)

**NO-GO if:**
- Requires hook architecture changes
- Performance regression >50ms
- Current detector already handles the identified failure modes adequately

## Verification

## Decisions

## Decision

<!-- Filled at completion via: fw inception decide T-038 go|no-go --rationale "..." -->

## Updates
