# VALUE REVIEW — Evidence F: Realized cost per subsystem (T-3370, GATHERER-F)

Date: 2026-09-16. Read-only survey; this file is the only thing written in the repo. Builds on
`VALUE-REVIEW-whole-repo-2026-09-16-datamap-C-recording.md` (GATHERER-C).

> **This is a COST signal, not a value signal.** It measures what we *spent* building and repairing each
> subsystem: wall-clock span, commits, lines changed, RCA-carrying tasks and dispatched-worker dollars. It does
> not measure value delivered. Value was never genuinely predicted (see §6). A bug-class task or RCA is counted
> against the subsystem whose files it *touched*, which is not necessarily the subsystem that *caused* the bug.

---

## TL;DR

- **Coverage.** 1,697 of 2,886 completed tasks (58.8%) can be attributed to a subsystem, and 485 of them span more
  than one. Of the $849.61 in dispatched-worker spend, $395.11 (46%) is attributable.
- **Top 5 by realized cost** (fractional commits):
  1. Core CLI (bin+lib, other)
  2. Watchtower (web/, other)
  3. Hooks/gates
  4. Root governance docs (CLAUDE.md and similar)
  5. Tools/scripts/other

  Audit is a close 6th, and the same set leads when ranked by capped wall-clock time.
- **Top 5 by RCA density** (share of tasks with a substantive RCA):
  1. Handover (36.9%) — **small: 12.1 fractional tasks**
  2. Designer/BPMN (33.7%)
  3. Task system (31.9%)
  4. Reviewer (31.8%)
  5. Audit (30.9%)
- **The two rankings disagree.** Spearman ρ = −0.29 across 18 subsystems, and −0.30 across the 15 with at least 30
  fractional tasks. The biggest spenders (Watchtower, root docs, tools) have among the *lowest* RCA density. The
  high-pain areas are mid-sized: Task system, Audit, Reviewer and Designer.
- **Honesty check.** The pre-completion BVP predictions show a weak positive rank correlation with commits
  (ρ = 0.19, n = 732). That correlation is **mostly explained by task-body length**:
  - Body length correlates with both commits (0.39) and predicted D1–D4 (0.42).
  - Within body-length terciles, the D1–D4 vs commits correlation falls to 0.05–0.10.
  - BVP shows no correlation with wall-clock time (ρ ≈ 0.00) or with dispatch dollars (ρ = −0.10, n = 89).
  - The vector is near-constant: two D1–D4 vectors account for 63% of predictions.

  **Verdict: BVP predictions carry no usable independent cost signal.**

---

## 1. Path → subsystem rules (first match wins)

The unit of attribution is one file path from `git log --numstat` on a non-merge commit whose subject starts with
`T-NNN` and does **not** contain "handover" (case-insensitive).

**Excluded paths** (dropped before matching, same list as GATHERER-C): `.tasks/`, `.context/`, `docs/`,
`.fabric/`, `.agentic-framework/`, `VERSION`, and `tests/`. Commits to `tests/` are reported separately in §5.

| Order | Subsystem | Regex (on repo-relative path) |
|---|---|---|
| 1 | BVP | `(^\|/)[^/]*bvp[^/]*($\|/)` or `^policy/value-drivers` or `^policy/prompts/` |
| 2 | Designer/BPMN | `bpmn\|designer\|corpus` (covers `agents/bpmn`, `agents/designer`, `web/blueprints/designer*`, `lib/corpus-id.sh`, `vendor/designer/`) |
| 3 | Reviewer | `^lib/reviewer/\|^web/blueprints/review(er)?\.py\|^agents/ux-review/\|^lib/review` |
| 4 | Dispatch/Orchestrator | `^agents/(dispatch\|orchestrator\|govd)/` or `^lib/(resolver\|outcome\|dispatch\|ollama\|pause\|spawn\|worker_\|govd\|aef_\|pi_worker\|peer\|message_router)` or `^web/blueprints/orchestrator` |
| 5 | TermLink integration | `termlink` (anywhere in the path; BVP's `agents/termlink/bvp-estimator*` was already caught by rule 1) |
| 6 | Component Fabric | `^agents/fabric/\|fabric\.py$\|^web/templates/fabric` (`.fabric/` cards themselves are excluded) |
| 7 | Hooks/gates | `^\.claude/\|^lib/hook\|^bin/hook-enable` |
| 8 | Hooks/gates | `^agents/context/(check-\|block-\|budget-gate\|checkpoint\|loop-detect\|error-watchdog\|commit-cadence\|audit-task-tools\|pre-compact\|post-compact\|stop-\|subagent-stop\|chat-bare-path\|pl007\|test-tier0\|inject-next-directive)` |
| 9 | Context Fabric/memory | `^agents/(context\|resume\|session-capture\|sessions\|healing)/` (the rest of agents/context after rule 8) or `^lib/(ask\|recall\|index-health\|post-write-index\|episodic)` or `^web/(embeddings\|search\|ask\|context_loader)` |
| 10 | Handover | `^agents/handover/` |
| 11 | Task system | `^agents/task-create/` or `^lib/(tasks\|inception\|verify\|task\|review_link\|human_review\|decided)` |
| 12 | Audit | `^agents/audit/` |
| 13 | Git agent | `^agents/git/` |
| 14 | Watchtower (web/ other) | `^web/` |
| 15 | Policy (other) | `^policy/` |
| 16 | Core CLI (bin+lib other) | `^(bin\|lib)/` |
| 17 | Agents (other) | `^agents/` |
| 18 | Root governance docs | `^[^/]+\.md$` (CLAUDE.md, FRAMEWORK.md, …) |
| 19 | Tools/scripts/other | everything else (`tools/`, `scripts/`, `deploy/`, `install.sh`, `vendor/` non-designer, stray root files) |

## 2. Split rule

For task *t* with a distinct attributable file set F(t):

- **Weight.** w(t, s) = |files in F(t) mapped to s| / |F(t)|. The weights for a task sum to 1.
- **Weighted fields.** These are multiplied by w: task count ("frac"), wall-clock minutes, commits, substantive-RCA
  flag, bug-class flag, and dispatch $ / tokens.
- **Lines ±.** These are *not* weighted, because they are already per file: each subsystem gets the added + removed
  lines of its own files.
- **Unweighted fields.** "Tasks touching" is unweighted, and "median wall-min" is the unweighted median over the
  tasks touching the subsystem.
- **RCA density.** Σ w·RCA / Σ w.

## 3. Per-subsystem table (sorted by fractional commits = primary realized-cost measure)

**Field sources:**

- **wall-min:** `metrics.wall_clock_minutes` from `.context/episodic/T-*.yaml`. It is heavy-tailed: 128 tasks
  exceed one week (max 145,634 min, T-1687). The uncapped total is therefore dominated by long-lived tasks, and the
  **capped** column (at most 480 min per task) is the robust one.
- **Substantive RCA:** a `## RCA` section with more than 200 characters after stripping HTML comments.
- **Bug-class:** the regex `bug|fix|error|regression|broken|crash` on name + tags.
- **Dispatch $ / tokens:** `terminal_event.total_cost_usd` and the four `usage` token counters from
  `.context/dispatches.jsonl`.

| # | Subsystem | tasks (frac) | tasks touching | wall-min total | wall-min cap-480 | median wall-min | commits (frac) | lines ± ¹ | subst. RCA (frac) | RCA density | bug-class frac / touching | dispatch $ | dispatch tok (M) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Core CLI (bin+lib other) | 460.1 | 622 | 805,443 | 63,401 | 24 | 1073.2 | 50,855 | 122.7 | 26.7% | 97.8 / 122 | 172.03 | 379.6 |
| 2 | Watchtower (web/ other) | 235.6 | 294 | 498,147 | 26,959 | 12 | 514.2 | 50,262 | 30.8 | 13.1% | 57.9 / 70 | 8.46 | 23.2 |
| 3 | Hooks/gates | 120.5 | 183 | 223,206 | 14,477 | 12 | 323.4 | 12,667 | 29.1 | 24.2% | 27.8 / 41 | 42.47 | 98.7 |
| 4 | Root governance docs | 112.8 | 192 | 194,712 | 14,962 | 12 | 306.6 | 7,515 | 5.4 | 4.8% | 14.2 / 23 | 12.96 | 28.9 |
| 5 | Tools/scripts/other | 101.1 | 146 | 283,292 | 11,250 | 14 | 303.3 | 14,097 ² | 15.0 | 14.9% | 16.2 / 23 | 34.06 | 79.9 |
| 6 | Audit | 123.3 | 187 | 176,576 | 13,294 | 21 | 287.7 | 11,578 | 38.1 | 30.9% | 20.0 / 30 | 19.80 | 51.7 |
| 7 | Task system | 113.1 | 176 | 117,908 | 10,666 | 8 | 249.6 | 7,341 | 36.1 | 31.9% | 39.2 / 55 | 5.51 | 13.4 |
| 8 | Component Fabric | 42.7 | 53 | 55,279 | 4,055 | 8 | 194.4 | 7,166 | 11.5 | 26.9% | 12.8 / 15 | 2.17 | 3.4 |
| 9 | Context Fabric/memory | 80.7 | 140 | 55,262 | 9,965 | 23 | 168.3 | 10,205 | 22.9 | 28.4% | 27.2 / 40 | 4.67 | 10.6 |
| 10 | Designer/BPMN | 63.4 | 74 | 9,465 | 5,183 | 9 | 129.1 | 6,602 ³ | 21.3 | 33.7% | 10.5 / 11 | 10.68 | 22.7 |
| 11 | Git agent | 40.5 | 64 | 38,677 | 4,611 | 22 | 114.1 | 3,223 | 9.4 | 23.2% | 11.2 / 15 | 11.21 | 25.7 |
| 12 | Reviewer | 46.5 | 74 | 18,118 | 5,883 | 22 | 102.5 | 6,748 | 14.8 | 31.8% | 8.5 / 13 | 8.81 | 22.7 |
| 13 | BVP | 45.7 | 53 | 21,187 | 5,070 | 9 | 86.2 | 7,944 ⁴ | 7.0 | 15.3% | 3.5 / 4 | 0.00 | 0.0 |
| 14 | Dispatch/Orchestrator | 36.9 | 54 | 616,973 ⁵ | 9,468 | 268 | 82.2 | 7,944 ⁴ | 6.1 | 16.4% | 3.5 / 5 | 20.05 | 49.3 |
| 15 | TermLink integration | 21.7 | 34 | 158,432 | 2,869 | 17 | 76.4 | 2,463 | 4.6 | 21.4% | 7.5 / 9 | 1.10 | 2.5 |
| 16 | Agents (other) | 31.5 | 48 | 8,512 | 2,228 | 6 | 67.3 | 4,129 | 9.5 | 30.1% | 11.6 / 15 | 41.12 | 81.0 |
| 17 | Handover ⚠small | 12.1 | 37 | 41,829 | 1,208 | 18 | 25.3 | 835 | 4.5 | 36.9% | 1.9 / 5 | 0.00 | 0.0 |
| 18 | Policy (other) ⚠small | 8.7 | 16 | 1,441 | 1,408 | 192 | 18.2 | 875 | 2.2 | 24.8% | 0.7 / 1 | 0.00 | 0.0 |

**Footnotes:**

1. **Lines are for completed tasks only**, excluding the stray root files `os` and `datetime` and all of `vendor/`
   (see footnotes 2 and 3).
2. **Stray root files.** Raw Tools/scripts/other was 1,661,521 lines, because the stray root files `os` (925,750)
   and `datetime` (721,674) were committed under T-012 (2026-03-29) and T-1716 (2026-05-04). They are no longer on
   disk. They look like ImageMagick `import` screenshots from a mistyped `import os` (UNVERIFIED). 14,097 is the
   figure without them.
3. **Vendored Designer bundles.** Raw Designer/BPMN was 97,523 lines, because
   `vendor/designer/aef-workflow-designer-*.html` bundles were recommitted at each version (about 9–11K lines
   each). 6,602 is the figure without `vendor/`.
4. **BVP and Dispatch both total 7,944 lines.** This was checked: the task sets differ (52 vs 53 tasks, with
   different IDs), so it is a coincidence.
5. **Dispatch/Orchestrator wall-clock outliers.** The uncapped total and the median of 268 are driven by long-lived
   arc anchors (T-1687 at 145,634 min, T-1643 and others). Use the capped figure.

**Small-sample flags:**

- **Handover** (12.1 fractional tasks) and **Policy** (8.7) are too small for their rates to be trusted.
  Handover's #1 RCA density rests on about 4.5 fractional RCA tasks.
- **TermLink integration** (21.7) is borderline.
- **BVP dispatch $ = 0** does not mean BVP had no dispatch cost. The BVP estimator's own worker runs are either not
  recorded with `terminal_event`, or are not keyed to the tasks whose files they touch.

## 4. Rankings

**By realized cost (fractional commits):**

1. Core CLI
2. Watchtower
3. Hooks/gates
4. Root governance docs
5. Tools/other
6. Audit
7. Task system
8. Component Fabric
9. Context Fabric
10. Designer
11. Git agent
12. Reviewer
13. BVP
14. Dispatch/Orchestrator
15. TermLink
16. Agents-other
17. Handover
18. Policy

**By capped wall-clock** (the same top 5, reordered): Core CLI, Watchtower, Root docs, Hooks/gates, Audit;
Tools/other is 6th.

**By RCA density** (rate, with fractional n in brackets):

| Rank | Subsystem | RCA density | Fractional n |
|---|---|---|---|
| 1 | Handover ⚠ | 36.9% | 12 |
| 2 | Designer/BPMN | 33.7% | 63 |
| 3 | Task system | 31.9% | 113 |
| 4 | Reviewer | 31.8% | 47 |
| 5 | Audit | 30.9% | 123 |
| 6 | Agents-other | 30.1% | 32 |
| 7 | Context Fabric | 28.4% | 81 |
| 8 | Component Fabric | 26.9% | 43 |
| 9 | Core CLI | 26.7% | 460 |
| 10 | Policy ⚠ | 24.8% | 9 |
| 11 | Hooks/gates | 24.2% | 121 |
| 12 | Git agent | 23.2% | 41 |
| 13 | TermLink | 21.4% | 22 |
| 14 | Dispatch/Orchestrator | 16.4% | 37 |
| 15 | BVP | 15.3% | 46 |
| 16 | Tools/other | 14.9% | 101 |
| 17 | Watchtower | 13.1% | 236 |
| 18 | Root docs | 4.8% | 113 |

**Excluding the ⚠ small subsystems,** the top 5 by RCA density are: Designer, Task system, Reviewer, Audit,
Agents-other.

**Agreement:** the two rankings **do not agree**. Spearman ρ(commits, RCA density) is −0.29 (n = 18) and −0.30 for
the 15 subsystems with at least 30 fractional tasks.

- **Where they diverge.**
  - Watchtower is #2 on cost but #17 on RCA density.
  - Root docs is #4 on cost but #18 on RCA density.
  - Designer is #10 on cost but #2 on RCA density.
  - Reviewer is #12 on cost but #4 on RCA density.
- **What the divergence suggests (a reading, not a finding).** Web and docs churn is high-volume and low-pain,
  while Task system, Audit, Reviewer and Designer carry a disproportionate share of write-ups about things that
  went wrong.
- **Caveat on the RCA practice.** `## RCA` became gate-enforced only for bug-class tasks from T-1550 onward. So RCA
  density partly reflects *when* a subsystem was worked on, and not only how painful it was.
- **Reference rates.** The corpus RCA rate is 17.4% overall and 23.0% among attributable tasks.

## 5. Coverage and limits (control)

- **Completed tasks: 2,886.**
  - With at least one non-handover `T-NNN` commit: 2,701.
  - **Attributable** (at least one non-excluded file): **1,697** (58.8%). GATHERER-C reported 1,681; the small
    difference comes from rename-path handling.
  - Multi-area: 485 (GATHERER-C: 522, using a coarser area definition).
- **Dropped: 1,189 tasks.**
  - Of these, 1,004 have commits that touch only excluded paths (`.tasks/`, `.context/`, `docs/`, `tests/`, …), and
    185 have no commits.
  - Dropped by workflow type: build 570, inception 411, test 129, refactor 60, specification 11, design 8.
  - **Most inceptions (411 of 457) are invisible to this instrument by construction**, because their artefact lives
    in `docs/`.
- **Tests.** 1,018 completed tasks touch `tests/`. Test effort is **not** in the table; it is excluded from the
  split so that it does not dilute source attribution. The 129 test-workflow tasks that touch only tests are part
  of the dropped set.
- **Dispatch spend.** 111 tasks carry spend ($849.61). Only 64 of them are attributable, covering $395.11 (46%).
  Main-session tokens are **not** attributable per task (GATHERER-C §2c), so the dispatch $ column is a small and
  biased slice of real token cost.
- **Wall-clock time** is the first-to-last-commit span, not effort. Anchors and arc tasks inflate it, hence the
  capped column.
- **Pre-convention history.** Tasks before the `T-NNN:` subject convention, and ID reuse in the early era (T-012
  has 375 commits), distort the Core CLI and Tools rows. No attempt was made to correct for either.
- **Bugs.** A bug-class or RCA task is charged to the subsystem it *touched while fixing*, not to the subsystem that
  *caused* the bug. Cause links are free text (14 explicit ones; GATHERER-C §2e).

## 6. Honesty check — do pre-completion BVP predictions track realized cost?

**Sample and method:**

- The sample is the 732 completed tasks whose *first* `bvp_scores_proposed` entry has `ts < date_finished`.
- The predicted score is the sum of all driver scores in that first entry.
- Spearman ρ is used throughout. As a rough noise floor, 2/√732 ≈ 0.074.

**Degeneracy:**

- There are only 44 distinct D1–D4 vectors. Two of them, `(4,0,3,2)` with 244 tasks and `(4,0,2,2)` with 220,
  cover 63% of the sample.
- Just 2 of the 732 are all-zero.
- Predicted totals cluster at 8 (182 tasks) and 9 (173).
- The estimator is `bvp-estimator-v1-heuristic` in every case: keyword rules applied to the task body.

**Results:**

| Realized measure | n | ρ (predicted total) |
|---|---|---|
| commits | 732 | **0.188** |
| wall-clock minutes | 732 | −0.003 |
| attributable lines ± | 460 | 0.146 |
| dispatch $ | 89 | −0.098 |
| commits, using D1–D4 sum only | 732 | 0.140 |
| commits vs *number of drivers in the vector* | 732 | 0.231 |

**Confound: task-body length.**

- Body length vs commits: ρ = 0.385.
- Body length vs predicted D1–D4: ρ = 0.424.
- Within body-length terciles (n = 244 each), predicted D1–D4 vs commits drops to **0.103, 0.051 and 0.063**,
  which is at or below the noise floor.
- The number of drivers in the vector correlates with commits (0.23) more strongly than the scores do. That points
  to a time/era confound: driver lists grew over time, and so did commit habits.

**Answer:** there is a weak raw correlation between predicted BVP and commit count. It is mostly an artefact of the
heuristic firing more on longer task bodies, and longer tasks take more commits. After controlling for body length
it is near zero, and against wall-clock time and dispatch spend there is no correlation at all. **The predictions
carry no usable independent signal about realized cost.** They do not measure value either, and nothing here can
test value. I am not claiming a correlation.

## 7. Reproduce

```bash
cd /opt/999-Agentic-Engineering-Framework
git log --no-merges --format='@@%H%x09%s' --numstat > /tmp/gf-numstat.txt
python3 /tmp/gf/realized_cost.py          # prints coverage, table, rankings, Spearman, honesty check
```

**What the script does** (`/tmp/gf/realized_cost.py` is a scratch copy, reproduced in logic by §1–§2):

1. Parses `/tmp/gf-numstat.txt`, keeping `^T-\d+` subjects without "handover".
2. Maps paths using the §1 rules and builds the per-task file set.
3. Reads the completed tasks' frontmatter and `## RCA` sections (PyYAML).
4. Reads `wall_clock_minutes` from the episodic files.
5. Sums `terminal_event` data from `dispatches.jsonl` per task.
6. Applies the §2 weights.
7. Computes Spearman on ranks (hand-rolled, no ties correction).

**Line-count exclusions for footnotes 2 and 3** are a second pass that skips `os`, `datetime` and `vendor/*`,
restricted to completed tasks.

## VERBS I RAN

No `fw` verbs. Only `git log`, `ls`, `sed`, `head`, `grep`, `wc` and Python/PyYAML readers. Scratch output went to
`/tmp/gf*` only.
