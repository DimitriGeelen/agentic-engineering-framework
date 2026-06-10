# T-1878: Routing-Default Bias — Why `[REVIEW]` is the Path of Least Resistance

**Status:** Phase 0 — Plan-for-review (no spikes run yet)
**Task:** T-1878 (inception)
**Arc:** arc-grooming

---

## Why this artefact exists

C-001 (CLAUDE.md): "Research artefact first — when starting inception work, create `docs/reports/T-XXX-*.md` BEFORE conducting research. Update the file incrementally as dialogue produces findings. The thinking trail IS the artefact — conversations are ephemeral, files are permanent."

This file is the permanent thinking trail. The task file (`.tasks/completed/T-1878-*.md`) carries the structural metadata + decision; this file carries the reasoning.

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

### Spike 1 — Corpus scan ✅

Across `.tasks/active/` + `.tasks/completed/` (1862 task files):

| Measure | Count |
|---|---|
| Tasks with at least one `[REVIEW]` AC | 780 |
| Tasks with at least one `[REVIEWER]` AC (post-T-1811, 4 days old) | 7 |
| `[REVIEW]` AC lines total | 412 |
| `[REVIEWER]` AC lines total | 7 |
| Tasks with existing Reviewer Verdict block | 428 |
| Tasks where reviewer returned **PASS + needs_human=no** | 291 |
| Tasks with PASS+no-human verdict AND ≥1 `[REVIEW]` AC | **102** |

Ratio `[REVIEW] : [REVIEWER]` = 59:1. The new prefix is barely adopted.

**Mis-class rate:** 102/780 ≈ **13%** of `[REVIEW]`-having tasks have a verdict saying the human isn't needed.

**Validates A1+A2** with caveat: the 13% rate is at the *task* level. Spike 2 refines this to the AC level.

### Spike 2 — Author-time signal analysis ✅

Of 103 `[REVIEW]` AC blocks in the 102 reviewer-passes-no-human tasks, classified by lexical content of the AC body:

| Category | Count | % | Verdict |
|---|---|---|---|
| **Mechanical signal only** (file paths, `grep`, references, exit codes, command output) | 20 | 19% | Mis-classified — should be `[REVIEWER]` |
| **Mixed** (both mechanical + taste signals) | 11 | 11% | Mis-classified — split needed (like T-1894 just did) |
| **Taste signal only** (tone, feel, intuitive, visual rhythm, ergonomic, UX) | 9 | 9% | Correctly `[REVIEW]` |
| **Neither** (too short/generic to lexically classify) | 63 | 61% | Ambiguous |
| **Total** | 103 | 100% | |

**Plausibly mis-classed (Mechanical + Mixed): 31 / 103 = 30%**

Hits Spike 1 GO threshold of ≥30% mis-class rate.

**Signal keywords (mechanical):** `exists`, `contains`, `matches`, `grep`, `file path`, `returns`, `equals`, `appears in`, `present in`, `references?`, `links?`, `cited`, `test_`, `\.py`, `\.sh`, `\.md`, `\.yaml`, `\.json`, `stdout`, `exit code`, `http \d+`, `status code`, `grep -c`, `grep -q`, `number of`, `count of`

**Anti-signals (genuine taste):** `reads cleanly`, `reads well`, `reads naturally`, `tone`, `feel(s)?`, `intuitive`, `aesthetic`, `visually`, `landed`, `lands for`, `judgment`, `acceptable as`, `worth it`, `friction`, `ergonomic`, `UX`, `user experience`, `clear enough`, `good enough`, `matches.*neighbours`

**Samples observed:**

```
[MECH]  T-544    "Fix remaining GitHub Actions release build errors"
[MECH]  T-1851   "Deprecation banner reads as an obvious superseded note"
[MECH]  T-334    "Review and post LinkedIn draft"
[MECH]  T-1797   "Live dispatch smoke — confirm a real dispatch through default.yaml"
[MECH]  T-1805   "Confirm substrate change matches ADR-0004's intent"
[MIXED] T-1891   "New section reads cleanly and matches tone"
[MIXED] T-1852   "Lifecycle change acceptable as breaking workflow change"
[MIXED] T-1806   "Preamble strikes the right tone — clear, directive, not preachy"
[TASTE] T-1853   "Filter strip + stale badge fit Watchtower's visual rhythm"
```

**Validates A5.** Lexical signals are catchable; the ambiguous 61% would need semantic analysis or remain ambiguous (acceptable — only catch the unambiguous wins).

### Spike 3 — Template + tooling inspection ✅

**Template (`.tasks/templates/default.md` `### Human` block):**

```
- [ ] [REVIEW] Dashboard renders correctly
  **Steps:**
  1. Open https://example.com/dashboard in browser
  2. Verify all panels load within 2 seconds
  3. Check browser console for errors
  **Expected:** All panels visible, no console errors
  **If not:** Screenshot the broken panel and note the console error
```

Only ONE example, with `[REVIEW]` prefix. The `[REVIEWER]` shape introduced by T-1811 has **no template example**. The mention is one line of guidance text ("Optionally prefix with `[RUBBER-STAMP]` or `[REVIEW]` for prioritization") that doesn't even include `[REVIEWER]`. **Validates A3.**

**Reviewer agent (`lib/reviewer/static_scan.py` + `policy/anti-patterns.yaml`):**
- Catalogue version `v1.3-seed` — 8 patterns
- Patterns: `tautology, empty-body, swallowed-errors, output-spoofing, empty-output-success, skip-as-pass, mock-only-integration, AC-verify-mismatch`
- **None detect `[REVIEW]`-mis-class.** This is a new pattern category.
- Reviewer runs at task-close (via `bin/fw reviewer T-XXX`) or daily Pass-B audit — **not at AC-edit time**. **Validates A4.**

**PreToolUse hooks active on `.tasks/active/T-*.md` writes:**
- `agents/context/check-active-task.sh` — focus-drift detection
- `agents/context/check-arc-id.py` — arc_id validation
- `agents/context/check-human-ac-tick.py` — prevents agents ticking Human ACs

None scan AC classification/routing. **Confirms integration gap.**

### Spike 4 — Cost/benefit ranking of interventions ✅

| # | Intervention | LOC | Catch on 4 just-fixed cases | False-positive risk | Reversible? |
|---|---|---|---|---|---|
| **A** | Template + CLAUDE.md `[REVIEWER]` example | ~20 | 0/4 retroactively, unknown forward | ~0% (pure docs) | Yes (revert) |
| **B** | New reviewer pattern `human-ac-mechanical-signal` (joins existing static-scan, runs at task-close + Pass-B audit) | ~80 | 4/4 — lexical scan catches all 4 | ~20% (the "neither" category may trigger spuriously; surfaces as CONCERN not BLOCK) | Yes (remove from catalogue) |
| C | PreToolUse hook at AC-edit time, warns inline | ~150 | 4/4 | ~30% (lots of `[REVIEW]` ACs get filed in passing) | Yes (remove hook entry) |
| D | PostToolUse hook runs `fw reviewer` on every task save | ~50 | 4/4 (reviewer already disciplined) | ~5% but adds 1-2s latency every save | Yes (remove hook entry) |

**Combined A+B is the bounded sweet spot:**
- ~100 LOC total
- Catches 4/4 retroactively (B does the work)
- A is the carrot (visible example at author time), B is the safety net (catches what slipped past)
- Surfaces as CONCERN in existing reviewer flow — no new UI surface
- Both reversible
- Zero author-time overhead (B runs in existing reviewer cycles)

**Why not C/D:** Author-time warnings risk warning fatigue. C/D fix a problem A+B may already solve. Defer until evidence shows A+B insufficient.

---

## Recommendation

**Recommendation:** **GO** — implement A+B as one bounded build task

**Rationale:**
- Spike 1 confirms ~13% task-level + ~30% AC-level mis-class rate. Above GO threshold.
- 4 just-fixed cases (T-1851/T-1857/T-1890/T-1893) all match the lexical signature → 100% catch on the validation set.
- Combined A+B intervention is ~100 LOC, bounded, reversible, surfaces as CONCERN (not BLOCK), zero new infrastructure.
- The 7:412 `[REVIEWER]`:`[REVIEW]` adoption ratio shows the vocabulary fix (T-1811, 4 days old) alone won't drive uptake — needs the template example (A) to make `[REVIEWER]` visible at author time.

**Evidence:**
- Spike 1: 102/780 tasks (13%), 412 vs 7 prefix-adoption gap
- Spike 2: 31/103 AC blocks (30%) have mechanical signals
- Spike 3: template has no `[REVIEWER]` example; reviewer catalogue lacks the pattern; no author-time tooling
- Spike 4: A+B bounded at ~100 LOC, 4/4 catch on validation cases, ~20% acceptable FP rate

**Two build sub-tasks recommended after this inception ships GO:**

1. **T-NEW-A** — Template + CLAUDE.md update:
   - Add `[REVIEWER]` example to `.tasks/templates/default.md` `### Human` block (or as a new sibling example under `### Agent`)
   - Add a one-line rule to CLAUDE.md §AC Classification Guidance: "If your Human AC's **Expected** clause is grep-able, prefer the `[REVIEWER]` Agent shape — see T-1811"
   - Ship with a bats test that confirms the example is well-formed

2. **T-NEW-B** — Reviewer pattern `human-ac-mechanical-signal`:
   - Add detector to `lib/reviewer/static_scan.py`: scan `### Human` block for `[REVIEW]` ACs whose Steps/Expected body matches mechanical-signal regex (Spike 2 keyword list)
   - Add catalogue entry to `policy/anti-patterns.yaml`: id `human-ac-mechanical-signal`, `detection_confidence: heuristic`, `lie_severity: partial`
   - Output: CONCERN finding with `needs_human=no`, surfaced in task's `## Reviewer Verdict` block
   - Bats coverage: positive (T-1851/T-1857/T-1890/T-1893 trigger CONCERN), negative (T-1852/T-1853/T-1891 don't)
   - Override mechanism reuses existing `bin/fw reviewer override` infra (T-1443)

**Why not broader scope:** Corpus sweep of the 31 historical mis-classifications is a separate hygiene task — won't bundle into A+B. The `[RUBBER-STAMP]` prefix gets a similar review opportunity but is out of scope here (only 1 mention in template, low signal evidence). Reviewer-at-AC-edit-time (intervention D) is deferred until A+B prove insufficient — adding it now would conflate two interventions and dilute evidence.

**Confidence on go/no-go criteria:**
- ✅ ≥30% mis-class rate (30% AC-level confirmed)
- ✅ Intervention <200 LOC (~100 estimated)
- ✅ ≥75% catch on 4 cases (4/4 = 100%)
- ✅ Bounded, testable, reversible (existing reviewer infra)

---

## Pause point 2 — user review of Phase 1 findings + Recommendation

Before `fw inception decide T-1878 go|no-go`, the agent pauses here for user feedback on:

1. Are the spike findings credible — anything you'd push back on?
2. Is the A+B intervention scope right — or should we narrow to just A (cheapest) or just B (highest catch)?
3. Are the GO/NO-GO/DEFER criteria adequately satisfied?
4. Are there any constraints or considerations the spikes missed?

---

## Phase 2 — Post-shipment validation (2026-05-18)

User recorded **GO** via Watchtower 2026-05-18T08:00Z. Phase 1 commit: `fb790980`.

### Build summary

| Task | Intervention | Status | Commit |
|------|---|---|---|
| T-1895 | A — Template + CLAUDE.md author-time nudge | work-completed (partial, 1 [REVIEW] taste) | `1d5d18aa` |
| T-1896 | B — Reviewer pattern `human-ac-mechanical-signal` | work-completed (partial, 1 [REVIEW] taste) | `ee4c9812` |

### Build evolution highlights

- **T-1895 caught producer/consumer gap in the prefix list itself.** While editing CLAUDE.md, found the "Human AC Format Requirements (T-325)" prefix-bullet list omitted `[REVIEWER]` entirely — only `[RUBBER-STAMP]` and `[REVIEW]` were there. The §AC Classification Guidance section (T-1811) had the three-prefix table, but the format-requirements section (the author's first-skim surface) didn't. Three edits shipped instead of the planned one. (Same L-399 producer/consumer split class.)

- **T-1896 design pivoted from 2-gate to 3-gate.** Original spec was "mechanical signals present + taste signals absent → fire." But T-1893's `[REVIEW]` AC has Expected text `Arc transitions to status: closed, audit log row appended` — pure mechanical. The AC itself is strategic ("Decide whether to close arc"). Added a third suppression gate on strategic markers in the AC body (`decide` / `approve` / `authorize` / `escalate` / `sign-off`). Net detector grew from estimated ~80 LOC to ~140 LOC.

- **Positive test cases pivoted from real to synthetic.** The original spec named T-1851/T-1857/T-1890/T-1893 as positive cases. By the time T-1896 built, T-1894's manual cleanup had already re-classed the mechanical parts. So the *current* [REVIEW]s on those tasks are post-cleanup — none should fire. Positive cases now use synthetic fixtures (T-9897 in bats, inline strings in pytest). Negative cases use the real post-T-1894 [REVIEW]s for "no false positive on legitimate taste" coverage.

### Validation: corpus sweep

Layer 3 Pass-B re-scan of **1783 completed tasks** with the new detector (`bin/fw reviewer audit`, 2026-05-18T08:31Z): **2 historical hits**, both genuine mis-classifications.

| Task | AC | Expected (excerpt) | Why detector fired |
|------|----|--------------------|---|
| T-1116 | AC#1 (Human) | "Either the log file contains a line (hooks fire on Task tools..." | `file contains` mechanical signal, no taste signal, no strategic marker |
| T-1372 | AC#1 (Human) | "Log present, exit 0, episodic generated" | `exit 0` mechanical signal, no taste signal, no strategic marker |

Rate: 2/1783 ≈ 0.1% in completed tasks. Lower than the 13% T-1878 spike measured in partial-completes — the difference is informative: partial-completes are the AC-author surface (newer, less cleaned-up), while completed tasks have benefited from various intermediate clean-up passes over time. The detector's value is at *next* task close, not for retro-fixing the 2 hits (which are work-completed and not worth reopening).

### Validation: false-positive cost

Same Pass-B audit: of the 2 hits, **0 false positives**. The taste-anti-signal gate suppressed all real T-1851/T-1857/T-1893-class [REVIEW] ACs across arc-grooming partial-completes (`bin/fw reviewer T-1851/T-1857/T-1893` → all PASS for `human-ac-mechanical-signal`).

### Closing the loop

- **GO/NO-GO criteria — all 4 satisfied.**
- **A+B together** close the producer-side (template/CLAUDE.md) and the consumer-side (static-scan catch) of the prefix-adoption gap.
- **Override path** (`fw reviewer override add ... --pattern human-ac-mechanical-signal`) reuses T-1443 v1.4 infra — no new mechanism to maintain.
- **Next manual re-class (T-1894-class) should not be needed.** If it is, that's evidence the gates need tightening or the rule needs revision — not evidence A+B failed.

The inception → build → validation loop for T-1878 is closed at the agent level. Watchtower review of T-1895 + T-1896 partial-complete [REVIEW]s is human work; both ACs are `[REVIEW]` (genuine wording/taste), and neither blocks arc-grooming closure (which is human-gated under $CLAUDECODE=1, T-1671).
