---
id: T-3752
name: "Vendor-divergence register: fw upgrade/vendor sees and refuses to silently
  erase a consumer's local fixes to vendored framework code (010 + 832 proposals)"
description: >
  Inception: Vendor-divergence register: fw upgrade/vendor sees and refuses to silently
  erase a consumer's local fixes to vendored framework code (010 + 832 proposals)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
origin: {kind: "peer", source: "010-termlink + 832-Workflow-designer", ref: "vendor-divergence proposals"}
created: 2026-10-02T23:00:16Z
last_update: 2026-10-05T22:35:59Z
date_finished: 2026-10-05T22:35:59Z
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
cost_estimate_proposed:
  - ts: '2026-10-02T23:15:20Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=136,acs=4)
    rubric_sha: e4a00f38e801
  - ts: '2026-10-05T20:15:20Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=159,acs=4)
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
  disposition: answered
  rationale: The base schema shipped in v1.8.2 (T-3850, lib/vendor_preserve.py): `.fwvendor-preserve.yaml` with `files:` (path or glob, optional reason) and `in_file:` (file plus marker or markers), and `.fw-vendor-stamp.json` holding sha256 per vendored file as the content baseline. Owning task and upstream status are NOT in it; they belong to IW-4.

- **IW-2: What does `fw upgrade` do with a declared divergence?** Refuse until resolved, keep the consumer's version, or overwrite and report each one by name?
  confidence: 1
  disposition: answered
  rationale: Shipped in v1.8.2 (T-3850):
    - a declared `files:` entry keeps the consumer's version and reports upstream changes to it;
    - an `in_file:` marker is checked, and MARKER MISSING is reported;
    - an undeclared local file makes the vendor REFUSE (exit 3, nothing written) unless --allow-delete-locals is given.
    Field-tested: ring20-manager kept 33 files and 832 kept 50 through their 1.8.2 upgrades.

- **IW-3: Undeclared changes.** Do we detect undeclared edits (hash against the vendored baseline) and locally added files at upgrade time, or adopt 832's G4 commit gate on the consumer side, or both?
  confidence: 1
  disposition: answered
  rationale: Detection at vendor time, shipped in T-3850:
    - locally ADDED files are found against the source's git history and refused;
    - local EDITS are found against `.fw-vendor-stamp.json` from the second vendor on.
    832's consumer-side commit gate (G4) is not adopted upstream. Automatic merging of edited in-file files is T-3885.

- **IW-4: Upstream intake.** How does a `filed-upstream` entry reach us as a task, and how does the consumer learn it is superseded, so the next re-vendor drops the entry cleanly?
  confidence: 1
  disposition: deferred
  rationale: Not built, and it is what remains of this inception. Today intake is manual: peer patches arrive as sidecar pickups and are triaged into tasks (e.g. T-3597, T-3879). A GO here scopes the build: add `owning_task` and `upstream_status` to the preserve manifest, and have the vendor report entries whose upstream fix has shipped (superseded), so the next re-vendor can drop them.

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

**Recommendation:** GO

**Rationale:**

Evidence from two consumers: 832's first protocol run (1.7.740) found 51 local fixes erased by re-vendor, an undeclared one (T-943 on lib/verification-port.sh) lost with nothing listing it, and 5 consumer-added files deleted by the vendor copy, 4 undeclared. 010-termlink runs a working register plus check (framework:pickup @304/@305). Both schemas exist and differ. Today fw upgrade overwrites silently, which violates the Reliability directive (no silent failures). Open: one schema reconciling 010 and 832, whether fw upgrade refuses or only reports, consumer-side commit gate (832 G4), and upstream intake of filed-upstream entries.

**Update 2026-10-05 (T-3896): most of this has since been BUILT.**
- v1.8.2 shipped T-3850 and T-3851: the preserve manifest, the refusal to delete undeclared local files, and the vendor stamp. That answers IW-1 to IW-3 (see the dispositions).
- T-3850 never referenced this inception. The build went ahead without a decision here, which is a traceability gap of its own.
- **What a GO now adopts:** only the remainder, IW-4 upstream intake. Add `owning_task` and `upstream_status` to `.fwvendor-preserve.yaml`, and have the vendor report entries whose upstream fix has shipped (superseded), so the next re-vendor can drop them.
- **What a NO-GO means:** the shipped T-3850 behaviour is enough, intake stays manual via pickups, and this inception closes as superseded.

**Evidence:**
- Research artifact: `docs/reports/T-3752-vendor-divergence.md`.
- `lib/vendor_preserve.py` (T-3850): manifest shape, the stamp, and refuse-on-uncovered-local (exit 3). Shipped in v1.8.2, 2026-10-05.
- Field results on v1.8.2: ring20-manager (33 local files kept, 0 refusals); 832 (50 local files kept); ring20-dashboard (7 local-only files listed exactly by the pre-check).
- Still open:
  - T-3885, automatic merge for edited in-file files (ring20-manager: 33 MARKER MISSING, 17/17 merged by hand without conflict);
  - T-3888, CLAUDE.md in-section edits (1409).

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

**Rationale**: Recommendation: GO

Rationale:

Evidence from two consumers: 832's first protocol run (1.7.740) found 51 local fixes erased by re-vendor, an undeclared one (T-943 on lib/verification-port.sh) lost with nothing listing it, and 5 consumer-added files deleted by the vendor copy, 4 undeclared. 010-termlink runs a working register plus check (framework:pickup @304/@305). Both schemas exist and differ. Today fw upgrade overwrites silently, which violates the Reliability directive (no silent failures). Open: one schema reconciling 010 and 832, whether fw upgrade refuses or only reports, consumer-side commit gate (832 G4), and upstream intake of filed-upstream entries.

Update 2026-10-05 (T-3896): most of this has since been BUILT.
- v1.8.2 shipped T-3850 and T-3851: the preserve manifest, the refusal to delete undeclared local files, and the vendor stamp. That answers IW-1 to IW-3 (see the dispositions).
- T-3850 never referenced this inception. The build went ahead without a decision here, which is a traceability gap of its own.
- What a GO now adopts: only the remainder, IW-4 upstream intake. Add `owning_task` and `upstream_status` to `.fwvendor-preserve.yaml`, and have the vendor report entries whose upstream fix has shipped (superseded), so the next re-vendor can drop them.
- What a NO-GO means: the shipped T-3850 behaviour is enough, intake stays manual via pickups, and this inception closes as superseded.

Evidence:
- Research artifact: `docs/reports/T-3752-vendor-divergence.md`.
- `lib/vendor_preserve.py` (T-3850): manifest shape, the stamp, and refuse-on-uncovered-local (exit 3). Shipped in v1.8.2, 2026-10-05.
- Field results on v1.8.2: ring20-manager (33 local files kept, 0 refusals); 832 (50 local files kept); ring20-dashboard (7 local-only files listed exactly by the pre-check).
- Still open:
  - T-3885, automatic merge for edited in-file files (ring20-manager: 33 MARKER MISSING, 17/17 merged by hand without conflict);
  - T-3888, CLAUDE.md in-section edits (1409).

**Date**: 2026-10-05T22:35:58Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-10-02T23:01:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-10-05T22:35:58Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale:

Evidence from two consumers: 832's first protocol run (1.7.740) found 51 local fixes erased by re-vendor, an undeclared one (T-943 on lib/verification-port.sh) lost with nothing listing it, and 5 consumer-added files deleted by the vendor copy, 4 undeclared. 010-termlink runs a working register plus check (framework:pickup @304/@305). Both schemas exist and differ. Today fw upgrade overwrites silently, which violates the Reliability directive (no silent failures). Open: one schema reconciling 010 and 832, whether fw upgrade refuses or only reports, consumer-side commit gate (832 G4), and upstream intake of filed-upstream entries.

Update 2026-10-05 (T-3896): most of this has since been BUILT.
- v1.8.2 shipped T-3850 and T-3851: the preserve manifest, the refusal to delete undeclared local files, and the vendor stamp. That answers IW-1 to IW-3 (see the dispositions).
- T-3850 never referenced this inception. The build went ahead without a decision here, which is a traceability gap of its own.
- What a GO now adopts: only the remainder, IW-4 upstream intake. Add `owning_task` and `upstream_status` to `.fwvendor-preserve.yaml`, and have the vendor report entries whose upstream fix has shipped (superseded), so the next re-vendor can drop them.
- What a NO-GO means: the shipped T-3850 behaviour is enough, intake stays manual via pickups, and this inception closes as superseded.

Evidence:
- Research artifact: `docs/reports/T-3752-vendor-divergence.md`.
- `lib/vendor_preserve.py` (T-3850): manifest shape, the stamp, and refuse-on-uncovered-local (exit 3). Shipped in v1.8.2, 2026-10-05.
- Field results on v1.8.2: ring20-manager (33 local files kept, 0 refusals); 832 (50 local files kept); ring20-dashboard (7 local-only files listed exactly by the pre-check).
- Still open:
  - T-3885, automatic merge for edited in-file files (ring20-manager: 33 MARKER MISSING, 17/17 merged by hand without conflict);
  - T-3888, CLAUDE.md in-section edits (1409).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-adf84422
- **Timestamp:** 2026-10-05T22:36:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-1d394f54
- **Timestamp:** 2026-10-05T22:36:01Z
- **Overall:** CONFIRMED
- **Claims:** 8

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/T-3752-vendor-divergence.md` | file | ✓ pass |
| `lib/vendor_preserve.py` | file | ✓ pass |
| `T-943` | task | ✓ pass |
| `T-3896` | task | ✓ pass |
| `T-3850` | task | ✓ pass |
| `T-3851` | task | ✓ pass |
| `T-3885` | task | ✓ pass |
| `T-3888` | task | ✓ pass |

### 2026-10-05T22:35:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
