---
id: T-2520
name: "AEF-side integration surface for Workflow Designer (T-173 collab with 832)"
description: >
  Inception: AEF-side integration surface for Workflow Designer (T-173 collab with
  832)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-07-10T09:19:41Z
last_update: 2026-07-10T11:28:25Z
date_finished: 2026-07-10T11:28:25Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-07-10T09:20:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-07-10T09:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2520: AEF-side integration surface for Workflow Designer (T-173 collab with 832)

## Problem Statement

The 832-Workflow-designer agent opened inception T-173 (their repo, their SoT):
integrate the Workflow Designer into AEF's surface area **while 832 stays the single
source of truth and future dev continues in 832**. They asked the AEF agent (me) to
answer IW-1..IW-5 — chiefly IW-1: *does AEF already have a plugin/component/tool-
registration mechanism the designer can plug into, or must it be built?* This AEF-side
inception governs my measured answers + a recommended AEF integration mechanism, which
feeds a **joint** recommendation to the operator. I do not build integration code; the
go/no-go and the integration-unit choice are the operator's. Cross-repo, portability
(Directive 4) implications → inception, not build.

Peer artifact: `/opt/832-Workflow-designer/docs/reports/T-173-aef-integration-inception.md`.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

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

- **IW-1: Does AEF have a plugin/component/tool-registration mechanism the designer can plug into, or must it be built?**
  confidence: 3
  disposition: answered
  rationale: Measured — AEF has NO general external-component/runtime loader. Its registration surfaces register *in-repo* units or expose *fw's own* verbs: MCP manifest (`policy/capability-overlay/tool-set.yaml` → `framework-mcp-manifest.json`) registers fw subcommands as MCP tools, not external apps; "plugin" (`agents/audit/plugin-audit.sh`, bin/fw:3644) audits Claude-Code *skills* for task-awareness — it is NOT a loader; Component Fabric reads cards as YAML *data* (topology/docs), never sources/execs them; agents/ + fw subcommands are in-repo dispatch. ⇒ M4-as-literally-stated must be built; the lightweight equivalent (thin `fw designer` wrapper over a pinned vendored build) does not.

- **IW-2: What reference/sync mechanism gives the cleanest "832=SoT, AEF=consumer" with least friction?**
  confidence: 3
  disposition: answered
  rationale: Recommend M3 (832 publishes a versioned single-file build) + a small NEW AEF fetch/pin surface (a `fw designer` subcommand — one case arm per bin/fw's route table, `bin/fw:3519`) that vendors the pinned released build. CORRECTION to my kickoff hypothesis: AEF's vendor/upgrade machinery CANNOT be "run in reverse" — the mapper confirmed it copies the *whole framework* framework→consumer only (`do_vendor` bin/fw:269; `--source`/`.upstream` pin a whole-framework git origin, not a component; "there is no path to pull a consumer's component up"). So M5-as-reuse is off the table; a scoped fetch is net-new but cheap. Reject M1/M2 (submodule/subtree pull *source* → cycle risk + consumer-init friction), M4 (no loader exists to plug into — IW-1).

- **IW-3: What exactly is the integration unit (single-file editor / +server / +corpus / +bridge+validator)?**
  confidence: 1
  disposition: deferred
  rationale: Operator's call — smaller unit = cheaper integration. My recommendation defaults to the single-file editor build as the minimal unit; awaiting operator confirmation. Authority gap, not evidence gap.

- **IW-4: How is the 832↔AEF dependency cycle avoided?**
  confidence: 3
  disposition: answered
  rationale: AEF references a *build artifact / pinned ref* of 832, never a recursive source pull. 832 vendors AEF (governance) at `.agentic-framework/`; AEF vendors only 832's *released designer build* — two artifacts, no source recursion. Confirmed AEF has no existing reference to 832 today (grep clean), so we start from zero coupling.

- **IW-5: Version & release cadence — how does an AEF user get a specific reproducible designer version, and how do releases propagate?**
  confidence: 2
  disposition: answered
  rationale: 832 owns a version tag on each released single-file build; AEF pins that version in its vendor manifest and bumps on `fw upgrade`-style sync. Reproducibility = pinned version string in AEF; propagation = 832 release → AEF pin-bump (manual or a scheduled mirror), same discipline as the framework's own vendor pin.

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

**Recommendation:** DEFER

**Rationale:**

Mechanism is answerable now from measurement (see artifact: AEF has no external-component loader; recommend M3 released-artifact from 832 + thin in-repo fw-designer wrapper reusing the vendor-sync machinery, referencing a pinned BUILD artifact not 832 source → no dep cycle). DEFER the overall go/no-go pending (a) operator's IW-3 integration-unit choice and (b) the joint recommendation with the 832 agent — an authority/coordination gap, not a confidence hedge.

**Evidence:**

- **IW-1 (no loader) — measured:** MCP registration wraps *fw's own verbs* only (`policy/capability-overlay/tool-set.yaml`, emitter `agents/mcp/manifest.py`, `fw mcp emit-manifest` bin/fw:5026; `fw_command` must be a real fw verb — no external exec target). "plugin" = skill governance-audit (`agents/audit/plugin-audit.sh`, bin/fw:3644), not a loader; `plugins/` holds only a WezTerm config. Component Fabric reads cards as YAML data, never sources/execs them (topology only). Agents/subcommands/blueprints all wired by editing a hardcoded case-arm/list (`bin/fw:3519` route table; `web/blueprints/__init__.py:7`). ⇒ no runtime plugin loader, no external-component registration anywhere.
- **IW-4 (no cycle) — measured:** AEF has no *code* reference to 832 (no import/exec/source anywhere). Plan references a *pinned build artifact*, never 832 source. (Correction to draft's "zero reference": prior *governance* history exists — T-2202/T-2203 setup tasks — but those are docs/tasks, not code coupling; IW-4 is about dependency cycles, which are nil.)
- **Recommended mechanism:** M3 (832 releases a versioned single-file designer build) + a thin in-repo `fw designer` launcher over a pinned, vendored copy of that build. Satisfies C1 (832=SoT), C2 (dev stays in 832), C3/Directive-4 (standard git/release + one small case arm), IW-4 (artifact not source).
- **Full analysis + mechanism map:** `docs/reports/T-2520-aef-integration-surface.md`.
- **Peer inception:** `/opt/832-Workflow-designer/docs/reports/T-173-aef-integration-inception.md`; reply posted to TermLink thread T-173.

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

**Rationale**: Mechanism is answerable now from measurement (see artifact: AEF has no external-component loader; recommend M3 released-artifact from 832 + thin in-repo fw-designer wrapper reusing the vendor-sync machinery, referencing a pinned BUILD artifact not 832 source → no dep cycle). DEFER the overall go/no-go pending (a) operator's IW-3 integration-unit choice and (b) the joint recommendation with the 832 agent — an authority/coordination gap, not a confidence hedge.

**Date**: 2026-07-10T11:28:24Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-07-10T09:20:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-07-10T11:28:24Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Mechanism is answerable now from measurement (see artifact: AEF has no external-component loader; recommend M3 released-artifact from 832 + thin in-repo fw-designer wrapper reusing the vendor-sync machinery, referencing a pinned BUILD artifact not 832 source → no dep cycle). DEFER the overall go/no-go pending (a) operator's IW-3 integration-unit choice and (b) the joint recommendation with the 832 agent — an authority/coordination gap, not a confidence hedge.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-233589f5
- **Timestamp:** 2026-07-10T11:28:26Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 4

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-1
     - evidence: `IW-1 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-2
     - evidence: `IW-2 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  3. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-4
     - evidence: `IW-4 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  4. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-5
     - evidence: `IW-5 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-3c4ef930
- **Timestamp:** 2026-07-10T11:28:26Z
- **Overall:** CONFIRMED
- **Claims:** 9

| Claim | Type | Status |
|-------|------|--------|
| `policy/capability-overlay/tool-set.yaml` | file | ✓ pass |
| `agents/mcp/manifest.py` | file | ✓ pass |
| `agents/audit/plugin-audit.sh` | file | ✓ pass |
| `web/blueprints/__init__.py:7` | file_line | ✓ pass |
| `docs/reports/T-2520-aef-integration-surface.md` | file | ✓ pass |
| `/opt/832-Workflow-designer/docs/reports/T-173-aef-integration-inception.md` | file | ✓ pass |
| `T-2202` | task | ✓ pass |
| `T-2203` | task | ✓ pass |
| `T-173` | task | ✓ pass |

### 2026-07-10T11:28:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
