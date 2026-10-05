---
id: T-3772
name: "OpenCode harness parity: every AEF, TermLink and Workflow Designer function
  works under OpenCode, enforced by a release parity test (operator direction relayed
  by 055, 2026-10-03)"
description: >
  Operator (verbatim via 055 opencode-parity 9bcf8f20): OpenCode should completely
  adopt AEF + TermLink + Workflow Designer functionality, also on the next release;
  breakage made known and remediated. Evidence 055 T-439: a Claude Code agent gets
  36 fw hooks + commands + MCP; an opencode agent (0506-Voxtype-extention) gets none,
  so sidecar mail lands and is never shown. Ask: adapter mapping opencode plugin events
  (tool.execute.before/after, session.idle) onto the same fw hook scripts; release
  parity test; T-3670 names an opencode plugin as the per-harness adapter.

status: captured
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-03T16:22:35Z
last_update: '2026-10-03T16:30:46Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-10-03T16:30:22Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=112,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-03T16:30:46Z'
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

# T-3772: OpenCode harness parity: every AEF, TermLink and Workflow Designer function works under OpenCode, enforced by a release parity test (operator direction relayed by 055, 2026-10-03)

## Problem Statement

Operator direction (2026-10-03, relayed verbatim by 055): "OpenCode should just completely adopt Agentic Engineering Framework functionality and TermLink functionality and Workflow Designer functionality … also when a next release comes. If something breaks down, then that should be made known and remediated." And: what 055 learns making opencode agents work goes into AEF's ONBOARDING for opencode installs, so every new opencode install gets it from the start.

Measured gap (055 T-439): a Claude Code agent gets 36 fw hooks + slash commands + fw/TermLink MCP; an opencode agent (0506-Voxtype-extention, AEF 1.7.832) gets none — sidecar mail lands at the hub and is never shown.

055's measured findings (opencode 1.18.34 on .107; write-up /opt/055-agentic-fleet-cockpit/docs/reports/T-439-opencode-mail.md, plugin /opt/055-agentic-fleet-cockpit/opencode/plugins/aef-mail.js, 055 commit e3bfa2ef — read via 055, project boundary):
1. Plugins load via OPENCODE_CONFIG with `"plugin": ["file:///abs/path.js"]`.
2. `session.idle` alone does not deliver mail to an agent waiting with no turn ending: a timer is needed (055 polls every 60 s, delivers only when the folder's session is not busy).
3. `session.list` returns EVERY folder's sessions (100 on .107): filter by directory and skip sessions with parentID, or mail lands in another project.
4. `/session/status` is `{}` when idle, a non-idle type when busy.
5. Reusing `fw hook sidecar-inbox` output unchanged (additionalContext) works as the delivery text; peek never consumes; dedup by content.
6. The project's fw path must be overridable for tests (055 uses AEF_MAIL_FW).
7. A project whose sidecar inbox was never used needs the hub anchor seed (`.context/sidecar/hub-id`, 055 OBS-024) before mail reaches it: fw init / fw upgrade must seed it for every fresh install (055 cc5bc7e8).
055 ships a MAIL-ONLY interim plugin via its cockpit launcher now and retires it when this lands; proven live both ways on opencode agents 020 and 0506 (2026-10-03).

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

**Rationale:** Operator direction is explicit and the gap is measured (0 of 36 hooks under opencode); the open questions are the adapter shape and the parity test, not whether.

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
