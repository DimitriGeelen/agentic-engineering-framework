---
id: T-2143
name: "RCA — agent reflexively routes prose-tone judgment to Human AC even when audience
  disqualifies (4-round recursion in T-2139 thread)"
description: >
  Inception: RCA — agent reflexively routes prose-tone judgment to Human AC even when
  audience disqualifies (4-round recursion in T-2139 thread)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [arc-008, rca, routing, audience-mismatch, inception]
components: []
related_tasks: [T-2138, T-2139, T-2140, T-2141, T-2142, T-1878, T-1947, T-1811]
arc_id: inception-review-loop
created: 2026-05-31T15:41:46Z
last_update: '2026-05-31T15:45:02Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-31T15:42:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
      F1: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-31T15:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2143: RCA — agent reflexively routes prose-tone judgment to Human AC even when audience disqualifies (4-round recursion in T-2139 thread)

## Problem Statement

In a single conversation thread on T-2139 (the T-2138 V1 keystone — the task that itself ships the framework's enforcement gate against handoff homework), I authored, restructured, rewrote, and trimmed the same Human AC **four times**, walking into a progressively deeper version of the same routing trap each round. The structural gates that exist for this class (T-1878 default-bias, T-1947 prose-mismatch detector, T-2139's own at-handoff blocking gate) all fired correctly at structural surfaces — but none of them looked at **audience**.

The agent reflexively routes "subjective judgment" → `[REVIEW]` (Human AC) without first checking *who the AC's question is being asked about*. When the audience is itself another agent (e.g. "does the validator's stderr block read well for an agent who trips it"), asking the operator to evaluate is structurally wrong — yet `[REVIEW]` is exactly the prefix the agent reaches for.

**For whom:** the agent author of any task whose subject-matter concerns other agents. **Why now:** operator caught the recursion in real time and explicitly asked for an RCA on why this keeps happening within the larger T-2138 → T-2140 → T-2141 remediation arc.

**Full evidence + 5-Whys + candidates:** `docs/reports/T-2143-routing-recursion-rca.md`.

## Assumptions

1. The 4-round recursion is a single class of failure, not four independent failures. (Working hypothesis — same task, same AC, same agent, same routing heuristic; alternative is that each round was a different mistake that just happened to land on the same file.)
2. The `[RUBBER-STAMP]` / `[REVIEWER]` / `[REVIEW]` three-prefix table in CLAUDE.md is silent on audience. (Verifiable by reading CLAUDE.md §AC Classification Guidance — done in research artifact, confirmed silent on audience.)
3. T-1947's prose-mismatch detector reads predicate (does Expected demand human taste), not subject (is the AC question about agents). (Verifiable by reading the detector's signal vocabulary — confirmed in research artifact.)
4. Other tasks in the corpus exhibit the same audience-mismatch class. (Untested — would be a spike before shipping Candidate B.)

## Exploration Plan

1. **Walk-through of the 4 rounds** — DONE in research artifact. Each round captured with operator pushback quote, detection mechanism, and fix applied.
2. **5-Whys to root cause** — DONE in research artifact. Bottoms out at: routing heuristic is single-axis (property of the *check*), missing the *audience* axis.
3. **Bigger-picture mapping** — DONE in research artifact. T-2143 is the 5th class in the `inception-review-loop` arc (T-2030 → T-2050 → T-2138 → T-2140 → T-2141 → T-2143). Different layer than the URL-construction homework; same family.
4. **Candidate generation** — DONE in research artifact. A (delete the AC), B (static-scan rule), C (CLAUDE.md table extension), D (combo).
5. **Spike (deferred unless operator picks B or D)** — grep `.tasks/{active,completed}/T-*.md` for agent-audience phrasings (`agent who`, `agent reads`, `agent trips`, etc.) inside `[REVIEW]` ACs. Would size the corpus for the static-scan rule.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN scope:**
- Producing an RCA artifact (root cause + 5-Whys + bigger-picture context).
- Generating remediation candidates with effort/coverage analysis.
- Inception decision (GO / NO-GO / DEFER on which candidate(s) to ship).

**OUT of scope (for THIS inception — would be child tasks if GO):**
- Actually deleting T-2139's Human AC (Candidate A — if GO, child task).
- Actually shipping the static-scan rule (Candidate B — if GO, child task, possibly sibling of T-2140).
- Actually editing CLAUDE.md's three-prefix table (Candidate C — if GO, child task).
- Backfill across other tasks in the corpus that exhibit the same audience-mismatch (would follow Candidate B's spike).

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

**GO if:**
- Operator agrees the 4-round recursion is a class instance (not coincidence) AND picks at least Candidate A (delete the offending AC).
- Operator picks Candidate D (A+B+C combo) — full structural closure mirroring T-2138's GO pattern.
- Operator picks Candidate B and/or C alone — partial closure, with explicit acknowledgement that the immediate symptom (T-2139's AC) is left for the next session to address.

**NO-GO if:**
- Operator judges the class too rare to warrant another structural rail (T-2139 is a meta-task, may be unique in the corpus).
- Operator prefers to settle T-2139's AC by sovereignty (operator ticks or leaves regardless of audience analysis) — the routing question is then closed by precedent, not by enforcement.

**DEFER if:**
- Operator wants the spike (corpus walk for agent-audience phrasings in `[REVIEW]` ACs) before committing to B/C. Then revisit with corpus data.

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

**Recommendation:** DEFER — pending operator candidate pick.

**Rationale:**

Evidence-gathering round complete (research artifact `docs/reports/T-2143-routing-recursion-rca.md`). Root cause identified: the agent's AC-routing heuristic is **single-axis** (does the *check* demand subjective judgment? → Human). The axis it misses is **audience** (is the question being asked *about* the human's experience, or about another agent's?). The class is one layer deeper than T-1878 (default-bias) and T-1947 (prose-mismatch detector); both fire on the predicate (does Expected need human taste), neither reads the subject (whose experience is being judged). T-2143 surfaces a gap in Candidate E's scope from T-2138 — E targets URL-construction homework; it doesn't generalise to audience-mismatched ACs.

Four remediation candidates with effort/coverage trade-offs (full analysis in research artifact):

| | What | Effort | Coverage |
|---|---|---|---|
| **A** | Delete T-2139's Human AC; close on agent side | ~2 min | Local (this task only) |
| **B** | Static-scan rule for `[REVIEW]` ACs with agent-as-subject phrasing | 2-3h spike + ship | Future authoring across corpus |
| **C** | Extend CLAUDE.md three-prefix table with audience axis + worked examples | ~30 min | Awareness/governance layer |
| **D** | Combination A + B + C (mirrors T-2138's GO shape: E + B + Q3-both) | 3-4h total | Local fix + future prevention + governance |

The structural decision (how aggressively to gate this class) is an operator call, not an agent call. **D** is the analogue of T-2138's GO. **A** alone is defensible if the class is judged rare. NO-GO if operator wants to settle T-2139's AC by sovereignty (tick or leave regardless).

**Evidence:**

- Research artifact: `docs/reports/T-2143-routing-recursion-rca.md` (full 5-Whys, 4-round walk-through, candidates, dialogue log).
- T-2139 commit chain: `8880e0ab` (V1 keystone) → `10299add` (fence exemption) → `cd4d321a` (T-2142 decomp) → `069f64d4` (self-contained brief) → `37416f84` (trim + reviewer overrides). Each commit message captures one round of the recursion.
- Parent arc: `inception-review-loop` — see `.context/arcs/inception-review-loop.yaml` for the class catalogue (URL-construction homework slices T-2030/T-2050/T-2138/T-2140/T-2141; T-2143 adds the 5th class).
- Related routing-failure tasks: T-1878 (`docs/reports/T-1878-routing-default-bias.md`), T-1947 (reviewer prose-mismatch detector).
- Operator pushback quotes (dialogue log in research artifact): four verbatim rounds, each detecting a different dimension of the same routing class.

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

### 2026-05-31T15:42:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
