---
id: T-2694
name: "corpus lint judges latest only — stored versions never re-judged when rules strengthen"
description: >
  Default sweep resolves meta['latest'] per project, so a map that passed under a weaker rule set is never re-examined when the rules improve. Named targets resolve to latest too; there is no map@vN addressing. Surfaced by 832 rail 342.

status: captured
workflow_type: build
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
created: 2026-07-31T08:16:01Z
last_update: 2026-07-31T08:16:01Z
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

# T-2694: corpus lint judges latest only — stored versions never re-judged when rules strengthen

## Context

`tools/corpus_lint.py:collect_targets` resolves `meta["latest"]` and nothing else — for the
default whole-store sweep *and* for explicitly named map ids. A stored version is reachable
only by raw file path (`…/draft-knowledge-leveling/v3.bpmn`); there is no `map@vN` address,
and `draft-*` projects are skipped entirely by the default sweep (T-2623, deliberate).

**The consequence is not "some files are unscanned". It is that the corpus is judged by
whatever rules existed at write-time and never re-judged when the rules get stronger** —
and the rules got stronger twice this week alone (T-2689 re-based lane-overflow from
membership onto containment; T-2690 added the skip channel). Every version that passed
under the weaker rule set still reads as "clean" because nothing ever asked again.

Surfaced empirically, not theoretically: at rail 342, 832 ran our own `lane_geometry`
predicate over our pinned `draft-knowledge-leveling v3` and found a **wholesale lane
inversion** (5/5 and 11/11 nodes crossing). Reproduced here witness-for-witness, plus two
overflow findings their rule cannot see. **v3 had never been judged by us at all.** I named
this to them at rail 343 as "a version-scope blind spot of the same family as the skip
problem — not a wrong answer, an unasked question."

Third instance this week of one class: **a scope decision made for a good reason and never
re-examined as the surface changed.** Siblings: T-2690 (skip vs pass), T-2692 causes 1 and 2
(issuer-indexed catalogue; blanket vendored-tree allowlist). Cf. L-521, L-522.

Note this is *not* an argument for rewriting history. Old versions are immutable by design
(D-Immutability). The ask is that they be **judged**, and that the result be visible.

## Acceptance Criteria

### Agent
- [ ] `map@vN` is addressable as a lint target, so any stored version can be named directly
      rather than reached by raw file path
- [ ] A sweep mode judges **every stored version**, not just `latest` — off by default so
      the standing baseline and its pinned count do not move
- [ ] Findings carry the version they came from, so a v3 finding is never mistaken for a
      finding against the promotion candidate (my own rail-339 imprecision: knowledge-leveling
      is a two-node authority call at v8 and a wholesale inversion at v3 — the version *is*
      the finding)
- [ ] Running the all-versions sweep over the live store produces a per-version report, and
      its output is recorded here as the first census — including `draft-knowledge-leveling v3`,
      whose expected result is already known independently from 832's run
- [ ] The default sweep's finding count is **unchanged** (baseline 4), proven by test, so
      this adds a lens without moving the gate
- [ ] Tests pin: `map@vN` resolution, an unknown version failing loudly rather than falling
      back to latest, and the all-versions mode finding something the default sweep does not
- [ ] Whether drafts join the all-versions sweep is decided explicitly and written down —
      T-2623 excluded them from the *baseline* for a good reason; that reason may or may not
      extend to a census that does not feed the gate

## First census — run before building anything

`corpus lint` already accepts raw file paths, so the whole-history answer needs no code
change; only the *addressing* and the *sweep* do. Running it first means the tool gets built
against a known-correct expected output instead of the tool defining its own truth.

**28 stored versions judged, 14 carry findings.** The default sweep reports 4.

| map@version | findings | rules |
|---|---|---|
| aef-session-lifecycle@v1 | 2 | lane-geometry, lane-overflow |
| aef-dispatch-loop@v1, @v2 | 1 each | emitterless-typed-event (known, T-2659 rail RED) |
| draft-knowledge-leveling@v2, v3, v6, v7, **v8** | 3 each | lane-geometry ×1, lane-overflow ×2 |
| draft-knowledge-leveling@v4, v5 | 1 each | lane-geometry only — **no spill** |
| draft-knowledge-leveling@v1 | 0 | — |
| draft-exception-handling@v2 | 1 | lane-geometry (v1, v3 clean) |
| draft-task-creation@v2 | 1 | lane-geometry (v1, v3 clean) |
| draft-trigger-handling@v1 | 1 | lane-overflow (v2–v6 clean — later authoring fixed it) |
| t2584-scratch@v1 | 1 | legacy-ref (known ghost referent) |

**Independent confirmation of the 832 exchange.** `draft-knowledge-leveling@v3` returns
exactly 1 lane-geometry + 2 lane-overflow — the same shape reported at rail 343 (wholesale
inversion 5/5 and 11/11, plus agent 194px and framework 44px spills). Two different runs,
same witnesses.

**★ The finding worth acting on: the spill entered at v6 and was carried forward.**
v5 has the inversion but **no** overflow; v6 adds both spills (agent 262px, framework 130px)
and v7/v8 inherit them. Node ids change across that boundary (`agt_0_healing` →
`agt_2_healing`, `fw_end_already` → `fw_7_refused`), so v5→v6 was a substantial
re-authoring that grew content past the declared bands. Nobody saw it because the sweep
only ever judged `latest` **and** the overflow rule did not exist yet — T-2688/T-2689
shipped afterwards. This is precisely the blind spot this task describes, caught in its
own first census.

That is decision-relevant for the pending v8 promotion: the spill is not inherent to the
map, it is a regression from one authoring step, and v4/v5 show the same content fitting.

**Caveat, stated rather than buried:** a finding count is not a classification. v3 and v8
both report "3 findings", but v3 is a wholesale inversion and v8 is the two-node authority
call — the detail distinguishes them, the count does not. This is the same imprecision I
made at rail 339 and is why the third AC above requires findings to carry their version.

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

### 2026-07-31T08:16:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2694-corpus-lint-judges-latest-only--stored-v.md
- **Context:** Initial task creation
