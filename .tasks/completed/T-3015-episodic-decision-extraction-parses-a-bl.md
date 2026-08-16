---
id: T-3015
name: "episodic decision extraction parses a block-structured document line by line"
description: >
  episodic decision extraction parses a block-structured document line by line

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/context/lib/episodic.sh, 
      agents/context/lib/extract_decisions.py, 
      tests/unit/episodic_yaml_decision_escape.bats]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-08-15T10:17:39Z
last_update: '2026-08-16T22:25:26Z'
date_finished: 2026-08-15T10:32:53Z
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
  - ts: '2026-08-15T10:30:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-15T10:30:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3015: episodic decision extraction parses a block-structured document line by line

## Context

`agents/context/lib/episodic.sh` extracts the task file's `## Decisions` section
by reading it **line by line out of a block-structured document**. One root cause,
three symptoms — measured in this tree at **2039 of 2649 episodics (77%)**, and
**19 of the last 20 by mtime**, so it fires on every task close rather than being
stable archive cruft.

Reported by 050-email-archive (`G-EPISODIC-PLACEHOLDER-LEAK`, refresh #2, opened
2026-06-09, 2mo+ of framework silence) and independently reproduced by
832-Workflow-designer at 81% (chat-arc 11890, 11892). Both filings are correct.
832's addition is the load-bearing one: **the placeholder-regex fix email-archive
proposed closes symptom 1 only, and removes the tell while 2 and 3 keep running.**
That is the false-green class — strictly worse than the visible leak.

## Acceptance Criteria

### Agent
- [x] Extractor strips HTML comment **spans** (not just delimiter lines), so a
      Decisions section consisting solely of the template comment yields no
      decision entries
- [x] Multi-line `**Chose:** / **Why:** / **Rejected:**` values are captured whole
      — a value wrapping onto continuation lines is not cut at the first newline
- [x] The silent `head -20` cap is gone; if any cap remains it is reported, not silent
- [x] Emitted YAML parses under `yaml.safe_load` with apostrophes, backticks and
      double quotes present in values (L-392 / L-385 / T-1871 regression guard)
- [x] Every verdict is pinned against a **discriminating fixture** — a fixture that
      produces the opposite verdict — so no leg can pass by never firing (PL-206)
- [x] Proven on a live artifact, not only fixtures: old and new extraction paths run
      side by side on the same real unfilled task file — old emits the placeholder
      lines, new emits nothing; and a real *filled* task still yields its decisions
      with `'` correctly doubled
- [x] Historical episodics are NOT bulk-rewritten (explicit non-goal — they are the
      evidence of reach, and rewriting stored memory is an operator decision)

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
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
out=$(python3 -m pytest tests/unit/test_extract_decisions.py -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
# Corpus-wide: the extractor over every real task file emits no placeholder text.
# NOT this task's own episodic — that is written after the gate runs, so a line
# asserting on it can only ever pass by being absent. Same shape as the clock
# that measured itself (T-3012).
python3 agents/context/lib/extract_decisions.py .tasks/templates/default.md > /tmp/.t3015-tmpl 2>&1 && ! grep -q "what was decided" /tmp/.t3015-tmpl
for f in .tasks/active/T-*.md; do python3 agents/context/lib/extract_decisions.py "$f"; done > /tmp/.t3015-all 2>&1 && ! grep -qE "\[what was decided\]|\[date\] . \[topic\]|\[rationale\]" /tmp/.t3015-all
python3 -c "import yaml,sys; yaml.safe_load('decisions:\n' + open('/tmp/.t3015-all').read()); print('parses')" > /tmp/.t3015-yaml && grep -q parses /tmp/.t3015-yaml
# Discriminating control: a genuinely filled section must still yield a decision.
python3 agents/context/lib/extract_decisions.py .tasks/completed/T-554-single-started-work-gate--enforce-one-ac.md > /tmp/.t3015-ctl 2>&1 && grep -q "Advisory vs blocking gate" /tmp/.t3015-ctl
out=$(bats tests/unit/episodic_yaml_decision_escape.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'

## RCA

**Symptom:** 2039 of 2649 episodics (77%) — and 19 of the last 20 by mtime — carry
verbatim template placeholder text as recorded decisions (`decision: '[date] —
[topic]'`, `chose: '[what was decided]'`). Two independent consumer projects
reported it before this tree looked.

**Root cause:** `episodic.sh` parses a **block-structured document line by line**.
`:147` filters `^<!--` and `^-->` — the comment *delimiters* — but not the comment
*interior*, and the task template's `## Decisions` block is exactly such a
multi-line comment containing `### [date] — [topic]` and `- **Chose:** [what was
decided]`. Those lines survive the filter and reach the `^### ` / `**Chose:**`
handlers at `:342-353`, which cannot tell them from real content. The same
line-oriented assumption produces the other two symptoms: `:346` runs `sed` on a
single `$line`, so a value wrapping onto continuation lines is cut at the first
newline; `:147`'s `head -20` drops the tail of any longer section with no note.

**Why structurally allowed:** the generator had no test that fed it a task file
whose Decisions section was *unfilled* — i.e. the overwhelmingly common case. Every
fixture exercised the filled path. The check was verified only in the state it
rarely occupies, so the leak was invisible to CI and visible only to whoever read
an episodic by hand. Compounding it, the leak is **self-camouflaging by volume**:
at 77% prevalence the placeholder text reads as normal generator output rather than
as a defect. And the truncation symptom has no tell at all — a phantom entry looks
like junk, a clipped rationale reads as complete.

**Prevention:** the extractor is a separately testable unit
(`agents/context/lib/extract_decisions.py`) with a pytest suite in which **every
verdict is pinned against a discriminating fixture** — the unfilled-template case
that was never tested is now the first leg. Per PL-206, a control whose stimulus
was built so it never fires is worth nothing; the negative legs assert the
extractor *does* emit decisions for a genuinely filled section, so "emits nothing"
cannot pass as success.

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

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
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

## Updates

### 2026-08-15T10:17:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3015-episodic-decision-extraction-parses-a-bl.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-30a853dd
- **Timestamp:** 2026-08-15T10:33:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-15T10:32:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
