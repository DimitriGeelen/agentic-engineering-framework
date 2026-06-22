---
id: T-2458
name: "AEF fw-MCP adoption strategy — consumers unwired + docs shell-only + deferred-tool friction (arc-010 headline-mechanic gap)"
description: >
  Inception: AEF fw-MCP adoption strategy — consumers unwired + docs shell-only + deferred-tool friction (arc-010 headline-mechanic gap)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-06-22T07:54:23Z
last_update: 2026-06-22T08:09:46Z
date_finished: 2026-06-22T08:09:46Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
---

# T-2458: AEF fw-MCP adoption strategy — consumers unwired + docs shell-only + deferred-tool friction (arc-010 headline-mechanic gap)

## Problem Statement

We exposed `fw` CLI functionality through an MCP server (`agents/mcp/framework_mcp_server.py`,
stdio, 22 curated tools) but **nobody uses it** — our own agents shell out to `bin/fw` (this
session: ~30 shell calls, 0 `mcp__fw__*` calls) and consumer ("other AEF") projects never receive
the server in their `.mcp.json`. This is arc-010's headline-mechanic gap: substrate shipped, the
deliverable (an agent observably using the MCP) never landed (G-062 / §ACD).

Three root causes (full evidence: `docs/reports/T-2458-aef-mcp-adoption-strategy.md`):
1. **Consumers can't** — `fw init`/`fw upgrade` never wire the `fw` server (`lib/init.sh:822`,
   `lib/upgrade.sh:1462` hardcode only context7/playwright/termlink). CRITICAL.
2. **Nobody's told to** — CLAUDE.md teaches `bin/fw` in every example, zero `mcp__fw__*` steering;
   tools are deferred (ToolSearch friction) vs always-present Bash.
3. **Hangs in workers** — framework-mcp stays `pending` in dispatched workers (OBS-058/061,
   T-2268 ACs 4-7).

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->
- Wiring the `fw` server into consumer `.mcp.json` on init/upgrade is *necessary* to enable
  adoption (maybe not sufficient — docs/coverage may still gate actual use).
- TermLink's adoption is driven by auto-wiring + near-complete CLI mirror — **VALIDATED** by the
  `/opt/termlink` code-read (artifact §4): TermLink ships its MCP pre-wired in the `.mcp.json`
  template every consumer inherits, and auto-discovers ~220 tools by verb-suffix convention (zero
  manual maintenance). AEF made the opposite choice on both. Codegen-from-`fw help` would make
  Strategy 3 (parity) nearly free — a material input to the IW-1 strategy call.

## Open Questions

- **IW-1: Which adoption strategy — (1) MCP-first for the common path, (2) MCP for specific
  contexts only [consumer/cross-project, sandboxed, worktree gate-bypass], or (3) invest to
  full CLI parity + MCP-first docs?**
  confidence: 3
  disposition: answered
  rationale: Operator chose (chat 2026-06-22) the full "make MCP the real interface" path —
  A=MCP-default + B=CLI-auto-added-to-MCP (codegen) + C=auto-propagate via init/upgrade = Strategy 3.
  Sequenced C→B→A. Two hard constraints: gate-matcher parity for mcp__fw__*; sovereignty denylist in
  codegen. See artifact §5. Formal GO recorded at /inception/T-2458.
- **IW-2: Is consumer-wiring alone (slice 1) sufficient for adoption, or is an MCP-first docs/
  steering change also required?**
  confidence: 2
  disposition: deferred
  rationale: Strong prior that steering is also needed (RC-2: I am Exhibit A — server was wired
  in the framework repo yet I still shelled). Resolve once TermLink's discoverability design is read.

## Exploration Plan

- Map AEF MCP wiring + root causes (Explore sweep) — **DONE**, see artifact §2.
- Benchmark TermLink's adopted MCP (`/opt/termlink` code-read) — **IN PROGRESS**, artifact §4.
- Contact TermLink agent on thread `aef-mcp-adoption` — posted (self-loop caveat noted).

## Technical Constraints

- AEF is intentionally **per-project vendored / isolated** (the deliberate inverse of TermLink's
  machine-wide single-binary model) — TermLink's distribution lessons transfer only partially.
- Sovereignty verbs (inception_decide, tier0_approve, arc_close, bvp_confirm, enforcement_baseline)
  are intentionally excluded from the MCP — adoption must not erode that boundary.

## Scope Fence

**IN:** diagnosing non-adoption; deciding the strategy; the consumer-wiring fix (slice 1); the
worker-hang fix (slice 2). **OUT (this inception):** building docs/coverage changes (slices 3+,
gated on IW-1); redesigning the MCP server; changing the sovereignty exclusion list.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause(s) identified with a bounded slice-1 (consumer-wiring) fix path — **met** (RC-1, §2)
- The strategy fork (IW-1) is a real decision the operator can make from the evidence — **met**
- Slice 1 is correct independent of which strategy is chosen — **met** (wiring is prerequisite to all 3)

**NO-GO if:**
- The MCP should be deprecated rather than adopted (e.g. shell is strictly preferable everywhere)
- Adoption would require eroding the sovereignty-verb exclusion boundary (it does not)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:**

Adoption gap confirmed: (1) fw init/upgrade never wire the fw server into consumer .mcp.json (lib/init.sh:822, lib/upgrade.sh:1462) so other AEF projects cannot use it; (2) CLAUDE.md teaches bin/fw in every example, zero mcp__fw__ steering; (3) mcp__fw__ tools are deferred (ToolSearch friction) while Bash is always present. This is arc-010's headline mechanic (an agent observably using the MCP) never landing despite substrate shipping (G-062/ACD). GO to pursue adoption; consumer-wiring is correct under any strategy and is slice 1; human picks strategy 1/2/3 via the inception decision.

**Evidence:**
- RC-1 (consumers unwired): `lib/init.sh:822-845` template lacks `fw`; `lib/upgrade.sh:1462`
  `recommended_servers` lacks `fw`; T-2268 (`6ef1c1816`) wired only the framework's own `.mcp.json`.
- RC-2 (no steering): CLAUDE.md has 0 `mcp__fw__*` references, ~30 `bin/fw` examples; `mcp__fw__*`
  are deferred tools (this session: 30 shell calls, 0 MCP calls = Exhibit A).
- RC-3 (worker hang): OBS-058/059/060/061; T-2268 ACs 4-7 blocked; partial fix T-2282.
- Gate lever: `.claude/settings.json` matchers `Bash|Write|Edit` don't match `mcp__fw__*` → MCP
  bypasses the worktree Bash gate (OBS-080), then re-applies gates by shelling to `bin/fw`.
- Full artifact: `docs/reports/T-2458-aef-mcp-adoption-strategy.md`.

**Proposed slices (on GO):**
1. **Consumer-wiring** (correct under any strategy) — `fw init`/`fw upgrade` add the `fw` server to
   consumer `.mcp.json`; consumer-facing → must keep `upgrade_fresh_machine_simulation.bats` green.
2. **Worker-hang** — close OBS-058/061, T-2268 ACs 4-7.
3+. **Docs/coverage** — gated on IW-1 (the chosen strategy).

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Adoption gap confirmed: (1) fw init/upgrade never wire the fw server into consumer .mcp.json (lib/init.sh:822, lib/upgrade.sh:1462) so other AEF projects cannot use it; (2) CLAUDE.md teaches bin/fw in every example, zero mcp__fw__ steering; (3) mcp__fw__ tools are deferred (ToolSearch friction) while Bash is always present. This is arc-010's headline mechanic (an agent observably using the MCP) never landing despite substrate shipping (G-062/ACD). GO to pursue adoption; consumer-wiring is correct under any strategy and is slice 1; human picks strategy 1/2/3 via the inception decision.

**Date**: 2026-06-22T08:09:45Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-22T08:09:45Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Adoption gap confirmed: (1) fw init/upgrade never wire the fw server into consumer .mcp.json (lib/init.sh:822, lib/upgrade.sh:1462) so other AEF projects cannot use it; (2) CLAUDE.md teaches bin/fw in every example, zero mcp__fw__ steering; (3) mcp__fw__ tools are deferred (ToolSearch friction) while Bash is always present. This is arc-010's headline mechanic (an agent observably using the MCP) never landing despite substrate shipping (G-062/ACD). GO to pursue adoption; consumer-wiring is correct under any strategy and is slice 1; human picks strategy 1/2/3 via the inception decision.

### 2026-06-22T08:09:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3b8a760e
- **Timestamp:** 2026-06-22T08:09:47Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-1
     - evidence: `IW-1 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

### 2026-06-22T08:09:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
