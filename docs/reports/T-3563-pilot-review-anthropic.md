# T-3563 pilot fit review — anthropic

Reviewer: Anthropic Claude Sonnet 5 (claude -p, Read/Grep/Glob only). 2026-09-29. Input: T-3563-pilot-review-brief.md; read-only access to the repository. Verbatim.

---

I've spot-checked well beyond the required four citations per arc — reading every primary source, cross-referencing task files, decisions.yaml, and concerns.yaml entries, and independently recounting one numeric claim. Here is the review.

```
ARC: continuous-run
VERDICT: amber
FIDELITY: Checked purpose/objective against the arc YAML and T-2158 inception report; checked all 6 context points against T-2158, T-3239-continuous-loop-demo/REPORT.md, learnings.yaml#L-652, and T-3200; checked all 9 decisions against the same report's Spike Findings/Bottom-line sections and against T-3254/T-3277/D-546; checked all 5 success criteria against REPORT.md's E1/E8 evidence blocks; checked all 5 open questions against T-3240, T-3276, T-3283, T-3200, and REPORT.md's "What is NOT proven" section. Every citation resolves to real, matching text — nothing invented or misattributed. One success criterion overstates current state relative to what its own cited sources (and the draft's own decisions list, one field above it) actually show.
CORRECTIONS:
  - field: success_criteria[2] (SC-3)
    replace_with: |
      - id: SC-3
        criterion: "A session that stops early without tripping the budget gauge can be carried forward without an operator, via an externally-driven turn rather than the in-session loop."
        evidence: "T-3254 (work-completed) ships the cron-injects-a-turn path; T-3257 live-fire proves it drives a real agent to completion (9/9, twice). Not yet armed in production: `continuous-driver-10m` is deliberately left PAUSED (D-546), and re-arming it is T-3283 (status: captured, horizon: later, blocked on G-097/G-098)."
    why: As drafted, SC-3 claims "is still carried forward" as a present-tense operating fact and cites T-3283 as supporting evidence — but T-3283 is the *unstarted* re-arm task (status: captured, horizon: later), and the draft's own decisions list two entries above states the cron was deliberately left paused (D-546, T-3257). The capability is real and proven in isolation, but not live today; the criterion and its evidence should say that, not imply an armed production behaviour.
OVERALL: Sound and well-sourced draft with one internally-inconsistent success criterion (SC-3 contradicts the draft's own decisions section); fix that line and it is fit to go live as-is otherwise.

ARC: readme-first-run
VERDICT: amber
FIDELITY: Checked purpose/objective/non_goals against T-2715 and T-2719 keystone; checked all 6 context points against T-2715 (§1, §4, F-5, F-7) and T-2719 (§Context, Persona A/B); checked all 7 decisions against T-2719 and T-2883 (including the "superseded" status on the OBS-170 closure-blocker decision, verified against T-2883's Evolution section, which explicitly documents that the original bug report was stale); checked all 5 success criteria against T-2719's evidence table (bats delta 532−528=4, mutation test, T-2816/T-2817/T-2815/OBS-170/OBS-171); checked history against T-2719 and T-2883 timestamps. Every citation resolves accurately — this is the strongest of the three drafts on fidelity, including correctly flagging its own closure item (demo_evidence still null) as an open question. One quality issue: the objective is narrower than the arc's actual mechanic.
CORRECTIONS:
  - field: objective
    replace_with: "A person with no agent reaches a working first task via the README's five-minute walkthrough without hitting an uncleared block, and each persona's regressions are caught by its own scenario, not masked by the other's."
    why: The drafted objective covers only the testing-methodology half of the arc (persona-scenario separation) and omits the primary outcome clause from the arc's own `headline_mechanic` — a person actually reaching a working first task. Since T-2719's own Recommendation and SC-5 (demo_evidence still null) make clear that the *unfinished* half of this arc is precisely that primary outcome, an objective that only names the testing property would let closure/scoring miss the thing still outstanding.
OVERALL: Excellent fidelity to sources throughout; broaden the objective to include the primary outcome clause and this is fit to go live.

ARC: orchestrator-rethink
VERDICT: amber
FIDELITY: Checked purpose/objective against T-1641's reconsideration report and the arc YAML; checked all 6 context points against docs/reports/T-1641-orchestrator-arc-reconsideration.md's Findings section and orchestrator-rethink-demo/README.md's Closure status; checked all 5 decisions against T-1641's Recommendation, decisions.yaml#D-058, and T-1671; checked all 4 success criteria against the demo README's Step 1-4 evidence and concerns.yaml#G-061 (closure_criteria/partial_mitigation) and #G-064 (status: closed, closed_date 2026-06-10, closure_notes — matches the draft's "481 dispatches / 290 cron firings... since 2026-05-14" almost verbatim); checked T-1642's Recommendation table for the "13-parameter table" claim (confirmed, all 13 rows present). One open question contains a numeric claim I independently recounted and found inaccurate.
CORRECTIONS:
  - field: open_questions[2]
    replace_with: |
      - question: "constituent_tasks lists 31 tasks while 123 task files carry arc_id: orchestrator-rethink (or arc-003) — which set does closure count?"
        source: ".context/arcs/orchestrator-rethink.yaml"
    why: Recounted directly (`grep -c '^arc_id: (orchestrator-rethink|arc-003)'` across `.tasks/`) and got 123 matching files, not 127. constituent_tasks itself does list exactly 31, so only the second number needs correcting.
OVERALL: Well-sourced and precise draft — the one factual slip is a small miscount in an open question, not a fidelity or fabrication problem; correct the number and it is fit to go live.
```
