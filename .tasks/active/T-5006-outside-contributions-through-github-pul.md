---
id: T-5006
name: "Outside contributions through GitHub pull requests (Mehdi's proposal)"
description: >
  Inception: Outside contributions through GitHub pull requests (Mehdi's proposal)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
arc_id: github-contributions
components: []
related_tasks: []
created: 2026-11-02T07:55:22Z
last_update: 2026-11-11T22:11:06Z
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
  - ts: '2026-11-02T07:56:35Z'
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
  - ts: '2026-11-02T08:00:25Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=157,acs=4)
    rubric_sha: e4a00f38e801
---

# T-5006: Outside contributions through GitHub pull requests (Mehdi's proposal)

## Problem Statement

Mehdi (GitHub contributor, author of issues #98, #104, #106) wants to send pull requests and has proposed how (full text in `docs/reports/T-5006-github-contributions.md`). Today the framework cannot take outside code safely:

- `CONTRIBUTING.md:79,87` says branch from and PR against `main`; there is no `main`. Our own PRs (#76 to #84) target `bleeding-edge`.
- `.github/workflows/test.yml` runs only for `main` and `master`, so a PR to `bleeding-edge` runs no tests.
- There is no pull request template.
- The commit-msg hook needs a `T-XXX` that exists in `.tasks/`; an outside contributor has none.
- **The structural problem (ours, not in the proposal):** `origin` (OneDev) is the source and GitHub is a mirror fed from it. PRs #76, #77 and #79 were merged on GitHub and then erased by a history rewrite; PR #80 re-landed them. A contributor's merge on GitHub has no defined route back to the source repo.

**For whom:** outside contributors first, the operator second (stays the only merger), the release train third (master only fast-forwards at release).
**Why now:** the first outside contributor is ready, and every PR merged before the route exists risks being erased again.

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

- **IW-1: Where does a contributor's merged PR land, and how does it reach OneDev before the next mirror sync can erase it?**
  confidence: 0
  disposition: open
  rationale: PR #80 shows the failure; candidates (merge on GitHub then pull into OneDev, apply on OneDev and let the mirror close the PR, or make GitHub the source) to be compared in the report.
- **IW-2: How do outside commits satisfy the T-XXX commit-msg rule?**
  confidence: 1
  disposition: open
  rationale: Mehdi proposes the intake task id plus issue number ("T-4935 (#104): …"); intake already files a task per issue (#104 → T-4935). Alternatives in the report.
- **IW-3: What runs on a PR before the operator looks at it, and what may a fork PR's CI see?**
  confidence: 1
  disposition: open
  rationale: test.yml triggers on main/master only; fork PRs get no secrets by default.
- **IW-4: Which framework gates must a contributed change pass before it lands (review seats, criteria, Verification, human ticks)?**
  confidence: 0
  disposition: open
  rationale: Mehdi's "later" CI check of 28/10; our review loop today runs only on tasks we file.
- **IW-5: Can GitHub branch protection on bleeding-edge coexist with the mirror sync that pushes to it?**
  confidence: 0
  disposition: open
  rationale: The mirror push may need force for a rewrite; protection would refuse it.
- **IW-6: Inbound licence terms: Apache-2.0 section 5 alone, a DCO sign-off, or a CLA?**
  confidence: 1
  disposition: open
  rationale: Mehdi proposes section 5 only, no CLA; operator's call.

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

**Recommendation:** DEFER

**Rationale:**

2026-11-12: the operator said "5006 is not ready". The GO of 2026-11-11 below was premature; it is withdrawn. **What it waits for (operator, 2026-11-12): the role chain first** — steps 1 to 8 (T-5021 requirements sign-off, T-5022 threat model, T-5023 to T-5028) must be done before this go/no-go is presented again. Mehdi's answers on #114 feed step 1; they do not replace the chain.

(Withdrawn GO rationale, 2026-11-11, kept for the record:) The question that held this at DEFER is settled in the plan: GitHub becomes the source repository and the private server its mirror, so a merged pull request can no longer be erased by a mirror sync, as happened to #76, #77 and #79 (`docs/reports/T-5006-draft-plan-for-mehdi.md` lines 68-70). The pilot contributor has reviewed the plan and accepted its stricter points (DCO sign-off, review before merge, one risk level higher), and answered the four open questions; the operator accepted the answers the same day and called the contributor trusted. GO means: run the pilot as planned. Code pull requests still wait for the isolated test hosts (T-5009), and the role-chain steps (T-5021 onward) stay the delivery plan.

(Filed 2026-11-02 as DEFER: the four facts cited were verified, but where a contributor's merge lands, and how it gets back to the source repo, was open.)

**Evidence:**
- GitHub #114, comment 6807371666 (2026-11-11): Mehdi accepts the plan and answers the four questions; recorded in `docs/reports/T-5006-draft-plan-for-mehdi.md` (commit b6a2addcb).
- Reply posted on #114 (comment 6808319260) with the operator's acceptance.
- #106 accepted as T-5082 (operator approval AP-106-accept) for pilot PR 2.

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

### 2026-11-02T07:56:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
