---
id: T-3140
name: "fw gaps renders only status:watching — 12 unresolved gaps invisible, 6 of them
  high"
description: >
  fw gaps renders only status:watching — 12 unresolved gaps invisible, 6 of them high

status: work-completed
workflow_type: build
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
created: 2026-08-25T10:36:01Z
last_update: 2026-08-25T10:45:48Z
date_finished: 2026-08-25T10:45:48Z
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
  - ts: '2026-08-25T10:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=384,acs=10)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-25T10:45:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3140: fw gaps renders only status:watching — 12 unresolved gaps invisible, 6 of them high

## Context

`fw gaps` is the register's only CLI reporting surface. It enumerates an
**allowlist** of statuses rather than partitioning the register, so any status
not in the allowlist is invisible — not rendered, not counted, not summarised.

Measured on `.context/project/concerns.yaml` (92 entries) at filing:

| status | n | counted in header? | rendered? |
|---|---:|---|---|
| resolved | 30 | **no** | no |
| closed | 18 | yes (as "resolved") | no |
| mitigated | 18 | **no** | **no** |
| watching | 14 | yes | yes |
| open | 6 | **no** | **no** |
| partial-mitigation | 2 | **no** | **no** |
| *(unset)* | 2 | **no** | **no** |
| accepted-risk | 1 | **no** | **no** |
| partially-resolved | 1 | **no** | **no** |

Three distinct defects fall out of the one root cause:

1. **12 unresolved gaps are invisible** — `open` (6), unset (2), `partial-mitigation`
   (2), `partially-resolved` (1), `accepted-risk` (1). **Six are severity `high`:**
   OBS-090, G-071, G-067, G-068, G-061, G-018. A gap whose status is literally
   `open` is not shown by the command whose job is to show open gaps.
2. **`mitigated` (18) is neither counted nor rendered**, though CLAUDE.md
   §Post-Fix Root Cause Escalation states the opposite in plain text: *"mitigation
   (cleaned up the mess) is not prevention (can't happen again)… Do not close the
   gap until prevention exists."* By the framework's own rule these are the least
   finished gaps in the register, and they are the ones it hides hardest.
3. **The header label names a status it does not count.** `18 resolved` counts
   `closed`/`decided-build`/`decided-simplify`; the 30 entries that actually carry
   `status: resolved` are counted nowhere.

G-018 — the gap CLAUDE.md cites as the origin of the Post-Fix Root Cause
Escalation rule, *"required 3 human corrections to escalate"* — sits at
`partially-resolved` and has never once appeared in `fw gaps` output.

This is the session's false-zero family again (T-1828, T-3125-T-3139, L-575,
G-085). `fw gaps` prints `No gaps being watched` when `watching` is empty. That
line is emitted identically whether the register is clean, or holds six
unrendered high-severity gaps. **A surface with no way to say "outstanding, but
in a status I do not enumerate" reports a quiet day and an unread backlog with
the same words.**

Origin: 832-Workflow-designer reported the header mislabel on the TermLink chat
arc after finding it in their own tree. Measuring ours found the render defect
underneath it, which is the larger of the two.

### Measured before/after

The title's "12 / 6 high" counts the non-`mitigated` unresolved states only —
accurate as written, and an undercount of the fix. Measured after the change:

| | before | after |
|---|---:|---:|
| gap entries rendered by `fw gaps` | 14 | **44** |
| non-terminal entries per an independent scan | 44 | 44 |
| entries counted nowhere in the header | 60 | 0 |

**30 entries became visible, 7 of them severity `high`:** G-018, G-020, G-061,
G-067, G-068, G-071, OBS-090. The seventh is G-020 (`mitigated`, high) — the
pickup-message governance gap CLAUDE.md devotes a whole §Pickup Message Handling
section to. Rendered set and independently-computed non-terminal set now agree
exactly, in both directions: nothing missing, nothing terminal rendered.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] AC1 — `fw gaps` **partitions** the register instead of allowlisting it: every
      entry whose status is not terminal is rendered. Terminal is the explicit set
      `{closed, resolved, decided-build, decided-simplify}`; everything else,
      including an unset/`None` status and any status added in future, is
      outstanding by default. Verified by set-agreement against an independently
      computed non-terminal id set, not by a count — a count goes stale the moment
      the register moves, and agreement does not.
- [x] AC2 — `mitigated` is classified **outstanding**, not terminal, and the code
      says why in one line citing CLAUDE.md §Post-Fix Root Cause Escalation. This
      is the one classification call in the task that is a judgement rather than a
      reading; it is recorded in `## Decisions` with the alternative rejected.
- [x] AC3 — no header label names a status it does not count. The header reports
      outstanding / closed / total, and the 30 `resolved` entries are inside the
      closed count rather than counted nowhere.
- [x] AC4 — the empty states are distinguishable. An empty register, a register
      that is entirely closed, and a register with outstanding entries each produce
      a different line. `No gaps being watched` may no longer be emitted for a
      register that holds unrendered outstanding gaps.
- [x] AC5 — a control exists that **fails against the pre-change code**, using
      FIXTURES ONLY (L-599). It must not pin to a live gap id or a live count: the
      register is edited continuously and a control that reports on the corpus
      stops being a control. Report how many of its assertions discriminate.
- [x] AC6 — `bash -n bin/fw` is clean and `fw gaps` runs without traceback against
      the live register (L-408: never edit bin/fw heredocs without syntax
      verification; the block being changed is inside a `python3 << PYEOF`).
- [x] AC7 — the 6 high-severity gaps named in Context are shown, by this session,
      to appear in `fw gaps` output where they did not before — with the before/after
      measured, not asserted.

### Human
- [ ] [REVIEW] Triage the 12 unresolved gaps this fix made visible for the first time

  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw gaps`
  2. Read the entries under any status other than `watching` — they have never
     appeared on this surface before. Six are `high`: OBS-090, G-071 (`open`),
     G-067, G-068 (unset), G-061 (`partial-mitigation`), G-018 (`partially-resolved`).
  3. For each, decide: still real and outstanding → leave it; superseded or
     genuinely finished → close it with `bin/fw gaps close <ID> --rationale "…"`.

  **Expected:** each of the six high-severity entries has been looked at once and
  either left deliberately or closed with a rationale. This is the decision the
  register existed to prompt and could not.

  **If not:** if any entry is unreadable or its status vocabulary is wrong (e.g. the
  2 entries with no `status:` field at all), say which — that is a register-schema
  defect and gets its own task rather than being fixed inline here.

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

# L-408: the edited block lives inside an UNQUOTED `python3 << PYEOF` heredoc in
# bin/fw, so the shell expands backticks and command substitution before python
# sees them. The first draft of the comment carried backticks and printed five
# "command not found" lines above the report. bash -n does not catch that — it is
# valid shell — so the stderr-empty assertion below is what catches it.
bash -n bin/fw

bin/fw gaps > /tmp/.t3140b 2>/tmp/.t3140e && [ ! -s /tmp/.t3140e ]

# Header must not label a count with a status it does not count.
grep -q "outstanding," /tmp/.t3140b

# The classification, at the unit level. `mitigated` outside the terminal set is
# the one judgement call in this task (see ## Decisions); pin it so a later edit
# that quietly reclassifies it has to argue with a test.
python3 -c "import sys; sys.path.insert(0,'.'); from lib.gaps import is_outstanding, TERMINAL_GAP_STATUSES as T; assert 'mitigated' not in T; assert 'open' not in T; assert is_outstanding({'id':'x'}); assert is_outstanding({'status':None}); assert is_outstanding({'status':'open'}); assert not is_outstanding({'status':'resolved'}); assert not is_outstanding({'status':'closed'})"

bats tests/unit/gaps_partition.bats > /tmp/.t3140a 2>&1 && grep -q "^ok 13 " /tmp/.t3140a && ! grep -q "^not ok" /tmp/.t3140a

# Live-corpus AGREEMENT between two independently-implemented scans — never a
# count. A count goes stale the first time somebody closes a gap; agreement
# survives the register moving, which is the only property that makes this
# worth running more than once. Exits 1 against the pre-change code (measured:
# 44 outstanding, 14 rendered, 30 missing).
tools/gaps-render-agreement.py > /tmp/.t3140c 2>&1 && grep -q "agreement: exact" /tmp/.t3140c

## RCA

**Symptom:** `fw gaps` reported `14 watching, 18 resolved` against a 92-entry
register and rendered 14 entries. 12 unresolved gaps — 6 severity `high` — had
never appeared on the surface at all, and the 30 entries carrying
`status: resolved` were counted nowhere. G-018, the gap CLAUDE.md cites as the
origin of its own §Post-Fix Root Cause Escalation rule, was one of the invisible
ones.

**Root cause:** the render enumerated an **allowlist** of statuses
(`watching` to render; `closed|decided-build|decided-simplify` to count)
rather than partitioning the register into terminal and outstanding. An
allowlist answers "is this one of the statuses I know about?" — and when the
answer is no, it drops the entry. The register's status vocabulary was never
constrained anywhere (there is no schema, no validator, no enum), so it grew
nine distinct values organically while the render kept asking about four.

**Why structurally allowed:** the failure is silent *in the direction of
under-reporting*, which is the direction nothing checks. Three compounding
reasons it survived:

1. **No disagreement to observe.** One renderer, one header, one register. There
   was no second surface to disagree with, and a wrong answer of the right shape
   is indistinguishable from a right one. (L-575 — consolidation buys consistency
   and spends the cross-check. Here there was never a cross-check to spend.)
2. **The empty state had no red.** `No gaps being watched` was printed whenever
   `watching` was empty, whether the register was clean or held six unrendered
   high-severity gaps. A surface with no way to say "outstanding, but in a status
   I don't enumerate" says *nothing outstanding* instead.
3. **The header's label made the miscount look deliberate.** Reading
   `18 resolved` next to a register with 30 `resolved` entries requires opening
   the YAML to notice; the number is plausible on its face, and plausible wrong
   numbers do not get audited.

**Prevention** (distinct from the fix):

- `tools/gaps-render-agreement.py` — two independently-implemented scans, asserting
  AGREEMENT rather than a count, so it survives the register being edited. It
  deliberately duplicates the terminal-status set instead of importing it: sharing
  the constant would make both sides of the comparison the same side.
- `tests/unit/gaps_partition.bats` — 13 fixtures-only tests, 10 of which fail
  against the pre-change code. Includes the direction test (an invented status
  must render, not vanish) and the false-zero test (the all-clear line may not
  appear over hidden work).
- The classification is now a **denylist of terminal states**, so the next status
  somebody invents shows up as outstanding and gets a decision, instead of
  disappearing. The fix and the prevention are the same design choice here, which
  is the only case where that is legitimate: the defect was the direction of the
  test, not a missing branch.

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

**Recommendation:** GO

**Rationale:** The code change is small and its effect is measured in both
directions, not asserted. `fw gaps` now renders 44 entries where it rendered 14,
and the rendered set agrees exactly with an independently-implemented scan of
the non-terminal half — nothing missing, nothing terminal shown. The one
judgement call (`mitigated` is outstanding) is settled by CLAUDE.md's own text
and is pinned by a test, so a later reclassification has to argue with something.

The Human AC is not a review of this code. It asks you to spend a few minutes on
the 30 entries the fix made visible — 7 of them `high` — which is the decision
the register existed to prompt and structurally could not.

**Evidence:**
- Rendered 14 → 44; register total 92; entries counted nowhere in the header 60 → 0.
- `tools/gaps-render-agreement.py`: exit 1 against pre-change (30 missing), exit 0 after.
- `tests/unit/gaps_partition.bats`: 13/13 green; **10 fail against pre-change**;
  the 3 that stay green are exactly the 3 labelled regression guards.
- `bash -n bin/fw` clean and `fw gaps` emits nothing on stderr — the latter caught
  a real L-408 backtick leak in this task's own first draft that `bash -n` passed.
- Newly visible high-severity: G-018, G-020, G-061, G-067, G-068, G-071, OBS-090.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-08-25 — is `mitigated` terminal?

- **Chose:** `mitigated` is **outstanding**. The terminal set is exactly
  `{closed, resolved, decided-build, decided-simplify}`.
- **Why:** CLAUDE.md §Post-Fix Root Cause Escalation says it in as many words —
  *"mitigation (cleaned up the mess) is not prevention (can't happen again)… Do
  not close the gap until prevention exists."* Classifying `mitigated` as done
  would put the framework's render in direct contradiction with the framework's
  own rule, and would hide the 18 entries that rule is specifically about. It is
  also the largest single bucket in the register, so getting it wrong dominates
  the outcome either way.
- **Rejected:** *terminal* — it reads as finished, and the count would look
  tidier (26 outstanding instead of 44). That tidiness is the whole objection:
  the number would be smaller because the surface stopped asking, which is the
  defect being fixed, restated one status to the left.
- **Rejected:** *a third bucket* (outstanding / mitigated / closed). More honest
  in principle, but it needs a status vocabulary the register does not have —
  nine values exist today with no schema, no validator and no enum, so a
  three-way split would need arbitrary rulings on `partial-mitigation`,
  `partially-resolved` and `accepted-risk` too. Two buckets need one ruling.
  If the register ever gets a schema, revisit; that is a separate task and the
  Human AC asks the operator to say whether the two unset-status entries make it
  worth filing.

### 2026-08-25 — allowlist or denylist?

- **Chose:** denylist — enumerate the *terminal* statuses, treat everything else
  as outstanding, including `None`, a missing key, and any status invented later.
- **Why:** the two fail in opposite directions. An allowlist that meets an
  unknown status drops the entry silently; a denylist surfaces it for a decision.
  For a register whose entire purpose is to stop things being forgotten, only one
  of those failure modes is survivable. This is the fix; everything else in the
  task is consequence.
- **Rejected:** keeping the allowlist and adding the six missing statuses to it.
  Restores today's numbers and reinstates the defect for the seventh status —
  the register's vocabulary demonstrably grows without anyone updating the render.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-25T10:36:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3140-fw-gaps-renders-only-statuswatching--12-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2a182d43
- **Timestamp:** 2026-08-25T10:45:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-25T10:45:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
