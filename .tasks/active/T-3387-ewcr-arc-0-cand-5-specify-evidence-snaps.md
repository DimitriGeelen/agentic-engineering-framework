---
id: T-3387
name: "EWCR Arc 0 cand-5: specify evidence snapshot/hash ordering and compensation-idempotency
  rules"
description: >
  Roadmap Arc 0 candidate 5. Evidence is snapshotted and hashed BEFORE validation;
  accepted evidence is immutable; compensation and attempt contracts are idempotent.
  Written as a contract with testable scenarios, no runtime.

status: started-work
workflow_type: specification
owner: agent
horizon: now
tags: [ewcr, arc0]
components: []
related_tasks: [T-3147, T-3384, T-3385]
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
created: 2026-09-18T15:38:49Z
last_update: 2026-09-18T18:38:12Z
date_finished:
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
      (workflow:specification); effort=8 (lines=272,acs=7)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-18T15:45:19Z'
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

# T-3387: EWCR Arc 0 cand-5: specify evidence snapshot/hash ordering and compensation-idempotency rules

## Context

Roadmap `5be23719` Arc 0 candidate 5, third contract written against the T-3385 frozen schemas (after T-3386 task lifecycle, T-3388 worked fixture). Deliverable: `docs/research/executable-workflow/contracts/v1/evidence-and-idempotency.md` — the contract Arc 1 candidates 7 (snapshot/hash/immutability) and 8 (idempotent attempt/result/compensation) must satisfy, with ten Given/When/Then scenarios, plus the committed supersession example `examples/evidence-reference-superseding.json` (`ev-0142-out4` superseding the pilot's `ev-0142-out3`) which validates against `evidence-reference.schema.json`. README gains a contracts table. Sources: arch §2.5, §6.6.1, §7.4, §7.5 steps 7–10, §13 #7/#9/#17/#18.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `docs/research/executable-workflow/contracts/v1/evidence-and-idempotency.md` specifies the ordering invariant: snapshot → hash → validate → accept; a hash computed after validation is a contract violation, with the refusal named — §1: four steps with ledger-position invariant; three violation shapes → `unresolved_reference` / `direct_state_mutation` / `missing_typed_input`; scenarios 1.1–1.3
- [x] Immutability rule: an accepted evidence reference (T-3385 schema) is never rewritten; supersession is a new reference with `supersedes:` — stated with a testable scenario — §2 + scenarios 2.1–2.3; scenario 2.1 is backed by the committed example `examples/evidence-reference-superseding.json` (schema-validated, Verification line 5)
- [x] Idempotency keys for attempt, result and compensation are defined (what fields form the key, what a duplicate delivery must return) with one scenario per contract showing duplicate delivery produces no second effect — §3 key table (attempt, result, compensation, plus deadline evaluation for §13 #17); scenarios 3.1–3.4
- [x] Each rule maps to an arch §13 acceptance scenario id and to its responsible Arc 1 component (candidates 7 and 8) — §4 table rows 7, 9, 17, 18, 10 with component column; §5 lists what each candidate must expose; explicit out-of-scope list
- [x] No runtime code; contract text + scenarios only — only `docs/research/executable-workflow/contracts/v1/` touched (Verification line 7 pins no `lib agents bin web` commits under T-3387)

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

# 1. the five sections the contract promises exist
D=docs/research/executable-workflow/contracts/v1/evidence-and-idempotency.md; for h in "## 1. Ordering invariant" "## 2. Immutability and supersession" "## 3. Idempotency keys" "## 4. Acceptance-scenario mapping" "## 5. What the responsible components"; do grep -q "^$h" "$D" || exit 1; done
# 2. every backticked code-shaped token the contract names is in the frozen refusal enum (schema field names excluded); a contract naming a code the schema does not know is a contract nothing can honour
python3 -c "import json,re,sys,glob; c=set(json.load(open('docs/research/executable-workflow/contracts/v1/refusal.schema.json'))['properties']['reason_code']['enum']); f=set(); [f.update(re.findall(r'\"([a-z_]+)\":', open(g).read())) for g in glob.glob('docs/research/executable-workflow/contracts/v1/*.schema.json')]; d=open('docs/research/executable-workflow/contracts/v1/evidence-and-idempotency.md').read(); n={m for m in re.findall(r'\x60([a-z_]+)\x60', d) if re.search(r'_(reference|mutation|input|position|delivery|mismatch)$', m)}-(f-c); bad=n-c; print('named',sorted(n),'unknown',bad); sys.exit(1 if bad or not n else 0)"
# 3. §13 mapping rows 7, 9, 17, 18, 10 present, and the out-of-scope list
for n in 7 9 17 18 10; do grep -qE "^\| $n \|" docs/research/executable-workflow/contracts/v1/evidence-and-idempotency.md || exit 1; done; grep -q "Explicitly out of Arc 0 scope" docs/research/executable-workflow/contracts/v1/evidence-and-idempotency.md
# 4. every scenario is Given/When/Then, and there are at least eight (three ordering, three immutability, one per idempotency key)
python3 -c "import re,sys; d=open('docs/research/executable-workflow/contracts/v1/evidence-and-idempotency.md').read(); b=re.split(r'^### Scenario ', d, flags=re.M)[1:]; ok=[all(k in x for k in ('**Given**','**When**','**Then**')) for x in b]; print(len(b),'scenarios,',sum(ok),'complete'); sys.exit(0 if b and all(ok) and len(b)>=8 else 1)"
# 5. the supersession example validates against the frozen evidence-reference schema and actually supersedes the pilot's accepted reference
python3 -c "import json,jsonschema,sys; s=json.load(open('docs/research/executable-workflow/contracts/v1/evidence-reference.schema.json')); e=json.load(open('docs/research/executable-workflow/contracts/v1/examples/evidence-reference-superseding.json')); jsonschema.Draft202012Validator(s).validate(e); sys.exit(0 if e['supersedes']=='ev-0142-out3' and e['status']=='accepted' else 1)"
# 6. the frozen schemas and manifest are untouched
python3 tools/ewcr-contracts-check.py
# 7. no runtime code under this task
[ -z "$(git log --format=%H --grep='^T-3387' -- lib agents bin web)" ]

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

### 2026-09-18 — the frozen enum is narrower than the evidence contract wants
- **What changed:** Writing the "hash computed after validation" refusal against the T-3385 enum showed there is no evidence-specific code: the closest honest fits are `unresolved_reference` (a verdict citing a hash the ledger never recorded), `direct_state_mutation` (re-hashing an existing snapshot) and `missing_typed_input` (accepting without a hash-matched verdict). They are correct but coarse — an operator reading `unresolved_reference` on an evidence event has to read `detail` to learn it was a hash mismatch. Also learned: the AC asked for three idempotency keys, but §13 #17 (deadlines fire once, never reset) is the same mechanism and the deadline schema already carries `evaluation_idempotency_key`, so the contract has four keys, not three.
- **Plan impact:** v1 stays frozen (README fence: change = `contracts/v2/`). A dedicated *evidence_hash_mismatch* code is recorded in the contract as a v2 candidate for Arc 1 cand 7 to propose with evidence from its fixtures, not added now. The reason-code verification line had to learn to exclude schema *field* names (`prior_position`, `expected_position`) from the code-shaped-token scan — the T-3386 regex would have false-failed here.
- **Triggered:** nothing filed; the v2 candidate lives in the contract text where cand 7's author will read it. Arc 0 now has contracts for cand 3, 7 and 8; cand 5 (deadlines) and 4 (compare-and-append) are *used* by this document (`stale_position`, `evaluation_idempotency_key`) but their admission-order contract is still the ledger contract, unwritten.

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

### 2026-09-18 — what a duplicate delivery returns
- **Chose:** the original record plus its ledger position (the caller gets the answer it would have got the first time), AND a `duplicate_delivery` refusal appended with `side_effect: false` naming the original — visible, not silent.
- **Why:** §7.4 says every loser of compare-and-append gets an immutable refusal record; §13 #14 wants hub redelivery operator-visible. Returning the original alone would make a redelivery storm invisible; refusing alone would make a legitimate at-least-once transport look broken to its caller.
- **Rejected:** (a) silent idempotent success — hides transport faults; (b) refusal only, no original returned — a resumed runner (§13 #9) needs the prior attempt's outcome to continue, and would have to do a second lookup.

### 2026-09-18 — conflicting result for one attempt
- **Chose:** `stale_position`, with `detail` naming both payload hashes and the position of the consumed one.
- **Why:** a second, different result for the same `attempt_id` is a compare-and-append conflict against the position at which the first was consumed — the frozen enum's `stale_position` is that exact meaning. It is not `duplicate_delivery` (the payloads differ) and inventing a code breaks the v1 freeze.
- **Rejected:** `duplicate_delivery` with a "conflicting" flag — the schema has no such flag and the semantics differ (a duplicate is harmless, a conflict is the event an operator must see first).

### 2026-09-18 — `decision_refs` on an accepted reference
- **Chose:** append-only; the single mutable field after acceptance. Removal is `direct_state_mutation`.
- **Why:** the schema carries `decision_refs` on the evidence object, and the human gate that reviews accepted evidence (§2.5 step 5) happens *after* acceptance by construction; a fully frozen object would leave that decision with nowhere to attach except a reverse index.
- **Rejected:** fully immutable after acceptance with decisions pointing at evidence instead — cleaner, but contradicts the frozen schema's shape; a v2 question.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-18T15:38:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3387-ewcr-arc-0-cand-5-specify-evidence-snaps.md
- **Context:** Initial task creation

### 2026-09-18T18:38:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
