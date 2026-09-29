# T-3563 pilot fit review — zai

Reviewer: Z.ai GLM-5.3 (opencode plan agent, read-only, in repo). 2026-09-29. Input: T-3563-pilot-review-brief.md; read-only access to the repository. Verbatim.

---

The arc files already contain the story blocks (with `story_source`/`story_review` lines), and the drafts match them verbatim. Now I'll verify the drafts against their cited sources, starting with continuous-run's.
The two main continuous-run sources check out. Now the supporting entries: L-652 in learnings, D-546 in decisions, and the task files.
L-652 and D-546 both support their citations. Now the continuous-run task files — I'll read the anchor task and spot-check the others.
T-3200 supports its citation. Let me check the T-2158 task body for the GO/DEFER history claims, and T-3200's tail for the "awaiting human review" state.
T-3200 is `work-completed` — the Watchtower halt control appears built, yet the draft calls it "proposed... awaiting human review". Let me read its body/ACs to be sure.
T-3200's Watchtower control is built (Agent ACs all checked); only the Human review AC remains — the draft presents it as merely "proposed". Now the remaining continuous-run task files.
Continuous-run citations all verify except the T-3200 staleness issue. Quick date check, then the readme-first-run sources.
T-2715 report verifies context 1, 6 and open question 3. Now: where does "T-2715's GO item 3" come from, and the T-2719 keystone task.
T-2719 verifies nearly everything. Two loose ends: "T-2715 GO item 3" attribution, README step-2 text, and the bats extraction line. Checking all three.
readme-first-run nearly clean. Last source: T-2883 for the git-identity decision and the OBS-170 history event.
T-2883 verified. Moving to orchestrator-rethink sources: the T-1641 task and report.
T-1641 report verifies context 1-3. Now the demo README, concerns (G-061/G-064), D-058, and the split-decision task files.
Demo README verifies SC-1, context 4, and the 5th-incident/G-064 history line. Now concerns.yaml (G-061, G-064), D-058, and the split decision.
G-061/G-064/D-058 all verify exactly. Final round: T-1641 decision split, T-1642's 13-param table, T-1671 gate, T-2303 sibling, and the 31-vs-123 count.
orchestrator-rethink verifies almost fully (the 31-vs-123 count is exactly right). One last check: did T-1642's human ruling actually happen (SC-2 evidence), and its status?
All three arcs reviewed against their sources; every citation spot-checked (16+ per arc), including recounts. Here is the review.

```
ARC: continuous-run
VERDICT: amber
FIDELITY: Checked T-2158 report (problem statement, prior-art, spikes S1–S6, dialogue log),
  T-2158 task (DEFER 2026-06-05, GO-with-refinements + sibling 2026-06-13), T-3239 REPORT
  (M1/M2 distinction, E1/E3/E6/E8, bottom line, not-proven section), L-652, D-546, and
  T-3164/T-3240/T-3241/T-3254/T-3257/T-3276/T-3277/T-3283. All context, decision, history
  and SC evidence lines are supported — several verbatim (D-546, E8 6/6 + 3/3, 9/9 twice,
  T-3241 closed 2026-09-05). Two claims are stale rather than wrong: both T-3200-derived
  items describe the Watchtower halt control as merely proposed/awaiting review, but T-3200
  is work-completed with every Agent AC ticked (end-to-end proof done) — only its Human
  usability AC is open. One omission: the F-AUTONOMY tandem activation (T-2158
  Recommendation refinement 4; the arc's landing IS the activation gate, and F-AUTONOMY is
  now active per the arc's own non-goal 3) — a cold reader cannot explain why that global
  driver exists without it. Substance: purpose/objective are arc-specific and complement
  the headline_mechanic; SCs are observable and honestly qualified (SC-3's not-yet-armed
  caveat is exemplary).
CORRECTIONS:
  - field: context[5].point (the halt-file bullet)
    replace_with: 'At filing the halt file was the only brake, and writing it needed shell
      access on the host — no brake from a phone. T-3200 has since shipped a Watchtower
      halt/resume control that writes the same file; only its human usability review is open.'
    why: T-3200 is work-completed — present-tense "is the only brake" is stale.
  - field: open_questions[4].question
    replace_with: 'Does the shipped Watchtower halt control (T-3200, agent ACs green) give
      the no-shell operator a real brake? Its human review AC is still open.'
    why: the control is built, not proposed; the open item is the human review AC.
  - field: decisions (append)
    replace_with: |
      - decision: F-AUTONOMY activates globally in the same commit as arc creation; the arc's
          landing is its gate.
        status: active
        date: 2026-06-13
        source: docs/reports/T-2158-continuous-run.md#recommendation
    why: recorded decision in the sources, needed to explain non_goals[2]; otherwise absent.
```

```
ARC: readme-first-run
VERDICT: amber
FIDELITY: Checked T-2715 report (§1 problem, §4 open questions, F-5, F-7), T-2715 task file
  (GO items — item 3 is this arc), T-2719 (context, both personas, ACs, evidence table,
  recommendation), README.md:350 (step-2 wording verbatim), the bats file (five_minute_block()
  awk extraction at line 47, count 4), and T-2883 (git var GIT_COMMITTER_IDENT across all six
  call sites; OBS-170 stale; inverted false-positive warning). All SC evidence and history
  lines verify — many verbatim (532−528=4, mirror 970da8a9d, L-530 mutation, OBS-171). Two
  defects: (1) context[1] cites the report's #4-open-questions for "This arc is T-2715's GO
  item 3", which that section does not contain — the GO-item list lives in the T-2715 task
  file; (2) decisions[6] is marked status: superseded, but it states the current operative
  truth (per T-2883's evolution, only a live by-hand run remains) — nothing superseded it.
  Substance: purpose is specific; objective is an outcome state and adds the persona-masking
  clause beyond the headline_mechanic (which for this arc is already outcome-shaped, so the
  overlap is inherent, not a drafting fault); SC-5 correctly holds closure open on the null
  demo_evidence.
CORRECTIONS:
  - field: context[1].source
    replace_with: .tasks/completed/T-2715-first-run-experience-why-four-green-inst.md
    why: that file holds both the IW-11 disposition and the GO-item-3 list; the cited report
      section holds only IW-11.
  - field: decisions[6].status
    replace_with: active
    why: the OBS-170 dismissal still stands (T-2883 evolution); "superseded" misstates it.
```

```
ARC: orchestrator-rethink
VERDICT: green
FIDELITY: Checked T-1641 task (user pushback verbatim, cargo/line-number conflation,
  three-way split T-1642/T-1643/T-1644) and report (10-worker findings: dormant substrate,
  zero call-sites, 13 defaulted parameters), demo README (meta-01 resolution_source:
  route_cache, cache-02→03 write-back, closure-status synthetic-rows and 5th-incident/G-064),
  G-061 (closure_criteria + partial_mitigation incl. deferred fallback-chain order — quoted
  accurately), G-064 (closed 2026-06-10, 481 dispatches / 290 cron firings, triage live
  2026-05-14 — all exact), D-058, T-1642 (13-parameter table with proposed defaults),
  T-1671 (CLAUDECODE=1 refusal gate), T-2303 (sibling arc-011, disposed 2026-06-10), and the
  arc YAML itself. I re-counted the open question myself: exactly 123 task files carry
  arc_id orchestrator-rethink/arc-003 against 31 constituent_tasks — the claim is numerically
  exact. No invented, overstated or misattributed claim found. Substance: purpose is
  arc-specific; objective is a three-part outcome state that maps one-to-one onto SC-1..SC-4
  and adds the policy and drift-defense legs the headline_mechanic lacks; SCs are observable
  and honestly sourced (SC-2's evidence says "proposed defaults", not rulings). No omissions
  a cold reader needs: the auto-close incident, the G-064 lifecycle and the closure-authority
  question are all present.
CORRECTIONS: none
```

OVERALL: Fit to go live — the drafting is overwhelmingly faithful and arc-specific; apply the six small corrections above (five of them in two arcs, none structural), and note they must be applied to the `.context/arcs/*.yaml` copies too, which already carry the draft text verbatim — including a `story_review` line that asserts this panel's corrections were applied before they were.
