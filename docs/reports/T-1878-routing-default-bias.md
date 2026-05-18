# T-1878: Routing-Default Bias — Why `[REVIEW]` is the Path of Least Resistance

**Status:** Phase 0 — Plan-for-review (no spikes run yet)
**Task:** T-1878 (inception)
**Arc:** arc-grooming

---

## Why this artefact exists

C-001 (CLAUDE.md): "Research artefact first — when starting inception work, create `docs/reports/T-XXX-*.md` BEFORE conducting research. Update the file incrementally as dialogue produces findings. The thinking trail IS the artefact — conversations are ephemeral, files are permanent."

This file is the permanent thinking trail. The task file (`.tasks/active/T-1878-*.md`) carries the structural metadata + decision; this file carries the reasoning.

---

## Problem statement (proposed)

**The observed pattern:** Agents authoring task files default to `[REVIEW]` Human ACs even when the "Expected" sub-claim is mechanical (grep, file-exists, structural). The reviewer agent (`fw reviewer`) confirms after-the-fact that many such ACs are agent-actionable (PASS + needs_human=no), but the routing decision was already made at file-time.

**Evidence (just this week):**

| Task | Original Human `[REVIEW]` AC | Mechanical content |
|---|---|---|
| T-1851 | "Banner reads clearly + references T-1851/T-1850 + links resolve" | refs are `grep`; link-target-existence is `test -f` |
| T-1857 | "Doc reads cleanly + CLI matches `fw arc help`" | verb-presence loop is mechanical |
| T-1890 | "Block message actionable cold + names both mechanisms with one-line guidance" | 100% mechanical — agent shouldn't need eyes |
| T-1893 | "Demo file is wire-evidence — 5 prongs, real captured output, addresses mechanic" | prong-count + fenced-block-presence + grep is mechanical |

T-1894 was the manual remediation (Today). Net: 4 mis-classifications shipped in one ~3-day window; one manual audit-and-split task to clean up.

**Why it matters:**

1. **Human review queue inflation** — every mis-classified `[REVIEW]` consumes human attention that could go to genuine taste/judgment calls.
2. **Trust dilution** — when 80% of `[REVIEW]` ACs are mechanical, the human stops reading carefully; real `[REVIEW]`s get glanced past.
3. **Recurrence cost** — T-954 (classification matrix) + T-1811 (`[REVIEWER]` prefix) were vocabulary fixes that didn't change the AC-author-time default. The pattern keeps happening.

**Why now:** 3rd instance of the meta-pattern (T-954 → T-1811 → T-1894). The Error Escalation Ladder says: A (don't repeat), B (technique), C (tooling), D (ways of working). We're at C/D — the discipline alone isn't holding; structural intervention is warranted.

---

## Assumptions (to test)

1. **A1 — Defensive bias is the primary driver.** Agents internalise CLAUDE.md's "when in doubt, make it Human — false negatives worse than false positives" and over-apply it, even when claims are clearly mechanical.
2. **A2 — `[REVIEWER]` prefix is unknown or unfamiliar at AC-author time.** T-1811 (4 days old) introduced the prefix; agents have not yet internalised it as a default option in their authoring vocabulary.
3. **A3 — Template anchoring matters.** The task template's example `### Human` block primes agents to write `[REVIEW]` ACs; no parallel `[REVIEWER]` example exists.
4. **A4 — Reviewer-at-close is too late.** The reviewer agent runs at task-close (or daily Pass-B). If it ran at AC-edit time, the agent would see "this looks like it could be `[REVIEWER]`" immediately and self-correct.
5. **A5 — A static scanner could catch most mis-classifications.** Patterns like `grep`, `references X`, `file exists`, `output contains Y`, `command returns Z` in a `[REVIEW]` AC's Steps/Expected are strong signals the AC is mechanical.

---

## Exploration plan

Each spike time-boxed to ≤30 min. Total ≤ 2 hours.

### Spike 1 — Quantitative corpus scan (30 min)

Across all `.tasks/{active,completed}/T-*.md`:
- Count total `[REVIEW]` Human ACs
- For each, run `fw reviewer T-XXX` and check whether it reports PASS + needs_human=no
- Compute: % of `[REVIEW]` ACs that the reviewer would close without human input

Output: a count + a sample of 5-10 false-positive `[REVIEW]`s for qualitative analysis. **Confirms or rejects A1+A2** depending on rate.

### Spike 2 — Author-time signal analysis (30 min)

For the 4 just-fixed cases (T-1851/T-1857/T-1890/T-1893), look at the `[REVIEW]` AC's text:
- Does the "Expected" clause contain `grep`-able patterns (file paths, command outputs, references to other task IDs, presence/absence checks)?
- Catalogue the lexical patterns that signal "this is mechanical"

Output: a candidate regex / keyword list for a static "this looks like a `[REVIEWER]`" detector. **Validates A5.**

### Spike 3 — Template + tooling inspection (20 min)

Read:
- `.tasks/templates/zzz-default.md` — what example does it surface for `### Human`?
- `agents/reviewer/` — what patterns does the existing reviewer actually catch? Could it run at edit-time?
- PreToolUse hooks on `.tasks/active/T-*.md` — what already fires when a task file is saved?

Output: list of integration points where a "routing-bias check" could be wired in. **Tests A3+A4.**

### Spike 4 — Cost/benefit of structural intervention (20 min)

For each candidate intervention (PreToolUse author-time warning, template example, reviewer-at-edit-time, Steps-pattern detector), estimate:
- Implementation cost (LOC, complexity, test surface)
- False-positive cost (annoying-warning rate)
- Catch rate (% of mis-classifications it would have caught on T-1851/T-1857/T-1890/T-1893)

Output: ranked list of interventions with bounded fix paths. **Inputs to GO/NO-GO.**

---

## Scope fence

**In scope:**
- AC-author-time routing decision (Human vs Agent + `[REVIEW]` vs `[REVIEWER]`)
- Structural interventions to shift the default toward `[REVIEWER]` when mechanical
- Audit-time detectors that surface mis-classification *before* the human sees it

**Out of scope:**
- Re-classifying historical mis-classified `[REVIEW]` ACs in the corpus (T-1894 covered this batch; full corpus sweep is its own task)
- Expanding `fw reviewer`'s pattern catalogue (separate concern)
- Watchtower UI changes
- Render-surface gate P-013 (T-1766) — different class of human-AC requirement
- Inception go/no-go decision authority (genuinely human, not in scope here)

---

## Technical constraints

- Any new PreToolUse hook must run <50ms (matches existing hooks like `check-arc-id.py`)
- Cannot read upstream into Claude session — author-time signal must come from the file being saved + corpus context, no network calls
- Backward compat: cannot break existing `[REVIEW]` ACs in the corpus (they stay until manually re-classed)
- Must work for both `Write` (full content) and `Edit/MultiEdit` (substitution) tool shapes — see T-1893's Prong 2 wire-evidence for the gotcha

---

## Dialogue log

### 2026-05-18 — User flagged "T-1878 is not ready !!!"

- **User:** Three exclamation marks — flagged that T-1878 surfaced in the human-review queue while being an empty skeleton (no Problem Statement, no Assumptions, no Exploration Plan, no Recommendation).
- **Agent action:** Demoted `horizon: later` + `status: captured` to park it. Asked user whether to (1) leave parked, (2) defer formally, (3) do the inception properly, (4) NO-GO close. Agent recommended (2). User chose (3).
- **Outcome:** Re-focused, promoted back to `horizon: now`, started filling the skeleton. This phase 0 artefact created BEFORE running any spike (per C-001).
- **Rationale for (3) over (2):** T-1894 (today) is the 3rd instance of the pattern T-1878 names. The premise is now empirically reinforced — manual audit-and-split is the *current* cost, but each cycle adds entropy. Structural intervention warranted if cost/benefit checks out.

---

## Spike results

*(empty until Phase 1 — to be populated as each spike completes)*

### Spike 1 — Corpus scan

*pending*

### Spike 2 — Author-time signal analysis

*pending*

### Spike 3 — Template + tooling inspection

*pending*

### Spike 4 — Cost/benefit of interventions

*pending*

---

## Recommendation

*(empty until all 4 spikes complete + dialogue with user confirms direction)*

---

## Pause point — user review of Phase 0 plan

Before running spikes, the agent pauses here for user feedback on:

1. **Assumption list (A1–A5):** is anything missing or wrong?
2. **Spike plan:** 4 spikes ≤2 hrs total — appropriate scope?
3. **Scope fence:** anything in/out that needs to flip?
4. **Constraints:** any technical constraint missing?

The plan above is the agent's proposal, not commitment. Once approved, spikes execute and findings populate above.
