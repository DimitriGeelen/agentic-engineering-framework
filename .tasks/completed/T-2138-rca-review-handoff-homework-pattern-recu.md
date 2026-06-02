---
id: T-2138
name: "RCA: review-handoff homework pattern recurs despite T-2030 GO — author-time
  gap"
description: >
  Inception: RCA: review-handoff homework pattern recurs despite T-2030 GO — author-time
  gap

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [arc-008, review-handoff, author-time-gate, rca, watchtower, ctl-027]
components: [lib/review_link_validator.py, lib/review.sh, agents/audit/reviewer/static_scan.py, .tasks/templates/zzz-default.md]
related_tasks: [T-2030, T-2050, T-2109, T-2113, T-2137, T-2101, T-2055]
arc_id: inception-review-loop
created: 2026-05-31T11:13:58Z
last_update: 2026-05-31T13:09:18Z
date_finished: 2026-05-31T13:09:18Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-31T11:14:24Z'
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
  - ts: '2026-05-31T11:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2138: RCA: review-handoff homework pattern recurs despite T-2030 GO — author-time gap

## Problem Statement

The review-handoff homework pattern — Steps that say *"Open each of these (Watchtower URL from `bin/fw watchtower url`): - `/path1` - `/path2`"* instead of full clickable URLs — keeps recurring despite T-2030 GO'd on 2026-05-25 (Candidate C, `app.url_map` validation). T-2050 shipped the validator code but as **advisory WARN at `fw task review` time**, and the validator's regex extracts URLs that are **present** — it cannot flag absence-of-URL homework. **7 active+completed sites** still carry the anti-pattern; T-2109 surfaced it again on 2026-05-31 + the `/inbox` chat slip same session.

**Full research artifact:** `docs/reports/T-2138-review-handoff-author-time-gap.md` (created BEFORE this body per Inception Discipline C-001; contains 5-Whys, evidence grep, 4 candidate shapes, and the Dialogue Log).

**Trigger:** operator verbatim — *"2109, why am i not getting full links??"* + *"please incpet rca why this keeps happening and what strcutural remdiation is furtehr needed"*.

## Assumptions

- **A1:** The homework pattern is systemic, not an isolated slip. (Tested: grep finds 7 sites across active+completed.) PASS.
- **A2:** Discipline-only enforcement (memories, CLAUDE.md rules) is insufficient. (Tested in-session: violated twice within 60 minutes with the memory freshly updated each time.) PASS.
- **A3:** T-2050's advisory WARN at `fw task review` is structurally unable to catch the dominant failure mode (absence-of-URL). (Tested: validator regex `https?://...` finds zero URLs in homework text → silent pass.) PASS.
- **A4:** Author-time gating is the strongest remediation but carries migration cost (7 legacy sites). Operator must decide whether to retro-fit, bypass-flag, or grandfather.

## Exploration Plan

This task is operator-dialogue-bound, not spike-bound. Per Inception Discipline rule 3 (no build artifacts before GO):

1. **Operator dialogue** (open) — operator picks A/B/C/D (or hybrid) from `docs/reports/T-2138-*.md` §Scope question. Three open scope questions documented there.
2. **Recommendation hardening** — once direction is picked, this body's Recommendation moves from DEFER to GO|NO-GO|DEFER on the picked candidate.
3. **Spawn first build slice** — operator approves spawn, agent files **one** build task. V-slices NOT pre-filed (T-2101's stalled V1..V5 is the cautionary tale).
4. **T-2050 cleanup** — orthogonal: T-2050 sits `started-work` since 2026-05-25 (CTL-027). Either close as superseded by T-2138's slice or close-on-evidence (the validator IS shipped and wired); operator decides which framing.

## Technical Constraints

- **Author-time hook scope** (Candidate A) — must fire on Write|Edit to `.tasks/{active,completed}/T-*.md` only; must scope pattern detection to Steps blocks under `### Human` to avoid false-positives on `## Verification` shell commands containing `/path`.
- **Bypass mechanism required** — 7 legacy sites need a documented Tier-2 logged bypass (`FW_ALLOW_REVIEW_LINK_HOMEWORK=1`) OR a mandatory pre-enabling sweep.
- **Render-time substitution** (Candidate D) — must NOT mutate source files; symmetry between Watchtower render and CLI `fw task review` output required if chosen.
- **Reviewer static-scan** (Candidate B) — pattern catalogue addition to `agents/audit/reviewer/static_scan.py`; advisory by default, escalatable via `[REVIEWER]` AC conversion.

## Scope Fence

**IN scope (this inception):**
- Decide which structural remediation(s) should layer on top of T-2050 to close the author-time gap
- Pick one of Candidates A/B/C/D (or hybrid) from the research artifact
- Answer the three open scope questions (direction, T-2050 disposition, legacy-site migration policy)
- Identify cross-surface coverage (task files, chat messages, handovers, handoff URLs in reports)

**OUT of scope (handle elsewhere):**
- The wrong-URL class (T-2050 already covers it via `app.url_map`)
- T-2137 (multi-option AC → spawn) — sibling, different mechanism
- T-2101 V1..V5 build slices — different mechanism, already GO'd
- Retro-fitting any of the 7 legacy sites until operator picks Candidate + migration policy
- Building any of the candidates before operator picks direction (Inception Discipline rule 3)

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

**Recommendation:** GO — Candidate **E + B**, with Q3 answer **both** (block-message teaching + separate doc cleanup). Selected by operator 2026-05-31.

**Rationale:**

The recurring pattern has crossed the systemic threshold (≥3 captures: T-2027 / T-2013 / T-1991 / T-2012 / T-2118 / T-1853 / T-2030 / T-2109 + the `/inbox` chat slip + 2× discipline failure in one session). T-2030's earlier GO decision identified the right *direction* (structural validation at handoff) but T-2050's shipping shape (advisory WARN, review-time, presence-only) cannot catch the dominant failure mode (absence-of-URL). Operator dialogue 2026-05-31 (see Dialogue Log in research artifact) selected:

- **Candidate E** — transition-time blocking gate. Fires at three handoff moments: `bin/fw task review T-XXX`, `update-task.sh --status work-completed` on a partial-complete build, `update-task.sh --status work-completed` on an inception. NOT every Write|Edit — WIP drafting stays unblocked. Reuses T-2050's `lib/review_link_validator.py` integration point (`lib/review.sh:emit_review`) — upgrade from `|| true` advisory to blocking exit, plus extended detection for absence-of-URL homework patterns. Class-aware URL resolution: inception → `/inception/<id>`, partial-complete build → `/review/<id>`. 7 legacy sites stay valid until their next handoff (natural retro-fit; no upfront sweep).
- **Candidate B** — reviewer static-scan companion. Add `review-link-homework` pattern to `agents/audit/reviewer/static_scan.py` catalogue. Emits CONCERN during normal completion review (before handoff) so the agent self-corrects before E fires. Cost: one regex entry; benefit: no agent-frustration round-trips when E eventually blocks.
- **Q3 = both** — the gate's block message names the review-vs-inception class explicitly ("this task is an inception, handoffs go to /inception/T-XXX") AND a separate sibling task sweeps surface text (CLAUDE.md §Presenting Work for Human Review, agents/task-create/AGENT.md, hook block messages, prompt preambles) to teach the distinction proactively.

Skip Candidate C (template + CLAUDE.md prose discipline) — proven insufficient by 2× same-session failure with the memory freshly updated. Skip Candidate D (render-time substitution) — rewriting source-of-truth text creates downstream trust issues and only papers over the symptom.

V-slices **NOT pre-filed** — T-2101's stalled V1..V5 is the cautionary tale. After operator records the structural GO via Watchtower, agent files ONE build slice (the E gate keystone) and parks B + Q3-cleanup as siblings to follow.

**Evidence:**
- T-2030 (parent inception, GO 2026-05-25): `docs/reports/T-2030-review-link-generation.md`
- T-2050 (build slice, `started-work` since 2026-05-25 — CTL-027): validator at `lib/review_link_validator.py`, wired at `lib/review.sh:165-169` with `|| true` advisory-only
- Validator regex extracts URLs that are **present**; structurally cannot flag absence-of-URL homework
- T-2109 recurrence (this session): commit `fa4e49d3` fixed inline after operator caught
- T-2113 (this session, commit `cb815bae`): same class, different route (`/cockpit` 404)
- `/inbox` chat slip (this session, no commit): same class, chat surface
- `[[feedback_review_concrete_links]]` updated *during* this session, violated 60 min later on T-2109 → discipline-only path proven insufficient
- 7 active+completed sites: `grep -rlE "URL from .bin/fw watchtower url" .tasks/`
- Full RCA + 5 candidate shapes + Dialogue Log (with operator's E+B+Q3-both decision): `docs/reports/T-2138-review-handoff-author-time-gap.md`

**Proposed build slices (file AFTER operator records the structural GO):**
- **V1 (keystone):** Candidate E — `lib/review_link_validator.py` extension + `lib/review.sh:emit_review` upgrade from `|| true` to blocking exit + class-aware block message + bats coverage. Also integrate at `agents/task-create/update-task.sh` `--status work-completed` for the build-partial-complete + inception-body-finalisation legs.
- **V2 (companion):** Candidate B — `agents/audit/reviewer/static_scan.py` catalogue entry `review-link-homework` with pattern matchers + unit tests.
- **V3 (Q3 cleanup):** sweep CLAUDE.md / AGENT.md / hook block messages / prompt preambles to teach review-vs-inception distinction proactively. Bounded — name the surfaces, rewrite three or four sentences each.

Ship V1 first (structural keystone). V2 + V3 can ship in parallel once V1 lands. None of the three is pre-filed yet — agent files them only after `fw inception decide T-2138 go` is recorded.

**Operator action requested:** record the structural GO via Watchtower at http://192.168.10.107:3000/inception/T-2138.

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

**Rationale**: The recurring pattern has crossed the systemic threshold (≥3 captures: T-2027 / T-2013 / T-1991 / T-2012 / T-2118 / T-1853 / T-2030 / T-2109 + the `/inbox` chat slip + 2× discipline failure in one session). T-2030's earlier GO decision identified the right *direction* (structural validation at handoff) but T-2050's shipping shape (advisory WARN, review-time, presence-only) cannot catch the dominant failure mode (absence-of-URL). Operator dialogue 2026-05-31 (see Dialogue Log in research artifact) selected:

**Date**: 2026-05-31T13:09:18Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-31T11:14:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-31T13:09:18Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The recurring pattern has crossed the systemic threshold (≥3 captures: T-2027 / T-2013 / T-1991 / T-2012 / T-2118 / T-1853 / T-2030 / T-2109 + the `/inbox` chat slip + 2× discipline failure in one session). T-2030's earlier GO decision identified the right *direction* (structural validation at handoff) but T-2050's shipping shape (advisory WARN, review-time, presence-only) cannot catch the dominant failure mode (absence-of-URL). Operator dialogue 2026-05-31 (see Dialogue Log in research artifact) selected:

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fba9d7b9
- **Timestamp:** 2026-06-02T15:01:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-31T13:09:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
