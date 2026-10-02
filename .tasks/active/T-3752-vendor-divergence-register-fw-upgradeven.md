---
id: T-3752
name: "Vendor-divergence register: fw upgrade/vendor sees and refuses to silently
  erase a consumer's local fixes to vendored framework code (010 + 832 proposals)"
description: >
  Inception: Vendor-divergence register: fw upgrade/vendor sees and refuses to silently
  erase a consumer's local fixes to vendored framework code (010 + 832 proposals)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-02T23:00:16Z
last_update: 2026-10-02T23:01:59Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-10-02T23:02:00Z'
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
---

# T-3752: Vendor-divergence register: fw upgrade/vendor sees and refuses to silently erase a consumer's local fixes to vendored framework code (010 + 832 proposals)

## Problem Statement

Consumers patch vendored framework code (`.agentic-framework/`) to fix bugs before we release the fix, and every `fw upgrade` / `fw vendor` erases those patches silently. Consumer-added files under the vendored tree get deleted too. 832 measured it on its first protocol run (2026-10-02, 1.7.740): 51 fixes to re-decide; one undeclared fix (T-943, lib/verification-port.sh) lost with nothing listing it; 5 local files deleted, 4 of them undeclared. 010-termlink runs a register plus checker (framework:pickup @304 code and guide, @305 live register). 832 originated the convention with a different schema. Both asked for it upstream. A silent overwrite violates the Reliability directive.

## Assumptions

- A declared register (path, reason, upstream status, owning task) is enough for `fw upgrade` to name every fix it is about to erase.
- 010's and 832's schemas can be reconciled into one without losing either side's fields.

## Open Questions

- **IW-1: One schema.** Which fields reconcile 010's `.vendor-divergence.yaml` and 832's? Candidates: path, content hash at patch time, reason, owning task, upstream status (filed-upstream / local-only / superseded).
  confidence: 1

- **IW-2: What does `fw upgrade` do with a declared divergence?** Refuse until resolved, keep the consumer's version, or overwrite and report each one by name?
  confidence: 1

- **IW-3: Undeclared changes.** Do we detect undeclared edits (hash against the vendored baseline) and locally added files at upgrade time, or adopt 832's G4 commit gate on the consumer side, or both?
  confidence: 1

- **IW-4: Upstream intake.** How does a `filed-upstream` entry reach us as a task, and how does the consumer learn it is superseded, so the next re-vendor drops the entry cleanly?
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

Evidence from two consumers: 832's first protocol run (1.7.740) found 51 local fixes erased by re-vendor, an undeclared one (T-943 on lib/verification-port.sh) lost with nothing listing it, and 5 consumer-added files deleted by the vendor copy, 4 undeclared. 010-termlink runs a working register plus check (framework:pickup @304/@305). Both schemas exist and differ. Today fw upgrade overwrites silently, which violates the Reliability directive (no silent failures). Open: one schema reconciling 010 and 832, whether fw upgrade refuses or only reports, consumer-side commit gate (832 G4), and upstream intake of filed-upstream entries.

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

### 2026-10-02T23:01:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
