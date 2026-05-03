# T-1641 Worker W10 — Drift Defenses (Absent)

**Scope:** Tests / audits / monitors / hooks that should EXIST to keep the T-1061 orchestrator arc from rotting silently.

## Summary

The arc shipped without a perimeter. Nothing structurally fails when a future agent (a) adds an MCP tool that skips `check_task_governance()`, (b) changes `DEFAULT_MODEL_FALLBACK`, (c) drifts frame 0x8 byte layout, (d) typos `tasktype:build` for `task-type:build`, or (e) drifts the `route_cache` on-disk schema. `fw audit` has zero orchestrator checks. `.fabric/components/` holds the TermLink crate but no cards for router/fallback/frame submodules. `concerns.yaml` names no decay vectors for this arc. Watchtower has `/sessions` but no orchestration-health surface — the absence that triggered T-1641 ("I see nothing that indicates we are orchestrating").

## Defense gap table

| # | Defense | Exists? | If absent — risk | Proposed mechanism |
|---|---------|---------|------------------|--------------------|
| 1 | MCP-tool `task_id` enforcement audit | No | High: G-011 recurrence in any new tool | `agents/audit/audit.sh` greps `tools.rs` for `handle_*` not preceded by `check_task_governance`; CI lint |
| 2 | Fallback-chain regression test | No | Medium: silent change loses Sonnet→Haiku resilience guaranteed by T-1061 | `tests/unit/test_fallback_chain.rs` pinning constant members + order |
| 3 | Governance-frame protocol regression | No | High: subscribers desync silently; G-017 reopens | `tests/integration/test_governance_frame.rs` with hex-golden fixture |
| 4 | Task-type tag-format invariant | No | High: typo → router silently picks default specialist; no error/log/metric | `termlink spawn` validates known tag prefixes; `fw audit` lints session tags |
| 5 | `route_cache` persistence-schema test | No | Medium: serde drift breaks restore silently; cold router each restart | v1 fixture in `tests/unit/test_route_cache_schema.rs`; version-tag file; refuse-and-rebuild on mismatch |
| 6 | WezTerm plugin contract test | No | Medium: plugin consumes `termlink list --json`; renamed key breaks plugin silently | Shared JSON schema file + integration test validating both sides |
| 7 | `fw audit` orchestrator-arc checks | No | High: rot invisible by definition (see §Summary) | New `agents/audit/orchestrator-scan.sh`: handler count, fallback length, frame test presence |
| 8 | Fabric coverage of orchestrator modules | Partial — TermLink crate registered; no router/fallback/frame cards | Medium: `fw fabric blast-radius` blind to changes in those modules | Register cross-repo cards: `termlink-orchestrator-router.yaml`, `-fallback.yaml`, `-governance-frame.yaml` |
| 9 | Concerns-register "orchestrator arc rot" | No — G-019 is generic | Medium: no durable breadcrumb for next session | Open **G-025 — Orchestrator Arc Rot** with the five decay vectors above |
| 10 | Watchtower orchestration-health page | No — `/sessions` ≠ orchestration health | High: operator has no at-a-glance signal; depends on running cargo locally | New `/orchestrator` blueprint: last N routing decisions, per-task-type specialist counts, fallback hit-rate, frame emit/recv tallies |

## Top 5 highest-impact absent defenses

1. **MCP-tool `task_id` audit (#1)** — direct G-011 recurrence vector; one grep in `audit.sh`. Highest likelihood: every new MCP tool is a fresh chance to forget.
2. **Watchtower `/orchestrator` page (#10)** — directly answers the question that triggered T-1641. Single biggest antifragility win.
3. **`fw audit` orchestrator-arc checks (#7)** — umbrella that makes #1/#2/#4 fail loudly instead of silently.
4. **Governance-frame protocol regression (#3)** — silent wire-format drift is the worst failure class. One golden hex fixture closes it for years.
5. **Task-type tag-format validator (#4)** — typo-class bugs are the most common silent-router-default vector; today the router cannot distinguish "no match" from "user typoed".

## Recommended follow-up tasks (`from-T-1641`)

- **T-NEW-A** *(audit/build)* — MCP-tool `task_id` scan in `agents/audit/audit.sh`; CI fails on missing `check_task_governance`. → #1
- **T-NEW-B** *(build)* — Watchtower `/orchestrator` blueprint: routing decisions, fallback status, frame counters. → #10
- **T-NEW-C** *(test)* — Bundled regression tests: fallback chain, route_cache schema, governance frame golden, `termlink list --json` schema. → #2/#3/#5/#6
- **T-NEW-D** *(build)* — `termlink spawn` validates known tag-prefix vocabulary; rejects unknown `task-type:` typos with actionable error. → #4
- **T-NEW-E** *(governance)* — Open G-025 in `concerns.yaml`; register the five decay vectors; close items only as defenses land. Anchors the rest. → #9
- **T-NEW-F** *(fabric)* — Cross-repo fabric cards for orchestrator/router/fallback/frame. → #8

Each follow-up is small (≤4h), reversible, with binary pass/fail. Sequencing: E first (durable register), then A+C in parallel, then B/D/F.
