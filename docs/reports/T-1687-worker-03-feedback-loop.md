# T-1687 Worker 03 — Triage Classifier → Heuristic Scanner Feedback Loop

**Scope:** Investigate whether verdicts from the reviewer's classifier layer feed back to tune the heuristic scanner's detection rules, plus related metrics, review process, error handling, and Watchtower surfacing.

**Method:** Source read of `lib/reviewer/*.py`, `tools/escalation-scan-v0*.py`, `web/blueprints/{reviewer,escalation,review}.py` + templates, and historical `.tasks/`/`docs/reports/` for context. No code was modified.

## Summary verdict

**No feedback loop exists today.** There are two distinct "classifier" systems in this codebase that are easy to conflate:

1. `lib/reviewer/classifier.py` (T-1483) — classifies **verification-block shell lines** into `READ_ONLY | STATE_TOUCHING | NETWORK_DEPENDENT | TIME_DEPENDENT | UNCLASSIFIED` so Pass-B reverify knows what's safe to re-execute. Consumed only by `lib/reviewer/reverify.py:26`. It has nothing to do with tuning `static_scan.py` anti-pattern detectors and carries no true/false-positive concept.
2. `tools/escalation-scan-v0.5.py` — the actual triage classifier with FP-relevant verdicts: `VALID_VERDICTS = ("real_symptom_fix", "false_positive", "defer")` (line 243). This is an LLM-augmented triage layer over a **separate** heuristic scanner (`tools/escalation-scan-v0.py`'s H1/H2/H3 regex heuristics), not over `lib/reviewer/static_scan.py`.

Neither classifier writes back into the regex/threshold definitions of its corresponding heuristic scanner. The design docs explicitly defer auto-tuning to an unshipped "v1."

---

## Q1 — Does the triage classifier verdict feed back to tune heuristic rules?

**Answer: No.**

- `lib/reviewer/classifier.py:29-34` defines line-categories for Pass-B safety gating, not FP/TP verdicts — irrelevant to detector tuning.
- The real triage classifier is `tools/escalation-scan-v0.5.py` (LLM verdicts over `escalation-scan-v0.py`'s H1/H2/H3 heuristic flags). Its regexes (`BUG_TITLE_RE`, `RCA_SECTION_RE`, `escalation-scan-v0.py:29-34`) are hand-authored and **duplicated verbatim** into v0.5 (`escalation-scan-v0.5.py:53`) rather than derived/adjusted from classifier output.
- `docs/reports/T-1727-v0-5-disagreement-rate.md:84-90` lists "manual triage to estimate true precision/recall" and a "confidence threshold experiment" as **unshipped v1 follow-up work** — direct confirmation that no auto-tuning loop has been built yet.
- Suppression does exist for `static_scan.py` findings via `lib/reviewer/overrides.py` (T-1443): `fw reviewer override add` writes a TTL'd waiver (`DEFAULT_TTL_DAYS=90`, `overrides.py:24`) to `.context/working/reviewer-overrides.yaml`, read back by `static_scan.py` at scan time. This is a **manually human-invoked** suppression list (via `override_cli.py`'s `add`/`prune`/`remove` subcommands) — not something the classifier writes automatically. It is the closest thing to a "feedback mechanism" in the repo, but the loop is human-in-the-middle, not classifier-driven.

**Gap:** the two classifier concepts (line-safety categorizer vs. LLM FP/TP triage) live in similarly-named files across two different subsystems (`lib/reviewer/` vs `tools/escalation-scan-v0.5.py`), which is a moderate discoverability risk for future agents searching for "the classifier."

## Q2 — Metrics or analytics on false-positive rates?

**Answer: Yes, but as a one-off manual report, not a live/automated metric.**

- `docs/reports/T-1727-v0-5-disagreement-rate.md:15-20` computes a "disagreement rate" = `(false_positive + defer) / total` = 64.7% (110/170), with a confidence-distribution table (lines 47-51).
- `docs/reports/T-1549-escalation-scan-v0.md:79` states a design target ("Recall ≥ 70%") but this is aspirational prose in a report, not code that computes/logs recall continuously.
- `lib/reviewer/audit.py`'s `run_pass_b` (Layer 3 daily re-scan) tallies `totals` (PASS/CONCERN/FAIL), `pattern_fire_counts`, and `suppressed_fire_counts` (`audit.py:58-116`) — no precision/recall/confusion-matrix math anywhere in `lib/reviewer/`.
- `static_scan.py` itself contains code comments citing one-time manual corpus walks as detector-threshold justification (e.g. "Corpus walk hit 4/5 false-positives" at `static_scan.py:1119`; "2119-file walk found 4 false-positives at that threshold" at `static_scan.py:1450`) — these are frozen, one-time calibration notes, not a running FP-rate metric.
- No dashboard for classifier/detector accuracy exists in `web/blueprints/metrics.py` or elsewhere.

**Gap:** FP-rate is measured only via ad hoc, non-repeating manual corpus walks captured as comments/reports — there is no automated job that re-measures FP rate over time as new tasks accumulate.

## Q3 — Review process for `defer`/`real_symptom_fix` verdicts?

**Answer: Yes for surfacing, no for action.**

- Verdicts are defined at `tools/escalation-scan-v0.5.py:243` (`real_symptom_fix`, `false_positive`, `defer`), written to `.context/working/escalation-drift-LATEST-v0.5.yaml`, and best-effort backprop'd per-candidate to `.context/dispatch-outcomes.jsonl` (`escalation-scan-v0.5.py:471-479, 496-504`).
- Surfaced read-only at Watchtower route `/escalation-drift` (`web/blueprints/escalation.py:75`, `escalation_drift()`), rendered in `web/templates/escalation_drift.html`: a "Triage (v0.5)" per-task column (lines 105-126) and a summary panel (`data-testid="escalation-v05-panel"`, lines 139-186) with counts per verdict plus combined `ERROR`+`PARSE-FAIL`.
- **No actionable review queue exists for these verdicts** — no approve/reject/promote actions tied to `real_symptom_fix`/`false_positive`/`defer` were found (contrast with the unrelated `cockpit.py` `/api/scan/approve|defer|apply` routes, which belong to a different recommendation subsystem entirely).
- `docs/reports/T-1727-v0-5-disagreement-rate.md:82` is explicit: "Per-call accuracy unmeasured… should NOT be treated as ground truth (e.g. don't auto-close tasks based on `false_positive`)" — the framework's own documentation says no automated downstream action should be taken on these verdicts yet.

**Adjacent but distinct concept:** `defer` also appears as an *inception Recommendation* value (unrelated — CLAUDE.md's "DEFER for evidence gaps not confidence gaps" rule, `docs/reports/T-2144-defer-as-hedge-rca.md`, `static_scan.py:1378` `detect_defer_as_hedge`). Do not conflate the escalation-scan `defer` verdict with the inception-Recommendation `DEFER` value — they are different fields in different workflows.

## Q4 — How are ERROR verdicts handled?

**Answer: Surfaced and logged in each subsystem; never silently swallowed, though one UI rollup merges ERROR with PARSE-FAIL.**

- **Pass-B corpus reverify** (`lib/reviewer/reverify.py`): `LineResult.status` can be `"ERROR"` on `subprocess.TimeoutExpired` (lines 235-245) or any other exception (246-255), capturing `stderr_tail`. `audit.py::run_pass_b_reverify` counts `n_error` per task (`audit.py:328`) and rolls an overall `totals["ERROR"]` if `reverify_task()` itself raises (`audit.py:320-324`). Printed in the CLI summary (`audit.py:435, 442`) and **gates the exit code**: `return 0 if (t["FAIL"]==0 and t["ERROR"]==0) else 1` (`audit.py:446`). Persisted to `.context/audits/reviewer/YYYY-MM-DD-pass-b.yaml`.
- **Escalation-scan v0.5**: verdict `"ERROR"` on missing task body (`escalation-scan-v0.5.py:411-418`), resolver failure (433-441), or LLM call failure (461-480). Each is best-effort backprop'd via `outcome.backprop_outcome(..., "verdict": "ERROR", ...)` (471-479), counted in the run summary (`"errors": errors`, line 516), and surfaced in the Watchtower panel — but **merged with PARSE-FAIL** in the rollup (`escalation_drift.html:176`: `by_verdict.get('ERROR',0) + by_verdict.get('PARSE-FAIL',0)`), so the two failure classes aren't independently distinguishable from that one summary number.
- **`static_scan.py` CLI-level errors** (catalogue-not-found, task-not-found) print to stderr with nonzero exit codes 3/4 (`static_scan.py:2466-2472`); catalogue load failure in `audit.py` returns exit 3 (`audit.py:450-452`). Per-task exceptions during the Pass-B corpus re-run are caught and appended to an `errors` list in the output YAML (`audit.py:70-72`) but **not counted in `totals`** — a task that errors during the scan is invisible in the PASS/CONCERN/FAIL tally unless someone opens the raw YAML. The CLI does print `Errors: N (see YAML)` (`audit.py:469`) so it isn't silent, but it's a soft gap: no retry, no alert beyond that one line.

## Q5 — Watchtower pages for escalation/triage/scan results

Confirmed routes + templates:

| Route | Blueprint:line | Template | Shows |
|---|---|---|---|
| `/reviewer/audit` | `web/blueprints/reviewer.py:83` (`reviewer_audit()`) | `reviewer_audit.html` | Latest Pass-A + Pass-B corpus YAML |
| `/reviewer/overrides` | `web/blueprints/reviewer.py:101` (`reviewer_overrides()`) | `reviewer_overrides.html` | Active/expired TTL'd overrides + feedback-stream event tail |
| `/escalation-drift` | `web/blueprints/escalation.py:75` (`escalation_drift()`) | `escalation_drift.html` | H1/H2/H3 heuristic flags + v0.5 LLM triage table/panel (verdict counts) |
| `/review/<task_id>` | `web/blueprints/review.py:131` | — | Human-facing per-task AC review (distinct subsystem, per its own docstring at `reviewer.py:6-7`) |

**Gap:** no dedicated page renders Layer-1 `static_scan.py` escalation-pattern fire counts (`escalation_fire_counts` in `audit.py:114`) — those are printed to CLI only (`audit.py:467-468`) and stored in the daily YAML, with no blueprint/template surfacing them.

---

## Historical context (task/report lineage)

- **`static_scan.py` + overrides origin:** T-1443 (independent reviewer agent), `docs/reports/T-1443-independent-reviewer-agent.md`.
- **Pass A/B + verification-line classifier (the *other* "classifier"):** T-1482, T-1483, T-1484, T-1485, T-1486.
- **Escalation-scan lineage (the actual FP/TP triage classifier):** T-1548 (RCA), T-1549 (`escalation-scan-v0.md`), T-1726/T-1727 (v0.5 LLM augmentation + disagreement-rate report), T-1748 (PARSE-FAIL parser hardening), T-1767 (cron deploy gap fix).
- **Unrelated `defer` concept (inception Recommendation hedge):** T-2144 (RCA), T-2145 (static-scan `detect_defer_as_hedge` rail) — do not conflate with escalation-scan's `defer` verdict.
- **`[REVIEWER]` AC-prefix conversion rule:** T-1811, CLAUDE.md "REVIEWER conversion rule."

## Conclusion / open questions for follow-up

1. No structural mechanism currently closes the loop from classifier verdict → detector rule change for either classifier system. If auto-tuning is desired, `docs/reports/T-1727-v0-5-disagreement-rate.md`'s "v1 follow-up" section (confidence threshold experiment) is the closest existing design intent to build from.
2. FP-rate tracking is a one-time report artifact, not a recurring metric — a periodic (e.g. weekly cron) re-run of the disagreement-rate calc against a growing corpus would close this gap without much new infrastructure (the pieces — `escalation-scan-v0.5.py`, `dispatch-outcomes.jsonl` backprop — already exist).
3. The `real_symptom_fix`/`false_positive`/`defer` verdicts are explicitly documented as **not** trustworthy enough for automated action (`T-1727` line 82) — any future feedback loop should treat them as advisory signal requiring human confirmation before altering scanner behavior, consistent with the framework's Authority Model (Agent = Initiative, not Authority).
4. Consider merging or cross-linking the two "classifier" naming collisions (`lib/reviewer/classifier.py` vs `tools/escalation-scan-v0.5.py`) in documentation to reduce future agent confusion when searching for "the classifier."
