# T-1111 — Empty Placeholder Sections in Inception Task Files: RCA + Mitigation

**Status:** Captured 2026-04-11 after the human caught empty `## Go/No-Go Criteria` sections in T-1105/T-1106/T-1107/T-1109 during the Watchtower review flow. This is a repeat of the T-1108/G-036 class but at a different section level.

---

## Observable symptoms

1. **2026-04-11 session (this session):** Main agent populated `## Recommendation` sections for T-1107 and T-1109, believed the review-flow story was complete. Human ran `fw inception decide T-1110`, hit the T-973 review-marker gate, then navigated to the Watchtower review pages and found **literal `[Criterion 1]` / `[Criterion 2]` placeholder text** in the `## Go/No-Go Criteria` sections of T-1105, T-1106, T-1107, and T-1109. Human pasted the placeholder text to the agent and said nothing else.

2. **Prior session:** Same class of bug caught for the `## Recommendation` section of T-1105 (T-012 commit `e308456e`). Agent populated it after human complaint.

3. **Prior session:** T-1108 / G-036 fixed the Watchtower template allowlist for the `## Structural Upgrade` section. The fix rendered the section but did not constrain the *content* — an empty section is still "rendered" with empty content.

4. **The class:** Inception task template (`zzz-default.md` or equivalent) ships with placeholder text ("REQUIRED before fw inception decide", "[Criterion 1]", "[Criterion 2]", etc.). Agents create tasks from the template and fill in *some* sections but skip others. The skipped sections reach the human review flow looking either (a) empty (templates with HTML comments) or (b) worse — filled with literal placeholder text that renders as legitimate content.

## Why the existing controls don't catch this

**C-001 (research artifact first):** enforces that a research artifact exists in `docs/reports/T-XXX-*.md` before inception commits. Does not check any section inside the task file itself.

**T-973 review-marker gate (`fw task review` before `fw inception decide`):** ensures the human *looks* at the review page, but does not inspect its contents. The gate trips only if the human never clicked review — it cannot tell the human "review skipped because all sections are placeholder."

**T-1108 / G-036:** fixed section **rendering** (Structural Upgrade section was invisible in Watchtower). Did not address section **emptiness** — the Recommendation section has always rendered, but it rendered empty boilerplate when unfilled.

**G-018 (silent quality decay):** registered as a known gap — "No structural guard against silent quality decay in generated artifacts". This is exactly the class of failure this task addresses. G-018 is high severity and has been watching for weeks. This RCA + fix will consume it.

**P-010 acceptance criteria gate:** runs on `fw task update --status work-completed`. Does not run on `fw inception decide`. Does not inspect Go/No-Go content.

**P-011 verification gate:** same as P-010 — not wired into `fw inception decide`.

## Hypotheses to test

| H | Description | Initial evidence |
|---|---|---|
| H1 | Placeholders render identically to real content; agent and human both overlook them | STRONGLY SUPPORTED — this session, agent missed Go/No-Go after populating Recommendation; previous session missed Recommendation after populating Structural Upgrade |
| H2 | Template design encourages skipping ("optional" feels like "omittable") | SUPPORTED — HTML comments like `<!-- REQUIRED before fw inception decide. Write your recommendation here -->` use the word REQUIRED but the comment itself is stripped from Watchtower rendering |
| H3 | No gate runs at decision time to inspect section content | CONFIRMED by code reading — `lib/inception.sh:decide()` checks review marker, not task file content |
| H4 | Agent's post-work verification relies on "does the commit pass hooks" rather than "does the artifact look complete" | SUPPORTED — this session's commits passed C-001 and T-973 but still contained placeholder sections |
| H5 | Watchtower rendering does not visually flag placeholder text | CONFIRMED — Markdown→HTML for `[Criterion 1]` renders as `[Criterion 1]` literal text, indistinguishable from user-authored content |
| H6 | `fw task review` command does not perform content audit before creating the review marker | CONFIRMED by code reading — command emits URL + QR + marker, no content inspection |

## Chokepoint candidates (structural fix)

### C1 — Decision-time content gate (RECOMMENDED)
`fw inception decide` pre-flight inspects the task file for unfilled placeholder patterns:
- Literal `[Criterion N]` strings
- `REQUIRED before fw inception decide` stubs
- `[TODO]`, `[PLACEHOLDER]`, `<!-- ... -->` comments in rendered sections
- Empty sections that are non-optional for inception workflow

If any found, block with a clear error listing each offending section + line.

### C2 — `fw task review` pre-render lint
When `fw task review` runs, it audits the task file for the same patterns *before* emitting the URL and creating the review marker. If any placeholder sections exist, the command fails with a human-readable diff saying "these sections still contain boilerplate — fix before review."

### C3 — Watchtower renders placeholders as red warnings
Instead of hiding them, Watchtower's inception page detects literal placeholder strings and renders them as loud red warning blocks ("⚠️ PLACEHOLDER CONTENT — THIS SECTION WAS NEVER FILLED IN"). Human can still proceed but the warning is unmissable.

### C4 — Template redesign with mandatory-section manifest
The task template grows a `## Sections Manifest` comment at the top listing which sections are REQUIRED vs OPTIONAL for each workflow type. `fw task update --status work-completed` and `fw inception decide` both consult the manifest to decide what to enforce.

## Proposed approach

**Combine C1 + C2** for defense-in-depth:
- C2 runs at `fw task review` time — catches the problem before the human even sees the review page, preventing wasted cognitive effort
- C1 runs at `fw inception decide` time — catches the problem if someone bypassed `fw task review` (--force) or if the task was edited between review and decide

C3 is user-visible reinforcement but alone is not enough — relies on human attention, which has already failed twice in two consecutive sessions.

C4 is the most structural but requires schema work and is harder to validate.

## Invariant tests

1. **`tests/integration/inception-decide-blocks-placeholders.bats`** — create a task file with `[Criterion 1]` in Go/No-Go, run `fw inception decide T-XXX go --rationale "test"`, assert exit != 0 and error message cites the placeholder.

2. **`tests/integration/task-review-blocks-placeholders.bats`** — same setup, run `fw task review T-XXX`, assert exit != 0 and error message cites the placeholder. Assert no review marker file created.

3. **`tests/lint/no-placeholder-literals-in-active-tasks.bats`** — grep all `.tasks/active/*.md` for `\[Criterion [0-9]+\]`, `\[TODO\]`, `\[PLACEHOLDER\]`. Fail if any match. Runs on pre-push hook.

## Scope fence

**IN:** RCA of the two same-session failures + named mitigation options + recommendation on which to implement + invariant test sketches.

**OUT:** Any actual code edits (deferred to T-1112a..c build tasks after GO). Any enforcement of the rule retroactively on existing task files (a separate sweep). Any change to the template itself (OPTIONAL — if C1+C2 pass, the template can stay as-is).

## Dialogue log (C-001 extension)

### Segment 1 — Discovery by human
- **Human:** "Go/No-Go Criteria / GO if: / [Criterion 1] / [Criterion 2] / NO-GO if: / [Criterion 1] / [Criterion 2]"
- (pastes the literal placeholder text from the Watchtower review page — no other message)

### Segment 2 — Agent recognition
- **Agent:** Greps for `[Criterion 1]` across active tasks, finds T-1105, T-1106, T-1107, T-1109 all have placeholder Go/No-Go sections despite having populated Recommendations.
- **Agent:** Acknowledges the class — same as T-1108 (empty Structural Upgrade) and the prior-session T-1105 empty Recommendation. Third consecutive session with the same bug class.

### Segment 3 — Fix + meta-RCA capture
- **Agent:** Populates the 4 missing Go/No-Go sections.
- **Human:** "ok great when done add inception task to investigate workflow, rca and mitigation suggestion"
- **Agent:** Creates T-1111 as inception with this document as C-001 research artifact.

## Recommendation (preview — full version in task file)

**Recommendation:** GO — implement C1 + C2 + invariant test 1 + invariant test 2 as a single structural fix. This is the chokepoint+invariant-test discipline (T-1105) applied to the placeholder-bleed-through class.

Build decomposition:
- **T-1112a:** Add `_audit_placeholders()` helper in `agents/task-create/update-task.sh` that scans a task file for literal `[Criterion N]`, `[TODO]`, `[PLACEHOLDER]`, `<!-- REQUIRED before -->` patterns. Returns a list of (section, line, pattern).
- **T-1112b:** Wire `_audit_placeholders()` into `lib/inception.sh:decide()` before the review-marker check. Block with clear error + bypass via `--force` only.
- **T-1112c:** Wire `_audit_placeholders()` into `lib/review.sh:fw_task_review()` before URL emission. Block with same error.
- **T-1112d:** Write `tests/integration/inception-decide-blocks-placeholders.bats` and `tests/integration/task-review-blocks-placeholders.bats`.
- **T-1112e:** Consume G-018 (silent quality decay) — mark as resolved by T-1112.

Net LOC: ~80 added, 0 removed. 1 gap resolved. 1 recurring bug class closed.
