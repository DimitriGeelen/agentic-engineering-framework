---
id: T-2086
name: "fix /bvp rubric duplicate rows for range scores (1–2 expands to two identical rows)"
description: >
  fix /bvp rubric duplicate rows for range scores (1–2 expands to two identical rows)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: [T-2084, T-2085]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T09:23:48Z
last_update: 2026-05-29T09:28:36Z
date_finished: 2026-05-29T09:28:36Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
---

# T-2086: fix /bvp rubric duplicate rows for range scores (1–2 expands to two identical rows)

## Context

T-2084's `_driver_rubrics()` parser handles the en-dash range form (`1–2 — desc`) by expanding the range to one entry per score (1 AND 2 both rendered with the same text). On /bvp this produces two visibly identical rows under F1:

```
1 — captures something, but session-scoped only…
2 — captures something, but session-scoped only…
```

Source rationale in `policy/value-drivers.yaml` for F1 uses `1–2 — desc` deliberately to indicate "scores 1 and 2 share this description". The renderer should match the source intent: collapse adjacent identical descriptions into a single row labeled with the score range (`**1–2** — desc`).

## Acceptance Criteria

### Agent
- [x] `_driver_rubrics()` returns a list of `(label, desc)` pairs where `label` is `"N"` for single scores and `"N–M"` for ranges. Protected-driver tables (D1-D4, one row per score) still yield 6 single-score entries.
- [x] Template renders each rubric line as `**<label>** — desc`; no two visible rows share the same description when the source declared a range.
- [x] Existing unit tests (tests/unit/test_driver_rubrics.py) updated to assert the new shape. New test pins F1's range-collapse (`policy/value-drivers.yaml` declares F1 with `1–2 — desc` → result has one entry covering 1–2, not two identical entries).
- [x] `/bvp` GET still 200; D1-D4 still show six numeric rows (0..5); F1 shows five rows (0, 1–2, 3, 4, 5); F2 unchanged.

### Human
- [ ] [REVIEW] F1 rubric expand on /bvp shows one row labeled `1–2`, not two identical `1 — …` and `2 — …` rows
  **Steps:**
  1. Open http://192.168.10.107:3000/bvp
  2. Click the F1 `(?)` expand widget (next to "Recall_Leverage")
  3. Read the entries
  **Expected:** Five rows: `**0** — produces no durable artifact…`, `**1–2** — captures something, but session-scoped…`, `**3** — writes a reusable artifact…`, `**4** — closes a loop…`, `**5** — creates or improves the retrieval/synthesis layer…`. No two rows share the same description.
  **If not:** Screenshot the F1 expand and report which scores duplicated.

<!-- legacy template guidance suppressed for brevity -->
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

python3 -m pytest tests/unit/test_driver_rubrics.py -q
curl -sf "$(bin/fw watchtower url)/bvp" -o /tmp/.t2086-vrf
# F1 row contains exactly 5 strong-labels: 0, 1–2, 3, 4, 5 (range collapsed)
test "$(awk '/<tr data-driver=\"F1\">/,/<\/tr>/' /tmp/.t2086-vrf | grep -cE '<strong>[^<]+</strong>')" = 5
# D1 row still has 6 single-score labels
test "$(awk '/<tr data-driver=\"D1\">/,/<\/tr>/' /tmp/.t2086-vrf | grep -cE '<strong>[0-9]</strong>')" = 6
# 'captures something' (F1 range desc) appears at most once
test "$(awk '/<tr data-driver=\"F1\">/,/<\/tr>/' /tmp/.t2086-vrf | grep -c 'captures something')" = 1

## RCA

**Symptom:** /bvp F1 rubric expand showed two visibly identical rows ("1 — captures something, but session-scoped only…" and "2 — captures something, but session-scoped only…") where the source declared one range row `1–2 — desc`.

**Root cause:** T-2084's `_driver_rubrics()` parsed the range form `1–2 — desc` and expanded it into `{1: desc, 2: desc}` via `for s in range(lo, hi + 1)`, then materialised as separate list entries. The template iterated and rendered both. The range syntax was treated as a parser-side shorthand for "two scores with the same text" instead of "one row covering two scores".

**Why structurally allowed:** T-2084's tests asserted `len(rubrics["F1"]) == 6` and `rubrics["F1"][0]` truthy — they treated 6-entry coverage as the contract. The same contract is satisfied by "1, 2 expanded with duplicate text" AND by "1–2 single row" — only an eyes-on view exposed which one was intended. L-403 / L-444 territory: source-intent-vs-render mismatch passes grep tests; only screenshot review catches it.

**Prevention:** Tests now pin (a) protected driver labels are single scores (`["0".."5"]`), (b) F1's source-declared range collapses to one entry, (c) overlapping ranges fall through to "driver omitted" rather than partial render. The new `test_f1_range_collapses_to_single_entry` uses a synthetic policy independent of the real F1 wording, so wording changes don't disarm the pin. Sweep candidate: lint for parser code that calls `range(lo, hi + 1)` and writes to a dict whose values are then rendered in a list — same source-intent class. Not in scope for this hotfix.

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

**Recommendation:** GO (complete — Agent ACs ticked; one Human [REVIEW] pending eyes-on)

**Rationale:** `_driver_rubrics()` shape moved from `dict[id, list[str]]` (indexed by score, range silently expanded) to `dict[id, list[(label, desc)]]` (source-order, range preserved as `"N–M"` label). D1-D4 unchanged (6 single-score entries); F1's `1–2 — desc` now renders as one collapsed row. 8/8 unit tests green (2 new pins: range-collapse, overlap-rejection). Live DOM grep confirms F1 has 5 strong-labels (0, 1–2, 3, 4, 5) and 1 occurrence of "captures something" (was 2); D1 still has 6 single-score labels.

**Evidence:**
- `web/blueprints/bvp.py:82-148` — `_driver_rubrics` returns `(label, desc)` tuples; range stays one entry; overlap → driver dropped
- `web/templates/bvp.html:43-46` — iterate `for label, desc in driver_rubrics[d_id]`
- `python3 -m pytest tests/unit/test_driver_rubrics.py -v` → 8 passed in 0.25s
- `curl /bvp` → F1: `<strong>0</strong>` `<strong>1–2</strong>` `<strong>3</strong>` `<strong>4</strong>` `<strong>5</strong>` (5 entries); D1: 6 single-score entries; `grep -c "captures something"` on F1 row → 1

Human eyes-on at http://192.168.10.107:3000/bvp closes the [REVIEW].

## Updates

### 2026-05-29T09:23:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2086-fix-bvp-rubric-duplicate-rows-for-range-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-78bc96e3
- **Timestamp:** 2026-06-11T12:12:59Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — Existing unit tests (tests/unit/test_driver_rubrics.py) updated to assert the new shape. New test pins F1's range-collapse (`policy/value-drivers.yaml` declares F1 with `1–2 — desc` → result has one e
  - **AC-verify-mismatch** (narrow, heuristic) — `path=policy/value-drivers.yaml in: Existing unit tests (tests/unit/test_driver_rubrics.py) updated to assert the new shape. New test pins F1's range-collapse (`policy/value-drivers.yaml`
### 2026-05-29T09:28:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
