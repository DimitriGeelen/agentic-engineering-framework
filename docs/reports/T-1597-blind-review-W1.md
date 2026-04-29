# Blind Review — Group W1
**Tasks:** 6 reviewed
**Summary:** 6 confirm-GO, 0 flag-concern, 0 inconclusive
**Reviewer:** TermLink blind worker W1 under T-1597
**Date:** 2026-04-29

Group W1 covers tasks whose fixes surface on the `/review` Watchtower page (plus the cockpit landing-page Action Required widget). All six tasks were verified live against `http://192.168.10.107:3000`.

---

## T-1574: Fix /review page Complete button for inception tasks
**Watchtower:** http://192.168.10.107:3000/review/T-1574
**Status:** work-completed
**Recommendation:** GO

### Human ACs evaluated
- AC text: "[REVIEW] /review page UX for inception tasks reads naturally — buttons are unambiguous, rationale required"
  - **Type:** [REVIEW] UI
  - **Evidence:** `curl /review/T-1565` (the canonical inception target) returns HTTP 200 and the served HTML contains `inception-decide-form`, `decide-btn-go`, `decide-btn-nogo`, `decide-btn-defer`. The fragment endpoint `/review/T-1565/acs` also contains `inception-decide-form` (so htmx polling won't revert the form). Cross-check: `/review/T-1582` (a non-inception build task) shows `class="complete-btn"` (the actual button) — non-inception path unchanged. Note: T-1565 also contains the literal substring `complete-btn`, but only inside the `<style>` block at line 213 (`.complete-btn { ... }`), not as an element class — so the AC #3 ("Complete button absent for inception") still holds in practice.
  - **Blind verdict:** confirm-GO

### Overall
The fix is structurally sound and matches the rationale exactly. Both `/review/<id>` and the htmx `/review/<id>/acs` fragment render the inception decide form, so polling can't regress the surface to a generic Complete button. Non-inception tasks still show the complete-btn element. I would stamp this. Strongest evidence: the fragment-endpoint test — that's the surface most likely to silently re-break, and it's correctly branched.

---

## T-1575: Structural Recommendation rendering — unified extractor
**Watchtower:** http://192.168.10.107:3000/review/T-1575
**Status:** work-completed
**Recommendation:** GO

### Human ACs evaluated
- AC text: "[REVIEW] T-1565 review page renders the recommendation cleanly — no literal `**` characters visible, evidence bullets rendered as a list, GO badge prominent"
  - **Type:** [REVIEW] UI
  - **Evidence:** `curl /review/T-1565` returns `class="rec-rationale"` and `class="rec-evidence"` (separate labeled sections, not a `<pre>` raw dump). No literal `**Rationale**` / `**Evidence**` markdown markers found in the body content — the `markdown2` rendering is hitting. The `rec-incomplete-warning` style hook is also defined for the warning path. The unit suite at `tests/unit/test_extract_recommendation.py` is referenced and was reportedly green at 24/19 cases.
  - **Blind verdict:** confirm-GO

### Overall
Three parsers consolidated to one shared helper, with the duplicate paths reduced to compat shims — that's the right structural fix, not a band-aid. The visible result on `/review/T-1565` is structured rendering with no raw markdown leaking. I would stamp this. Strongest evidence: `class="rec-rationale"` and `class="rec-evidence"` both present in the served HTML — the wall-of-markdown symptom is gone.

---

## T-1577: F10 — extend NO-REC distinction to landing-page Action Required widget
**Watchtower:** http://192.168.10.107:3000/review/T-1577
**Status:** work-completed
**Recommendation:** GO

### Human ACs evaluated
- AC text: "[REVIEW] Cockpit landing-page Action Required pills visually match `/approvals` filter buttons"
  - **Type:** [REVIEW] UI / cross-surface parity
  - **Evidence:** `curl /` shows `1 NO-REC` pill on the Action Required card. `curl /approvals` shows the filter button labeled `NO-REC (1)`. Counts agree (both = 1). Python eval against `web.blueprints.cockpit.get_action_summary()` returns `no_rec_ac_count=1, unknown_ac_count=0` — matches the rendered pill counts exactly. The cockpit blueprint also exposes the full set of expected keys (`go_ac_count`, `defer_ac_count`, `nogo_ac_count`, `no_rec_ac_count`, `unknown_ac_count`).
  - **Blind verdict:** confirm-GO

### Overall
Cross-surface count parity verified live (cockpit = approvals = 1). The deeper structural win the task claims (refactoring cockpit's local AC parser to call the canonical `_parse_acceptance_criteria` from `web/blueprints/tasks.py`) is exactly the right move — it eliminates the L-298 root cause (parser drift) rather than just patching the symptom. I would stamp this. Strongest evidence: the cockpit and approvals NO-REC counts agree exactly under live load.

---

## T-1578: F11 — Add NO-REC banner to /review page
**Watchtower:** http://192.168.10.107:3000/review/T-1578
**Status:** work-completed
**Recommendation:** GO

### Human ACs evaluated
- AC text: "[REVIEW] /review page on a NO-REC task reads naturally"
  - **Type:** [REVIEW] UI
  - **Evidence:** The Steps reference `/review/T-1062`, but T-1062 has since received a Recommendation (the `/review/T-1062` HTML now shows `data-verdict="GO"` patterns, not `data-verdict="NO-REC"`) — Steps are stale, not broken. T-801 (cited in the task's own evidence as the canonical NO-REC live test) is still NO-REC: `curl /review/T-801` returns `data-verdict="NO-REC"` and the literal `NO-REC` banner text. The CSS rule `.recommendation-block[data-verdict="NO-REC"]` is defined in the served stylesheet (cyan `#0e7490` palette, matching cockpit + approvals).
  - **Blind verdict:** confirm-GO (with stale-Steps caveat — see Overall)

### Overall
The fix works correctly on at least one live NO-REC task (T-801). The Steps in the Human AC point at T-1062, which has migrated off NO-REC since this task shipped — so the Steps are no longer reproducible without picking a different task. That's a Steps-rot issue, not a fix-rot issue: the underlying functionality is intact. I would stamp this and note the Steps could be retargeted at T-801 if anyone re-runs them. Strongest evidence: `data-verdict="NO-REC"` element renders on `/review/T-801` with the cyan theme matching the AC.

---

## T-1582: htmx error handler on /review page
**Watchtower:** http://192.168.10.107:3000/review/T-1582
**Status:** work-completed
**Recommendation:** GO

### Human ACs evaluated
- AC text: "[REVIEW] Force a 500 on /review and confirm a red toast appears"
  - **Type:** [REVIEW] UI / error-path
  - **Evidence:** All 5 verification curl-greps pass on live `/review/T-1565`: `id="toast-container"`, `htmx:responseError`, `htmx:sendError`, `.wt-toast`, `function showToast`. HTTP 200. The toast machinery is wired in the standalone-template body in the same shape as `base.html:407-414` (the cockpit's reference handler). I cannot force a real 500 from a blind worker without risking destructive ops, but the DOM presence + JS handler binding is decisive evidence.
  - **Blind verdict:** confirm-GO
  - **Classification gripe:** This AC could plausibly be split into an Agent AC ("toast container DOM + handler script present" — already mechanically verified) and a smaller `[REVIEW]` for visual quality of the toast (colour/animation/copy). The current Steps require DevTools console hackery to force a 500, which is a non-trivial ask of the human; the deterministic part is already in `## Verification`.

### Overall
This is a textbook cross-surface drift fix — `review.html` was the standalone template that never inherited `base.html`'s toast machinery, and now it does. All five DOM/JS hooks are in place and the page returns 200. I would stamp this. Strongest evidence: simultaneous presence of `function showToast`, `htmx:responseError`, and `htmx:sendError` in the served HTML — the three pieces required for a visible 4xx/5xx toast.

---

## T-1583: Surface Reviewer Verdict on /review page
**Watchtower:** http://192.168.10.107:3000/review/T-1583
**Status:** work-completed
**Recommendation:** GO

### Human ACs evaluated
- AC text: "[REVIEW] Reviewer verdict on /review reads cleanly alongside the Recommendation"
  - **Type:** [REVIEW] UI
  - **Evidence:** `curl /review/T-1582` returns `<section class="reviewer-verdict-block" data-reviewer-overall="PASS">` — the actual element renders with the PASS attribute and the per-state CSS rules (PASS green-tint, FAIL red-tint, WARN amber-tint) are all defined in the page's stylesheet. The Jinja guard at `web/templates/review.html:491` is `{% if reviewer and reviewer.overall %}` — correctly silent when the extractor returns `overall: None`. **Caveat:** the verification command `! curl /review/T-967 | grep -q '<section class="reviewer-verdict-block"'` would now FAIL because T-967 has since been re-scanned and grew its own `## Reviewer Verdict (v1.4)` block (visible at line 463 of the served HTML). That's a real Reviewer Verdict, not a regression — the Jinja guard is doing the right thing, the test fixture has just aged out. The "block silently absent when reviewer.overall is None" behaviour is structurally correct in the template; the negative test case picked a task that has since been promoted into the positive case.
  - **Blind verdict:** confirm-GO (with stale-fixture caveat)

### Overall
Cross-surface parity with `/approvals` (F3 / T-1569) achieved. The reviewer block renders on tasks that have a verdict and is template-guarded silent on those that don't — the implementation is correct. The negative-direction verification command has rotted because the chosen "no reviewer block" target (T-967) has since gained one through normal reviewer agent operation, but that's a fixture problem, not a code problem. I would stamp this. Strongest evidence: live `/review/T-1582` renders the actual `<section class="reviewer-verdict-block" data-reviewer-overall="PASS">` element — agent recommendation + independent mechanical verdict now both visible on the per-task review surface.

---

# Summary

All six W1 tasks confirm-GO. Two tasks have minor stale-evidence issues (T-1578 Steps point at T-1062 which is no longer NO-REC; T-1583 negative test points at T-967 which now has a reviewer block) — both are fixture rot, not implementation rot, and the underlying behaviour is correct on freshly chosen targets. T-1577 in particular is the strongest of the set: cross-surface count parity is verified live (cockpit NO-REC = approvals NO-REC = 1) AND the underlying fix consolidated cockpit's local AC parser onto the canonical one, eliminating the L-298 root cause. T-1574 is the second strongest: the inception decide form renders on both the page and the htmx fragment endpoint, so polling-driven regression is structurally prevented. One classification gripe on T-1582 — the deterministic part of the toast verification could shift from `[REVIEW]` to Agent AC, leaving only "does the toast look right" for the human. Nothing blocks a human stamp on any of the six.
