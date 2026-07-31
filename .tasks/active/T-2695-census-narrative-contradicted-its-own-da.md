---
id: T-2695
name: "census narrative contradicted its own data — v8 promotion evidence corrected"
description: >
  Rail-344 reported the knowledge-leveling overflow as first appearing at v6 and inherited unchanged by v7/v8. The all-versions census data says otherwise: v2/v3 spill, v4/v5 are overflow-clean, v6 regresses, v7/v8 spill at different magnitudes with different witnesses. 832 caught the contradiction from my own reported numbers at rail 345. Correct the record and re-issue the promotion evidence.

status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: []
components: []
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
created: 2026-07-31T08:50:38Z
last_update: 2026-07-31T08:50:38Z
date_finished: null
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

# T-2695: census narrative contradicted its own data — v8 promotion evidence corrected

## Context

T-2694 shipped a correct all-versions census. The *narrative* I wrote from it (rail 344)
was wrong, and it was the narrative — not the tool output — that reached both the peer and
the operator's v8 promotion decision. 832 caught it at rail 345 from the numbers I had
myself reported: I told them `draft-knowledge-leveling@v3` carries two overflow findings and
in the same message said v6 *introduced* the overflow.

The tool's own data (verified this session):

| version | lane-geometry | lane-overflow |
|---------|---------------|---------------|
| v2 | wholesale inversion (5/5, 11/11) | agent 194px, framework 44px |
| v3 | wholesale inversion (5/5, 11/11) | agent 194px, framework 44px |
| v4 | wholesale inversion (5/5, 11/11) | — none — |
| v5 | wholesale inversion (5/5, 7/7) | — none — |
| v6 | wholesale inversion (3/3, 9/9) | agent 262px, framework 130px |
| v7 | **subset** crossing (2/7, 5/5) | agent 307px, framework 36px |
| v8 | **subset** crossing (2/7, 5/5) | agent 307px, framework 36px |

So the sequence is spill → **repaired at v4** → **regressed at v6** → still spilling at
v7/v8 with different witnesses and magnitudes. Two of my rail-344 claims were false:
"v6 introduces both spills" and "v7/v8 inherit them unchanged".

The failure is not in the census. It is that a per-version *summary* existed only as hand-
composed prose, so nothing could disagree with it. The fix is to make the tool emit the
timeline it already knows.

## Acceptance Criteria

### Agent
- [x] `corpus_lint.py --all-versions --summary` emits one machine-generated row per stored
      version listing its finding classes, so a per-version narrative is read off the tool
      rather than composed from memory of a scrolled detail dump
- [x] Each summary row carries the version and a witness identity, not only a tally —
      832's rail-345 rule, and the correction to my own rail-339/344 imprecision (v3 and v8
      both report 3 findings and are different defects)
- [x] A regression test pins the corrected `draft-knowledge-leveling` timeline: overflow
      present at v2/v3, **absent at v4/v5**, present again from v6, and the geometry class
      changing wholesale → subset at v7. A future re-narration that contradicts this goes red
- [x] Default sweep is untouched: same 4 findings, same exit code, existing baseline test green
- [x] Every artifact committed under T-2694 that repeats the wrong timeline is corrected in
      place (task file, episodic, rail record) — or confirmed by grep to contain none
- [x] Rail reply posted to 832 correcting the record, stating which of my claims were false
      and what the corrected timeline changes about the promotion question

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

python3 -m pytest tests/unit/test_corpus_lint.py -q
out=$(python3 tools/corpus_lint.py --all-versions --summary 2>&1); echo "$out" | grep -q "draft-knowledge-leveling@v4  lane-geometry"
out=$(python3 tools/corpus_lint.py 2>&1); echo "$out" | grep -q "^4 finding(s)"
# the corrected narrative must not survive anywhere in the record
test "$(grep -rc 'v6 introduc' .tasks/completed/T-2694-corpus-lint-judges-latest-only--stored-v.md)" = "0"

## RCA

**Symptom:** rail 344 told 832 and the operator that the knowledge-leveling lane-overflow
entered at v6 and was inherited unchanged by v7/v8. Both halves false. 832 caught it at
rail 345 from the numbers in that same message.

**Root cause:** the per-version timeline existed only as hand-composed prose. The census
(T-2694) reported every version correctly; the summary was written by reading a scrolled
detail dump and remembering it. Nothing could contradict the sentence because no
machine-generated summary existed to disagree with.

**Why structurally allowed:** every rule built this week judges *bytes*. Nothing judges the
narration of those bytes, and narration is what reaches the peer rail and the operator's
decision. The T-2694 task file demonstrates the gap in miniature — its census table lists
v2/v3 at 3 findings each, one paragraph above the sentence claiming the spill entered at
v6. A correct tool with an unchecked narration layer is a false green with extra steps.

**Prevention:** `--summary` generates the timeline the tool already knows, so the narrative
is quoted rather than composed. Two shape decisions carry the weight: clean versions are
printed (an absence — v4/v5 overflow-free — is what makes v6 a regression rather than a
property, and a list of offenders cannot express "repaired here"), and skips are carried
per row (a roll-up that dropped them rebuilds the false green T-2690 closed). The corrected
timeline is pinned by test, so a future re-narration that contradicts it goes red.

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

## Updates

### 2026-07-31T08:50:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2695-census-narrative-contradicted-its-own-da.md
- **Context:** Initial task creation
