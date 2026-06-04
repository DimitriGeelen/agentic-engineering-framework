---
id: T-2204
name: "Recommendation-completeness gate has bypass paths — fw task create, fw work-on,
  direct YAML, and review-batch emission all bypass T-1716"
description: >
  Inception: Recommendation-completeness gate has bypass paths — fw task create, fw
  work-on, direct YAML, and review-batch emission all bypass T-1716

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-06-04T09:00:06Z
last_update: 2026-06-04T09:02:11Z
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
  - ts: '2026-06-04T09:02:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2204: Recommendation-completeness gate has bypass paths — fw task create, fw work-on, direct YAML, and review-batch emission all bypass T-1716

## Problem Statement

T-1715/T-1716 shipped a filing-time `--recommendation`+`--rationale` gate on `fw inception start` under `$CLAUDECODE=1`. The gate works on that one path. **It does not fire on any other path that creates a task with `workflow_type: inception`** — `fw task create --type inception`, `fw work-on --type inception`, direct YAML write, or post-hoc `fw task update T-XXX` that flips `workflow_type`. **The downstream handoff verbs `fw task review` / `fw task review-batch` also have no Recommendation-completeness pre-check** — they emit class-correct `/inception/<id>` URLs regardless of whether the body is filled.

This-session repro (third recurrence of the T-679 rule):
- T-2201 (pre-flight Claude CLI config inception) — filed via task-create, `## Recommendation` block = template comment only.
- T-2203 (structural-observation harvester inception) — same.
- Agent ran `fw task review-batch T-2201 T-2203`, posted `/inception/T-2201` and `/inception/T-2203` to operator chat as "awaiting decision" handoffs. Operator opened both, saw blank Recommendation blocks, pushed back.

**For whom:** every agent under `$CLAUDECODE=1` filing inceptions on any path other than `fw inception start`, and every operator who opens a `/inception/<id>` link the agent handed off.

**Why now:** two same-session repro cases; user explicitly named the pattern as "getting lost"; full L-399 (producer/consumer parity for hook bypass contracts) discipline already established but not applied here. Research artifact: `docs/reports/T-2204-recommendation-completeness-bypass-paths.md`.

## Assumptions

- **A1:** T-1716's check shape (require `--recommendation`+`--rationale` under `$CLAUDECODE=1`) is the right shape for the other producer paths. Test: read `lib/inception.sh:107-120`, confirm the check is portable.
- **A2:** A PreToolUse Write/Edit hook on `.tasks/active/T-*.md` can parse YAML frontmatter + grep the `## Recommendation` body in <100ms without measurably slowing edit cadence. Test: time the existing `check-inception-decisions` hook (same path shape) on a real session.
- **A3:** `fw inception retrofit-recommendations --apply` (T-1716 Stream C) is safe to fire on a cron schedule — it injects DEFER stubs only when block is template-only AND no `Recommendation:` line exists. Test: read `lib/inception.sh:902-980`; dry-run `fw inception retrofit-recommendations` against current active/ set.
- **A4:** Operator preference is "refuse emission" over "annotate emission" when `fw task review-batch` hits an empty Recommendation. Evidence: 2026-06-04 pushback ("again surface without recommendation") was unambiguously about refusing the handoff, not just labelling it.

## Open Questions

- **IW-1: Single producer fix (B), single consumer fix (C), pair (B+C), or full hybrid (E = B+C+D cron)?**
  confidence: 2
  disposition: <decide-time>
  rationale: Leaning E by L-399 producer/consumer parity discipline; but B+C alone may suffice if retrofit cron adds shipping cost without proportional defence (active inceptions get reviewed within hours, not days).

- **IW-2: For Candidate B (Write/Edit hook), what's the bypass mechanism per T-1890 parity rule — env var only, flag only, or both?**
  confidence: 2
  disposition: <decide-time>
  rationale: Env var `FW_ALLOW_EMPTY_RECOMMENDATION=1` is needed because the Write tool has no flag surface; `--allow-empty-recommendation` flag is needed because `fw task create` and `fw work-on` do have one. T-1890 says ship both when hook gates internal + external producer patterns.

- **IW-3: Does `fw task update T-XXX` that flips `workflow_type` to `inception` post-hoc count as a filing event — should it trigger the same Recommendation-completeness check at the moment of the flip?**
  confidence: 1
  disposition: <decide-time>
  rationale: Probably yes (mid-build pivot to inception means the Recommendation contract now applies), but UX cost is real — the flip happens during exploration when no Recommendation can yet be sound. Maybe defer-stub injection on flip is the right shape.

- **IW-4: Should `fw task review-batch` refuse emission entirely, or emit with a `[NO-REC]` annotation (T-1576 already wires this verb in handover output)?**
  confidence: 1
  disposition: <decide-time>
  rationale: Operator preference (A4) is refuse. T-1576's `[NO-REC]` annotation belongs in *survey output* (handover, queue listings) where the agent surveys what exists; the handoff verb is where the agent *commits* to advisory — different semantics. Lean refuse.

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

T-1715/T-1716 closed fw-inception-start filing path under $CLAUDECODE=1. T-2201 + T-2203 are this-session repro: both filed via fw task create + fw work-on (workflow_type: inception set directly), bypassed T-1716, sat with template Recommendation blocks, agent emitted /inception/<id> handoff URLs anyway. Three filing-path bypasses (task create, work-on, direct YAML) plus one consumer-side gap (fw task review/review-batch emission lacks Recommendation-completeness pre-check) remain after T-1716. Retrofit-recommendations exists but is manual-only (no cron, no hook). Bounded fix shape known (extend T-1716 contract to all producers + add review-batch emission gate). Evidence concrete, risk low — GO.

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

### 2026-06-04T09:02:11Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
