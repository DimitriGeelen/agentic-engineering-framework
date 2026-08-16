---
id: T-2145
name: "Reviewer detector — defer-as-hedge (T-2144 leg B): flag inception tasks with
  Recommendation=DEFER + completed evidence artifact"
description: >
  Reviewer detector — defer-as-hedge (T-2144 leg B): flag inception tasks with Recommendation=DEFER
  + completed evidence artifact

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [arc-008, reviewer, defer-as-hedge, advisory-model]
components: [agents/audit/reviewer/static_scan.py]
related_tasks: [T-2144, T-2143, T-2140, T-1947, T-679]
arc_id: inception-review-loop
unlocks_inception_decision: ["T-2144:defer-as-hedge-detector"]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-31T17:11:15Z
last_update: '2026-08-16T22:24:54Z'
date_finished: 2026-05-31T20:50:25Z
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
cost_estimate_proposed:
  - ts: '2026-05-31T17:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-31T17:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2145: Reviewer detector — defer-as-hedge (T-2144 leg B): flag inception tasks with Recommendation=DEFER + completed evidence artifact

## Context

Leg B of T-2144's Candidate D GO (recorded 2026-05-31T17:09:34Z). T-2144 RCA: agent files inception with `Recommendation: DEFER` despite complete evidence (5-Whys, candidate matrix, dialogue log) — a confidence-calibration failure that masquerades as a recommendation. T-679 + T-2144 = 2 documented incidents of the family. This task ships the reviewer static-scan rail that catches the structural fingerprint at task close.

Full diagnosis: `docs/reports/T-2144-defer-as-hedge-rca.md`. Detector lives alongside T-1947's prose-mismatch detector in the same catalogue.

## Acceptance Criteria

### Agent
- [x] `agents/audit/reviewer/static_scan.py` gains a new detector `defer-as-hedge` that fires when ALL of these hold on a task body:
  - `workflow_type: inception` in frontmatter
  - `## Recommendation` section contains the literal substring `Recommendation:** DEFER` (any case after the **)
  - `## Recommendation` references a path matching `docs/reports/T-\d+-.*\.md`
  - That artifact exists on disk AND contains ≥1 of: `## 5-Whys` (or `5-Whys`), a candidate matrix table with ≥3 rows, OR a `## Dialogue Log` section
  - `Rationale:` block in `## Recommendation` is >300 chars (substantive)
- [x] Detector emits CONCERN (not FAIL) with message naming the gap: "DEFER-with-evidence-complete: rationale + candidates + dialogue log present; recommend promoting to GO/NO-GO with the existing rationale."
- [x] Detector entry added to the reviewer catalogue config (likely YAML/JSON wherever T-1947's `reviewer-prose-mismatch` lives — same format) with default-on, TTL-overridable.
- [x] Unit test in `tests/unit/test_reviewer_static_scan.py` (or whichever test file covers the existing reviewer detectors) covers: (a) DEFER+full-evidence task triggers CONCERN, (b) DEFER+no-evidence (legitimate no-evidence-yet DEFER) does NOT trigger, (c) GO+full-evidence does NOT trigger, (d) NO-GO+full-evidence does NOT trigger, (e) non-inception workflow_type does NOT trigger.
- [x] Bats integration test pinning `fw reviewer T-XXX` end-to-end against a synthetic DEFER-as-hedge fixture.
- [x] T-2143 (currently a legitimate sovereignty-pending DEFER-equivalent state — operator may still pick NO-GO) covered by an explicit override entry with rationale "operator pick pending, not a hedge". *(Resolved: T-2143 self-corrected to GO post-T-2144; detector returns 0 findings against current T-2143 body — no override needed. Override SHAPE documented in catalogue entry's description for future use. See `docs/reports/T-2145-corpus-walk.md` §AC #7.)*
- [x] Corpus walk: `grep -lE "Recommendation:\*\* DEFER" .tasks/completed/T-*-inception-*.md` enumerated, each result either (a) confirmed legitimate-DEFER + override entry filed, or (b) flagged as historical DEFER-as-hedge instance + concern logged. *(Walk: 2119 files, 180 inceptions with DEFER, 4 hits at spec threshold all classified as false-positives, threshold raised to ≥2 indicators → 0 findings. See `docs/reports/T-2145-corpus-walk.md`.)*
- [x] T-2144 `inception_decisions:` field populated retrospectively with `B: defer-as-hedge detector ships in T-2145` so the `unlocks_inception_decision: [T-2144:B]` link on T-2145 itself becomes valid (resolves the gate that fired when filing this task). *(Field added to T-2144 with id `defer-as-hedge-detector` (B→kebab); link added to T-2145 frontmatter as `unlocks_inception_decision: ["T-2144:defer-as-hedge-detector"]`.)*

### Human
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
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

python3 -m py_compile lib/reviewer/static_scan.py
python3 -c "from lib.reviewer.static_scan import detect_defer_as_hedge; print('ok')" | grep -q ok
out=$(python3 -m pytest tests/unit/test_reviewer_defer_as_hedge.py 2>&1); echo "$out" | grep -q "13 passed"
out=$(bats tests/unit/test_reviewer_defer_as_hedge.bats 2>&1); echo "$out" | grep -q "ok 5"
out=$(python3 -c "import yaml; d=yaml.safe_load(open('policy/anti-patterns.yaml')); print('defer-as-hedge' in [p['id'] for p in d['patterns']])"); echo "$out" | grep -q True
test -f docs/reports/T-2145-corpus-walk.md
out=$(python3 -m pytest tests/unit/test_reviewer_*.py 2>&1); echo "$out" | grep -qE "[0-9]+ passed" && ! echo "$out" | grep -qE "[0-9]+ (failed|error)"

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

### 2026-05-31 — Corpus walk raised the indicator-count threshold

- **What changed:** AC #1 specified the artifact must contain "≥1 of: 5-Whys, candidate matrix, OR Dialogue Log". Corpus walk against 2119 files surfaced 4 false-positives at that threshold (T-2137, T-1611, T-1666, T-1298 — all single-indicator cases that were legitimate sovereignty-pending / sequence-planning / revisit-trigger DEFERs). The T-2143 origin pattern had ≥2 indicators (5-Whys + Dialogue Log).
- **Plan impact:** Detector raises threshold to ≥2 indicators. Spec-driven false-positive rate of 100% (4/4) collapsed to 0%; T-2143 origin shape still detected via synthetic fixture. Mirrors T-2147's "corpus-tuned regex overrides filing-time pattern list" pattern shipped earlier today.
- **Triggered:** Corpus walk report `docs/reports/T-2145-corpus-walk.md` documents the threshold raise. Catalogue entry description block cites the report.

### 2026-05-31 — AC #7 obviated by T-2143 self-correction

- **What changed:** AC #7 anticipated T-2143 needing a TTL'd reviewer override (rationale "operator pick pending, not a hedge"). T-2143 self-corrected to GO Candidate D post-T-2144 with an explicit reframe note. Detector returns 0 findings against current T-2143 body.
- **Plan impact:** No override entry needed. The override SHAPE is documented in the catalogue entry's description block instead — preserves discoverability without filing a now-misleading override.
- **Triggered:** AC #7 ticked with the resolution noted inline; no additional task or override needed.

### 2026-05-31 — Inception_decisions backfill mechanics

- **What changed:** AC #9 called for `inception_decisions: B` on T-2144 to make the `unlocks_inception_decision: [T-2144:B]` link on T-2145 valid. The hook (T-1984) requires `id:` to be kebab-case — `B` is rejected. Backfilled as `id: defer-as-hedge-detector` instead; T-2145's `unlocks_inception_decision:` updated to match.
- **Plan impact:** None — the link still serves its purpose (T-2145 ships T-2144's identified Candidate D leg B). The kebab-case constraint is a structural improvement (letter-id `B` is non-descriptive; `defer-as-hedge-detector` is self-documenting).
- **Triggered:** No follow-up — the constraint is enforced by an existing hook, agent adapted to it.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO — ready to close.

**Rationale:** All 9 Agent ACs ticked with evidence; 7 verification commands all PASS; 13 unit + 5 bats + 273 reviewer regression tests green; no Human ACs. The detector lands at 0/0 precision on the live 2119-file corpus after the threshold-raise — the four spec-threshold false positives all routed to legitimate-DEFER classifications and the synthetic positive fixture still triggers. The T-2143 origin pattern is preserved as the canonical positive case via unit + bats fixtures. AC #7 obviated by T-2143's self-correction; AC #9 mechanics required the kebab-case rename (B → defer-as-hedge-detector).

**Evidence:**
- `lib/reviewer/static_scan.py:1252-1392` — `detect_defer_as_hedge` implementation + 4 regexes + `_count_candidate_matrix_rows` helper
- `lib/reviewer/static_scan.py:1495-1497` — wired into `scan_task` pipeline as v1.6 +2 detector
- `policy/anti-patterns.yaml` — 13th catalogue entry with description, positive/negative examples, override syntax, corpus-walk note
- `tests/unit/test_reviewer_defer_as_hedge.py` — 13 unit tests covering 5 AC #4 cases + 8 edge/integration cases
- `tests/unit/test_reviewer_defer_as_hedge.bats` — 5 bats integration tests through `bin/fw reviewer T-XXX`
- `docs/reports/T-2145-corpus-walk.md` — 99-line walk report: 2119 files, 4 → 0 finding progression, AC #7 + #9 resolution notes
- `.tasks/completed/T-2144-*.md:18-21` — `inception_decisions:` backfilled (kebab-case id)
- `.tasks/active/T-2145-*.md:17` — `unlocks_inception_decision:` link added

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-31T17:11:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2145-reviewer-detector--defer-as-hedge-t-2144.md
- **Context:** Initial task creation

### 2026-05-31T17:12:32Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-05-31T20:38:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9f56c418
- **Timestamp:** 2026-06-02T15:01:20Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `out=$(python3 -m pytest tests/unit/test_reviewer_defer_as_hedge.py 2>&1); echo "$out" | grep -q "13 passed"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 33
     - evidence: `python3 -c "from lib.reviewer.static_scan import detect_defer_as_hedge; print('ok')" | grep -q ok`
### 2026-05-31T20:50:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
