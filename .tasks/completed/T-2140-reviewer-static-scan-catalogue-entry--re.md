---
id: T-2140
name: "Reviewer static-scan catalogue entry — review-link-homework (T-2138 V2)"
description: >
  T-2138 V2 sibling to T-2139. Add review-link-homework pattern to agents/audit/reviewer/static_scan.py
  catalogue. Emits CONCERN on a [REVIEW] AC whose Steps contain the absence-of-URL
  homework patterns. Provides catch-before-handoff backstop so the agent self-corrects
  before T-2139's gate fires.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [arc-008, review-handoff, T-2138-followup]
components: []
related_tasks: [T-2138, T-2139]
arc_id: inception-review-loop
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-31T13:30:17Z
last_update: '2026-08-16T22:24:54Z'
date_finished: 2026-05-31T21:28:40Z
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
  - ts: '2026-05-31T13:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-31T13:45:03Z'
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
  - ts: '2026-06-11T22:24:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=3 
      (body:fw-recall-or-memory-link); F-ORCH=0 (no-signal); F3=0 (no-signal); 
      F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=3 
      (body:fw-recall-or-memory-link); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2140: Reviewer static-scan catalogue entry — review-link-homework (T-2138 V2)

## Context

T-2138 V2 sibling to T-2139 (the transition-time blocking gate). Adds the `review-link-homework` static-scan detector to `lib/reviewer/static_scan.py` so `fw reviewer T-XXX` flags the review-handoff homework pattern BEFORE the agent surfaces a task for review. Backstop that fires earlier than T-2139's gate — agent self-corrects at pre-completion review, never reaches the transition-time block.

Full diagnosis + candidate matrix + dialogue log: `docs/reports/T-2138-review-handoff-author-time-gap.md`. Same arc-008 (inception-review-loop) detector triplet as T-2147 (audience-mismatch) and T-2145 (defer-as-hedge), both shipped this week.

## Acceptance Criteria

### Agent
- [x] Detector function `detect_review_link_homework(ac_section, verification_section)` lives in `lib/reviewer/static_scan.py`. Returns `list[Finding]` with `pattern_id="review-link-homework"`, `lie_severity="partial"`, `detection_confidence="heuristic"`. *(Function signature simplified to `(ac_section)` only — `verification_section` was specified but unneeded since the detector is scoped to AC section by design — see Evolution.)*
- [x] Fires CONCERN when an AC body or its `**Steps:**` block contains any of: `URL from ... bin/fw watchtower url`, `base from ... bin/fw watchtower url`, or `(Watchtower URL from` — case-insensitive. Pattern detection scoped to `### Human` subhead ACs only (Verification block paths are legitimate and must not trip).
- [x] Silent on author opt-out marker `<!-- review-link-homework-ok: ... -->` <!-- review-link-homework-ok: AC documents the opt-out marker syntax --> anywhere in the AC body (mirrors `[[audience-mismatch-ok]]` shape used by T-2147).
- [x] Detector wired into `scan_task` so `fw reviewer T-XXX` surfaces findings in `## Reviewer Verdict` block and exit-code semantics. Same plumbing as T-2147/T-2145.
- [x] Catalogue entry `id: review-link-homework` exists in `policy/anti-patterns.yaml` with lie_severity=partial, description, positive example, negative example, opt-out marker syntax, override syntax (`fw reviewer override add T-XXX --pattern review-link-homework`).
- [x] Unit tests in `tests/unit/test_reviewer_review_link_homework.py` cover: (a) positive: Human AC Steps with `URL from bin/fw watchtower url` → finding; (b) positive: `(Watchtower URL from` literal → finding; (c) negative: same pattern under `### Agent` → silent; (d) negative: `## Verification` block containing `/path` → silent; (e) negative: AC with full `http://192.168.10.107:3000/path` URLs → silent; (f) negative: opt-out marker present → silent; (g) `scan_task` integration. *(12 tests written, all green.)*
- [x] Bats integration tests in `tests/unit/test_reviewer_review_link_homework.bats` cover: (a) synthetic fixture T-99XX with homework Steps → `bin/fw reviewer T-99XX` emits the pattern id; (b) negative fixture with full URLs → silent; (c) catalogue + detect-fn-export sanity checks. *(5 bats tests, all green.)*
- [x] Corpus walk artifact `docs/reports/T-2140-corpus-walk.md` documents: scan of `.tasks/{active,completed}/T-*.md`, hit count, sample sites, any false-positives that drove regex refinement. *(2119 files scanned, 5 true-positives matching T-2138 prior grep, 0 false-positives on first attempt.)*
- [x] All existing 273 reviewer tests still pass — no regression in the 13-detector catalogue. *(285 total now pass: 273 prior + 12 new for this detector.)*

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

# T-2140 verification — all checks file-direct grep / pytest / module import
python3 -c "from lib.reviewer.static_scan import detect_review_link_homework"
grep -q "id: review-link-homework" policy/anti-patterns.yaml
grep -q "detect_review_link_homework" lib/reviewer/static_scan.py
python3 -m pytest tests/unit/test_reviewer_review_link_homework.py -q
python3 -m pytest tests/unit/test_reviewer_audience_mismatch.py tests/unit/test_reviewer_defer_as_hedge.py -q
test -f docs/reports/T-2140-corpus-walk.md
grep -q "Findings: 5 across 5 files\|Findings (per-AC) | 5" docs/reports/T-2140-corpus-walk.md

## Recommendation

**Recommendation:** GO — close T-2140; arc-008 reviewer detector triplet complete.

**Rationale:** Third and final detector of the arc-008 review-loop-quality triplet shipped this week (T-2147 audience-mismatch + T-2145 defer-as-hedge + T-2140 review-link-homework). All three follow the same pattern: catch-before-handoff CONCERN that complements an existing structural gate (T-2143 routing-discipline ladder, T-2144 advisory model, T-2138/T-2139 transition-time link gate). Detector landed at 0/0 false-positive rate on the 2119-file corpus on first attempt — better than either sibling (T-2147 needed 3 regex iterations; T-2145 needed indicator-count threshold raise). Two structural design choices (AC-section scope + `### Human` subhead filter) eliminated the documentation-meta FP class without regex tuning. T-2138's prior grep listed 7 sites; this detector caught exactly the 5 true-violations (4 active arc-007 + 1 completed) while correctly silencing the 5 meta-documentation sites that necessarily quote the literal pattern.

**Evidence:**
- Code: `lib/reviewer/static_scan.py:1437+` (`detect_review_link_homework` + `_REVIEW_LINK_HOMEWORK_RE` + `_REVIEW_LINK_OPT_OUT_RE`) + wired into `scan_task` at v1.6 +3.
- Catalogue: `policy/anti-patterns.yaml` lines ~373-426 (`id: review-link-homework`).
- Tests: `tests/unit/test_reviewer_review_link_homework.py` (12 pass) + `tests/unit/test_reviewer_review_link_homework.bats` (5 pass) = 17 new tests.
- Regression: 285 total reviewer tests pass (273 prior + 12 new). No detector cross-talk.
- Corpus walk: `docs/reports/T-2140-corpus-walk.md` — 2119 files scanned, 5 hits (T-1991, T-2012, T-2013, T-2027, T-1853), 0 false-positives.
- Arc-008 detector triplet complete: T-2147 (audience-mismatch, 14 tests) + T-2145 (defer-as-hedge, 13 tests) + T-2140 (review-link-homework, 17 tests) = 44 new arc-008 tests this week.
- The 5 active corpus hits will surface as CONCERN at their next `bin/fw reviewer` run — agents authoring those tasks can self-correct before T-2139's transition-time gate fires at handoff.

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

### 2026-05-31 — detector signature simplified to `(ac_section)` only
- **What changed:** AC #1 specified the detector as `detect_review_link_homework(ac_section, verification_section)`. Implementation reached for `verification_section` and realised it added no value — the scope decision is "AC section only, Human subhead only", and Verification block paths are out of scope structurally, not by filtering. Function signature simplified to `(ac_section)`, mirroring `detect_audience_mismatch`.
- **Plan impact:** AC text retained the original signature ref with a corrective note. No behavioural change.
- **Triggered:** None.

### 2026-05-31 — 0/0 FP on first attempt vs sibling detectors' iterations
- **What changed:** T-2147 (audience-mismatch) needed 3 regex iterations to clear corpus false-positives, dropping `agent files` and restricting `the agent will <X>` to receptive verbs. T-2145 (defer-as-hedge) needed an indicator-count threshold raise from spec ≥1 to corpus-tuned ≥2 to eliminate sovereignty-pending DEFER false-positives. T-2140 landed at 0/0 false-positives on the first regex attempt.
- **Plan impact:** No spec deviation. The structural design choices (scope to `## Acceptance Criteria` section + filter to `### Human` subhead) made regex tuning unnecessary — the meta-documentation FP class (T-2030/T-2118/T-2138/T-2139/T-2140) is excluded by AC-section scope, not by regex pattern. Captured the lesson in `docs/reports/T-2140-corpus-walk.md` §"Design choices that drove 0 false-positives".
- **Triggered:** None. The lesson — *prefer scoping over regex tuning when the violation class lives on a structural surface (Human ACs) and the FP class lives elsewhere (body sections)* — informs future detectors but doesn't need a separate task.

### 2026-05-31 — arc-008 reviewer-detector triplet complete
- **What changed:** This task closes the arc-008 review-loop-quality detector triplet (T-2147 audience-mismatch + T-2145 defer-as-hedge + T-2140 review-link-homework). All three share the catch-before-handoff backstop shape: complement an existing structural gate (T-2143 routing ladder, T-2144 advisory, T-2138/T-2139 transition-time gate) with a static-scan rail that fires DURING pre-completion review.
- **Plan impact:** Arc-008 detector inventory: 3 new detectors + 44 new tests this week. Reviewer catalogue at 14 patterns (was 11 at week start). The "two-layer governance" shape (author-time discipline + reviewer-time backstop) is now established as a repeatable pattern — same shape as T-1878 default-bias + T-1947 prose-mismatch sibling pair.
- **Triggered:** No new tasks. T-2141 (CLAUDE.md/AGENT.md/block-message review-vs-inception sweep) and T-2143 leg-A propagation (chat-message URL slip) remain as the arc-008 follow-ons.

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

### 2026-05-31T13:30:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2140-reviewer-static-scan-catalogue-entry--re.md
- **Context:** Initial task creation

### 2026-05-31T13:30:48Z — status-update [task-update-agent]
- **Change:** tags: +T-2138-followup

### 2026-05-31T21:20:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fc8f0b4d
- **Timestamp:** 2026-06-02T15:01:18Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `python3 -m pytest tests/unit/test_reviewer_review_link_homework.py -q`
### 2026-05-31T21:28:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
