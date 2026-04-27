# T-1565: Approval Arc Gaps Audit

## Scope (what you read)

- `web/blueprints/approvals.py` (3 loaders + aggregator + decide/complete-batch endpoints)
- `web/blueprints/inception.py` decide endpoint (the actual write path) + `web/blueprints/review.py` per-task page + `web/blueprints/reviewer.py` overrides UI + `web/blueprints/tasks.py` `complete_task`
- `web/templates/approvals.html`, `web/templates/_approvals_content.html`
- `lib/review.sh` (`emit_review`)
- `lib/inception.sh` (`do_inception_decide`, T-1259/T-1260 enforcement, sweep)
- `bin/fw review-queue` (T-1536) and `bin/fw task review` / `fw task verify`
- `agents/task-create/update-task.sh` Recommendation gate (T-679/T-1529), RCA gate (T-1550), AC gate (P-010), partial-complete recheck path
- `lib/reviewer/{static_scan,overrides,audit,drift}.py`
- Sampled tasks: T-1448, T-1483, T-1538 (inception with Recommendation), T-1542 (bug-class captured, no Recommendation/RCA yet)
- Cross-corpus check: 13 active inceptions (2 EMPTY/MISS Recommendation), 26 partial-complete tasks (all have Recommendation — gate is working post T-1529)

## Findings

### F1 — Tier-0 auto-exec regex is dead code (HIGH)

`web/blueprints/approvals.py:454` and `:463`:

```python
return bool(re.search(r"(?:^|/|\\s)fw inception decide T-\\d+ (?:go|no-go)\\b", command_preview))
…
m = re.search(r"fw inception decide (T-\\d+) (go|no-go)", cmd_str)
…
rat_m = re.search(r'--rationale\\s+"(.*)"(?:\\s|$)', cmd_str, re.DOTALL)
```

The string is already a raw string (`r"…"`), so `\\d` / `\\s` / `\\b` survive into the regex as a literal backslash followed by `d`/`s`/`b` — they do not mean digit/whitespace/word-boundary. Verified: `_is_inception_decide("fw inception decide T-1538 go --rationale 'ok'")` returns `False`; same for any realistic preview.

Effect: the T-1192 self-consuming auto-execute path on `decide_approval` never fires. The `auto_executed` branch in the response is unreachable — humans approving via Watchtower always get the `Agent can retry` fallback, even though the code intends to run the decide for them.

Severity: HIGH (silent dead path on a structural execution surface).

Fix sketch: drop the double-escapes — `r"(?:^|/|\s)fw inception decide T-\d+ (?:go|no-go)\b"` etc. Add a unit test that pins the three sample command shapes.

### F2 — UI "Complete Task" buttons use deprecated `--force`, bypassing RCA + Recommendation gates on first transition (HIGH)

- `web/blueprints/tasks.py:676` (`/api/task/<id>/complete`)
- `web/blueprints/approvals.py:524-526` (`/api/approvals/complete-batch`)

Both invoke `fw task update T-XXX --status work-completed --force --reason "…"`. Per `agents/task-create/update-task.sh:435-443`, `--force` is documented deprecated and sets every `--skip-*` flag at once: sovereignty, AC, verification, human-ownership, **recommendation, and RCA**.

For partial-complete (already work-completed in `active/`) the recheck path at `:519-574` is benign — gates already fired on first transition. **But** the `/tasks/<id>` page also exposes "Complete Task" (`tasks.py:555-558` `can_complete`) when all ACs are checked and status ≠ work-completed. That's a *first* transition. A bug-class agent-only task (no Human ACs, all Agent ACs ticked) clicked from this page lands in `completed/` without ever firing the RCA gate (T-1550, the structural fix for G-019) or the Recommendation gate.

Severity: HIGH (silent bypass of the very gates the framework was just hardened to enforce; T-1550 spike showed 99% of bug-class tasks shipped without RCA — `--force` keeps a hole through this exact same surface).

Fix sketch: replace `--force` with the narrow flags actually justified for "human clicked from UI": `--skip-sovereignty` + (only on partial-complete recheck) `--skip-acceptance-criteria`. Never `--skip-rca` or `--skip-recommendation` — those represent unwritten artefacts, not authorization. Symmetric to F1, this is a 3-line change in two places.

### F3 — Reviewer Verdict invisible on /approvals (MEDIUM)

`lib/reviewer/static_scan.py` writes `## Reviewer Verdict (vX.Y)` into the task body with overall verdict, per-AC findings, and patterns like `mock-only-integration`, `swallowed-errors`, `output-spoofing`, `ac-verify-mismatch`, `empty-output-success`. Both inception cards (`_load_pending_go_decisions`, approvals.py:144-217) and Human-AC cards (`_load_pending_human_acs`, :222-297) extract `## Recommendation` and `## Go/No-Go Criteria` but **never** the reviewer block. `_approvals_content.html` has no reviewer rendering at all.

Effect: at the moment of human decision, the agent's self-assessment is visible; the structural-scan's findings (the only mechanical advisor in the arc) are not. The reviewer is wired into update-task.sh:665-674 to *write* findings but no surface delivers them.

Severity: MEDIUM (defeats the purpose of the reviewer agent at the highest-leverage point).

Fix sketch: extend the loaders to also extract `overall` + `len(findings)` + `needs_human` from `## Reviewer Verdict`. In `_approvals_content.html`, add a small badge next to each card: `Reviewer: 2 findings, needs_human=yes`, deep-linking to `/tasks/<id>#reviewer-verdict`. ~30 LOC.

### F4 — /approvals silently drops inceptions without substantive `## Recommendation` (MEDIUM)

`web/blueprints/approvals.py:128-130`:

```python
rec_section = _extract_section(body, "Recommendation")
if not rec_section or len(rec_section.strip()) < 20:
    continue
```

Verified gap: T-1546 (`pickup-add-get-apiidentity-to-watchtower`, inception, decision pending, no `**Recommendation:**` line) is invisible on /approvals. T-1565 (this task) the same. The skip is justified for never-explored backlog (T-1123), but a *started-work* inception that the agent began and forgot to write a recommendation for is exactly the case where the human should see "agent is stuck — write recommendation or escalate." Silent drop = blind spot, asymmetric with the partial-complete path where the Recommendation gate (T-1529) **blocks** completion under the same condition.

Severity: MEDIUM (already-known design tension; one inception currently affected, but pickup imports add more).

Fix sketch: split the filter — show inceptions in started-work without Recommendation under a "Needs agent action" subsection (the template already has the fallback rendering at `_approvals_content.html:128-148`, the loader just never emits them). Keep captured/unexplored hidden.

### F5 — `fw review-queue` excludes inception tasks pending decision (MEDIUM)

`bin/fw:3400-3402`:

```python
unchecked = len(re.findall(r"^\s*-\s*\[ \]", human_m.group(1), re.MULTILINE))
if unchecked == 0:
    continue
```

The CLI is documented as "terminal mirror of Watchtower /approvals" (T-1536, `bin/fw:3343`). But /approvals' Decisions section includes `pending_go` (inception decisions) regardless of unchecked Human ACs. `fw review-queue` only lists tasks with unchecked Human ACs, so inceptions awaiting GO/NO-GO with all (or zero) Human ACs already checked are absent from the terminal mirror — present on web, missing on CLI.

Severity: MEDIUM (asymmetry between terminal and web — same class of bug as T-1559).

Fix sketch: a second pass over active inception tasks where `_extract_decision(body) == "pending"`, surfaced under a `DECISIONS:` header before the `VERDICT` table.

### F6 — Recommendation gate fires only when Human ACs remain, leaving reviewer.needs_human tasks ungated (MEDIUM)

`agents/task-create/update-task.sh:173`:

```bash
[ "${PARTIAL_COMPLETE:-false}" = true ] || return 0
```

The Recommendation gate is keyed off "task has unchecked Human ACs at completion time". But `lib/reviewer/static_scan.py:668` also sets `needs_human=True` when `risk_declared in {high, medium}` or `human_signoff_declared == "required"` — these are independent signals. A task with `human_signoff: required` in frontmatter and no Human ACs in body completes silently with no Recommendation written. The reviewer flagged it as needing human review; the gate didn't enforce the artefact.

Severity: MEDIUM (cross-component decoupling — two systems with different definitions of "needs human").

Fix sketch: extend `check_recommendation_for_review` trigger to OR over (PARTIAL_COMPLETE, frontmatter `human_signoff: required`, frontmatter `risk: high`/`medium`, prior reviewer scan with needs_human=true). Aligns the artefact gate with the reviewer's classification.

### F7 — No cross-project aggregation of pending approvals (LOW)

Each project (framework + each consumer) runs an isolated Watchtower with its own `/approvals`. With N consumers, the operator must manually visit N+1 dashboards to know what's pending. Pending Tier-0/inception/AC items in consumer projects are invisible from the framework's Watchtower. Memory note `feedback_dispatch_project_flag.md` already calls this out for dispatch; the same blindness exists for approvals.

Severity: LOW (workflow rather than correctness; explicit operator step).

Fix sketch: out of scope here. A `/approvals?federated=1` aggregator could fan out via TermLink remote `bus read` to every registered project's `.context/approvals/` and pending task index. ~1 day of work.

### F8 — `.gate-bypass-log.yaml` has no surface (LOW)

`agents/task-create/update-task.sh:32-42` writes a YAML log every time `--skip-*` or `--force` bypasses a gate. Nothing reads it: no Watchtower page, no `fw audit` rule, no `fw doctor` warning. The log is an "audit artefact without auditor" — a structural assertion that gate bypasses are observable without anyone observing.

Severity: LOW (latent — only matters when bypasses become a bad pattern).

Fix sketch: small `/audit/bypasses` page (last 14 days, by flag, by task), or `fw audit` warns when bypass count > N/week.

### F9 — Resolved Tier-0 approvals accumulate without bound (LOW)

`web/blueprints/approvals.py:67-75` lists `resolved-*.yaml` and slices `[:20]` for display. There is no pruning anywhere — files just accumulate in `.context/approvals/`. Cosmetic for now, but `_load_resolved_approvals()` is called every /approvals refresh and globs/parses the entire history.

Severity: LOW.

Fix sketch: prune `resolved-*.yaml` older than 30 days in a daily cron or `fw audit` step.

## Synthesis (highest-leverage next moves)

1. **Bundle F1 + F2 in one PR.** Both are 5-line regression-class fixes on the structural enforcement boundary. F1 unblocks the T-1192 auto-exec the codebase clearly intended to ship; F2 closes a silent RCA/Recommendation bypass hiding behind well-named UI buttons — exactly the pattern T-1550 was just designed to prevent. Validation is cheap: unit-test `_is_inception_decide` against three sample previews; click "Complete Task" on a fresh bug-class agent task in dev and confirm the RCA gate now fires.

2. **Then land F3 (Reviewer Verdict on /approvals).** The reviewer agent is the only mechanical advisor in the arc; not surfacing its findings to /approvals defeats the v1.0–v1.5 build chain (T-1443 → T-1485). Once findings are visible at decision time, F4's "silent inception drop" becomes immediately obvious to operators (and the human-action signal sharpens), making F4/F6 cheaper to fix as a follow-up.

F5, F7, F8, F9 are nice-to-have cleanups for the next sweep, not now.
