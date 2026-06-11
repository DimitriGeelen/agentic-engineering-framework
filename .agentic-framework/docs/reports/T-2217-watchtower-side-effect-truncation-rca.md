# T-2217 — Watchtower side-effect-warning truncation — RCA + systemic mitigation

**Workflow:** inception
**Filed:** 2026-06-05 (during S-2026-0605-2131 wind-down)
**Operator directive:** *"please rca and incept systemic mitigation ⚠ Decision recorded; side-effect warning: === Task Update === Task: T-2209 …"*
**Class:** 4th incident of G-068 META-class (Watchtower decision-form silent-failure on the human's primary control surface)

---

## §0. The trigger event (today)

- 2026-06-05 ~17:46Z (and again ~21:46Z): operator clicked **GO** on `/inception/T-2209` via Watchtower.
- Watchtower's `web/blueprints/inception.py:record_decision` ran `bin/fw inception decide T-2209 go --rationale … --from-watchtower`.
- **Primary action succeeded**: ## Decision block written to `.tasks/completed/T-2209-*.md`; commit `00da96d8c T-2209: inception decision GO (via Watchtower)` landed.
- **Side-effect failed**: `do_inception_decide()` chained to `update-task.sh --status work-completed`, which **errored on the T-2190 disposition gate**:

  ```
  ERROR: Cannot complete inception — 2 Open Question(s) under-disposed.
  T-2190 (T-2186 Slice 4): every IW-N question in ## Open Questions must carry
    disposition: answered|deferred|dissolved
    rationale: <evidence>
  Missing:
      - IW-2 (disposition=false rationale=false)
      - IW-1 (disposition=false rationale=true)
  Options:
    1. Add disposition + rationale lines per missing question
    2. --skip-disposition-gate "rationale"  (direct, logged Tier-2)
    3. FW_SKIP_DISPOSITION_GATE=1 <command>  (env-var, logged Tier-2)
  ```

- **What the operator saw**: `⚠ Decision recorded; side-effect warning: === Task Update === Task: T-2209 ("Capability-overlay arc — MCP subsystem + CLI route for agent-callable framework) File: /opt/999-Agentic-Engin` — truncated at char 150 by `web/blueprints/inception.py:551` (`(stderr or stdout)[:150]`).
- **Result**: operator can see the decision was recorded; cannot see *what blocks completion*, *what to fix*, *how to recover*. T-2209 is currently stuck `started-work` in `.tasks/active/` while the Decision says GO.

---

## §1. Why this is structurally a 4th-incident-of-class, not a one-off bug

The class is **G-068** (`.context/project/concerns.yaml:2090`):

> *"Three-RC compounding bug let the human's primary GO/NO-GO/DEFER channel silently no-op on T-1744. … The framework has no liveness check on 'Watchtower decisions actually persist' — `fw audit` PASSED throughout the failure window because the audit checks task structure, not decision-form fidelity."*

G-068 identified three RCs (RC1-RC3) and a fourth META-pattern that has been carried as `(not yet filed)` for **31 days**:

> *"T-1746 fixes all three RCs with surgical edits + integration test pinning all three layers. **But the META-pattern — no e2e contract test pinning 'user submits → decision persists OR user sees error' — is what allowed three independent code paths to drift together unchecked.**"*

| Date | Incident | RC | Resolution |
|------|----------|-----|------------|
| 2026-05-05 12:48Z | T-1744 GO submitted 4× over 2h, zero persistence | RC1 validator regex too strict on inner emphasis | T-1746 surgical fix |
| 2026-05-05 same | T-1744 false-positive primary_landed | RC2 `_decision_recorded_in_task` matched placeholder comment | T-1746 surgical fix |
| 2026-05-05 same | error vs warning route confusion | RC3 template only renders `?error=`, ignores `?warning=` | T-1746 surgical fix |
| **2026-06-05 ~17:46Z** | **T-2209 side-effect warning truncated to banner** | **RC4 (new) — 150-char `(stderr or stdout)[:150]` truncation loses actionable text** | **TBD — this inception** |
| Meta-pattern | Three (now four) independent code paths drift together unchecked | **e2e contract test never shipped** | **`(not yet filed)` — 31 days unaddressed** |

The four RCs are independent code paths (validator, recorded-detection, error/warning template route, side-effect-warning truncation) but each is an instance of the same class: *"the Watchtower decide POST has no contract pinning 'operator submits → decision persists in completed/ with rationale OR operator sees actionable error'."*

---

## §2. The blindspot ladder (why each leg drifts independently)

```
  ┌─ Validator ────────────┐
  │ regex / parse / shape  │  ←  RC1
  └─ ↓ ────────────────────┘
  ┌─ Primary action ───────┐
  │ writes Decision block  │  ←  do_inception_decide leg 1
  └─ ↓ ────────────────────┘
  ┌─ primary_landed check ─┐
  │ detects placeholder    │  ←  RC2 (false-positive caught text)
  └─ ↓ ────────────────────┘
  ┌─ Side-effect: update-task.sh ─┐
  │ runs status work-completed    │  ←  RC4 fires here (T-2190 disposition gate)
  │ runs verification (P-011)     │  ←  potential RC5 (P-011 truncation same issue)
  │ runs auto-tick / sweep        │  ←  potential RC6 (any chained leg)
  └─ ↓ ────────────────────────────┘
  ┌─ HTMX response render ────────────┐
  │ truncates stderr to 150 chars     │  ←  RC4 cause
  │ routes warning vs error           │  ←  RC3
  └─ ↓ ────────────────────────────────┘
  ┌─ Operator UX ─────────────────────┐
  │ sees banner, can't see fix path   │  ←  the operator-visible symptom today
  └────────────────────────────────────┘
```

**Each box is a leg the framework can fail at independently.** RC1, RC2, RC3, RC4 are four different boxes that all manifest as "decision did or did not persist, operator can't tell why or what to do." The META-fix that G-068 named — an **e2e contract test** spanning operator-submit through completed/-state with actionable-stderr verification — would have caught every one of them.

---

## §3. Candidate mitigations (steelman + strawman per candidate)

### Candidate A — Widen the truncation limit (`[:150]` → `[:1500]` or full)

- **Steelman.** Smallest possible change. `web/blueprints/inception.py:551` is one literal. Today's incident would have rendered the full error inline; operator would see the disposition-gate text + bypass options + recover commands. Zero new tests needed; zero new architecture.
- **Strawman.** Treats the symptom, not the class. RC5/RC6 are still possible — any other side-effect with structured-but-long output could hit a different truncation in a different code path. The META-pattern G-068 named is unaddressed; the next G-068 incident will land on a path A doesn't cover.
- **F8 cost:** 0.5 (XS — single-char edit, ~2 LoC).
- **Closes:** RC4 only. Does not close G-068 META.

### Candidate B — Ship the G-068 META-fix (end-to-end contract test)

- **Steelman.** G-068 explicitly named this as the META-fix 31 days ago and never shipped. A Playwright (or curl-driven) test that POSTs to `/inception/<id>/decide` and asserts (1) task moves to `completed/`, (2) operator-visible HTML contains either success markers OR actionable error text (not just a banner), would have caught RC1, RC2, RC3, RC4, and would catch RC5/RC6 the moment they manifest. The same harness can test NO-GO and DEFER paths. The framework already has `tests/playwright/` infrastructure (per CLAUDE.md §AC Classification Guidance Tier 3).
- **Strawman.** Bigger to ship (~80-150 LoC test harness + fixture inception with under-disposed Open Questions + cleanup). Doesn't fix today's RC4 — operator still sees truncated warning until A also ships. Tests can themselves drift (fixture rot — needs maintenance gate).
- **F8 cost:** 3.0 (M — test harness + multiple decision-path fixtures + CI hookup).
- **Closes:** RC4 (by failing CI on truncation regression), G-068 META, and pre-empts RC5/RC6.

### Candidate C — Pre-flight validation at Watchtower decide-time

- **Steelman.** Move the side-effect validation (disposition gate, P-010, P-011) *before* the Decision block is written. The Watchtower POST runs `update-task.sh --status work-completed --dry-run` first; if it would fail, refuse the decide POST with the actionable error visible (HTTP 200 + swappable error fragment, per T-2051 pattern). No "decision recorded; side-effect warning" state — either it lands cleanly or the operator is told why up front.
- **Strawman.** `update-task.sh --dry-run` doesn't exist today; it'd need to be added (a non-trivial refactor of the side-effect chain). Architectural shift — primary/side-effect distinction was deliberate (T-1470: side-effect failure is non-fatal). Moving validation earlier reintroduces the failure mode T-1470 fixed (operator can't record decision when transient side-effect glitches).
- **F8 cost:** 5.0 (L — `update-task.sh --dry-run` flag + plumbing + refactor of `record_decision` + regression tests).
- **Closes:** RC4 by design (no warning shown at all). Closes G-068 META at a fundamental level. Cost is the issue.

### Candidate D — Render full stderr in an expandable `<details>` block

- **Steelman.** Show 150-char preview as-is + collapsible `<details><summary>Show full output</summary>{full_stderr}</details>`. Operator who knows the error fits in the banner sees it; operator who needs more clicks to expand. Best-of-A UX without UI clutter.
- **Strawman.** Still UX-leg-only — doesn't close G-068 META, just makes A nicer. Requires Pico CSS / template work. Same regression risk as A (next truncation in a different leg).
- **F8 cost:** 1.0 (S — template change + ~15 LoC HTML rendering).
- **Closes:** RC4 only. Does not close G-068 META.

---

## §4. BVP Scoring Matrix

Scoring 0-5 per driver. Active drivers per `policy/value-drivers.yaml` (D1-D4 + F-RECALL, F-ORCH).

| Driver (weight) | A: widen | B: e2e contract | C: pre-flight | D: details |
|---|---|---|---|---|
| D1 Antifragility (×9) | 1 — fixes symptom, system doesn't strengthen | **5** — every class-N regression now fails CI | 4 — class-prevention at the source | 2 — UX-leg only |
| D2 Reliability (×7) | 2 — operator sees actionable text | **5** — predictable observable failure mode pinned by test | **5** — no inconsistent intermediate state | 3 — full text behind one click |
| D3 Usability (×5) | 4 — small win, immediate | 2 — operator UX unchanged until B-test fails CI | 4 — clearer decide-flow when blocked | **5** — best UX preserving banner brevity |
| D4 Portability (×3) | 5 — pure literal, no new deps | 3 — Playwright lock-in (already in tree) | 4 — `--dry-run` is a portable contract | 5 — HTML/CSS only |
| F-RECALL (×6) | 0 — no recall surface | **5** — test is the durable recall surface | 3 — flag becomes the recall surface | 1 — UX-only |
| F-ORCH (×5) | 1 — no orchestration impact | 4 — CI gate is orchestration | 4 — pre-flight is orchestration | 1 — none |

**Weighted totals:**

- A: `1·9 + 2·7 + 4·5 + 5·3 + 0·6 + 1·5` = 9 + 14 + 20 + 15 + 0 + 5 = **63**
- B: `5·9 + 5·7 + 2·5 + 3·3 + 5·6 + 4·5` = 45 + 35 + 10 + 9 + 30 + 20 = **149**
- C: `4·9 + 5·7 + 4·5 + 4·3 + 3·6 + 4·5` = 36 + 35 + 20 + 12 + 18 + 20 = **141**
- D: `2·9 + 3·7 + 5·5 + 5·3 + 1·6 + 1·5` = 18 + 21 + 25 + 15 + 6 + 5 = **90**

**Value/Cost ratios:**

- A: 63 / 0.5 = **126** (highest ratio — but covers RC4 only, leaves META open)
- B: 149 / 3.0 = **49.7**
- C: 141 / 5.0 = **28.2**
- D: 90 / 1.0 = **90**

**Combined A+B (joint):** value 63+149=212 (realistic ~190 with overlap), cost 0.5+3.0=3.5, ratio **~54** — close to B alone but covers the immediate symptom AND the class.

---

## §5. The strategic question the operator owns

T-2209's strategic-investment framing applies here too: G-068 META has been unaddressed 31 days because the **value/cost ratio** alone keeps preferring A-shaped surgical fixes. Each individual incident is "small enough to surgical-fix"; each surgical fix passes the cost gate; the META-pattern keeps drifting because no single incident is large enough to justify B's cost.

**The forward bet:** *"this control surface — operator-facing GO/NO-GO via Watchtower — is foundational. The 4th incident of the same class in 31 days is the signal. Pay B's cost now to stop paying A's symptom-fixes per incident."*

That is the same strategic-investment frame the operator applied to T-2209 / Path C-scoped. If it applies there, it likely applies here.

---

## §6. Recommendation

**Recommendation: GO — ship A + B jointly (Candidate A as the immediate symptom fix, Candidate B as the class-closing META-fix).** Filed initially as DEFER pending this analysis; analysis is now complete; upgrading.

**Rationale:**
1. **A alone is insufficient** — 4 incidents of the same class in 31 days, three of which were on independent code paths A wouldn't have caught.
2. **B alone leaves today's RC4 un-mitigated** — operator still sees the banner-only warning until A also lands.
3. **A is XS (0.5 F8)** — no reason to defer it for B's larger build.
4. **B closes G-068 META** — the 31-day-old `(not yet filed)` follow-up. By T-2144's discipline, evidence is sufficient: 4 incidents, 31 days, named META, named harness. This is GO with calibrated confidence, not DEFER.
5. **C is over-cost for the marginal value** — it would close at the source but at L-cost; the same class-closure is achievable by B at M-cost.
6. **D is a UX nice-to-have** — defer to a future round if operator finds A's wider truncation insufficient.

**Slicing under §ACD G-062:**
- **Slice 1 (A):** widen `web/blueprints/inception.py:551` truncation from 150 to ~1500 chars; add a `<pre>` wrap for newline preservation. Single edit. Operator sees today's actual error on T-2209's next retry. F8 0.5.
- **Slice 2 (B):** Playwright contract test at `tests/playwright/test_inception_decide_contract.py` — three test cases (GO success, GO with disposition-gate-blocked, NO-GO success). Fixture: a temporary inception with under-disposed Open Questions. Assertions: (a) primary action persists when expected, (b) operator-visible HTML contains actionable text when failed (≥300 chars of error visible, includes the "Options:" recovery block). F8 3.0. Wires into `fw test playwright`.

**Headline mechanic** (G-062 §ACD): *"operator submits GO via Watchtower against a fixture inception with under-disposed Open Questions; CI test fails because the operator-visible HTML truncates the actionable recovery options. The test failing IS the demo that the regression-net works."* Wire-level deliverable.

**Operator-Sovereign acts (this task cannot self-execute):**
- `fw arc create` is **not** needed (this is a single-task bug-class fix, not a multi-slice arc)
- Inception decide on T-2217 is Sovereign per `$CLAUDECODE=1` block — operator runs via `/inception/T-2217`

---

## §7. Recovery for the immediate T-2209 stuck state

Independent of T-2217's mitigation choice, T-2209 is currently stuck `started-work` with Decision = GO. Two recovery paths:

1. **Honest fix** — operator adds `disposition: …` + `rationale: …` to T-2209's IW-1 and IW-2 Open Questions per T-2190, then re-runs `fw inception decide T-2209 go` (or clicks GO again). The disposition gate then passes, work-completed transition fires, T-2209 moves to `completed/`.
2. **Tier-2 bypass** — `FW_SKIP_DISPOSITION_GATE=1 bin/fw task update T-2209 --status work-completed --skip-sovereignty --reason "T-2217 mitigation pending; operator-authorised"` — logged to `.context/working/.gate-bypass-log.yaml`. Single-use, escapes the gate without disabling it.

Either is operator-Sovereign. The agent cannot self-authorise.

---

## §8. Dialogue log

### 2026-06-05 — Operator filing

**Operator (truncated text pasted):**
> *"please rca and incpet systemic mitigation ⚠ Decision recorded; side-effect warning: === Task Update === Task: T-2209 ("Capability-overlay arc — MCP subsystem + CLI route for agent-callable framework) File: /opt/999-Agentic-Engin"*

**Agent diagnostic:**
1. Located the warning render at `web/blueprints/inception.py:551` — `(stderr or stdout)[:150]`.
2. Found T-2209 still in `active/` with `status: started-work` (work-completed failed).
3. Manually re-ran `update-task.sh --status work-completed` and saw the full T-2190 disposition gate error.
4. Searched concerns register — found G-068 (filed 2026-05-05) with the META-pattern `(not yet filed)` follow-up.
5. Realised today is the **4th incident of G-068 class** in 31 days.
6. Filed T-2217 as inception (DEFER initially, upgraded to GO after candidate analysis).

### 2026-06-05 — Recommendation evolution

| Stamp | Recommendation | Rationale |
|---|---|---|
| Filing | DEFER | Evidence gap — candidates A/B/C/D not yet analysed |
| §3-§4 analysis | **GO — A + B joint** | A closes immediate RC4 at XS cost; B closes G-068 META-class (31-day-old follow-up). Strategic-investment framing applies same as T-2209. |

---

### 2026-06-05 — RC5 surfaced WHILE writing this RCA

**Mid-RCA the framework reproduced the same class on T-2217 itself.**

T-2217's IW-4 had `disposition: deferred` + `rationale: …` correctly filled. The disposition gate at `agents/task-create/update-task.sh:770` refused work-completed with `IW-4 (disposition=true rationale=false)`. Investigation:

```bash
# update-task.sh:770
if echo "$line" | grep -qE "(IW-[0-9]+|^[[:space:]]*-[[:space:]]*Q-?[0-9]+)"; then
```

The `IW-[0-9]+` branch has **no line anchor** — it matches the substring anywhere on a line. The IW-4 rationale text contained the phrase "add IW-1/IW-2 dispositions" (referring back to T-2209's open questions). The parser saw `IW-1` mid-line, treated it as a new question marker, **flushed IW-4's verdict before reaching IW-4's rationale line**, and produced `disposition=true rationale=false`.

**This is RC5 of G-068 class.** Adding to the table in §1:

| Date | Incident | RC | Resolution |
|------|----------|-----|------------|
| 2026-06-05 mid-RCA | T-2217 disposition gate false-positive | RC5 (new) — `update-task.sh:770` IW-N regex matches `IW-N` anywhere on a line, not just question-marker positions; rationale text referencing other IWs triggers premature verdict flush | TBD — Slice 3 candidate (anchor the regex to bullet/heading delimiters) |

**The recursive symmetry matters:** T-2217 is an inception about *Watchtower side-effect-warning truncation*, and the gate that blocks T-2217 itself is exactly the gate whose side-effect warning was truncated on T-2209. The framework reproduced the META-class on the very inception filed to address it. That is the strongest possible signal that B (the e2e contract test) is the right fix shape.

**Workaround applied:** rewrote IW-4 rationale to say *"the missing dispositions"* instead of `"IW-1/IW-2 dispositions"`. Bug remains in `update-task.sh:770` — should be filed as a build slice (proposal: Slice 3 of T-2217 — anchor the IW-N regex per `^[[:space:]]*-[[:space:]]*\*\*IW-[0-9]+:` shape).

### Recommendation evolution (updated)

| Stamp | Recommendation | Rationale |
|---|---|---|
| Filing | DEFER | Evidence gap — candidates A/B/C/D not yet analysed |
| §3-§4 analysis | **GO — A + B joint** | A closes immediate RC4 at XS cost; B closes G-068 META-class (31-day-old follow-up). |
| Post-RC5 | **GO — A + B + Slice 3 (regex anchor)** | RC5 surfaced WHILE writing the RCA. The recursive symmetry confirms B is correct shape. Slice 3 added: anchor `update-task.sh:770` regex. F8 0.5 (XS). |

*(further entries appended as exploration / operator dialogue proceeds)*
