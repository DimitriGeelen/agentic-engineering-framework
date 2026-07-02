# T-1687 Worker 01 — Escalation Scanner Heuristic Rules

**Scope:** `tools/escalation-scan-v0.py` (T-1549) vs `tools/escalation-scan-v0.5.py` (T-1727)
**Method:** direct source read, no execution.

## 1. Exact heuristic rules for flagging a symptom-fix candidate

Both scripts walk `.tasks/completed/T-*.md` and classify each task as "bug-class"
before applying flag rules. v0.5 only implements the H1 rule (as its input
pipeline); v0 implements three:

- **H1 — Bug-class task with no `## RCA` (or equivalent) section.**
  `is_bug_class(fm, title, body)` (v0) / `_is_bug_class(fm, title)` (v0.5) returns
  True if any of:
  1. `BUG_TAG_RE` matches the frontmatter `tags` field, OR
  2. `workflow_type` is NOT in `{inception, specification, design}` AND
     `BUG_TITLE_RE` matches the task title/name.
  A task is flagged H1 if `is_bug_class(...)` is True AND `has_rca(body)` is False.

- **H2 — Learning ID referenced across ≥3 completed tasks within a 30-day window**
  (v0 only). Built from `LEARNING_REF_RE` matches inside task bodies, grouped by
  learning ID; for each ID with ≥3 referencing tasks, checks whether any 3
  chronologically-sorted `date_finished`/`last_update` timestamps fall within a
  30-day span (`dates[i+2] - dates[i] <= timedelta(days=30)`).

- **H3 — Bug-class, no RCA, AND no learning captured** (v0 only; "strongest
  signal"). Same bug-class + no-RCA gate as H1, plus `has_learning_capture(body)`
  is False (i.e. `LEARNING_REF_RE` finds no `L-NNN`/`PL-NNN`-style reference
  anywhere in the body).

v0.5 does not re-implement H2/H3 — it only re-derives the H1 candidate set
(see §4) and hands each candidate to an LLM for a richer real/false/defer
verdict.

## 2. Regexes / patterns

Identical definitions in both files (v0.5 comment explicitly calls this a
"mirror of v0 heuristic — kept here to avoid modifying v0's output contract"):

```python
BUG_TITLE_RE = re.compile(
    r"\b(fix|bug|rca|broken|crash|error|regression|fail|hotfix)\b", re.I
)
BUG_TAG_RE = re.compile(r"\b(bug|bugfix|hotfix|rca|incident)\b", re.I)
RCA_SECTION_RE = re.compile(
    r"^##+\s*(RCA|Root\s*Cause|Why\s*This\s*Happened)\b", re.I | re.M
)
```

v0 additionally defines (used only by H2/H3, not present in v0.5 at all):

```python
LEARNING_REF_RE = re.compile(r"\b([LP]L?-\d{3,4})\b")
```

**`has_rca()` / `_has_rca()` detail** (identical logic in both files): a
`RCA_SECTION_RE` match alone is not sufficient — the function also strips HTML
comments (`<!--.*?-->`) from the 800 characters following the heading, then
requires at least one of the first 5 non-blank, non-`#`-prefixed lines to be
longer than 30 characters. This guards against a bare `## RCA` heading with no
real content (or only an HTML-comment placeholder) counting as "has RCA."

`is_bug_class()` / `_is_bug_class()` short-circuits to `False` for
`workflow_type` in `{inception, specification, design}` regardless of title —
these workflow types are structurally exempt from bug-class classification
even if the title contains a trigger word like "fix."

## 3. Difference between v0 and v0.5

| Aspect | v0 (T-1549) | v0.5 (T-1727) |
|---|---|---|
| Purpose | Pure heuristic scan, read-only | Per-candidate **LLM augmentation** of v0's H1 output |
| Rules implemented | H1, H2, H3 | H1 only (re-derived independently, see §4) |
| Output | `docs/reports/T-1549-escalation-scan-v0.md` (human) + `.context/working/escalation-drift-LATEST.yaml` (machine, top-10 sample only) | `.context/working/escalation-drift-LATEST-v0.5.yaml` (full candidate list with LLM verdicts) |
| Side effects | None — pure read + report write | Dispatches one LLM call per candidate via `lib/resolver` (writes `.context/dispatches.jsonl`), back-props verdicts to `.context/dispatch-outcomes.jsonl` via `lib/outcome.backprop_outcome` |
| LLM involvement | None | Yes — POSTs each candidate's (truncated) body to litellm (`/v1/messages`, default `http://localhost:4000`, default model `claude-3-5-sonnet-hermes3`) and parses a fenced-YAML verdict envelope (`real_symptom_fix` / `false_positive` / `defer`) with a regex fallback (`_regex_fallback`) for malformed YAML output |
| Window | All completed tasks (H1/H3), 30-day window only for H2 repeat-timing and for the "recent_flagged" sample in the report | Configurable `--window-days` (default 30) applied directly to the H1-equivalent candidate collection |
| Candidate source | Scans `all_tasks` directly | Explicitly does **not** trust v0's YAML for the full candidate set — v0 only emits a top-10 `recent_sample`, so v0.5 "self-walks completed/ ... to avoid a contract dependency on v0's output" (`collect_candidates()`), reusing the same H1 rule inline. It still loads and reports v0's headline numbers (`corpus_total`, `h1_flagged`) for context. |
| Failure semantics | N/A (no external calls) | Per-candidate: LLM call failure → `verdict=ERROR`, scan continues (never modifies v0's report); non-conformant LLM output → `verdict=PARSE-FAIL` after both strict-YAML and regex-fallback parsing fail |

## 4. How v0.5 decides when to skip candidates (idempotency)

- v0.5 loads its own prior output (`load_existing_v05()` reads
  `escalation-drift-LATEST-v0.5.yaml`) and indexes prior candidate verdicts by
  `task_id` (short `T-XXX` form).
- For each newly-collected candidate, if a prior verdict exists (`prior =
  existing_by_id.get(short_id)`) **and** `--force`/`ESCALATION_V05_FORCE=1` is
  not set **and** `is_recent_enough(prior["ts"])` is True, the candidate is
  skipped: the prior verdict is carried forward unchanged into the new output
  (`out_candidates.append(prior)`) and `skipped_idempotent` is incremented — no
  new LLM call is made.
- `is_recent_enough(verdict_ts)` parses the prior verdict's ISO timestamp and
  returns True if it is within `IDEMPOTENCY_DAYS` of "now" (`datetime.now(UTC) -
  timedelta(days=IDEMPOTENCY_DAYS)` as cutoff).
- `IDEMPOTENCY_DAYS` defaults to **7**, overridable via env var
  `ESCALATION_V05_IDEMPOTENCY_DAYS`.
- Full re-dispatch bypass: `--force` CLI flag or `ESCALATION_V05_FORCE=1` env
  var forces re-triage even if a recent verdict exists.

## 5. Maximum candidates per run

- `MAX_CANDIDATES_PER_RUN` module constant defaults to **200**, sourced from
  env var `ESCALATION_V05_MAX` (`int(os.environ.get("ESCALATION_V05_MAX",
  "200"))`).
- Overridable per-invocation via `--limit` CLI flag (`default=
  MAX_CANDIDATES_PER_RUN`).
- Applied as a hard slice on the collected candidate list before the dispatch
  loop: `for entry in candidates_in[: args.limit]:` — candidates beyond the
  limit are silently not processed in that run (no explicit "N more skipped"
  log line, unlike v0's report truncation notice for its own top-25/top-10
  samples).
- v0 itself has no candidate cap — it processes the full completed-task corpus
  every run for H1/H2/H3, and only *truncates its report output* (top 25 for
  H1's `recent_flagged` sample, top 15 for H2, top 10 for the YAML
  `recent_sample`/`h2_top`).
