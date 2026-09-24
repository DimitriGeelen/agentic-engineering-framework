---
id: T-3389
name: "EWCR Arc 0 cand-3: consolidated refusal/threat matrix from the four external
  reviews (blocked: reviews not transferred)"
description: >
  Roadmap Arc 0 candidate 3. Requires the Claude, Z.ai, DeepSeek and Mistral review
  findings which were NOT in the transferred packet (questions-and-dispositions.md
  section 3). Not startable until the operator transfers them. Peer-transfer gap,
  distinct from Q-15.

status: work-completed
workflow_type: specification
owner: human
horizon: now
tags: [ewcr, arc0]
components: [tools/ewcr-arc0-writeset-scoped-coverage.py]
related_tasks: [T-3147, T-3384, T-3145]
arc_id: ewcr-arc0-contract-evidence
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
created: 2026-09-18T15:39:14Z
last_update: 2026-09-24T20:39:28Z
date_finished: 2026-09-24T20:39:28Z
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
  - ts: '2026-09-18T15:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 4
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=4 
      (workflow:specification); effort=8 (lines=278,acs=7)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-18T15:45:20Z'
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

# T-3389: EWCR Arc 0 cand-3: consolidated refusal/threat matrix from the four external reviews (blocked: reviews not transferred)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `docs/research/executable-workflow/contracts/v1/refusal-threat-matrix.md` consolidates every blocker finding from the four reviews into rows: finding id → source review → threat → refusal scenario → responsible component → verification fence
      — 19 rows: Claude 6 (CL-1..6), Z.ai 5 (ZA-2..6), DeepSeek 3 (DS-1..3), Mistral 5 (MS-1..5); every review contributes ≥1, asserted by a verification line with a control leg.
- [x] Every row's refusal scenario references the T-3385 `refusal` schema and an arch §13 scenario id; rows with no §13 scenario are flagged as NEW scenarios for the operator to accept
      — each row carries a `reason_code` and `scenario_refs` in the frozen `refusal.schema.json` vocabulary; two findings had no §13 scenario and are proposed **unnumbered** for the operator to accept (N-1 per-attempt task mutation from DS-1; N-2 credential-scope excess from MS-3).
- [x] The count of arch §13 scenarios the current substrate would already fail is produced (the missing measurement named in questions-and-dispositions.md §3) and recorded in the matrix header
      — **14 of 20 would fail, 1 would pass, 5 not applicable yet**, each with a file:line or command output; header/body parity asserted by a verification line with a control leg.
- [x] No runtime code
      — asserted mechanically: no commit whose subject starts `T-3389:` touched `lib|bin|agents|web|tools`.

### Human
- [ ] [REVIEW] Transfer the four external review findings (Claude, Z.ai, DeepSeek, Mistral — roadmap §4 Arc 0 task 3) into `docs/research/executable-workflow/reviews/` so this task becomes startable
  **Steps:**
  1. Locate the four review documents in the sending project (`0503-codex-cli-playground`, same packet as manifest v1 rev 0)
  2. Copy them as raw files (not Watchtower HTML — G-086) into `cd /opt/999-Agentic-Engineering-Framework && mkdir -p docs/research/executable-workflow/reviews` and commit under this task id
  3. Add their sha256 to `docs/research/executable-workflow/source-manifest.yaml` as a new revision
  **Expected:** four files present, hashes in the manifest, `git log --oneline -1 -- docs/research/executable-workflow/reviews` shows the commit
  **If not:** the agent cannot build the matrix from memory of the reviews; leave this task at horizon later

- [ ] [REVIEW] **OR** rule the DeepSeek and Mistral findings out of Arc-0 scope, recording that ruling as their disposition (the alternative route 832 named at `agent-chat-arc` @643 — either one closes clause 2's arithmetic, and **only one is needed**)
  **Steps:**
  1. Decide whether the DeepSeek and Mistral reviews are Arc-0 inputs at all. They were named as requirements in six places (roadmap:64, :139, :229, :358, architecture:857, questions:148) but never transferred here, and 832 confirms no disposition table exists for either on their side.
  2. If they are out of scope, record the ruling — it becomes their disposition, which is what clause 2 requires: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task update T-3389 --add-tag "scope-ruled"` and state the ruling in this task's `## Decisions` section.
  3. Post the ruling to 832 on the correlation chain so their register can move: it answers R6 and, per their @1536, R6 and exit-clause 2 move together.
  **Expected:** the ruling is written down somewhere 832 can cite, and clause 2's "every blocker finding has a disposition" is satisfiable by arithmetic — two families dispositioned as out-of-scope, two by the existing Claude §17 / Z.ai §18 tables.
  **If not:** clause 2 stays open indefinitely regardless of effort on either side. This is the failure mode 832 named: *"Either closes the arithmetic. Silence does not."*
  **Note:** this is a scope decision on a draft-authorised arc — arc-019's fence puts it outside agent authority, which is why it is raised rather than taken.
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

# T-3389: the two transferred reviews hash exactly to the values 832 published.
test "$(sha256sum docs/research/executable-workflow/reviews/T-032-deepseek-review-response.md | cut -d" " -f1)" = "4dae4098b2602b2794525292e1aa3053e0c486b23a67d9c3292ce80dc3a4d8a9"
test "$(sha256sum docs/research/executable-workflow/reviews/T-032-mistral-review-response.md | cut -d" " -f1)" = "0eecb8af7be56ba045581167ef66b73fd9d2aa17fcd241f84defc0e7d17bfb0e"
timeout 300 python3 tools/ewcr-contracts-check.py > /tmp/.t3389-contracts 2>&1
timeout 300 python3 tools/ewcr-trace-check.py > /tmp/.t3389-trace 2>&1
python3 -c 'import re,collections; t=open("docs/research/executable-workflow/contracts/v1/refusal-threat-matrix.md").read(); c=collections.Counter(m.group(1) for m in re.finditer(r"^\| ([A-Z]{2})-[0-9]+ \|", t, re.M)); assert set(c)=={"CL","ZA","DS","MS"} and min(c.values())>=1 and sum(c.values())==19, c'
python3 -c 'import re; t=open("docs/research/executable-workflow/contracts/v1/refusal-threat-matrix.md").read(); assert "**14 of 20 would fail. 1 would pass. 5 are not applicable yet.**" in t; assert len(re.findall(r"\| \*\*would-fail\*\* \|",t))==14 and len(re.findall(r"\| \*\*would-pass\*\* \|",t))==1 and len(re.findall(r"\| not-applicable-yet \|",t))==5'
test -z "$(git log --format="%H" --grep="^T-3389:" -20 | xargs -r -n1 git diff-tree --no-commit-id --name-only -r | sort -u | grep -E "^(lib|bin|agents|web|tools)/")"

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

*(The DEFER below was correct when written on 2026-09-19 — it named an evidence gap.
The gap closed on 2026-09-24 when the operator ran `run-me.sh` and both reviews landed
with matching hashes. Superseded, kept for the record at the end of this section.)*

**Recommendation:** GO — the matrix is built, both fences are green, and one Human AC is now satisfiable on evidence

**Rationale:** The evidence gap that made DEFER correct on 2026-09-19 is closed. All four
reviews are in this repository or in the pinned dossier, and the two transferred files
hash **exactly** to the values 832 published on the DM rail — verified twice, and pinned
as verification lines so they re-run rather than resting on a sentence. Nothing in the
matrix is reconstructed from memory: every row cites a review section, and every substrate
claim cites a file:line or a command's output.

The deliverable is `contracts/v1/refusal-threat-matrix.md` — 19 blocker rows (Claude 6,
Z.ai 5, DeepSeek 3, Mistral 5), each mapping a finding to a `reason_code` and
`scenario_refs` in the frozen `refusal.schema.json` vocabulary, a responsible component,
and either a runnable fence or a named gap. Plus the measurement
`questions-and-dispositions.md` §3 called missing: **14 of 20** §13 scenarios would fail on
the current substrate, 1 passes, 5 have nothing to fail yet.

**Which Human AC the operator now needs to tick — and which to leave:**

1. **Tick AC 1 (transfer).** It happened. `docs/research/executable-workflow/reviews/`
   holds both files with matching sha256 and a `PROVENANCE.md` recording who moved them,
   when, and why by hand. One deviation worth naming rather than hiding: the AC's step 3
   said to add the hashes to `source-manifest.yaml` as a new revision; they went into
   `PROVENANCE.md` and the matrix header instead, both of which are hash-checked by this
   task's verification lines. If you want them in `source-manifest.yaml` too, say so and
   it is a one-line follow-up — I did not edit that file on my own judgement because it is
   the packet's provenance record, not mine.
2. **Do NOT tick AC 2 (rule DeepSeek and Mistral out of scope).** It is now moot and
   ticking it would record a scope ruling that did not happen. Both families are **in**
   scope and dispositioned in the matrix: DS-1..3 and MS-1..5. The AC's own text says only
   one of the two routes is needed, and route 1 is the one that ran.

**Evidence:**
- `sha256sum` on both reviews matches the published values exactly (verification lines 1–2)
- `python3 tools/ewcr-contracts-check.py` → OK, 7 schemas, 7 examples, hashes match (line 3)
- `python3 tools/ewcr-trace-check.py` → OK, 20 invariants traced (line 4) — `traceability.yaml` was **not edited**
- 19 rows, every review contributing ≥1, asserted by line 5; a control leg confirms the assertion fails when a row is removed
- Header/body parity on 14/1/5 asserted by line 6; control leg confirms it fails when one verdict is flipped
- No runtime code: line 7 asserts no T-3389 commit touched `lib|bin|agents|web|tools`
- Agreement with `traceability.yaml` tabulated row-by-row in matrix §5.2 — 12 overlapping scenarios, no contradiction found, so nothing to record in `## Decisions` under that heading
- Two NEW scenarios proposed rather than numbered (N-1 per-attempt mutation from DS-1; N-2 credential-scope excess from MS-3), plus independent corroboration that §13 #14 has no `reason_code` in the frozen enum

**What this does not settle:** whether 832's exit-clause 2 is closed. This gives all four
review families an AEF-side disposition, which is what clause 2 needs *from this
repository*. Their register is theirs to move.


<details><summary>Superseded DEFER of 2026-09-19</summary>

**Recommendation:** DEFER — pending an operator choice between two named options

**Rationale:** This is a genuine evidence gap, not a confidence hedge. The task cannot
start: it requires the four external model reviews (Claude, Z.ai, DeepSeek, Mistral) and
`docs/research/executable-workflow/reviews/` **does not exist in this repository**. The
reviews were never transferred from the sending project. Building the matrix from
memory of documents this repo has never held would fabricate exactly the content whose
purpose is refusal fidelity — and the fabrication would be invisible in the artifact.

832-Workflow-designer independently reached the same arithmetic from their side
(`agent-chat-arc` @643, R6): their pinned dossier carries disposition tables for Claude
(§17) and Z.ai (§18) **only**, so two of four model families have no disposition table
anywhere. Exit-clause 2 requires that *every* blocker finding carry a disposition, so
clause 2 is unsatisfiable from the packet regardless of how good the two existing tables
are. Silence does not close it; one of the two options below does.

**The operator choice — both are Sovereign, neither is mine:**

1. **Transfer the reviews.** Copy the four review documents from
   `0503-codex-cli-playground` into `docs/research/executable-workflow/reviews/` as raw
   files (not Watchtower HTML — G-086), add their sha256 to `source-manifest.yaml` as a
   new revision. T-3389 then becomes startable and I build the matrix.
2. **Rule DeepSeek and Mistral out of Arc-0 scope**, recording that ruling *as* their
   disposition. This closes clause 2's arithmetic without the transfer. It is a scope
   decision on a draft-authorised arc, which arc-019's fence
   (*"No runtime implementation, autonomy expansion, BVP confirmation, bulk task
   creation, or supersession of prior DEFER/NO-GO decisions"*) places outside agent
   authority.

**My recommendation between them:** option 1 if the reviews still exist and are
reachable — a real disposition table is worth more than a scope ruling, and clause 2's
wording ("every blocker finding") was written expecting four. Option 2 is the correct
answer only if the DeepSeek/Mistral reviews are genuinely unavailable or were never
meant to be Arc-0 inputs; in that case recording the ruling is strictly better than
leaving the arithmetic open indefinitely.

**Evidence:**
- `ls docs/research/executable-workflow/reviews` → No such file or directory (measured 2026-09-19)
- Task title records the block verbatim: *"(blocked: reviews not transferred)"*
- 832's R6 ask, `agent-chat-arc` @643; restated @1536; my confirmation from this side @1539
- Sibling clause 1 **is** answered and landed: `arc-0-clause-1-attestation.md` (T-3394, commit `174f31777`)
- Arc-0 exit status: clause 1 answered (pending 832's operator), clause 2 blocked here, clause 3 (2/6) is 832's register

</details>

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

### 2026-09-18T15:39:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3389-ewcr-arc-0-cand-3-consolidated-refusalth.md
- **Context:** Initial task creation

### 2026-09-24T20:39:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e842c030
- **Timestamp:** 2026-09-24T20:39:30Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Human)** — [REVIEW] Transfer the four external review findings (Claude, Z.ai, DeepSeek, Mistral — roadmap §4 Arc 0 task 3) into `docs/research/executable-workflow/reviews/` so this task becomes startable
  - **human-ac-mechanical-signal** (partial, heuristic) — `matched='shows the c' in Expected: four files present, hashes in the manifest, `git log --oneline -1 -- docs/research/executable-workflow/reviews` shows the commit`

### 2026-09-24T20:39:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
