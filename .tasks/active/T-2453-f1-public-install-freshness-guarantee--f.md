---
id: T-2453
name: "F1: public install freshness guarantee — fresh github clone ships stale framework (v1.6.25 vs HEAD v1.6.66)"
description: >
  Inception: F1: public install freshness guarantee — fresh github clone ships stale framework (v1.6.25 vs HEAD v1.6.66)

status: captured
workflow_type: inception
owner: human
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-06-21T13:22:44Z
last_update: 2026-06-21T13:23:46Z
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

# T-2453: F1: public install freshness guarantee — fresh github clone ships stale framework (v1.6.25 vs HEAD v1.6.66)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

**For:** a fresh onboarder who installs AEF from the public GitHub front door (`install.sh` off
`master`). **Problem:** that path has no freshness guarantee — the T-2441 dogfood measured it delivering
**fw v1.6.25** while origin (onedev) HEAD was **v1.6.66** (~40 patch versions / months behind). `fw doctor`
already surfaces the underlying *mirror divergence* ("1 ref(s) differ between origin and github"), and
`fw mirror sync` (T-1594) runs every 15 min — yet the public clone was still stale, so the first spike is
**why the mirror-sync safety net did not keep `master` on github fresh.** **Why now:** the staleness is
also the root cause of the F8 routing failure (bare `fw` → a global shim that lacks recent fixes), so the
whole F1/F2/F8 cluster traces back here.

**Candidate solution space (from `docs/reports/T-2441-aef-onboarding-dogfooding.md` §F1 — to be chosen by
the inception):**
1. **Gate the github mirror push on release** — only fast-forward `master` on a tagged release, so the
   public front door never ships an arbitrary mid-flight commit.
2. **`install.sh` staleness WARN** — at clone/install time, compare the cloned `VERSION` against the latest
   upstream tag and warn (or refuse) when N behind. Most portable; no release-process change.
3. **Tagged releases + `install.sh --tag`** — publish releases as tags and let consumers pin a known-good
   version instead of tracking a moving `master`.

**Entanglement:** F2 (legacy shim message) and F8 (bare-`fw` routing) both surface *because* the install
was stale — they are tracked in [[project_t2441_onboarding_dogfooding]] / T-2448. This inception owns the
release-freshness question; T-2448 owns the shim-routing mechanics.

**Recommendation (filed GO — see `## Recommendation`):** the gap is real and confirmed; worth a focused
inception to pick among the three candidates. Not yet explored, so the candidate choice is open — but the
problem reality is established, hence GO rather than DEFER (the candidates are the inception's job, not an
evidence gap about whether to act). Parked `horizon: next` for a dedicated session.

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

**Rationale:**

Confirmed reliability gap from T-2441 dogfood: public GitHub install.sh ships fw v1.6.25 while origin HEAD is v1.6.66 (~40 patch versions behind); a real onboarder gets a months-old framework. fw doctor already surfaces the mirror divergence but the public front door has no freshness guarantee. Worth a focused inception to choose among 3 candidates (gate github mirror push on release / install.sh staleness WARN vs latest tag / tagged releases + install.sh --tag pin); first spike = why fw mirror sync (T-1594, 15-min cron) did not keep github fresh.

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

### 2026-06-21T13:23:46Z — status-update [task-update-agent]
- **Change:** horizon: now → next
