---
id: T-2141
name: "CLAUDE.md/AGENT.md/block-message review-vs-inception class distinction sweep
  (T-2138 V3)"
description: >
  T-2138 V3 sibling to T-2139. Sweep prose surfaces where review-vs-inception distinction
  is currently muddled. Surfaces: CLAUDE.md §Presenting Work for Human Review, agents/task-create/AGENT.md,
  hook block messages, prompt preambles. Rewrite three or four sentences each to teach
  the class distinction proactively, complementing T-2139's class-aware block message
  which teaches at violation time. T-2138 Q3-both: both block-message teaching (V1/T-2139)
  AND prose sweep (V3) ship.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: [T-2138, T-2139]
arc_id: inception-review-loop
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-31T13:30:33Z
last_update: '2026-06-11T22:24:08Z'
date_finished: 2026-05-31T23:17:04Z
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
      D2: 1
      D3: 3
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2141: CLAUDE.md/AGENT.md/block-message review-vs-inception class distinction sweep (T-2138 V3)

## Context

T-2138 V3 — author-time prose sweep across surfaces where the review-vs-inception class distinction is currently muddled or absent. Complements T-2139's class-aware block-message (violation-time teaching) by teaching at the surfaces agents read BEFORE filing a handoff: CLAUDE.md, AGENT.md, inception/review error messages, and the dispatch preamble.

Two decision classes are at play, with distinct Watchtower routes (T-2125/T-2129 codified the URL mapping but not the *class-distinction prose* that frames it):
  - **Inception go/no-go** — `workflow_type: inception` → `/inception/<id>`, recorded via `fw inception decide` (agent-blocked, T-1259)
  - **Partial-complete review** — build task with unchecked Human ACs → `/review/<id>`, recorded by the human ticking the box + `fw task update --status work-completed`

Source diagnosis: `docs/reports/T-2138-review-handoff-author-time-gap.md` + T-2125 URL-class codification.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md §Presenting Work for Human Review gains one explicit "two decision classes" framing sentence near the per-class URL table — name the inception-vs-partial-complete distinction in plain English before the table lands, so readers don't treat the table as URL trivia.
- [x] `lib/inception.sh` agent-block message (the `$CLAUDECODE=1` refusal at L425) names the class — current text says "Inception decisions belong to the human" without distinguishing from review decisions; updated text disambiguates from `/review/<id>` decisions explicitly.
- [x] `agents/task-create/AGENT.md` gains a brief "Handoff classes" subsection naming the two routes (inception → `/inception/<id>`, partial-complete → `/review/<id>`) so task-creation-time agents know which gate they're authoring toward.
- [x] `agents/dispatch/preamble.md` reviewed for handoff routing references; updated only if it mentions handoff URLs/classes (otherwise the absence is captured in Evolution). *(Survey: zero matches for `review|partial-complete|/inception|/review|fw task review|fw inception decide` — preamble is about Task-tool dispatch I/O, not handoff routing. Documented in Evolution.)*
- [x] No existing test fails (run `python3 -m pytest tests/unit/test_reviewer_*.py -q` to confirm the 285-test reviewer suite still passes; CLAUDE.md/AGENT.md prose changes shouldn't affect tests but the run is the proof). *(285 passed in 2.95s — confirmed.)*

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

# T-2141 verification — four surface edits + regression test
grep -q "Two decision classes, one CLI verb (T-2141)" CLAUDE.md
grep -q "Inception decisions (workflow_type: inception" lib/inception.sh
grep -q "## Handoff classes (T-2125, T-2141)" agents/task-create/AGENT.md
bash -n lib/inception.sh
python3 -m pytest tests/unit/test_reviewer_review_link_homework.py tests/unit/test_reviewer_audience_mismatch.py tests/unit/test_reviewer_defer_as_hedge.py -q

## Recommendation

**Recommendation:** GO — close T-2141; arc-008 review-vs-inception class-distinction prose sweep complete.

**Rationale:** Three of four surfaces gained explicit class-distinguishing prose (CLAUDE.md framing sentence, lib/inception.sh block message, agents/task-create/AGENT.md Handoff-classes subsection). The fourth surface (agents/dispatch/preamble.md) had zero handoff-routing references on survey — preamble is about Task-tool dispatch I/O contracts, not handoff routing — so no edit was needed; absence captured in Evolution. Reviewer regression suite (285 tests across the 13-detector catalogue + sibling arc-008 detectors shipped T-2147 + T-2145 + T-2140 this week) still PASS. Lands the author-time teaching leg of T-2138 Q3-both (block-message teaching T-2139 V1 + prose sweep T-2141 V3 both shipped).

**Evidence:**
- CLAUDE.md edit: §Presenting Work for Human Review now carries "Two decision classes, one CLI verb (T-2141)" block immediately before the per-class URL table — frames the table as documenting two structurally-distinct decisions, not URL trivia.
- lib/inception.sh edit: agent-block message at L425 now reads "Inception decisions (workflow_type: inception → GO/NO-GO/DEFER on /inception/<id>) belong to the human. This is structurally distinct from partial-complete review (build task with unchecked Human ACs → /review/<id>) — both look like 'reviews' but route to different Watchtower pages and answer different operator questions (T-2125, T-2141)." `bash -n` passes.
- agents/task-create/AGENT.md edit: gains "## Handoff classes (T-2125, T-2141)" subsection with the 2-row table mapping `workflow_type: inception` → `/inception/<id>` (decide verb) and `workflow_type: build + ### Human ACs` → `/review/<id>` (tick + work-completed verb) so task-creation-time agents know which gate they're authoring toward.
- agents/dispatch/preamble.md: surveyed for handoff routing references (`review|partial-complete|/inception|/review|fw task review|fw inception decide`) — zero matches. Preamble's scope is Task-tool dispatch I/O conventions, not handoff routing; no edit needed.
- Regression: 285 reviewer tests pass (prose-only changes had zero detector impact).
- arc-008 "two-layer governance" pair completed for the review-handoff class: T-2139 V1 (transition-time block message — violation-time teaching) + T-2141 V3 (author-time prose surfaces — pre-violation teaching). Same shape as the T-2147/T-2145/T-2140 detector triplet's scan-time + CLAUDE.md author-time pairs.

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

### 2026-06-01 — dispatch preamble had no handoff-routing surface to teach
- **What changed:** AC #4 expected the dispatch preamble to either gain class-distinguishing prose OR have its absence captured. Survey result: `grep -nE "review|partial-complete|/inception|/review|fw task review|fw inception decide" agents/dispatch/preamble.md` returns zero matches. The preamble's scope is Task-tool dispatch I/O contracts (write-to-disk, return ≤5 lines, /tmp file conventions) — handoff routing is downstream of dispatch, not part of it.
- **Plan impact:** AC #4 ticked without an edit. Original spec wording ("Rewrite three or four sentences each" — T-2141 description) over-counted the surfaces; only three carried handoff-routing prose worth teaching.
- **Triggered:** None. The dispatch surface remains intentionally orthogonal to handoff routing — that's a feature of the layering, not a gap.

### 2026-06-01 — author-time + violation-time pair shape now standard for arc-008
- **What changed:** This task closes the second instance of arc-008's "two-layer governance" pattern: author-time teach + structural backstop. First instance was the detector triplet (T-2147 + T-2145 + T-2140 reviewer detectors paired with CLAUDE.md teaching paragraphs). Second instance: T-2139 (V1 transition-time class-aware block message — violation-time teach) + T-2141 (V3 prose surfaces — author-time teach) for the review-handoff class.
- **Plan impact:** No spec deviation. Worth noting that the same shape — *catch the failure where it happens AND teach where it could have been prevented* — is now repeated enough to read as a deliberate arc-008 idiom, not a coincidence. Mirrors T-1878 default-bias (author-time) + T-1947 prose-mismatch (scan-time) pair from earlier weeks. Three pairs in the catalogue now.
- **Triggered:** None. The pattern is descriptive at this point; future arc-008 work can reach for it without filing.

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

### 2026-05-31T13:30:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2141-claudemdagentmdblock-message-review-vs-i.md
- **Context:** Initial task creation

### 2026-05-31T13:30:48Z — status-update [task-update-agent]
- **Change:** tags: +T-2138-followup

### 2026-05-31T23:12:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-084eebfb
- **Timestamp:** 2026-06-02T15:01:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-31T23:17:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
