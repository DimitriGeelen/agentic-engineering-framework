---
id: T-3503
name: "arc membership S3: fw bvp arcs drops tag-only arcs instead of ranking them
  at zero"
description: >
  arc membership S3: fw bvp arcs drops tag-only arcs instead of ranking them at zero

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc:arc-grooming]
components: [lib/bvp.sh, web/blueprints/bvp.py]
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
created: 2026-09-26T12:56:05Z
last_update: 2026-09-26T13:15:51Z
date_finished: 2026-09-26T13:15:51Z
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
  - ts: '2026-09-26T13:00:12Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=337,acs=12)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-26T13:00:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3503: arc membership S3: fw bvp arcs drops tag-only arcs instead of ranking them at zero

## Context

Slice S3 of `docs/reports/T-3501-arc-mechanism-faults.md` (operator GO
2026-09-26). Reported by **cashweb-integration-agent** on `agent-chat-arc` @1247 as
*"BVP arc ranking blind spots: an arc with no canonical members was dropped rather
than reported as zero."* Both halves verified here.

**Two defects, compounding, in the same function — which exists twice.**

```python
members = _arc_member_tasks(arc_slug, arc_id_str)   # matches arc_id: ONLY
scores, source = _arc_rolled_up_scores(members)     # [] -> (None, '')
if not scores:
    continue                                         # the arc VANISHES
```

1. **Membership is `arc_id:`-only.** The legacy `arc:<slug>` tag form is not
   unioned, so a tag-only arc yields `members = []`.
2. **An unscorable arc is dropped, not reported.** `continue` removes the row
   entirely, and it collapses two different states: *no members found* (defect 1)
   and *members found but none scored* (genuine no-data). They become
   indistinguishable, and **an arc absent from the ranking looks identical to an
   arc that does not exist** — in the table the operator uses to choose arcs.

**Both copies carry it**, so both of the operator's arc-value views are affected:

| copy | surface |
|---|---|
| `lib/bvp.sh:563` | `fw bvp arcs` CLI |
| `web/blueprints/bvp.py:421` | Watchtower `/bvp` |

**Why this is delegation and not a fifth reimplementation.** `lib/bvp.sh:545`
already documents itself as mirroring `web/blueprints/bvp.py`, and arc membership
is now implemented in at least five places. The framework has a rail against
exactly this — audit's T-1881 check, *"No inline `arc:<slug>` tag-only scans
outside canonical lib… Any NEW occurrence is silent-corpus #3 in waiting"* — whose
own mitigation text says **"Migrate to `lib/arc_membership.{sh,py}`."** So both
copies delegate membership to the canonical helper rather than growing another
regex.

**A gap found while establishing that, and filed separately:** the T-1881 rail's
pattern is `grep[^|]*arc:[A-Za-z0-9_-]` — it matches **shell `grep` invocations
only**. A *Python* reinvention of arc membership is invisible to it. That is why the
check reported PASS in today's audit while these two Python copies were both
missing the tag half of the union. The rail did not fail; it cannot see this class.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `lib/bvp.sh:_arc_member_tasks` resolves membership through
      `lib/arc_membership.py`'s canonical union, instead of its own `arc_id:`-only
      match.
      → Delegates via `_arc_membership_index()`. Two module-level caches were added
      with it, which also removed an **O(arcs × tasks)** blow-up: membership was
      re-derived per arc over the whole corpus, so `fw bvp arcs` did ~20 × 3,484
      frontmatter parses. **It exceeded a 300 s timeout before; it runs in 18.8 s
      now.** That speedup was a side effect, not a goal.
- [x] `web/blueprints/bvp.py:_arc_member_tasks` does the same.
      → Same union, same helper, imported the way the sibling blueprint
      `arcs.py:34` already does it. **Partial by design on the second half** — see
      the `continue` AC below.
- [x] A tag-only arc is **ranked, not dropped**.
      → `test_a_tag_only_member_is_found`, plus `..._deduplicates_a_task_carrying_both_forms`
      (a task with both forms is one member, not two — otherwise it would be
      double-weighted in the roll-up mean).
- [x] An arc that genuinely cannot be scored is **reported as unscorable**, not
      silently omitted — `continue` is gone **in the CLI**.
      → Emits a row with `no-members` / `members-unscored`, rendering `-` rather
      than `0.00`, sorted after the ranked rows.
      **DIVERGENCE, deliberate and bounded:** `web/blueprints/bvp.py` still
      `continue`s, because rendering a scoreless arc needs a template change on a
      render surface and that is a reviewed change, not a side effect of a
      membership fix. The divergence affects only arcs with **zero scorable
      members — currently none**, since the membership fix gave every arc members.
      Recorded in a comment at the divergence site, not left implicit.
- [x] `no members found` and `members found but unscored` are **distinguishable**.
      → `test_the_two_empty_states_are_distinguishable`. One is a membership
      problem, the other a scoring problem, and they take different responses.
- [x] CONTROL LEG: an arc with real scores ranks exactly as before.
      → `test_a_scored_arc_still_ranks_normally` and
      `test_scored_arcs_sort_before_unscorable_ones` — unscorable rows must not
      displace real ones at the top of the ranking.
- [x] If the canonical helper cannot be imported, membership **degrades loudly**.
      → `arc_membership_degraded()` returns the reason; `cmd_arcs` prints a
      `WARNING: arc membership DEGRADED to arc_id:-only` banner naming it. Pinned by
      `test_a_failed_canonical_import_is_reported_not_swallowed`, which also asserts
      the degraded path still finds `arc_id:` members rather than returning nothing.
- [x] Measured before/after on the live corpus.
      → **`fw bvp arcs` listed 16 of 20 arcs; it now lists 20 of 20.** The four it
      was hiding: `arc-009 horizon-axis-hardening`, `arc-015
      onboarding-shape-detection`, `arc-016 readme-first-run`, `arc-018
      ladder-trigger-producer`. **Three of those four are among the five arcs the
      audit currently WARNs as stale** — the arcs most needing attention were the
      ones the value ranking could not see at all.
- [x] Watchtower restarted and `/bvp` verified against the fix.
      → Restarted; all four previously-hidden arcs now present in the rendered page
      (1 occurrence each), HTTP 200. Done because `fw watchtower current` cannot see
      a `lib/` change (OBS-544, found during S1).
- [x] Existing BVP suites stay green; no change to scoring arithmetic.
      → **64 passed** across seven BVP suites. This slice changes only *which tasks
      count as members*; `_arc_rolled_up_scores` is untouched. Note the per-arc
      scores DO move (e.g. `value-prioritisation` 64→71, `continuous-run` 76→63) —
      that is the mean re-computed over the correct member set, which is the point.

### Human

- [ ] [REVIEW] The `/bvp` arcs table now lists four arcs it previously omitted — confirm the page still reads correctly with them present, and that the ranking is usable.
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` — open `<url>/bvp`
  2. Find the arcs table. Four arcs appear that were absent before: `horizon-axis-hardening`, `onboarding-shape-detection`, `readme-first-run`, `ladder-trigger-producer`
  3. Check the table still fits, sorts sensibly, and that nothing is truncated or overlapping with 20 rows instead of 16
  **Expected:** All 20 arcs listed; layout holds at the larger row count; the ranking order reads as value-descending and is usable for choosing an arc.
  **If not:** Note which rows break the layout. The membership fix is independent of presentation — a render adjustment can follow without reverting it.

  *Why this is yours and not a reviewer scan:* it is a render surface (P-013), the
  question is whether a denser table still reads well, and the answer is about your
  perception of the page — not something a static scan can settle.

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
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
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
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

out=$(python3 -m pytest tests/unit/test_bvp_arc_membership_union.py -q 2>&1); echo "$out" | grep -q "11 passed" && ! echo "$out" | grep -q "failed"
out=$(python3 -m pytest tests/unit/test_bvp_cli_arcs_rollup.py tests/unit/test_bvp_status_filter.py tests/unit/test_bvp_cli_rank_proposed.py tests/unit/test_bvp_blueprint_cost.py tests/unit/test_bvp_scatter_arc_mode.py tests/unit/test_bvp_signals_rollup.py tests/unit/test_bvp_quadrant_value_axis.py -q 2>&1); echo "$out" | grep -q "64 passed" && ! echo "$out" | grep -q "failed"
bash -n lib/bvp.sh
python3 -c "import ast; ast.parse(open('web/blueprints/bvp.py').read())"
# Both copies must delegate to the canonical helper — neither may regrow its own scan.
grep -q "from arc_membership import scan_tasks_by_arc_membership" lib/bvp.sh
grep -q "from lib.arc_membership import scan_tasks_by_arc_membership" web/blueprints/bvp.py
# The CLI must no longer be able to silently drop an arc: assert the reporting
# states exist rather than pinning a live arc count (T-3326).
grep -q "no-members" lib/bvp.sh
grep -q "members-unscored" lib/bvp.sh
cmp -s lib/bvp.sh .agentic-framework/lib/bvp.sh

## RCA

**Symptom:** `fw bvp arcs` and Watchtower `/bvp` listed **16 of 20 arcs**. The four
omitted included three of the five arcs the audit WARNs as stale — so the arcs most
in need of attention were invisible in the table used to choose which arc to work.

**Root cause, two defects compounding in one function that exists twice:**

1. `_arc_member_tasks` matched `arc_id:` only. The legacy `arc:<slug>` tag form —
   still the sole binding for a number of arcs — was not unioned, so those arcs
   rolled up zero members.
2. The caller did `if not scores: continue`, deleting the row. That collapsed *no
   members found* and *members found but unscored* into one invisible state, so **an
   arc missing from the ranking was indistinguishable from an arc that does not
   exist.**

**Why structurally allowed:** arc membership is implemented in at least five places
(`lib/arc_membership.{py,sh}`, `lib/arc.sh`, `agents/audit/audit.sh`, `lib/bvp.sh`,
`web/blueprints/bvp.py`), and `lib/bvp.sh:545` documents itself as *mirroring*
`web/blueprints/bvp.py` — the duplication was known and written down. The framework
has a rail against exactly this, audit's T-1881 check, and **it reported PASS in the
same run in which both copies were wrong**, because its pattern requires the literal
token `grep` and cannot see a Python reinvention (OBS-546). A guard that polices one
language while the duplication spreads in another is not a guard against the
duplication.

**Prevention:**
1. Both copies now **delegate** rather than re-derive; verification asserts the
   import exists in each, so regrowing a local scan fails the gate.
2. `test_the_two_empty_states_are_distinguishable` pins the distinction whose
   collapse was the second defect — a fix that reported both as one state would
   have relabelled it rather than fixed it.
3. `test_an_unscorable_arc_renders_a_dash_not_a_zero` — an arc that cannot be scored
   is not an arc worth nothing. Same rule as `blast_radius` unknown-not-zero.
4. **Not prevented, filed:** OBS-546 (the T-1881 rail cannot see Python sites) and
   OBS-545 (audit's completion-ratio check reads the deprecated
   `constituent_tasks:` cache as a fallback rather than a union).

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

### 2026-09-26 — the arcs the ranking hid were the arcs the audit was flagging

- **What changed:** The slice was filed on a reported *capability* gap ("tag-only
  arcs are dropped"). What the measurement showed is sharper: the four hidden arcs
  were `horizon-axis-hardening`, `onboarding-shape-detection`, `readme-first-run`
  and `ladder-trigger-producer`, and **three of those four are among the five arcs
  the audit WARNs as stale**. Two governance surfaces were disagreeing about the
  same arcs — one flagging them as needing attention, the other omitting them from
  the table used to choose work.
- **Plan impact:** Raised the slice's priority in hindsight and changed what the
  Recommendation has to say: this was not a completeness nicety, it was the
  selection surface hiding its own backlog.
- **Triggered:** Nothing new filed; it strengthens the case already recorded under
  T-3501.

### 2026-09-26 — the guard against this class could never have caught this instance

- **What changed:** Before adding a fifth membership implementation I checked
  whether the repo forbade it, and it does — audit's T-1881 rail, *"Any NEW
  occurrence is silent-corpus #3 in waiting"*. But its pattern requires the literal
  token `grep`, so it polices shell scans and is blind to Python. It reported PASS
  over 461 files in the same audit run in which **both** Python copies were missing
  the tag half of the union.
- **Plan impact:** Settled the implementation choice — delegate to the canonical
  helper rather than write a better regex, which is what the rail's own mitigation
  text instructs. Verification now asserts the *import* exists in each copy, so
  regrowing a local scan fails the gate rather than needing the rail to notice.
- **Triggered:** **OBS-546**, with the candidate fix: invert the check to assert
  membership sites *import* the helper. An allowlist of callers is finite; the set
  of ways to write a regex is not.

### 2026-09-26 — an O(arcs × tasks) blow-up surfaced by accident

- **What changed:** Capturing the "before" baseline, `fw bvp arcs` **timed out at
  300 s**. Membership was being re-derived per arc across the whole corpus — ~20 ×
  3,484 frontmatter parses. Delegating to the single-pass helper plus two caches
  brought it to **18.8 s**.
- **Plan impact:** None to scope; the caches were required by the delegation
  anyway. Recorded because the performance fix was a side effect and should not be
  claimed as a goal, and because a verb that cannot finish inside a timeout is one
  nobody runs.
- **Triggered:** Nothing.

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

**Rationale:** The defect is measured, the fix is measured, and the only open
question is a layout one. `fw bvp arcs` listed **16 of 20 arcs**; it now lists
**20 of 20**, and three of the four it was hiding are among the five arcs the audit
currently WARNs as stale — so the ranking was silently omitting precisely the arcs
most in need of attention. Both surfaces (CLI and `/bvp`) were fixed together so
they cannot disagree, and both now delegate to `lib/arc_membership.py` rather than
carrying a fifth private copy of membership. Scoring arithmetic is untouched;
`_arc_rolled_up_scores` was not modified. Per-arc scores DO move (e.g.
`value-prioritisation` 64→71, `continuous-run` 76→63) because the mean is now taken
over the correct member set — that is the intended effect, not a side effect.

The one thing left for you is genuinely yours: whether a 20-row table still reads
well on `/bvp`. That is a render-surface judgement (P-013), not something a scan can
settle, and it does not gate the correctness of the membership fix — a layout
adjustment can follow without reverting anything.

**Evidence:**
- Before/after on the live corpus: 16 → 20 arcs. Recovered: `horizon-axis-hardening`,
  `onboarding-shape-detection`, `readme-first-run`, `ladder-trigger-producer`.
- Watchtower restarted; all four confirmed present in the rendered `/bvp`, HTTP 200.
- `tests/unit/test_bvp_arc_membership_union.py` — 11 tests, including the control leg
  that a scored arc ranks unchanged, and that the two empty states
  (`no-members` vs `members-unscored`) stay distinguishable.
- 64 existing BVP tests green across seven suites; 9/9 verification lines.
- Unplanned performance result: `fw bvp arcs` exceeded a 300 s timeout before this
  change (membership was re-derived per arc over the whole corpus, ~20 × 3,484
  frontmatter parses) and completes in **18.8 s** now.
- Bounded divergence, deliberate and commented at the site: `web/blueprints/bvp.py`
  still skips an arc with zero scorable members, because rendering one needs a
  template change. No arc is in that state today.
- Two findings filed rather than silently fixed: **OBS-546** (audit's T-1881 rail
  cannot see Python reinventions of arc membership — it passed while both copies
  were wrong) and **OBS-545** (audit's completion-ratio check reads the deprecated
  `constituent_tasks:` cache as a fallback rather than a union).

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

### 2026-09-26T12:56:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3503-arc-membership-s3-fw-bvp-arcs-drops-tag-.md
- **Context:** Initial task creation

### 2026-09-26T13:13:50Z — status-update [task-update-agent]
- **Change:** tags: +arc:arc-grooming

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2e019f79
- **Timestamp:** 2026-09-26T13:16:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-26T13:15:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
