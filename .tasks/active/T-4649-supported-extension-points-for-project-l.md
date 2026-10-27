---
id: T-4649
name: "Supported extension points for project-local hook additions so consumers stop
  patching vendored files (ring20: 27 in-file patches)"
description: >
  ring20 (msg 83c8790d): patches check-tier0, check-project-boundary, web/app.py,
  approvals, notify, enrich, shared.py in place; every upgrade overwrites them. Explore:
  a project hooks.d run before/after each framework hook with a defined contract (can
  add a refusal, never remove one), .framework.yaml-declared allowlists per gate,
  and which of ring20's 27 patches are general enough to upstream instead.

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [consumer, upgrade, extension-points]
components: []
related_tasks: []
origin: {kind: "peer", source: "proxmox-ring20-management", ref: "83c8790d"}
created: 2026-10-22T14:14:29Z
last_update: 2026-10-27T10:58:02Z
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
  - ts: '2026-10-22T14:15:17Z'
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
  - ts: '2026-10-22T14:15:31Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=112,acs=4)
    rubric_sha: e4a00f38e801
---

# T-4649: Supported extension points for project-local hook additions so consumers stop patching vendored files (ring20: 27 in-file patches)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

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

- **IW-1: Which of ring20's 9 "needs an extension point" patches warrant a supported framework extension point (blueprints, nav, CSRF-exempt declaration, post-approval hook, reviewer-brief addendum), and which should stay project-local?**
  confidence: 2
  disposition: answered
  rationale: per-point analysis in docs/reports/T-4649-ring20-patch-triage.md §AEF analysis. GO: blueprint registration + nav (1, 2), notification-only post-decision hook (4), and tightening-only project gate patterns (6, new, from 055's T-640 outage). CSRF (3) only as an operator-owned allowlist (see IW-2). NO-GO: reviewer-brief addendum (5), which conflicts with T-3580's fixed reviewer prompt. Category-5 items are separate fixes, not extension points

- **IW-2: Does a CSRF-exemption declaration (relaxing a gate) belong in an extension contract at all, or only behind an operator-signed allowlist?**
  confidence: 2
  disposition: answered
  rationale: not as a self-declared contract (a blueprint declaring itself exempt is project code weakening a gate). Only as a committed, operator-owned allowlist naming each endpoint, its auth mechanism and a task id, listed by fw audit, with list changes as an operator action. Proposed; the operator rules on it at decide time (ring20 patches #9, #10)

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

**Recommendation:** GO, scoped: build extension points 1+2 (blueprints + nav), 6 (tightening-only project gate patterns) and 4 (notification-only post-decision hook). Point 3 (CSRF) only as an operator-owned allowlist, and only if the operator agrees to that shape. NO-GO on 5 (reviewer-brief addendum).

**Rationale:** ring20 carries 27 in-file patches across 22 vendored files and had to roll back be.2 because upgrade would overwrite them (their G-187). Today's only supported extension points are BOUNDARY_EXTRA_READ_PATHS, .fwvendor-preserve.yaml (whole-file keep) and project hooks in .claude/settings.json (kept by upgrade, T-3833). None of them can add a page or add to a framework gate. On 2026-10-26, 055's local edit of a vendored gate killed every agent on one host for about 6 h. The point-by-point analysis splits what is safe to open from what is not:
- **Points 1, 2, 4 and 6** add routes or display, only observe a decision, or can only tighten a gate. So they are safe to open.
- **Point 3** relaxes a gate. It is acceptable only behind an allowlist the operator owns.
- **Point 5** puts producer-controlled text into the reviewer's prompt, undoing T-3580. So it is not built.

**Evidence:**
- docs/reports/T-4649-ring20-patch-triage.md §AEF analysis: per-point table with today's code (web/blueprints/__init__.py, web/shared.py:137 NAV_GROUPS, web/app.py:193 csrf_protect, web/blueprints/approvals.py:1160 decide_approval, T-3580 reviewer prompt)
- ring20 triage (msg 02db28da): 9 "needs an extension point" patches out of 37
- 055 T-640/T-641 and AEF T-4782: the vendored-gate edit that caused the 2026-10-26 outage

**Dialogue Log:**
- 2026-10-26: operator said "t4649, go" in chat. Not recorded: the questions were still open.
- 2026-10-27: operator: "4649 is not ready !!!", then "let's work on it". The agent found IW-1/IW-2 undisposed and the GO resting on the problem, not on an answer. It did the per-point analysis above and narrowed the recommendation.

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

### 2026-10-22T19:28:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
