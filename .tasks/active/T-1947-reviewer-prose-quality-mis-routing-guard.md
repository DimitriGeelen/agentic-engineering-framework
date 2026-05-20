---
id: T-1947
name: "reviewer prose-quality mis-routing guard — REVIEWER necessary-but-not-sufficient
  on prose ACs (T-1811 extension)"
description: >
  reviewer prose-quality mis-routing guard — REVIEWER necessary-but-not-sufficient
  on prose ACs (T-1811 extension)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [lib/reviewer/static_scan.py, tests/unit/test_reviewer_prose_mismatch.bats]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T07:28:57Z
last_update: 2026-05-20T07:43:25Z
date_finished: 2026-05-20T07:43:25Z
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
  - ts: '2026-05-20T07:30:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1947: reviewer prose-quality mis-routing guard — REVIEWER necessary-but-not-sufficient on prose ACs (T-1811 extension)

## Context

T-1811 introduced the `[REVIEWER]` Human AC prefix as a third class between
`[REVIEW]` (human taste) and `[RUBBER-STAMP]` (mechanical). The intent: ACs
verifiable by `fw reviewer T-XXX` static scan should be routed to the
reviewer agent instead of consuming human attention.

Investigation on T-1811 itself revealed a hole: the author tagged a prose-clarity
AC ("Updated CLAUDE.md section reads clearly and the conversion rule is
unambiguous") as `[REVIEWER]`, but the reviewer's nine detectors operate on
YAML/shell structural patterns — **zero detectors evaluate natural-language
prose quality**. Result: the reviewer silently ignores the prose AC and emits
its verdict based on findings from OTHER ACs. `Overall: CONCERN` looks identical
at the surface whether the scanner had something to say about the prose or
stayed silent because no detector applies.

This task ships a static-scan detector (`detect_reviewer_prose_mismatch`)
that catches `[REVIEWER]` prefix combined with prose-quality vocabulary in
the AC body or Expected clause — emitting per-AC CONCERN that surfaces the
mis-routing instead of letting it pass silently. CLAUDE.md §AC Classification
Guidance gains the "necessary-but-not-sufficient" caveat for the `[REVIEWER]`
prefix. T-1811 AC#1 gets demonstrated re-classification back to `[REVIEW]`.

Related learnings: L-409 (the rule), L-410 (epistemic hygiene on
unsubstantiated quantitative claims used to justify build-vs-buy choices).

## Acceptance Criteria

### Agent
- [x] `lib/reviewer/static_scan.py` gains `detect_reviewer_prose_mismatch(ac_section)` that emits a `reviewer-prose-mismatch` Finding when a Human AC has `[REVIEWER]` prefix AND its body or Expected clause matches the existing `_HUMAN_AC_TASTE_RE` (reads/tone/rhythm/intuitive/...)
- [x] `scan_task` wires the new detector into the catalogue alongside `detect_human_ac_mechanical_signal`
- [x] `tests/unit/test_reviewer_prose_mismatch.bats` covers: (a) positive — `[REVIEWER]` + "reads clearly" in Expected → CONCERN finding; (b) negative — `[REVIEWER]` + grep-able Expected → silent; (c) negative — `[REVIEW]` + "reads clearly" → silent (already covered by mechanical-signal detector); (d) negative — `[REVIEWER]` under `### Agent` subhead → silent (only Human ACs are routed)
- [x] All bats cases green: `bats tests/unit/test_reviewer_prose_mismatch.bats` (6/6)
- [x] Existing reviewer test suite still green: `bats tests/unit/reviewer_human_ac_mechanical_signal.bats` (5/5 — no regression)
- [x] CLAUDE.md §AC Classification Guidance §"Three Human-AC prefixes" extended with explicit `[REVIEWER]` necessary-but-not-sufficient rule and the prose-vocabulary list
- [x] T-1811 active task file: AC#1 (was `[REVIEWER]`) re-classified to `[REVIEW]` with rationale comment pointing to L-409
- [x] `bin/fw reviewer T-1811` after the re-class drops from 2 findings (CONCERN-on-AC#3 + prose-mismatch-on-AC#1) to 1 finding (CONCERN-on-AC#3 only) — prose-mismatch correctly silenced

### Human
- [ ] [REVIEW] The new CLAUDE.md `[REVIEWER]` necessary-but-not-sufficient paragraph reads clearly and the prose-vocabulary list lands without feeling like a wall of jargon
  <!-- L-409 dogfood: this task's CLAUDE.md edit is itself prose-quality work,
       and the rule it ships says prose ACs are [REVIEW] not [REVIEWER]. Filed
       as [REVIEW] accordingly. -->
  **Steps:**
  1. Open CLAUDE.md and scroll to §AC Classification Guidance "Three Human-AC prefixes" table
  2. Read the new paragraph beginning "`[REVIEWER]` is necessary-but-not-sufficient on prose-quality ACs"
  3. Apply the test: as a reader who hasn't seen this conversation, do you understand (a) why the rule exists, (b) which vocabulary triggers the constraint, (c) what to do instead?
  **Expected:** The paragraph stands alone — a fresh reader can decide whether to route a new AC as [REVIEW] or [REVIEWER] from the prose alone
  **If not:** Note paragraphs that lost you; the wording can be tightened or examples added

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

python3 -c "import ast; ast.parse(open('lib/reviewer/static_scan.py').read())"
bash -n bin/fw
bats tests/unit/test_reviewer_prose_mismatch.bats
out=$(bin/fw reviewer T-1811 2>&1); echo "$out" | grep -qv "reviewer-prose-mismatch"
grep -q "necessary-but-not-sufficient" CLAUDE.md
grep -q "L-409" .context/project/learnings.yaml

## RCA

**Symptom:** T-1811 AC#1 (`[REVIEWER] Updated CLAUDE.md section reads clearly`) was the explicit attempt to use the reviewer agent for prose-quality verification. Running `bin/fw reviewer T-1811` returned `Overall: CONCERN, Needs Human: no, Findings: 1` — the finding was on Agent AC#3 (`AC-verify-mismatch` on `lib/verify-acs.sh`), not on the Human prose AC. The Human AC was silently skipped because the reviewer has no detector that fires on its content; the surface output looks identical to "all clear on prose".

**Root cause:** The `[REVIEWER]` prefix in CLAUDE.md (T-1811) was defined as "AC verifiable by `fw reviewer` static scan" without explicit scope on what the scan can and cannot verify. The reviewer has 9 detectors (tautology, empty-body, swallowed-errors, output-spoofing, empty-output-success, skip-as-pass, mock-only-integration, human-ac-mechanical-signal, ac-verify-mismatch) — all operating on YAML/shell structural patterns. None evaluate natural-language prose quality. Authors reading the `[REVIEWER]` definition without inspecting the detector catalogue can route a prose-clarity AC there hoping the reviewer will judge "reads clearly". The reviewer dutifully stays silent (no detector applies) and reports on whatever OTHER ACs trip its existing patterns.

**Why structurally allowed:** Two gaps:
1. **`[REVIEWER]` vocabulary in CLAUDE.md was scope-vague.** "Static-scan-verifiable" reads as a wide promise; the actual coverage is the 9 detectors. The gap between author expectation and scanner capability was invisible until T-1811 itself exercised it.
2. **The reviewer's silence-on-no-match is indistinguishable from PASS-on-match at the verdict surface.** When an AC fires no detector, the AC simply doesn't appear in `Per-AC findings:`. There is no "AC #1 not assessable by this scanner" output. The human reading the verdict sees Findings on OTHER ACs and the prose AC's absence reads as success.

**Prevention:** `detect_reviewer_prose_mismatch` (this task) catches the routing error at scan time — if `[REVIEWER]` prefix combines with taste vocabulary (reads/tone/rhythm/intuitive/cleanly/voice/cohesive/...), emit CONCERN per-AC. The CLAUDE.md update adds the explicit "necessary-but-not-sufficient" rule with the prose-vocabulary list, so authors writing fresh ACs see the constraint before filing. T-1811's own AC#1 demonstrated the re-class.

**Connects to existing learnings:** L-403 (re-class operations leave partial-complete state), L-401 (review-queue bucket discipline). New: L-409 (this rule), L-410 (epistemic hygiene on quantitative claims used to justify build-vs-buy).

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

## Recommendation

**Recommendation:** GO

**Rationale:** The T-1811 [REVIEWER] mis-routing was a real bug — the reviewer silently skipped the prose AC and reported on other ACs, producing a verdict surface that read as success on the dimension the author cared about. This task closes the gap structurally: (a) a new detector emits CONCERN per-AC when prose vocabulary appears under `[REVIEWER]`, (b) CLAUDE.md gains the explicit necessary-but-not-sufficient rule with the prose-vocabulary list, (c) T-1811 AC#1 itself was re-classed back to `[REVIEW]` as the worked example. Bonus: surfaced L-410 — a self-correction on the unsubstantiated "humans skim CLAUDE.md edits in seconds" claim I had used to justify dismissing path (b) (build LLM-backed prose detector) in the user-facing elaboration.

**Evidence:**
- `bats tests/unit/test_reviewer_prose_mismatch.bats` — 6/6 green
- `bats tests/unit/reviewer_human_ac_mechanical_signal.bats` — 5/5 green (no regression on inverse detector)
- `bin/fw reviewer T-1811` before re-class: 2 findings (CONCERN-on-AC#3 + prose-mismatch-on-AC#1)
- `bin/fw reviewer T-1811` after re-class: 1 finding (CONCERN-on-AC#3 only) — prose-mismatch correctly silenced
- L-409, L-410 captured in `.context/project/learnings.yaml`
- `policy/anti-patterns.yaml` extended with `reviewer-prose-mismatch` catalogue entry

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

### 2026-05-20T07:28:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1947-reviewer-prose-quality-mis-routing-guard.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-c9cc7257
- **Timestamp:** 2026-05-20T07:43:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-20T07:43:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
