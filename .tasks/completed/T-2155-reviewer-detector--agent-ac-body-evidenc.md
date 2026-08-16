---
id: T-2155
name: "reviewer detector — Agent AC body-evidence present but checkbox unticked (T-1761
  prevention)"
description: >
  Static-scan detector for the recurring T-1761-class block: Agent AC text describes
  work that is plainly satisfied in the body (Recommendation / RCA / Decision / Evolution
  / referenced artifact) but the checkbox stays unticked. Reviewer agent currently
  has no scan for this — agent ticks manually after the gate refuses, which is exactly
  the after-the-fact pattern T-1831 C-4 calls out. CONCERN-level, partial-confidence
  pattern; pair-task to T-2145 (defer-as-hedge) and T-2147 (audience-mismatch). HV-LC:
  ~1 detector + unit tests + a real-task smoke. Arc cut: arc-003 (reviewer is orchestrator-adjacent)
  + arc-006 (BVP scoring depends on Agent AC ticks).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [arc-003, arc-006, reviewer, governance, t-1761-prevention]
components: [lib/reviewer/static_scan.py, 
      tests/unit/test_reviewer_ac_evidence_untick.py]
related_tasks: [T-1761, T-2145, T-2147, T-2059, T-1985, T-1831]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-01T08:50:00Z
last_update: '2026-08-16T22:24:55Z'
date_finished: 2026-06-01T08:58:30Z
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
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 5
      D2: 0
      D3: 2
      D4: 3
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4-5 (body:new-class); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:55Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 5
      D2: 0
      D3: 2
      D4: 3
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4-5 (body:new-class); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2155: reviewer detector — Agent AC body-evidence present but checkbox unticked (T-1761 prevention)

## Context

T-1761 (Watchtower decide flow, session S-2026-0601-08xx) hit the recurring "Agent AC body-evidence present, checkbox unticked" block: the AC `[ ] Inception: evaluate naming-convention heuristic vs marginal status quo; produce go/no-go in research artifact docs/reports/T-1761-auto-classify-heuristic.md` pointed at an artifact that **existed**, with a complete `**Recommendation:** GO` block inside — yet the box stayed `[ ]`. The decide flow refused. Agent ticked manually to unblock, which is exactly the after-the-fact pattern T-1831 C-4 calls out: "writing the RCA/candidates/recommendation in the body does NOT tick the boxes; you have to do it explicitly."

The reviewer agent's existing catalogue covers neighbour classes but not this one:
- `detect_ac_verify_mismatch` — fires when a **ticked** AC names a path that verification never touches (opposite direction)
- `detect_defer_as_hedge` (T-2145) — fires on **inception Recommendation:DEFER** with complete evidence trail
- `detect_human_ac_mechanical_signal` — fires on `[REVIEW]` Human ACs with grep-able Expected
- T-1985 auto-tick — automatically ticks `[REVIEWER]`-prefix Agent ACs that pass review

The gap: an **untickled Agent AC** (no `[REVIEWER]` prefix) that references a `docs/reports/T-NNNN-*.md` artifact which exists with substantive content. Auto-tick can't help (prefix wrong); ac-verify-mismatch can't help (AC not ticked, no verification cross-check); defer-as-hedge can't help (only fires on inception Recommendation line). This detector closes that gap: catch-before-handoff, CONCERN-level, partial-confidence.

**Gate shape (all must hold):**
1. AC under `### Agent` subhead
2. AC is unticked (`- [ ]`)
3. AC does NOT have `[REVIEWER]` prefix (T-1985 owns those)
4. AC text mentions a `docs/reports/T-NNNN-*.md` artifact path
5. Referenced artifact exists on disk AND contains substantive content (≥1 of: `**Recommendation:**` line, `## Recommendation` heading, file size ≥1500 bytes)
6. No author opt-out marker (`ac-evidence-untick-ok` in AC body or surrounding lines)

Pair-tasks: T-2145 (defer-as-hedge), T-2147 (audience-mismatch backstop), T-2059 (L-387 SIGPIPE) — all CONCERN-level reviewer-time backstops for author-time discipline that didn't fire.

## Acceptance Criteria

### Agent
- [x] `detect_ac_evidence_untick` function exists in `lib/reviewer/static_scan.py` with the six-gate shape documented in §Context.
- [x] Detector is wired into `scan_task()` (sits alongside `detect_defer_as_hedge` / `detect_review_link_homework`).
- [x] Pattern id `ac-evidence-untick`; lie_severity `partial`; detection_confidence `heuristic`; CONCERN-level under the standard verdict thresholds.
- [x] Unit test file `tests/unit/test_reviewer_ac_evidence_untick.py` with 10 cases (≥7 spec): (a) positive — Agent AC unticked + artifact exists + Recommendation present; (b) negative — AC ticked; (c) negative — no artifact path in AC text; (d) negative — artifact path but file missing; (e) negative — `[REVIEWER]`-prefix (auto-tick territory); (f) negative — opt-out marker present; (g) negative — Human-section AC; (h) positive — substantive-size proxy without Recommendation marker; (i) negative — skeleton artifact; (j) two-AC mixed batch (only unticked fires).
- [x] All existing reviewer unit tests still pass (`python3 -m pytest tests/unit/test_reviewer_*.py -q`) — 295 passed in 3.04s.
- [x] Detector exits cleanly on every task in `.tasks/completed/` and `.tasks/active/` (no exception spam) — corpus walk: 2121 tasks scanned, 0 exceptions, 0 false positives. Synthesized T-1761 pre-fix state correctly fires one finding (`artifact=docs/reports/T-1761-auto-classify-heuristic.md; markers=[Recommendation: line, size=6340B]`).
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
       - [x] [REVIEWER] Block message names both bypass mechanisms
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

# T-2155 verification commands (L-387 safe — direct grep on file, capture-then-grep on cmd output):
grep -q "def detect_ac_evidence_untick" lib/reviewer/static_scan.py
grep -q "ac-evidence-untick" lib/reviewer/static_scan.py
python3 -c "import ast; ast.parse(open('lib/reviewer/static_scan.py').read())"
out=$(python3 -m pytest tests/unit/test_reviewer_ac_evidence_untick.py -q 2>&1); echo "$out" | grep -qE "[0-9]+ passed"
out2=$(python3 -m pytest tests/unit/test_reviewer_static_scan.py tests/unit/test_reviewer_audience_mismatch.py tests/unit/test_reviewer_defer_as_hedge.py tests/unit/test_reviewer_auto_tick.py tests/unit/test_reviewer_review_link_homework.py tests/unit/test_reviewer_human_ac_mechanical_signal.py -q 2>&1); echo "$out2" | grep -qE "[0-9]+ passed"
out3=$(python3 -c "from lib.reviewer.static_scan import detect_ac_evidence_untick, scan_task; print('imports ok')" 2>&1); echo "$out3" | grep -q "imports ok"

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

### 2026-06-01 — Substantive-content proxy includes size threshold

- **What changed:** Original gate-5 design was "artifact contains a `**Recommendation:**` line OR `## Recommendation` heading". Corpus walk surfaced a class of legitimate cases where the artifact is research-shaped (5-Whys, dialogue log, options matrix) but doesn't yet have a Recommendation block — the AC nonetheless promises a deliverable that plainly exists.
- **Plan impact:** Added a third disjunct — file size ≥1500 bytes — as a proxy for "non-skeleton". Test case (h) pins this directly.
- **Triggered:** None — single-task scope cut. The 1500B threshold is documented in the detector docstring; tunable if FP class emerges.

### 2026-06-01 — Opt-out marker mirrors existing detector convention

- **What changed:** Decided to use the same `ac-evidence-untick-ok` literal marker pattern that defer-as-hedge and review-link-homework use, rather than introducing a new mechanism. Author drops the literal into the AC body when human review is genuinely in flight.
- **Plan impact:** None — chose for convention parity rather than novelty. Test case (f) pins.
- **Triggered:** None.

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

**Recommendation:** GO

**Rationale:** Pure-add static-scan detector — 6/6 Agent ACs pass, 10 new unit tests cover the spec'd 7 cases + 3 extras (size-proxy, skeleton-silence, mixed-batch), full reviewer test suite of 295 tests stays green, 2121-task corpus walk yields 0 exceptions and 0 false positives, and synthesised T-1761 pre-fix state correctly produces exactly one finding citing `artifact=docs/reports/T-1761-auto-classify-heuristic.md; markers=[Recommendation: line, size=6340B]`. CONCERN-level (partial severity) under the standard thresholds — surfaces the after-the-fact tick pattern without blocking close. Closes the specific gap between `detect_ac_verify_mismatch` (ticked + path), `detect_defer_as_hedge` (inception Recommendation:DEFER), and `_should_auto_tick` ([REVIEWER]-prefix only) — the unticked-plain-Agent-AC with existing artifact was the uncovered class.

**Evidence:**
- Detector: `lib/reviewer/static_scan.py` — `detect_ac_evidence_untick(ac_section, task_path)` with six gates (Agent subhead, unticked, no `[REVIEWER]` prefix, `docs/reports/T-NNNN-*.md` reference, artifact exists with substantive content, no opt-out marker).
- Wired: `scan_task()` — sits after `detect_review_link_homework`; v1.6 +4.
- Unit tests: `tests/unit/test_reviewer_ac_evidence_untick.py` — `10 passed in 0.12s`. Cases (a)…(j) per AC #4.
- Regression: `python3 -m pytest tests/unit/test_reviewer_*.py -q` → `295 passed in 3.04s`.
- Corpus walk: 2121 tasks (`.tasks/active/` + `.tasks/completed/`), 0 findings, 0 exceptions — corpus is currently clean (T-1761 was the only known instance and it was hand-fixed in S-2026-0601-08xx).
- Synthesised T-1761 smoke: flipping the `[x]` back to `[ ]` on `.tasks/completed/T-1761-orchestrator-mcp-scan-auto-classify-by-n.md` produces `1 finding(s) pattern=ac-evidence-untick sev=partial`.

**What's next:**
- The detector handles the explicit-artifact pattern (`docs/reports/T-NNNN-*.md`). A future widening could cover Agent ACs whose body-evidence lives in `## RCA` / `## Decision` / `## Evolution` sections rather than an external artifact — but the false-positive surface there is large (those sections often outlive a partial-complete review cycle). Leaving as a separate decision if a second instance class appears.
- Two pair-tasks remain open from session memory: the AC routing-ladder rails (T-1947, T-2143, T-2147) are author-time discipline; this detector is the reviewer-time backstop for a fourth axis (work-done vs. tick-state) the ladder doesn't cover. No coordination required — they compose orthogonally.

## Updates

### 2026-06-01T08:50:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2155-reviewer-detector--agent-ac-body-evidenc.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-15d3f7e1
- **Timestamp:** 2026-06-02T15:01:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-06-01T08:58:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
