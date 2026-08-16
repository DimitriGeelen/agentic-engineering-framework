---
id: T-2148
name: "CLAUDE.md update — add audience axis to three-prefix table (T-2143 leg C)"
description: >
  CLAUDE.md update — add audience axis to three-prefix table (T-2143 leg C)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [arc-008, claudemd, audience-mismatch, ac-routing]
components: [CLAUDE.md]
related_tasks: [T-2143, T-2139, T-2147, T-1811, T-1878, T-1947]
arc_id: inception-review-loop
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-31T17:28:02Z
last_update: '2026-08-16T22:24:55Z'
date_finished: 2026-05-31T20:06:37Z
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
  - ts: '2026-05-31T17:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-31T17:30:03Z'
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
      D3: 2
      D4: 2
      F-RECALL: 4
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=4 
      (body/components:instruction-sync); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:55Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 4
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=4 
      (body/components:instruction-sync); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2148: CLAUDE.md update — add audience axis to three-prefix table (T-2143 leg C)

## Context

Leg C of T-2143's Candidate D GO (recorded 2026-05-31T17:25:06Z). Author-time teaching counterpart to T-2147's reviewer detector. T-2143 RCA: CLAUDE.md §AC Classification Guidance and the §Three Human-AC Prefixes table both phrase routing as a property of the **check** (is the Expected clause grep-able?) — never as a property of the **audience** (whose experience is being judged?). Single-axis routing heuristic; T-2148 adds the missing axis.

Full diagnosis + suggested table revision in `docs/reports/T-2143-routing-recursion-rca.md` §Candidate C.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md §AC Classification Guidance gains an explicit fourth question to the "Make it a Human AC if ANY apply" list: **"6. Subject of the judgment is *human experience*** — not an agent's experience. If the AC's wording reads 'agent who…' / 'agent reads…' / 'for an agent…', the audience is agents, not the operator; route to Agent AC (self-eval) instead, regardless of how subjective the judgment is." — added as item #6 with full operator-seat test and T-2143 origin reference. Verbatim opening: "Subject of the judgment is human experience".
- [x] CLAUDE.md §Three Human-AC Prefixes table gains a new column or post-table note: "Audience axis — `[REVIEW]` and `[REVIEWER]` both presume the *human* is the verifier. If the AC subject is agent experience (stderr prose, internal CLI output, framework gate wording), it belongs in `### Agent`, not under any Human prefix." — added as post-table paragraph `**Audience axis (T-2143):**` immediately after the table, before the REVIEWER conversion rule. Author-time test included.
- [x] Worked example added to §AC Classification Guidance using T-2139's recursion (4 rounds, RCA in T-2143, leg A deleted the offending AC). Concrete example shows what the audience-mismatched AC looked like and what the correct routing was. — `**Worked example — audience mismatch (origin: T-2143 / T-2139 round 4):**` paragraph with paraphrased Round-4 AC and the diagnosis that the audience disqualifies any Human prefix entirely.
- [x] Cross-reference paragraph linking T-2143 (RCA), T-2147 (reviewer detector), T-1878 (default-bias rule), T-1947 (prose-mismatch detector). The four together form the routing-discipline ladder. — `**Routing-discipline ladder (T-2143):**` paragraph at the end of the §AC Classification Guidance section reads the four as a composed sequence (check-shape → vocabulary → audience → reviewer-time backstop).
- [x] Memory file written: `feedback_audience_axis_for_ac_routing.md` with the principle ("Check audience before subjectivity. Subjective + agent-audience = Agent self-eval, not Human review.") + link chain. MEMORY.md index updated. — file at `/root/.claude/projects/-opt-999-Agentic-Engineering-Framework/memory/feedback_audience_axis_for_ac_routing.md`; MEMORY.md gained the entry pointing at it as the 2nd CRITICAL block.
- [x] Existing §AC Classification Guidance + §Three Human-AC Prefixes paragraphs are **kept** (not replaced); the new axis appends as additional rules. — verified by diff: items 1-5 of the Human-AC trigger list unchanged, three-prefix table rows unchanged, T-1811 worked example unchanged, T-1947 prose vocabulary paragraph unchanged. Audience-axis content is purely additive.

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

# T-2148 verification commands:
# AC #1 — item 6 added to the "Make it a Human AC" list
grep -q "Subject of the judgment is human experience" CLAUDE.md
# AC #2 — audience-axis post-table paragraph
grep -q "Audience axis (T-2143)" CLAUDE.md
# AC #3 — worked example header present
grep -q "Worked example — audience mismatch (origin: T-2143 / T-2139 round 4)" CLAUDE.md
# AC #4 — routing-discipline ladder paragraph
grep -q "Routing-discipline ladder (T-2143)" CLAUDE.md
# AC #5 — memory file exists and MEMORY.md indexes it
test -f /root/.claude/projects/-opt-999-Agentic-Engineering-Framework/memory/feedback_audience_axis_for_ac_routing.md
grep -q "feedback_audience_axis_for_ac_routing" /root/.claude/projects/-opt-999-Agentic-Engineering-Framework/memory/MEMORY.md
# AC #6 — existing T-1811 worked example untouched (purely additive change)
grep -q "Confirm focus-drift block message is actionable" CLAUDE.md

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

### 2026-05-31 — routing ladder reads cleanly as a composition, not a flat list

- **What changed:** Filing assumed the audience axis was a *fourth bullet* added to a flat list. Build revealed it's a *layered ladder*: T-1878 (check-shape) routes between Human prefixes, T-1947 (vocabulary) routes between `[REVIEW]` and `[REVIEWER]`, T-2143 (audience) routes *out of* Human prefixes entirely, T-2147 catches what slips through. The four compose in a fixed sequence; presenting them as a flat list under-sells the composition.
- **Plan impact:** Added a dedicated `**Routing-discipline ladder (T-2143):**` paragraph instead of just bullets — surfaces the *order* of axes as the design rule (audience-check is the hardest cut and runs before subjectivity). The flat list approach would have read like four unrelated rules.
- **Triggered:** Nothing new — bounded scope shift. The composition framing is also reflected in the memory file's "Routing-discipline ladder" section.

### 2026-05-31 — worked example uses paraphrase, not verbatim AC text

- **What changed:** T-2139's Round-4 AC was deleted in T-2143 leg A. Verbatim quoting would require digging into git history. Paraphrasing the AC shape preserves the teaching value without the archeology cost.
- **Plan impact:** Worked example uses `(paraphrased)` annotation. Steps/Expected use deliberately archetypal wording ("stderr makes the agent unblock itself without operator help") rather than reconstructing the exact prose.
- **Triggered:** Nothing — accepted scope cut.

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

**Recommendation:** GO

**Rationale:** All 6 Agent ACs ticked with content in place; CLAUDE.md edits are purely additive (no existing prose deleted); the routing-discipline ladder reads cleanly as a composition rather than a flat list; memory file + MEMORY.md index updated; the audience axis now sits both as a Human-AC trigger (item #6) and as a post-table paragraph in the Three-Prefix section, with a worked example anchoring it to T-2139's actual recursion. The sibling tasks (T-2147 reviewer detector, T-2141 sweep) can build on this rule.

**Evidence:**
- CLAUDE.md item 6 in "Make it a Human AC" list — operator-seat test, T-2143 origin reference
- CLAUDE.md `**Audience axis (T-2143):**` paragraph after the three-prefix table
- CLAUDE.md `**Worked example — audience mismatch (origin: T-2143 / T-2139 round 4):**` paragraph
- CLAUDE.md `**Routing-discipline ladder (T-2143):**` paragraph composing T-1878 / T-1947 / T-2143 / T-2147
- `/root/.claude/projects/-opt-999-Agentic-Engineering-Framework/memory/feedback_audience_axis_for_ac_routing.md`
- MEMORY.md gains `## CRITICAL: AC Routing — Check AUDIENCE Before Subjectivity (T-2143 origin)` block
- All 7 Verification commands pass (grep-able audit on every added paragraph)

**What's next:** T-2147 (reviewer detector) will scan against the new rule at task close. T-2141 (sweep of existing AGENT.md and block messages for the same routing trap) is the broader-corpus sibling.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-31T17:28:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2148-claudemd-update--add-audience-axis-to-th.md
- **Context:** Initial task creation

### 2026-05-31T17:29:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-05-31T20:02:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-84c6d14c
- **Timestamp:** 2026-06-02T15:01:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-31T20:06:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
