---
id: T-3731
name: "Revise the configuration engine: auto-discover new config keys (framework + external modules TermLink, Workflow Designer, LiteLLM) onto the Watchtower config surface, with version monitoring and currency per external module"
description: >
  Inception: Revise the configuration engine: auto-discover new config keys (framework + external modules TermLink, Workflow Designer, LiteLLM) onto the Watchtower config surface, with version monitoring and currency per external module

status: captured
workflow_type: inception
owner: human
horizon: next
tags: [config, high-value, arc-candidate, termlink, designer, litellm, version-monitoring]
components: []
related_tasks: []
created: 2026-10-02T14:55:03Z
last_update: 2026-10-02T14:55:03Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
---

# T-3731: Revise the configuration engine: auto-discover new config keys (framework + external modules TermLink, Workflow Designer, LiteLLM) onto the Watchtower config surface, with version monitoring and currency per external module

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Inventory: where does configuration live today (FW_CONFIG_REGISTRY, .framework.yaml, policy/*.yaml pins, env-only FW_* keys, hard-coded floors like termlink_transport VERSION_FLOOR, LiteLLM base URL/model routes, Workflow Designer pin), and which keys exist in code but not in the registry?**
  confidence: 1
- **IW-2: Discovery: how are new config keys found automatically (static scan of fw_config/FW_* reads, a module manifest each external module publishes, or both) and surfaced on the Watchtower config page with owner, default, source and validation?**
  confidence: 0
- **IW-3: External modules (TermLink, Workflow Designer, LiteLLM, plus future ones): one module registry with installed version, required floor, latest available, currency status and upgrade advice, consumed by fw doctor, audit and the config page?**
  confidence: 0
- **IW-4: Scope: one inception plus build slices, or a separate arc (operator: "maybe even a separate arc later"); and what is the headline mechanic an operator would observe?**
  confidence: 1

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

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

Operator request 2026-10-02, high value. Today: a hand-maintained registry (lib/config.sh FW_CONFIG_REGISTRY, ~47 keys, Watchtower /config); external-module settings and versions are scattered and ad hoc: designer pin + fw designer check-currency (whose advice is wrong, T-3729), a hard-coded TermLink VERSION_FLOOR in lib/sidecar/termlink_transport.py, LiteLLM referenced only as an ANTHROPIC_BASE_URL override with no config entry or version check. New settings appear without being registered (config-registry parity lint only checks one direction). GO on exploration: inventory every config and version surface, design discovery + a module registry, decide whether it becomes its own arc.

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
