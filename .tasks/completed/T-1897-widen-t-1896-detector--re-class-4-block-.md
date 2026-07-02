---
id: T-1897
name: "Widen T-1896 detector + re-class 5 block-message [REVIEW] ACs as [REVIEWER]
  (T-1878 C)"
description: >
  Widen reviewer pattern human-ac-mechanical-signal regex to include conformance-check
  dialect (names X / shows Y / points at Z / contains override flag / status:closed
  / row appended); re-class the 5 [REVIEW] ACs the wider detector should have caught:
  T-1730, T-1731, T-1762, T-1766, T-1893. Sibling to T-1895/T-1896 (T-1878 A+B); origin:
  2026-05-18 audits of arc-grooming partial-completes found my T-1896 detector regex
  too narrow (twice — the 4 first, then T-1893 added after a user-led reviewer-agent
  sweep showed mech=0 on it despite being pure procedural-conformance).

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [lib/reviewer/static_scan.py, 
      tests/unit/reviewer_human_ac_mechanical_signal.bats, 
      tests/unit/test_reviewer_human_ac_mechanical_signal.py]
related_tasks: [T-1878, T-1895, T-1896, T-1811, T-1730, T-1731, T-1762, T-1766, 
      T-1893]
arc_id: arc-grooming
created: 2026-05-18T08:51:35Z
last_update: '2026-06-11T22:24:02Z'
date_finished: 2026-05-18T10:22:24Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1897: Widen T-1896 detector + re-class 5 block-message [REVIEW] ACs as [REVIEWER] (T-1878 C)

## Context

T-1878's A+B intervention (T-1895/T-1896) shipped a structural catch for `[REVIEW]` Human ACs whose Expected reads as a deterministic shell check. The detector caught 2 historical hits on 1783 completed tasks (T-1116, T-1372) — good — but a 2026-05-18 audit of arc-grooming partial-completes found **4 currently mis-classed [REVIEW] ACs the detector should have flagged**: T-1730, T-1731, T-1762, T-1766. The detector regex (`_HUMAN_AC_MECHANICAL_RE`) only matches the **I/O-checking dialect** (grep / curl / exit-code / file contents / HTTP status / appended); it does not match the **conformance-checking dialect** (block message *names* X / *shows* Y / *points at* Z / *contains* the override flag). Both dialects are semantically grep-able — both should fire.

This task widens the regex AND re-classifies the 4 currently mis-classed ACs (T-1730/T-1731/T-1762/T-1766) to `[REVIEWER]` Agent ACs with `bin/fw reviewer T-XXX` in their `## Verification` blocks. T-1766 may need to be split (conformance portion → [REVIEWER]; "is the wording crisp?" residue → [REVIEW] kept).

Full reasoning: `docs/reports/T-1878-routing-default-bias.md` Phase 2 + the 2026-05-18 partial-completes audit in conversation log.

## Acceptance Criteria

### Agent
- [x] `_HUMAN_AC_MECHANICAL_RE` in `lib/reviewer/static_scan.py` widened with conformance-check dialect (`names?` / `shows?` / `points? at|to` / `contains? the` / `(override|bypass) (flag|env var|mechanism|syntax)` / `audit log row appended` / `block-message names|shows|contains` / `names? missing`). I/O dialect preserved.
- [x] **Bonus (Gate 2b):** Added taste-in-AC-line suppression — `[REVIEW]` line itself containing taste markers (e.g. "reads usefully", "feels clean") suppresses the finding even if Expected has mechanical signals. Fixes a T-1896-class FP discovered during widening.
- [x] Catalogue entry `policy/anti-patterns.yaml` `examples_positive` updated with 3 conformance-style examples (names X / shows Y / audit row appended); `examples_negative` updated with Gate 2b example ("reads usefully" header wins).
- [x] Python unit tests `tests/unit/test_reviewer_human_ac_mechanical_signal.py` extended: 5 new positive cases (names X / shows Y / override flag / audit row appended + Gate 2b taste-in-header). 16/16 PASS.
- [x] Bats test `tests/unit/reviewer_human_ac_mechanical_signal.bats` extended: T-9899 synthetic conformance fixture + new positive bats case. 5/5 PASS.
- [x] Corpus regression: `bin/fw reviewer audit` ran. New hits surfaced: 7 active (T-1730/T-1731/T-1762/T-1773/T-1774/T-1775/T-1805) + 9 historical completed-tasks. The 4 out-of-scope actives (T-1773/T-1774/T-1775 integration smokes; T-1805 ADR-intent) overridden with rationale; the 9 historicals overridden 365d per D-Immutability. Net unsuppressed: 0.
- [x] T-1730 [REVIEW] AC re-classed: empty ### Human (with note); new Agent AC A9 [REVIEWER]; Verification line added. Reviewer T-1730 → `human-ac-mechanical-signal` fires 0×.
- [x] T-1731 [REVIEW] AC re-classed: empty ### Human (with note); new Agent AC A9 [REVIEWER]; Verification line added. Reviewer T-1731 → `human-ac-mechanical-signal` fires 0×.
- [x] T-1762 [REVIEW] AC re-classed: empty ### Human (with note); new Agent AC [REVIEWER]; Verification line added. Reviewer T-1762 → `human-ac-mechanical-signal` fires 0×.
- [x] T-1766 [REVIEW] AC SPLIT: conformance ("names file/template/bypass") → Agent [REVIEWER] AC; residual taste ("a fresh agent can act without re-reading T-1766") stays as `[REVIEW]` (genuine cognitive-load UX). Reviewer T-1766 → `human-ac-mechanical-signal` fires 0×.
- [x] T-1893 [REVIEW] AC SPLIT: procedural-conformance (closure mechanics / status:closed / audit row appended) → Agent [REVIEWER] AC; residual decision-quality ("should this arc actually close?") → new `[REVIEW]` Human AC capturing the genuine strategic question. Reviewer T-1893 → `human-ac-mechanical-signal` fires 0×.
- [x] Each of the 5 re-classed tasks: `bin/fw reviewer T-XXX` confirms `human-ac-mechanical-signal` pattern silent post-conversion (0 fires each).
- [x] `## Verification` block on this task passes (commands added below).

### Human
- [ ] [REVIEW] Re-classed ACs preserve the spirit of the original — the [REVIEWER] Agent AC + Verification command genuinely covers what the original [REVIEW] was asking about, and the residual [REVIEW] (where kept, on T-1766) names only the truly taste portion
  **Steps:**
  1. Open each re-classed task (T-1730, T-1731, T-1762, T-1766) in Watchtower
  2. Read the original [REVIEW] text in the git diff vs the new [REVIEWER] AC + Verification command
  **Expected:** No conformance check is lost; the residual [REVIEW] on T-1766 reads as crisp-wording taste, not as smuggled mechanical
  **If not:** Note which AC fell on the wrong side; reopen with revised classification

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

# Unit + bats coverage on the widened detector.
python3 -m pytest tests/unit/test_reviewer_human_ac_mechanical_signal.py -q
bats tests/unit/reviewer_human_ac_mechanical_signal.bats
# Reviewer pattern still wired + catalogue entry present with widened examples.
test "$(grep -c 'id: human-ac-mechanical-signal' policy/anti-patterns.yaml)" -ge 1
test "$(grep -c 'detect_human_ac_mechanical_signal' lib/reviewer/static_scan.py)" -ge 2
test "$(grep -c 'T-1897 widening' policy/anti-patterns.yaml)" -ge 1
# All 5 re-classed tasks pass: reviewer no longer fires the mechanical-signal pattern.
test "$(bin/fw reviewer T-1730 2>&1 | grep -c 'human-ac-mechanical-signal')" -eq 0
test "$(bin/fw reviewer T-1731 2>&1 | grep -c 'human-ac-mechanical-signal')" -eq 0
test "$(bin/fw reviewer T-1762 2>&1 | grep -c 'human-ac-mechanical-signal')" -eq 0
test "$(bin/fw reviewer T-1766 2>&1 | grep -c 'human-ac-mechanical-signal')" -eq 0
test "$(bin/fw reviewer T-1893 2>&1 | grep -c 'human-ac-mechanical-signal')" -eq 0

## RCA

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

### 2026-05-18 — Gate 2b added: taste in AC line suppresses
- **What changed:** Original three-gate design (T-1896) checked AC line for strategic markers and Expected clause for taste markers. Building the widening surfaced a T-1896-style FP on T-1896 itself: `[REVIEW] Reviewer finding wording reads usefully — Expected: Finding text names the AC by index ...`. The AC LINE has taste ("reads usefully"), the Expected has mechanical ("names the A"). Original Gate 2a (strategic-in-line) didn't catch taste-in-line; Gate 3a (taste-in-Expected) didn't catch the Expected's mechanical signal-without-suppression-because-taste-lived-in-the-header. Added Gate 2b: AC line itself with taste markers suppresses regardless of Expected content. The AC header voice wins.
- **Plan impact:** ~5 LOC added to detector, one new pytest case (`test_silent_on_taste_in_ac_header_line`), catalogue example_negative.
- **Triggered:** No new task. Caught during widening regression on T-1896.

### 2026-05-18 — Corpus regression surfaced 4 out-of-scope active hits
- **What changed:** Original spec scoped the re-class to 5 known mis-classes (T-1730/T-1731/T-1762/T-1766/T-1893). Widening the regex made 4 additional active hits visible: T-1773/T-1774/T-1775 (integration smokes — Expected describes running-system observation, not static checks), and T-1805 (ADR-vs-implementation conformance — needs intent-reading judgment). All four are technically conformance-dialect but their real verification needs live infra or human judgment, not static-scan PASS.
- **Plan impact:** Did NOT extend scope to re-class these 4. Overrode with 90d TTL + rationale, queued as future follow-up (the integration-smoke class needs a different Verification path — running the actual dispatch — not a reviewer-PASS substitute).
- **Triggered:** No new task. Override entries in `.context/working/reviewer-overrides.yaml`. Future task may revisit when an integration-smoke harness exists.

### 2026-05-18 — Verification command form: pattern-fires-0 over Overall-PASS
- **What changed:** Initial draft of the re-class Verification command was `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"`. This requires the entire reviewer verdict to be PASS — but many tasks have OTHER unrelated findings (AC-verify-mismatch, mock-only-integration, etc.) that cause CONCERN/FAIL independent of the [REVIEW] mis-class issue. T-1730 has `mock-only-integration` finding → Overall CONCERN even after re-class. So Overall-PASS substitute was wrong for the re-class verification — it was checking "task is clean" not "this specific class of mis-class is resolved".
- **Plan impact:** All 5 re-classed tasks (and T-1897's own Verification block) use the precise form: `test "$(bin/fw reviewer T-XXX 2>&1 | grep -c 'human-ac-mechanical-signal')" -eq 0`. Pin: the pattern under remediation is silent on this specific task.
- **Triggered:** No new task. Caught when T-1730's Verification command failed (CONCERN ≠ PASS) despite the re-class itself being correct.

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

## Recommendation

**Recommendation:** GO

**Rationale:** T-1878 C closes the loop on the [REVIEW]→[REVIEWER] adoption gap. T-1878 A+B (T-1895/T-1896) shipped the author-time nudge + structural detector for the I/O-checking dialect. T-1897 widens the detector to the conformance-checking dialect (names X / shows Y / contains override flag / audit row appended), adds taste-in-header suppression (Gate 2b — caught a real FP on T-1896 itself during widening), and re-classes the 5 known mis-classes that surfaced in the arc-grooming partial-completes audit. Three are straight conversions (T-1730/T-1731/T-1762 — empty ### Human, new [REVIEWER] Agent AC); two are splits (T-1766/T-1893 — procedural→Agent, residual taste/strategic→Human).

The remaining `[REVIEW]` Human AC on this task is genuine taste — does the re-class preserve the spirit of each original AC? — only the human can answer.

**Evidence:**
- `lib/reviewer/static_scan.py` — `_HUMAN_AC_MECHANICAL_RE` widened with 7 conformance-dialect alternatives; Gate 2b (taste-in-line suppression) added at `detect_human_ac_mechanical_signal`
- `policy/anti-patterns.yaml` — 3 new positive examples (conformance dialect) + 1 new negative (Gate 2b)
- `tests/unit/test_reviewer_human_ac_mechanical_signal.py` — 16/16 PASS (5 new tests)
- `tests/unit/reviewer_human_ac_mechanical_signal.bats` — 5/5 PASS (T-9899 conformance fixture + positive bats case)
- Re-classed 5 tasks: T-1730 (A9), T-1731 (A9), T-1762 (gate-refusal-conformance), T-1766 (block-message-conformance Agent + residual UX [REVIEW]), T-1893 (closure-mechanics Agent + decision-quality [REVIEW])
- Corpus regression: `bin/fw reviewer audit` → 0 unsuppressed `human-ac-mechanical-signal` hits in active/ + completed/; 15 suppressed by override (2 historical T-1896 + 9 new completed-history + 4 out-of-scope active)
- 4 out-of-scope actives overridden 90d with rationale (T-1773/T-1774/T-1775 integration smokes; T-1805 ADR-intent) — queued for future follow-up
- Verification block on this task: 9/9 PASS

**Follow-up (not blocking):**
- Integration-smoke Verification path — the 4 90d-overridden tasks need a Verification that actually runs the dispatch (not a reviewer-PASS substitute). File when live-infra harness available.

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

## Updates

### 2026-05-18T08:51:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1897-widen-t-1896-detector--re-class-4-block-.md
- **Context:** Initial task creation

### 2026-05-18T10:07:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-69016d36
- **Timestamp:** 2026-06-02T18:58:50Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - mock-only-integration @ AC vs Verification cross-check
### 2026-05-18T10:22:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
