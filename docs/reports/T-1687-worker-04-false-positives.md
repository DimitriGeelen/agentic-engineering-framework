# T-1687 Worker-04 — Escalation Scanner: False-Positive Characteristics & Filtering Strategy

**Scope:** `tools/escalation-scan-v0.py` (heuristic Layer B v0, T-1549/T-1555) and
`tools/escalation-scan-v0.5.py` (LLM-augmentation layer, T-1727/T-1748), the
`escalation-triage` prompt, and their test coverage.

## 1. Pre-LLM filters (v0 heuristic, before any triage call)

v0's `H1` heuristic (`tools/escalation-scan-v0.py`) is the sole gate that decides
whether a completed task becomes an escalation-scan *candidate* at all. Three
filters run before a task is ever considered for LLM triage:

1. **`workflow_type` exclusion** (`is_bug_class`, line 54-63) — tasks with
   `workflow_type` in `{inception, specification, design}` are hard-excluded from
   bug-class classification regardless of title wording. This prevents e.g. an
   inception task titled "investigate crash root cause" from being misread as a
   bug-fix.
2. **Bug-class inclusion test** — a task only becomes a candidate if it either
   (a) has a tag matching `BUG_TAG_RE` (`bug|bugfix|hotfix|rca|incident`), or
   (b) (after surviving filter 1) has a title matching `BUG_TITLE_RE`
   (`fix|bug|rca|broken|crash|error|regression|fail|hotfix`). Non-bug-class tasks
   never reach H1.
3. **RCA-presence check** (`has_rca`, line 66-77) — a task is only flagged
   (H1) if it does **not** have a real `## RCA`/`## Root Cause`/`## Why This
   Happened` section. "Real" is defined narrowly: after stripping HTML comments
   (`<!--.*?-->`), at least one of the first 5 non-blank, non-`#` lines must
   exceed 30 characters. This is designed specifically to reject the
   boilerplate placeholder comment (`<!-- REQUIRED for bug-class tasks ... -->`)
   that the RCA-gate template inserts — an empty/templated RCA section does
   **not** count as having an RCA, so the task still gets flagged (correctly,
   per the scanner's own design intent).

v0.5 (`escalation-scan-v0.5.py`) re-implements the identical `_is_bug_class` /
`_has_rca` logic (lines 96-114) rather than trusting v0's output, specifically
because v0's `recent_sample` field only carries 10 tasks while v0.5 needs full
30-day coverage (~170-340 candidates) to compute a meaningful disagreement
rate. No additional structural filter is added at this layer — v0.5's
job is to catch what v0's regex-only heuristic gets *wrong*, not to filter
further before dispatch. Only two mechanical guards exist beyond the shared
heuristic: an **idempotency window** (`IDEMPOTENCY_DAYS=7`, skips candidates
with a recent verdict already recorded) and a **date cutoff**
(`--window-days`, default 30, via `_parse_finished`).

## 2. Candidate body truncation

`CANDIDATE_BODY_TRUNCATE = 6000` characters (`escalation-scan-v0.5.py:68`).
When a candidate's body (frontmatter stripped) exceeds this, it is cut and
suffixed with `\n\n[...body truncated for triage prompt...]` (lines 184-186,
398-401). The stated rationale in the same line is token economy: **"keeps
prompts under ~8K tokens."** At roughly 4 chars/token, 6000 chars ≈ 1500
tokens for the body alone, leaving headroom for the rest of the
`escalation-triage.md` prompt template (frontmatter fields, calibration
examples, instructions) within an ~8K token budget — sized for the local
`hermes3:8b` model dispatched via litellm/ollama-loop, not a large
context-window model.

## 3. Candidate volume in a 30-day window

From the two available runs:

- **v0's own `.context/working/escalation-drift-LATEST.yaml`** (current, corpus
  2157 tasks): `h1_flagged: 340` total (76% of 444 bug-class tasks), but
  `recent_30d_flagged: 5` — v0's `recent_flagged` list is filtered to
  `date_finished`/`last_update` within the last 30 days, which is much
  narrower than the full H1 flag count (most H1 flags are old backlog, not
  recent).
- **v0.5's ground-truth 30-day disagreement-rate report** (`T-1727-v0-5-disagreement-rate.md`,
  run 2026-05-05, corpus smaller at that date): v0.5's independent
  `collect_candidates(30)` walk (which re-derives H1 from scratch rather than
  reading v0's narrow `recent_sample`) produced **170 candidates** in a
  30-day window — this is the authoritative "how many candidates get flagged
  in 30 days" figure, since it's a full re-walk of `completed/` rather than a
  capped top-10 sample.

So: **~170 candidates/30-day window** is the representative figure (current
live LATEST-v0.5.yaml run shows only 5 dispatched because idempotency skipped
the rest — `skipped_idempotent: 5`, `dispatched: 0` — meaning those 5 already
had fresh verdicts within the 7-day idempotency window from a prior run).

## 4. Escalation-drift-LATEST files (read directly)

**`.context/working/escalation-drift-LATEST.yaml`** (v0, generated
2026-07-01T03:23:02Z): corpus_total 2157, bug_class_total 444 (20%),
h1_flagged 340 (76% of bug-class), h2_repeat_patterns 117, h3_flagged 265
(59%), recent_30d_flagged 5.

**`.context/working/escalation-drift-LATEST-v0.5.yaml`** (generated
2026-07-01T03:33:02Z, window_days 30): dispatched 0, skipped_idempotent 5,
errors 0. Of the 5 idempotent-cached candidates: 2 `real_symptom_fix`
(T-2300, T-2398, confidence 0.9/0.95), 2 `false_positive` (T-2351, T-2379,
confidence 0.95 each), 1 `ERROR` (T-101 — Ollama connection refused to
`192.168.10.107:11434`, an infra/network failure unrelated to triage logic).
Notably 2/5 in this micro-sample were false positives caught by the LLM layer
— both because the title contained "fix" but the body showed doc/refactor
work with no actual code change, matching the dominant FP pattern documented
below.

## 5. False-positive rate and examples (ground truth, T-1727 report)

The authoritative FP measurement is in `docs/reports/T-1727-v0-5-disagreement-rate.md`
(30-day backlog, 170 heuristic-flagged candidates, all dispatched through
`escalation-triage`):

| Verdict | n | % |
|---|---|---|
| `real_symptom_fix` (agrees with heuristic) | 50 | 29.4% |
| `false_positive` (LLM disagrees) | 110 | 64.7% |
| `defer` | 0 | 0% |
| `PARSE-FAIL` | 10 | 5.9% |

**Disagreement rate 64.7%** — roughly two-thirds of v0's regex-only H1 flags
are not real symptom-fix-discipline failures. This vastly exceeded the 10%
promotion threshold, confirming the LLM layer as a necessary precision filter
on top of the cheap regex heuristic, not a redundant second check.

Worked FP example from the report: `T-1014` "Fix Playwright navigation test
timeout — batch contention" — the heuristic's `BUG_TITLE_RE` matched the word
"Fix" in the title, but the LLM correctly identified the body as a test
refactor (batch-size tuning), not a bug response (verdict `false_positive`,
confidence 0.95).

The `escalation-triage.md` prompt itself (`prompts/escalation-triage.md`,
lines 85-96) encodes four canonical FP patterns as calibration examples for
the LLM classifier:
1. Title contains "fix" but `workflow_type=refactor` and no bug fix involved.
2. "fix typo in README" — one-character change, nothing structural to RCA.
3. Title says "hotfix" but the RCA exists out-of-line in
   `docs/reports/T-XXX-rca-*.md` rather than inline (v0's blind spot — it
   only scans task body, not artifact files).
4. "fw upgrade error path improvement" — a defensive-coding feature where
   "error" refers to the code path being hardened, not a bug being fixed.

Confidence is uniformly high on both sides of the verdict split (mean 0.94 for
`false_positive`, 0.92 for `real_symptom_fix`), so confidence alone cannot be
used to separate signal from noise — the report explicitly flags per-call
accuracy as unmeasured against ground truth (L-355 caps 7-8B local models at
76-79% accuracy on this task class), meaning the *aggregate* disagreement
rate is treated as robust while individual verdicts are advisory only, not
auto-actionable.

## 6. Parser-level false positives (structural, not classification)

Separately from triage-verdict FPs, `tests/unit/test_escalation_v05_parser.py`
pins a second false-positive class: **verdict-word leakage**. The parser
(`parse_verdict_envelope` / `_regex_fallback`, `escalation-scan-v0.5.py:243-335`)
constrains the extracted verdict to the fixed set
`{real_symptom_fix, false_positive, defer}` on *both* the strict-YAML path and
the regex-fallback path, specifically to prevent an invalid word (e.g.
`verdict: maybe`) or a verdict-shaped word merely *mentioned inside the
rationale prose* (e.g. `rationale: "This task involves a real_symptom_fix
concept"`) from being misread as an actual verdict. Tests
`test_invalid_verdict_word_returns_empty_via_regex`,
`test_invalid_verdict_word_in_yaml_returns_empty`, and
`test_verdict_word_inside_rationale_does_not_leak` pin this. This class of FP
was created by T-1748 to close a 5.9% PARSE-FAIL rate (10/170) discovered in
the original T-1727 run, by adding a regex fallback for sloppy LLM output
(unquoted colons, missing closing fences, no fence at all) while keeping the
verdict-word gate strict enough not to introduce new false verdicts.
