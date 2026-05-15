# T-1745 — RCA: Watchtower inception-decide silent failure on bold-emphasized recommendation

**Filed:** 2026-05-05
**Trigger:** Human attempted to record GO on T-1744 via `http://192.168.10.107:3002/inception/T-1744`. Form submitted four times across 2h+; zero recorded. No UI feedback indicated failure.
**Severity:** arc-blocking — the human's primary decision-recording channel is broken.
**Arc:** orchestrator-rethink (T-1744 promotion-decision is currently un-recordable).

## Symptom

POST `/inception/T-1744/decide` returns HTTP 200, page reloads, no error/warning banner. Decision is not persisted to `## Decision` section. Repeat attempts produce identical silent no-op.

## What we know from the log

`grep "inception decide T-1744" .context/working/watchtower.log` — four attempts at `12:48:09`, `13:33:25`, `14:02:20`, `14:55:07`. Every one:

```
inception decide T-1744 failed:
  primary_landed=True
  stdout=''
  stderr='ERROR: ## Recommendation section required before decision

The task file must contain a ## Recommendation section with a non-commented:
  **Recommendation:** GO / NO-GO / DEFER
  **Rationale:** Why (cite evidence)
  **Evidence:** Bullet list of findings'
192.168.10.107 - - [...] "POST /inception/T-1744/decide HTTP/1.1" 200 -
```

Three independent bugs compound here.

## RC1 — Validator regex too strict on inner emphasis

**Where:** `lib/task-audit.sh:154` — `audit_inception_recommendation`

```bash
if printf '%s\n' "$stripped" | grep -qE \
  '^[[:space:]]*[-*]?[[:space:]]*\*\*Recommendation:\*\*[[:space:]]*[A-Za-z]'; then
    return 0
fi
return 1
```

The regex requires `[A-Za-z]` (a letter) immediately after `**Recommendation:**` and optional whitespace. T-1744's body, line 105:

```markdown
**Recommendation:** **GO** — promote T-1727 (escalation-scan v0.5 build) ...
```

After the prefix and space, the next character is `*` — the opening of inner emphasis around `GO`. The character class `[A-Za-z]` rejects `*`, so the gate returns `1` even though the section is substantively complete.

**Why structurally allowed:**
- The validator was hardened over time (T-1497, T-1510, T-1528) for various comment-leak edge cases. Each fix targeted one variant. Inner emphasis on the verdict was never a tested case.
- The previous session flagged the exact same regex weakness in `lib/inception_recommendation.sh::has_real_recommendation` as a "C-006 cosmetic false positive" on T-1744. Two parsers, same bug, fix to one wouldn't help the other.

**Markdown rendering ships emphasis as a feature.** Templates and example outputs throughout the codebase use `**Recommendation:** GO` *and* `**Recommendation:** **GO**` interchangeably for emphasis. The validator picked one form arbitrarily; the writer picked another. Drift was inevitable.

## RC2 — `primary_landed` false positive on placeholder comment text

**Where:** `web/blueprints/inception.py:555-581` — `_decision_recorded_in_task`

```python
m = _re.search(r"^## Decision\b.*?(?=^#{2,} |\Z)",
               body, _re.MULTILINE | _re.DOTALL)
if m and decision.upper() in m.group(0).upper():
    return True
```

The function captures the `## Decision` section body and checks whether the chosen decision word ("GO" / "NO-GO" / "DEFER") appears anywhere in it.

T-1744's `## Decision` section, before any decision is recorded:

```markdown
## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->
```

The placeholder comment contains the literal string `go|no-go`. After `.upper()`, that becomes `GO|NO-GO`. The substring check `"GO" in "...GO|NO-GO..."` returns True. **`primary_landed=True` is reported even though the decision was never recorded.**

The handler at `web/blueprints/inception.py:544-548` then routes the response:

```python
if not ok:
    if primary_landed:
        warn = (stderr or stdout or "side-effect warning")[:300]
        return redirect(url_for("inception.inception_detail",
                                task_id=task_id, warning=warn))
    err = ...
    return redirect(url_for("inception.inception_detail",
                            task_id=task_id, error=err))
```

Because `primary_landed=True`, the handler routes through `?warning=` instead of `?error=`. The user is told (silently) that the primary decision succeeded and only a side-effect warning occurred.

## RC3 — Template renders `?error=` but not `?warning=`

**Where:** `web/templates/inception_detail.html:384-393`

```jinja
{% if request.args.get('error') %}
<div role="alert" style="...">
    <strong>Decision NOT recorded.</strong>
    <code>{{ request.args.get('error') }}</code>
    ...
</div>
{% endif %}
```

The template only conditionally renders for `?error=`. There is no corresponding block for `?warning=`. So when RC2 routes the failure as a warning, **nothing is rendered**. The user sees the page reload to the same state with no feedback.

T-1454 (OBS-017) added the `?error=` banner specifically because "the user sees a silent redirect and clicks GO repeatedly" — and the comment names that exact failure mode. The fix landed for the error path; the warning path was added later (T-1470) and never got the matching template support.

## Combined effect

| Stage | Should happen | What happened |
|-------|---------------|---------------|
| User clicks GO | Validator passes | Validator rejects (RC1) |
| CLI exits non-zero | Handler routes via `?error=` | Handler routes via `?warning=` (RC2) |
| Browser loads page | Banner shows the error | Template ignores `?warning=` (RC3) |
| User sees | "Decision NOT recorded" red banner | Nothing — looks like success |

**Three independent failures aligned to produce a maximum-damage silent no-op.** Removing any one would have surfaced the problem: a stricter handler would 500, a comment-stripped check would route to `?error=`, a warning-rendering template would have shown the user *something*. None of those conditions held.

## Structural mitigations

Each RC needs its own fix; the meta-mitigation is consolidation + cross-cutting test.

### M1 — Loosen the validator regex (RC1 fix)

`lib/task-audit.sh:154` — change the regex to accept emphasis on the verdict:

```bash
# Before:
'^[[:space:]]*[-*]?[[:space:]]*\*\*Recommendation:\*\*[[:space:]]*[A-Za-z]'

# After (accept optional emphasis around verdict):
'^[[:space:]]*[-*]?[[:space:]]*\*\*Recommendation:\*\*[[:space:]]*\*{0,2}[A-Za-z]'
```

Or, more semantically: parse the verdict token specifically:

```bash
'^[[:space:]]*[-*]?[[:space:]]*\*\*Recommendation:\*\*[[:space:]]*\**[[:space:]]*(GO|NO-GO|DEFER)'
```

The same fix should apply to `lib/inception_recommendation.sh:39` so the C-006 audit detector and the decision-gate stay aligned.

### M2 — Strip HTML comments in `_decision_recorded_in_task` (RC2 fix)

`web/blueprints/inception.py:555` — re-use the comment-strip pattern that already lives in `audit_inception_recommendation`:

```python
section_body = m.group(0)
# Strip HTML comments before scanning for the verdict
section_body = _re.sub(r'<!--.*?-->', '', section_body, flags=_re.DOTALL)
# Look for a non-commented Decision: <verdict> line specifically
if _re.search(r'\*\*Decision\*\*:\s*\**(GO|NO-GO|DEFER)\**',
              section_body, _re.IGNORECASE):
    if decision.upper() in section_body.upper():
        return True
```

The two-step check (strip comments, then look for the canonical line, then verify the verdict word) eliminates the false positive without requiring a brittle pattern.

### M3 — Render `?warning=` in the template (RC3 fix)

`web/templates/inception_detail.html:393` — add a yellow warning banner after the red error block:

```jinja
{% if request.args.get('warning') %}
<div role="alert" style="background: #fef3c7; border: 1px solid #f59e0b; ...">
    <strong>Decision recorded with warning.</strong>
    <code>{{ request.args.get('warning') }}</code>
    <p>The primary decision landed but a side-effect failed. Check the task before continuing.</p>
</div>
{% endif %}
```

Even if RC2 stops misclassifying, real warning paths (genuine side-effect failures after a real decision) deserve UI feedback.

### M4 — Pin tests across the three parsers

Add an end-to-end fixture-driven test at `tests/integration/test_inception_decide_form.py` that:

1. Creates a fixture inception task with `**Recommendation:** **GO**` (inner emphasis).
2. POSTs the decision form with `decision=go&rationale=fixture`.
3. Asserts response is `302` (redirect) AND on follow-up GET, **either** the decision is in `## Decision` section **or** the `?error=` banner is rendered.
4. Repeat with: bare verdict, single-emphasis `*GO*`, bulleted form, bold prefix `***Recommendation***`.

This pins **all three RCs simultaneously**: the validator must pass, the handler must classify correctly, and the template must surface the result. No single-layer test would have caught this triple-failure.

### M5 — Consolidate the three "is the decision present" parsers

Three places parse the same shape with diverging regexes:

| Location | Function | Purpose |
|----------|----------|---------|
| `lib/task-audit.sh:117` | `audit_inception_recommendation` | Decision-gate (blocks `fw inception decide`) |
| `lib/inception_recommendation.sh:23` | `has_real_recommendation` | Audit detector C-006 |
| `web/blueprints/inception.py:555` | `_decision_recorded_in_task` | Watchtower primary-landed check |

Each has slightly different rules and edge-case handling. Drift between them caused this incident. Either:

- Consolidate to a single canonical parser (Python helper imported from web/, shelled out to from bash via `python3 -m fw.inception.parse`), OR
- Pin all three with the **same fixture corpus** as part of M4. If the parsers must stay separate, they must agree on every fixture.

This is the L-356 lesson generalised: detector parsers diverge over time. Without a shared corpus, the next variant ships broken.

## Why this happened (escalation, per G-019)

**Symptom-level fix temptation:** "The validator regex is too strict — loosen it." That fixes RC1 alone. The user's test would still fail because RC2+RC3 would now produce a false-success path (decision still not recorded, but `primary_landed` reports True off the comment, and template ignores warning).

**Why the framework was blind for hours:** The user submitted GO at 12:48; we noticed the bug at ~14:55 only because the user explicitly told us. The post-fix audit showed nothing wrong — `fw audit` PASS. The watchtower.log silently captured "inception decide T-1744 failed" at INFO level (Python logging.error), but no monitor scanned the log for it. **The framework has no liveness check on "Watchtower decisions actually persist."**

This belongs in concerns.yaml as a **G-067** candidate: silent-failure on the human's primary control surface is a worse blind spot than the substrate-blindness pattern G-064 captures. The cron monitor surfaces work that ran; nothing surfaces work that *should have run* but didn't.

## Recommendation

**GO** — fix is bounded, scoped, and arc-blocking. Three small surgical edits (one regex, one comment strip, one template block) plus one cross-cutting integration test. ~50 lines of code. Mitigates RC1+RC2+RC3 simultaneously.

**Build task to file on GO:** T-1746 — three-RC fix + integration test pin.

**Concern to register:** G-067 — Watchtower silently swallows decision-form failures (human primary control surface has no liveness check).

## Evidence

- `.context/working/watchtower.log` lines 19, 110, 187, 264 — four `inception decide T-1744 failed: primary_landed=True` entries
- `.tasks/active/T-1744-spike-d-off-ramp-pick-a-different-g-064-.md:105` — `**Recommendation:** **GO**` body
- `lib/task-audit.sh:154` — failing regex
- `web/blueprints/inception.py:578` — false-positive primary_landed regex
- `web/templates/inception_detail.html:384` — error-only banner block
- `lib/inception_recommendation.sh:39` — sibling regex with same weakness
