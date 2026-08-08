---
id: T-2870
name: "ratify from the text: laneMeta authority class + workflowMeta kind= carrier gap in frozen mapping-v1"
description: >
  ratify from the text: laneMeta authority class + workflowMeta kind= carrier gap in frozen mapping-v1

status: work-completed
workflow_type: specification
owner: human
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
created: 2026-08-08T14:30:52Z
last_update: 2026-08-08T14:44:05Z
date_finished: 2026-08-08T14:44:05Z
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

# T-2870: ratify from the text: laneMeta authority class + workflowMeta kind= carrier gap in frozen mapping-v1

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Both rulings answered **from the vendored text**, each derivation naming the clause it
      rests on. No ruling derived from rail correspondence — that was the OBS-190 failure
      mode this task exists to spend the fix on.
- [x] Ruling 2's carrier-gap claim is a count, not an impression: `aef:workflowMeta` occurs
      **0** times in the frozen standard.
- [x] Ruling 1's element-granularity hazard **measured** against our own compiler, with a
      positive control proving the instrument sensitive (`@authority` edit → exactly one
      line changes, `owner: human`→`owner: agent`).
- [x] The measurement **refuted** the first draft's prediction (our compiler is conformant:
      `@height`-only edit is byte-identical), and the artifact says so plainly rather than
      keeping the prediction.
- [x] The first measurement run was a false positive (both arms void — cwd broke compiler
      resolution, control shared the defect). Cause diagnosed, guard added, filed OBS-197 +
      a learning, and recorded in the artifact instead of being quietly re-run.
- [x] All three of 832's cold-reading flags **ruled on from the text**, including flag C
      which they invited us to challenge — answered `No` with the §2 struck-through-row
      evidence, not agreed with out of deference.
- [x] Our corpus's exposure to non-frozen keys measured by XML parse (56 diagrams, 652
      attributes, 91% non-frozen) and filed as its own task **T-2871**, not folded in here.

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

- [ ] [REVIEW] These are AEF's **ratification positions**, not just the agent's analysis

  Ratifying a standard is a sovereignty-level act — AEF is a ratifying party, and ruling
  `NO` on 832's proposed form for diagram-kind, and `No` on their "Frozen (v1)" heading,
  commits AEF to positions in a two-party standards process. The evidence is the agent's;
  the position is yours.

  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && cat docs/reports/T-2870-mapping-v1-rulings.md`
     (or read it rendered at the Watchtower link `fw task review T-2870` emits)
  2. Read the "Rulings summary" table at the end — six rows, each with its basis.
  3. The two that carry weight beyond analysis:
     - **Ruling 2** — we tell 832 `NO` on adding `kind=` to `aef:workflowMeta`, while
       saying `YES` to the capability and naming the amendment path.
     - **Flag C** — we tell 832 their document titled "Frozen (v1)" is actually v1.1 and
       should be retitled. They invited the challenge; this takes them up on it.
  4. Confirm the tone is right for a peer standards party, not a subordinate one.

  **Expected:** you endorse both as AEF's position, or amend them before they go on the rail.

  **If not:** say which ruling to soften/reverse and why; the artifact is the single source
  and the rail post is generated from it, so amending it upstream is sufficient.

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
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# The artifact exists and carries the rulings summary.
test -f docs/reports/T-2870-mapping-v1-rulings.md
grep -q "## Rulings summary" docs/reports/T-2870-mapping-v1-rulings.md

# The vendored standard is still on its pin — every ruling here is derived from
# those exact bytes, so a drifted standard invalidates the whole artifact.
out=$(bats tests/unit/standard_pin.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'

# Ruling 2's load-bearing count: aef:workflowMeta is absent from the frozen standard.
test "$(grep -c 'workflowMeta' policy/standards/aef-bpmn-mapping-v1-partI.md)" = "0"

# Ruling 1's measurement, re-run end-to-end: @height-only edit is a task-graph no-op
# while @authority flips exactly owner:. Both arms guarded non-empty first, because a
# void arm is what made the first run report the opposite of the truth (OBS-197).
# NB `diff | grep -q` is unsafe here for a reason NOT in the hints above: diff exits 1
# to mean "files differ" — the very outcome we are asserting — so pipefail fails the
# line on success. Capture first (`|| true`), then grep. Third member of the L-387
# family: SIGPIPE, test-runner exit codes, and now informational-nonzero producers.
bash -c 'set -eo pipefail; d=$(mktemp -d); s=tests/fixtures/aef-bpmn/session-handover.bpmn; bin/fw bpmn compile "$s" 2>/dev/null > "$d/base"; sed "s/height=\"150\"/height=\"999\"/" "$s" > "$d/h.bpmn"; sed "s/authority=\"sovereignty\"/authority=\"initiative\"/" "$s" > "$d/a.bpmn"; bin/fw bpmn compile "$d/h.bpmn" 2>/dev/null > "$d/h"; bin/fw bpmn compile "$d/a.bpmn" 2>/dev/null > "$d/a"; test -s "$d/base" && test -s "$d/h" && test -s "$d/a"; diff -q "$d/base" "$d/h" >/dev/null; ! diff -q "$d/base" "$d/a" >/dev/null; delta=$(diff "$d/base" "$d/a" || true); echo "$delta" | grep -q "owner: agent"; rm -rf "$d"'

## Recommendation

**Recommendation:** GO — endorse both rulings as AEF's ratification position and let them go
to 832 on the rail.

**Rationale:** Every ruling here is derived from the vendored bytes, and the two that carry
weight are the two I would most expect an operator to want to check — so here is why I think
they hold rather than why they are safe.

*Ruling 2 (NO on the form)* rests on a count anyone can repeat: `aef:workflowMeta` occurs
zero times in the frozen standard. That is not an interpretive claim. 832 proposed hanging a
new attribute on a carrier their own frozen document never admits, and the escape hatch that
would have licensed it (§2's editor-internal note) is textually scoped to a different
element. Saying yes would ratify a key onto a carrier with no class, no value set, and no
conformance clause — and `kind=` is the one datum that decides whether the forward compile
runs at all. We lose nothing by saying no to the form: we told them yes to the capability and
named the two-step path that gets it there properly.

*Flag C (their document is v1.1, not v1)* is the one they explicitly invited us to challenge,
which is exactly why it should not be answered with deference. The decisive evidence is
internal: §2 is the section that defines what "frozen" means for this standard, and it
contains a struck-through row annotated *"in v1.1"*. A frozen table with a v1.1 edit in it
has already answered the question. The remedy we recommend is the cheap one (retitle plus a
changelog), not the expensive one (split the document), and we say plainly that it breaks our
own pin and that this is the pin working rather than failing.

The one thing I would flag against myself: the empirical leg **refuted** my own prediction.
I predicted element-granular diffing would cause spurious task-graph churn; measurement shows
our compiler is conformant and unaffected. The amendment we ask 832 for therefore fixes no
live bug of ours — it removes an ambiguity that a third-party implementation would resolve
wrongly. That is a weaker case than the artifact's first draft made, and it is stated that
way in the text rather than quietly dropped.

**Evidence:**
- `docs/reports/T-2870-mapping-v1-rulings.md` — full derivations, all six rulings, quoted clauses.
- `grep -c workflowMeta policy/standards/aef-bpmn-mapping-v1-partI.md` → **0** (Ruling 2's basis).
- Measurement, both arms non-empty-guarded: `@height` 150→999 ⇒ byte-identical 107-line
  output; `@authority` sovereignty→initiative ⇒ exactly one line, `owner: human`→`owner: agent`.
  Control proves the instrument sensitive.
- Corpus exposure by XML parse: 56 diagrams, 501 `<aef:meta>` elements, 652 attributes,
  **91% on non-frozen keys**; `state=` 102 uses. Filed as T-2871.
- `bats tests/unit/standard_pin.bats` green — the bytes every ruling cites are still on 832's pin.
- Self-correction recorded, not buried: OBS-197 (control shared the arms' fatal defect and
  certified an instrument measuring nothing), OBS-198 (`diff | grep -q` fails under pipefail
  precisely when it succeeds), plus a learning on absolute-vs-relative guards.

**What GO authorises:** posting these as AEF's positions on the 832 rail. Nothing in the
standard or our corpus changes as a result — Ruling 2 asks 832 to amend their document, and
T-2871 (already filed) is where our own exposure gets fixed.

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

### 2026-08-08T14:30:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2870-ratify-from-the-text-lanemeta-authority-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b9c7a0e6
- **Timestamp:** 2026-08-08T14:44:07Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -rf`

### 2026-08-08T14:44:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
