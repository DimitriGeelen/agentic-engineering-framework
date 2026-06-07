# Global Free Driver — Worked Examples

Three worked global free-driver proposals, each captured at full fidelity (candidate scan → sharpening dialogue → final spec). Use these to calibrate what a complete session looks like.

These are illustrative examples drawn from plausible scenarios — not historical sessions. The shape and discipline are what matter; the specific drivers proposed below may or may not ever ship as real free drivers in this project.

---

## Example 1 — `F-RECALL` (a real driver, derived from canonical history)

This one is real. `F-RECALL` is an active free driver in `policy/value-drivers.yaml` v3. The session below is a reconstruction of what its proposal would have looked like under this bundle.

### §1 Context

Operator invoked `fw bvp driver create "recall-quality"` after a sequence of tasks (T-2173, T-2174 RCA) surfaced that the agent was retrieving stale memory entries and acting on them without verification. Pattern: memory was authored once and never re-checked against current code. Driver question: should the framework track "recall quality" as a first-class scoring dimension?

### §2 Candidates Considered

Workflow C — operator named "recall-quality" directly. No candidate scan run.

### §3 Picked Candidate

`recall-quality` — captures how well the agent's memory-recall workflow surfaces and verifies relevant past context vs. acting on stale or hallucinated material.

### §4 Sharpening Dialogue

#### R1 — Differentiation

**Agent:** "What does recall-quality distinguish that D1 Antifragility doesn't already cover?"

**Operator:** "D1 is about systems strengthening under stress. Recall is about retrieving the right past context — that's upstream of stress response. If I recall the wrong precedent I make the wrong call regardless of how antifragile the system is."

**Agent:** "Test: a task that scores high on recall-quality but low on D1?"

**Operator:** "Work that improves the memory index / dedup / freshness detection. That work is recall-improvement; it doesn't directly improve stress response — it improves the input to stress response."

[CONVERGED]: recall-quality distinguishes memory-retrieval-fidelity from system-resilience. D1 measures what happens when stressed; F-RECALL measures whether the agent has the right context before being stressed.

#### R2 — Weight Calibration

**Agent:** "Where on 1-9? Anchor."

**Operator:** "Heavier than D3 Usability (5) and D4 Portability (3) — bad recall blocks every other driver from acting correctly. Lighter than D1 (9) because recall failure is usually recoverable; antifragility failure compounds. Maybe 6?"

**Agent:** "6 puts it between D2 Reliability (7) and D3 Usability (5). Test: a task that improves F-RECALL by 1 vs. a task that improves D2 by 1 — which ranks higher?"

**Operator:** "D2. Because D2 covers the broader 'no silent failures' surface. F-RECALL is a slice of that. So F-RECALL should be < D2. 6 is right."

[CONVERGED]: weight 6, anchored < D2 Reliability (7) and > D3 Usability (5).

#### O1 — Edge Cases (drilled)

**Agent:** "Score 0 example?"

**Operator:** "A task that adds memory entries the agent never retrieves. Recall didn't happen; doesn't matter how good the entry is."

**Agent:** "Score 5?"

**Operator:** "A task that fixes a recurring class of recall-staleness — where the agent was acting on outdated memory and now has structural detection."

**Agent:** "Score 2 that could be argued as 3?"

**Operator:** "A task that adds a single new memory entry with verification discipline. 2 because one entry; 3 because the verification discipline could be a new pattern. Boundary: does the discipline apply only to that entry, or generalises?"

[CONVERGED]: 0=memory adds with no retrieval; 5=structural fix to recurring recall failure; 2↔3 boundary on whether the verification pattern generalises beyond the one entry.

#### O2 — Scope Test (drilled)

**Agent:** "Walk through 3 recent tasks. Which would F-RECALL dominate?"

**Operator:** "T-2173 yes — direct recall-failure RCA. T-2174 partial — the pivot was triggered by stale verdict text. T-2244 no — pure code change."

[CONVERGED]: 1.5 of 3 dominated. Scope is well-shaped (not too broad, not too narrow).

#### O3 — Overlap Test (skipped — R1 was strong)

[SKIPPED]: R1 converged firmly on the distinction from D1+D2. O3 would be redundant.

#### O4 — Scoring Rubric (drilled)

```yaml
"0": no recall involvement (e.g. greenfield code, no memory dependency)
"1": ad-hoc recall, no structural improvement
"2": one new memory entry added with verification discipline
"3": new verification pattern that applies to multiple entries
"4": detection mechanism for a recall-staleness class
"5": structural fix that prevents the recurring recall failure entirely
```

### §5 Decisions Ledger

| ID | Decision | Decided-by | Reversibility |
|----|----------|------------|---------------|
| D1 | F-RECALL is a real driver (R1 converged with strong distinction from D1+D2) | jointly | load-bearing |
| D2 | Weight 6, anchored between D2 (7) and D3 (5) | jointly | load-bearing |
| D3 | Rubric covers 0–5 (drilled) | agent | load-bearing |

### §6 Rejected Paths

- Weight 7 — rejected because that would tie with D2 Reliability, and recall is a slice of the broader reliability surface, not a peer.
- Calling it "memory-quality" — rejected because "memory" overloads with auto-memory storage discipline, which is a different concern.

### §7 Open Questions

All dimensions converged; no open questions.

### §8 Final Spec

```yaml
- id: F-RECALL
  name: Recall Quality
  weight: 6
  status: active
  added: 2026-06-01
  added_by: dimitri
  source_task: T-2168
  rationale: |
    R1: Distinguishes memory-retrieval-fidelity from system-resilience.
    D1 Antifragility measures stress response; F-RECALL measures whether
    the agent has the right context before being stressed.
    R2: Weight 6, anchored < D2 Reliability (7) because recall is a slice
    of broader reliability, > D3 Usability (5) because bad recall blocks
    other drivers from acting correctly.
  scoring_rubric:
    "0": no recall involvement
    "1": ad-hoc recall, no structural improvement
    "2": one new memory entry added with verification discipline
    "3": new verification pattern that applies to multiple entries
    "4": detection mechanism for a recall-staleness class
    "5": structural fix that prevents the recurring recall failure entirely
  retire_when: when memory recall is verified at retrieval-time by the
    framework itself, not by per-task discipline
```

### §9 Operational Consequences

After global recompute: top-5 ranking shifted to surface T-2168 (which F-RECALL scores 4) above several D1-dominant tasks. Operator noted "this matches my gut — the recall work matters more than the audit polish".

---

## Example 2 — Driver killed mid-session (illustrative)

### §1 Context

Operator invoked `fw bvp driver create "test-discipline"` after a code-review pass flagged thin test coverage on recent commits.

### §3 Picked Candidate

`test-discipline` — captures how well a task's test coverage reflects the code it touches.

### §4 Sharpening Dialogue

#### R1 — Differentiation

**Agent:** "What does test-discipline distinguish that D2 Reliability doesn't?"

**Operator:** "Tests are about catching regressions. D2 is about no silent failures."

**Agent:** "Test: a task that scores high on test-discipline AND low on D2?"

**Operator:** "Hmm... if I add tests for code that wasn't going to fail anyway, that's high on tests but not really on D2... but is that valuable?"

**Agent:** "Suspicion: 'tests for safe code' is low-value work. If tests only matter where regression risk exists, then test-discipline is reliability discipline, which is D2."

**Operator:** "Yeah you're right. Kill it. D2's rubric should encourage test coverage on risky code."

[REJECTED]: test-discipline as a separate driver.

### §5 Decisions Ledger

| ID | Decision | Decided-by | Reversibility |
|----|----------|------------|---------------|
| D1 | Kill the candidate. Test discipline is part of D2 Reliability. | jointly | load-bearing |
| D2 | Recommend operator edit D2's scoring rubric to surface test coverage as a sub-criterion. | agent | reversible |

### §6 Rejected Paths

- `test-discipline` as a free driver — rejected because R1 collapsed to D2.

### §8 Final Spec

No spec written. Recommendation handed to operator: review D2 Reliability rubric.

### §9 Operational Consequences

Operator filed `fw bvp driver edit D2 --rubric-tweak` follow-up. No new driver landed; no recompute triggered.

---

## Example 3 — Recommend --none (illustrative)

### §1 Context

Operator invoked `fw bvp driver suggest` on a quiet week — no obvious project signal driving a new driver.

### §2 Candidates Considered

```
1. team-velocity — distinguishes work that improves time-to-ship from work that doesn't
2. operational-overhead — distinguishes work that reduces ongoing cron/audit load
3. agent-trust — distinguishes work that improves operator confidence in agent outputs
none — none of these
```

### §3 Picked Candidate

Operator picked `none — none of these`.

### §4 Sharpening Dialogue

No sharpening run; operator's pick was `--none`.

### §5 Decisions Ledger

| ID | Decision | Decided-by | Reversibility |
|----|----------|------------|---------------|
| D1 | No new driver this round. | operator | reversible |

### §6 Rejected Paths

- `team-velocity` — operator: "we don't ship to a calendar, this would just incentivise small slices over real work."
- `operational-overhead` — operator: "that's covered by D2 Reliability sub-criterion 'no silent failures'."
- `agent-trust` — operator: "I trust outputs based on dialogue + reviewer + my own read. Encoding this as a driver feels like trying to measure something I should be doing by judgment."

### §8 Final Spec

No spec written. Zero approved drivers is a valid outcome.

### §9 Operational Consequences

No recompute. Artefact lives at `docs/reports/T-XXXX-bvp-driver-suggest-none.md` for future reference — the rejection rationales are useful context for the next driver session.

---

## What these examples teach

- **R1 is the gate.** When R1 collapses (Example 2), the candidate dies. When R1 converges firmly (Example 1), the rest of the dimensions can drill freely.
- **Weight anchoring works.** Example 1's "between D2 and D3" is more useful than "weight 6" in isolation.
- **Skip-when-stuck is normal.** Example 1 skipped O3; Example 2 didn't drill any optionals because R1 already settled it.
- **`--none` is real.** Example 3 produces an artefact even though no driver landed. The rejection rationales prevent the same candidates being re-proposed next session.
- **Dialogue capture matters.** Read §4 in each example. The dialogue is where the *why* lives. The final spec captures the *what*.
