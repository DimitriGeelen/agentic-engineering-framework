---
id: T-3429
name: "arc-scoped value drivers are created and added by default; an external value-driver
  reviewer replaces the operator-approval step (operator ruling 2026-09-22; depends
  on T-3428 scoring specs)"
description: >
  Operator ruling 2026-09-22: 'per default just create them and add them; if needed
  institute an external value driver reviewer'. Replace the fw arc approve-driver
  human step (T-1926, M6/D8 §ACD gate) with a default path that writes proposed_scoped_drivers
  straight into scoped_drivers when an external reviewer certifies them. Reviewer:
  a dispatched or static check that a proposed driver (1) carries a valid scoring:
  spec (T-3428), (2) does not duplicate D1-D4 or an existing driver, (3) states in
  one line what it distinguishes (D6). Keep --none and remove-driver; keep the cap
  of 3 and weight <=6 (M2). Watchtower and CLI surfaces updated; audit rail for auto-added
  drivers without a reviewer record. Depends on T-3428.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [agents/audit/audit.sh, bin/fw, lib/arc-driver-review.sh, lib/arc.sh, tests/unit/arc_remove_driver_verb.bats, tests/unit/t3429_arc_approve_driver_default_path.bats, tests/unit/t3429_arc_driver_review.bats, tests/unit/t3429_arc_driver_reviewer_record_rail.bats, web/blueprints/arcs.py, web/templates/arc_detail.html]
related_tasks: []
arc_id: arc-006
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
created: 2026-09-22T10:41:00Z
last_update: 2026-09-22T18:15:42Z
date_finished: 2026-09-22T18:15:42Z
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
  - ts: '2026-09-22T10:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=269,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-22T10:45:18Z'
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
  - ts: '2026-09-22T15:44:05Z'
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
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3429: arc-scoped value drivers are created and added by default; an external value-driver reviewer replaces the operator-approval step (operator ruling 2026-09-22; depends on T-3428 scoring specs)

## Context

Operator ruling 2026-09-22 (given twice, verbatim): "When we add it, I want us per default
take out the restriction that user operator has to approve the Arc value drivers. Per default
just create them and add them. If needed let's institute an external value driver reviewer if
we don't have it, to ensure we have enough quality." This is a Sovereign decision on the M6/D8
§ACD gate in `lib/arc.sh:arc_approve_driver` (`_arc_approve_driver_acd_gate`): the gate stops
being the default path and becomes the override path. Quality moves from the operator to a
mechanical reviewer that can be audited.

Surfaces today: `lib/arc.sh:1234` (`arc_approve_driver`, dedup at :1306, cap 3 / weight ≤6),
`web/blueprints/arcs.py:959` (`/api/arc/<id>/approve-driver` shells `--from-watchtower`),
`agents/audit/audit.sh:3396` (`check_bvp_driver_scorability`, T-3428),
`fw bvp driver --validate-scoring FILE` (T-3428), `policy/driver-scoring-example.yaml`,
CLAUDE.md §Arc-Scoped Driver Suggestion Workflow steps 4–5 and §Arc Action Handoffs table.

Reviewer = static check, no model call, so its verdict is reproducible and re-runnable:
(a) the proposed entry carries a `scoring:` spec (inline under the entry, or a
`scoring_file:` path) that passes the T-3428 validator; (b) its name/id does not duplicate
D1–D4, any `free_drivers[]` entry in `policy/value-drivers.yaml`, or an existing
`scoped_drivers[]` entry on the arc (case-insensitive, whitespace/hyphen-normalised);
(c) the rationale names at least one of D1–D4 it distinguishes from and is ≥ 60 chars (D6).
Verdict written back onto the proposed entry as `reviewer: {verdict, checks, ts, reviewer_id}`.

## Acceptance Criteria

### Agent
- [x] `fw arc review-driver <arc> "<name>"` runs checks (a)(b)(c), prints one line per check
      with PASS/FAIL and the reason, exits 0 on all-pass and 1 otherwise, and writes the
      `reviewer:` block onto the matching `proposed_scoped_drivers[]` entry (`--dry-run`
      writes nothing). `--all` reviews every proposed entry on the arc.
- [x] `fw arc approve-driver <arc> "<name>"` with neither `--i-am-human` nor
      `--from-watchtower` no longer refuses: it runs the reviewer and, on PASS, appends the
      entry to `scoped_drivers[]` with `approved_by: reviewer:<reviewer_id>` and the
      `reviewer:` block copied in; on FAIL it refuses naming the failed check(s). Cap 3 and
      weight ≤ 6 (M2) and the T-1979 dedup still apply on this path. `--i-am-human` /
      `--from-watchtower` still approve without the reviewer, recording `approved_by: human`.
- [x] `fw arc approve-driver <arc> --all-reviewed` approves every proposed entry that passes
      review, in proposal order, stopping at the cap with a message naming what it skipped;
      `--none` keeps its existing human gate unchanged (a negative ruling stays sovereign).
- [x] The estimator/agent path that writes `proposed_scoped_drivers:` (Workflow A step 3,
      `policy/prompts/bvp-driver-session.md` and CLAUDE.md §Arc-Scoped Driver Suggestion
      Workflow steps 4–5) is rewritten so the default next step is `--all-reviewed`, not
      "surface to the human"; §Arc Action Handoffs table gains the reviewer row.
- [x] Audit rail `check_arc_driver_reviewer_record` in `agents/audit/audit.sh`: WARN for any
      in-progress arc `scoped_drivers[]` entry whose `approved_by` starts with `reviewer:` but
      has no `reviewer:` block or whose block says `verdict: fail`; PASS line with the count
      otherwise; silent when no arc has scoped drivers. Mirrored in `fw doctor`.
- [x] Watchtower `/arcs/<slug>` proposed-driver table shows the reviewer verdict per row
      (PASS / FAIL with failed check names / not reviewed) and the Approve button posts through
      the reviewer path; `bin/fw watchtower restart` run and `bin/fw watchtower current` exits 0.
- [x] Tests: bats covering (a)(b)(c) each failing on a crafted fixture and passing on a valid
      one, the default approve path, `--all-reviewed` stopping at the cap, `--none` still
      gated, and the audit rail WARN/PASS/silent legs; `TEST_TEMP_DIR` set in setup;
      `tests/unit/*arc*` and `tests/unit/*bvp*` stay green.
- [x] The six drivers the audit names as unscorable (identity-fidelity, provisioning-safety,
      Discard fidelity, Loop closure (conditional), unknown-input-safety,
      first-run-recoverability) are run through `review-driver --dry-run`; each FAILs check (a)
      as expected, and the task's `## Decisions` records that writing their scoring specs is
      per-arc follow-up work, one task per arc, not done here.
- [x] `FW_VENDOR_ONLY=... bin/fw vendor self` run for every touched file under lib/ agents/
      web/ policy/ and `bin/fw vendor self --check` clean; new files registered with
      `fw fabric register`; `arc_id: arc-006` set in this task's frontmatter.

### Human
- [ ] [REVIEW] The reviewer verdict column on `/arcs/<slug>` reads at a glance and the Approve
      button's post-review outcome is understandable without opening the CLI
      **Steps:**
      1. Open `$(cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url)/arcs/arc-011`
      2. Look at the proposed-driver table: each row shows PASS, FAIL (with the failed check
         names) or "not reviewed"
      3. Click Approve on a PASS row, then on a FAIL row
      **Expected:** the PASS row moves to scoped drivers with `approved_by: reviewer:…`; the
      FAIL row stays proposed and the page names the failed check(s)
      **If not:** note which row and what the page said; the CLI equivalent is
      `cd /opt/999-Agentic-Engineering-Framework && bin/fw arc review-driver arc-011 "<name>"`
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

timeout 300 bats tests/unit/t3429_arc_driver_review.bats > /tmp/.t3429a.out 2>&1 && ! grep -q "^not ok" /tmp/.t3429a.out
test "$(grep -c '# skip' /tmp/.t3429a.out)" -eq 0
timeout 300 bats tests/unit/t3429_arc_approve_driver_default_path.bats > /tmp/.t3429p.out 2>&1 && ! grep -q "^not ok" /tmp/.t3429p.out
test "$(grep -c '# skip' /tmp/.t3429p.out)" -eq 0
timeout 300 bats tests/unit/t3429_arc_driver_reviewer_record_rail.bats > /tmp/.t3429r.out 2>&1 && ! grep -q "^not ok" /tmp/.t3429r.out
test "$(grep -c '# skip' /tmp/.t3429r.out)" -eq 0
# The reviewer verb exists and its help names all three checks.
bin/fw arc review-driver --help > /tmp/.t3429h.out 2>&1 && grep -q "distinguishes" /tmp/.t3429h.out
# Check (a) FAILs on a driver the T-3428 audit already names as unscorable. `;` not
# `&&`: review-driver exits 1 on FAIL, and the grep IS the assertion (T-3203).
bin/fw arc review-driver arc-020 identity-fidelity --dry-run > /tmp/.t3429six.out 2>&1; grep -q "(a) scorable       FAIL" /tmp/.t3429six.out
# --dry-run wrote nothing to the live arc.
test "$(git diff --name-only .context/arcs/arc-020.yaml | grep -c .)" -eq 0
# Audit rail and its fw doctor mirror both shipped.
grep -q "check_arc_driver_reviewer_record" agents/audit/audit.sh
grep -q "Arc driver reviewer records" bin/fw
# Watchtower: the running process is current with web/ (G-104), and all three
# verdict states render.
bin/fw watchtower current
curl -sf "$(bin/fw watchtower url)/arcs/arc-011" -o /tmp/.t3429arc.html && grep -q "Reviewer: PASS" /tmp/.t3429arc.html
curl -sf "$(bin/fw watchtower url)/arcs/arc-006" -o /tmp/.t3429arc6.html && grep -q "Reviewer: FAIL" /tmp/.t3429arc6.html
curl -sf "$(bin/fw watchtower url)/arcs/arc-014" -o /tmp/.t3429arc14.html && grep -q "Reviewer: not reviewed" /tmp/.t3429arc14.html
# The Approve button posts the DEFAULT (reviewer) path — no --from-watchtower.
grep -q 'approve-driver", slug, name\]' web/blueprints/arcs.py
# Docs name the new default next step.
grep -q -- "--all-reviewed" CLAUDE.md
grep -q -- "--all-reviewed" policy/prompts/bvp-driver-session.md
bin/fw vendor self --check

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

### 2026-09-22 — the reviewer has to be able to judge things that are not proposals
- **What changed:** the spec describes the reviewer as operating on `proposed_scoped_drivers[]`.
  Two real call shapes are not proposals: the six already-approved unscorable drivers the AC
  demands a verdict on, and an ad-hoc `fw arc approve-driver <arc> "<new name>" --rationale …`
  with no proposal behind it. A reviewer that only reads proposals would have refused the second
  shape outright — the new default path would have worked only for estimator output.
- **Plan impact:** the selector falls back to `scoped_drivers[]` (read-only), and
  `FW_ARC_REVIEW_INLINE_ENTRY` lets the approve path hand the reviewer an entry built from the
  command line. Neither writes.
- **Triggered:** a `where:` field on every verdict, so the report says which list it judged.

### 2026-09-22 — a red sibling suite that is not this task's (OBS-474)
- **What changed:** `tests/unit/audit_stale_arc_warning.bats` went red during the closing sweep.
  The AC asks for `tests/unit/*arc*` and `*bvp*` to stay green, so this had to be settled before
  close rather than waved past.
- **Finding:** not a T-3429 regression. The test sets `FW_AUDIT_TIMEOUT=120`, while the audit's
  structure section runs `check_invariant_suite` → `timeout 300 bats tests/lint/` (110 tests,
  ~3-5 min, wired in by T-3191). The audit blows its own budget and exits 124, so the
  `[ "$status" -le 1 ]` assertion fails. Proven twice: with the T-3429 rail disabled the audit
  hangs at the identical point, and a `git archive` of the pre-T-3429 commit (2c2315768) returns
  `BASELINE_AUDITRC=124` on the identical fixture at the identical point.
- **Why it looked like mine:** it is timing-flaky, not deterministically red — the same suite
  passed earlier in this session under lighter load. A test sitting on a self-timeout boundary
  reads as "the change you just made broke it" every time the machine is busy.
- **Triggered:** OBS-474. Not fixed here — the remedy is a scope call (raise the test's budget,
  move `check_invariant_suite` out of `structure`, or give the lint sub-run its own budget), and
  one-bug-one-task applies.

### 2026-09-22 — a truncated sweep was hiding a second red suite (OBS-475)
- **What changed:** running the sibling sweep to completion (excluding the OBS-474 file) surfaced
  `tests/unit/t2230_bvp_driver_init.bats` at 4 ok / 11 not ok. Every earlier sweep in this
  session hit its own 1200s wall before reaching that file, so the suite *looked* green.
- **Finding:** also pre-existing. The tests set `PROJECT_ROOT=$TEST_TEMP_DIR`, but `fw` resolves
  the project root by walking up from cwd — and bats runs from the framework repo — so
  `--init` sees the repo's own `policy/value-drivers.yaml`, says "already exists", exits 0, and
  never writes into the temp dir. `bats` against a `git archive` of 2c2315768 gives the identical
  4 ok / 11 not ok.
- **Why this matters beyond the two files:** "the suite stayed green" was an artefact of the
  sweep being cut short, not a measurement. A timed-out test run reports the tests it reached and
  says nothing about the rest — the same false-green shape this task's own audit rail exists to
  catch, one level up.
- **Triggered:** OBS-475. Not fixed here.

### 2026-09-22 — the audit rail's subject is the CLAIM, not the driver
- **What changed:** the obvious rail would WARN on any scoped driver without a `reviewer:` block.
  That fires on every driver approved before today — 7 of them — which trains the rail out on
  day one.
- **Plan impact:** the rail fires only on `approved_by: reviewer:…` (a certification claim) with
  no usable verdict behind it. A human-approved or legacy entry never claimed a reviewer, so it
  is out of scope by construction rather than by an allowlist that would need maintaining.
- **Triggered:** a dedicated test leg for the legacy shape, since "does not fire" is the
  assertion most likely to rot silently.

## Recommendation

**Recommendation:** GO

**Rationale:** Every Agent AC is met and verified against the live corpus, not only fixtures. The
default path through `fw arc approve-driver` now runs the static reviewer and approves on PASS;
the §ACD refusal survives as the override, and `--none` is untouched. The structural limits the
ruling did *not* change — cap 3, weight ≤6, T-1979 dedup — each have a test proving they still
bite on the path that no longer asks a human, because that is the half of this change most likely
to have been loosened by accident. 29 new bats tests, 0 failures, 0 skips. The sibling `*arc*` /
`*bvp*` sweep is 274 ok / 0 not ok / 0 skip **excluding two files that were already red before
this task** — `audit_stale_arc_warning.bats` (OBS-474) and `t2230_bvp_driver_init.bats`
(OBS-475). Both were proven pre-existing by running the same fixtures against a `git archive` of
commit 2c2315768, which fails identically; neither is fixed here, and both are filed. Stating
that plainly rather than reporting a green number that quietly drops two files. What remains is a
render-surface judgement — whether the verdict column reads at a glance and the Approve outcome
is understandable without the CLI — which is a Human AC by P-013 and the one thing I cannot
verify on the operator's behalf.

**Evidence:**
- `fw arc review-driver` ships with three static checks. All six drivers the T-3428 audit names
  as unscorable FAIL check (a) as predicted, and `--dry-run` left their arc YAMLs untouched.
- Default approve on a fixture arc records `approved_by: reviewer:static-v1` with the full
  verdict block copied onto the entry; a FAIL refuses and names `FAILED (a) scorable` /
  `FAILED (c) distinguishes` rather than only a headline.
- `--all-reviewed` on a 5-proposal arc: 3 approved, 2 skipped, naming both skipped drivers and
  the remedy (`fw arc remove-driver`).
- `check_arc_driver_reviewer_record` WARNs on a claim with no block and on `verdict: fail`
  (naming the failed checks), PASSes with the count, stays silent with no scoped drivers, and
  never fires on a human-approved entry. Mirrored in `fw doctor` — live run prints
  `OK  Arc driver reviewer records: 7 scoped driver(s), every reviewer-approved one carries its verdict`.
- Watchtower renders all three states live: `Reviewer: PASS` on `/arcs/arc-011` (2 rows),
  `Reviewer: FAIL — scorable` on `/arcs/arc-006`, `Reviewer: not reviewed` on `/arcs/arc-014`.
  `bin/fw watchtower restart` run; `bin/fw watchtower current` exits 0.
- `bin/fw vendor self --check` clean; `lib/arc-driver-review.sh` registered in the fabric.

## Decisions

### 2026-09-22 — Check (a) accepts a handler, not only a `scoring:` spec
- **Chose:** reuse `lib/bvp-scorability.sh`'s predicate verbatim — a driver is scorable when a
  hand-written handler exists for its id/name/alias **or** when it carries a `scoring:` /
  `scoring_file:` spec that passes the T-3428 validator.
- **Why:** the Context words check (a) as "carries a valid `scoring:` spec". Read literally that
  would refuse `D-DISJOINT` and `D-WIRE-EVIDENCE` on arc-011, which the estimator can already
  score through a handler — and it would make the reviewer and `check_bvp_driver_scorability`
  disagree about the word "scorable" while both WARN at the same operator. The honest question
  is "can the estimator score this at all", which is what the audit rail measures. None of the
  six unscorable drivers pass either reading, so the AC's expected outcome is unchanged.
- **Rejected:** a spec-only reading — it would have manufactured a disagreement between two
  rails that are supposed to be the same measurement.

### 2026-09-22 — Check (b) skips the entry under review by identity, not by name
- **Chose:** `if s is entry: continue` when scanning `scoped_drivers[]`.
- **Why:** an already-approved driver is reviewable (that is how the six get a verdict at all),
  and a name comparison makes every such driver a duplicate of itself. Identity is the only test
  that separates "this very entry" from "a second entry that happens to carry the same name",
  which IS a real collision. Caught by running the six before writing the test, not by the test.

### 2026-09-22 — The six unscorable drivers get a verdict here, not a scoring spec
- **Chose:** run all six through `review-driver --dry-run`, record that each FAILs check (a),
  and leave spec-writing as per-arc follow-up — one task per arc (arc-020, arc-012, arc-015).
- **Why:** a scoring spec is a per-arc authoring judgement about what that arc actually values;
  writing six from outside their arcs would produce six specs nobody owns. The task brief says
  so explicitly, and one-bug-one-task applies to authoring gaps too.
- **Rejected:** drafting placeholder specs to clear the audit WARN — that converts a visible gap
  into an invisible one, which is the exact inversion T-3428 was filed to undo.

### 2026-09-22 — the reviewer gates on the default path for humans too, not only agents
- **Chose:** the reviewer runs whenever neither `--i-am-human` nor `--from-watchtower` is given,
  regardless of `$CLAUDECODE`. Added `--scoring-file PATH` so an ad-hoc driver named on the
  command line — which has no proposal to carry an inline `scoring:` block — can reach check (a)
  at all.
- **Why:** the old §ACD gate only fired under `$CLAUDECODE=1`, so a human at a terminal passed
  straight through. Keeping that shape would mean a human could still add an unscorable driver
  silently, which is the exact gap T-3428 named. The reviewer is a QUALITY gate, not an
  AUTHORITY gate, and quality does not depend on who is typing.
- **Consequence, handled:** five existing tests in `tests/unit/arc_remove_driver_verb.bats`
  (T-1976 ×3, T-1979 ×2) approved spec-less drivers on the unflagged path and went red. Their
  subjects are preserved — only the fixtures' quality moved to what the reviewer now requires;
  the genuine back-compat case (approval with no rationale at all, which cannot pass check (c)
  by construction) moved to the `--i-am-human` override, which is where that behaviour now
  lives. One new leg pins that an ad-hoc driver with no mechanism is refused.
- **Rejected:** scoping the reviewer to `$CLAUDECODE=1` to keep the five tests untouched — that
  would have made the framework's quality bar depend on the terminal it was typed into.

### 2026-09-22 — `--all-reviewed` is serial, and re-reads the arc between approvals
- **Chose:** review-then-approve one driver at a time, re-reading `scoped_drivers[]` each pass.
- **Why:** each approval changes both the cap headroom and the dedup set the NEXT review reads.
  Batching the reviews up front would judge driver 2 against the arc as it was before driver 1
  landed, so a self-colliding pair could both pass.

### 2026-09-22 — The Watchtower page renders the stored verdict; it never runs the reviewer
- **Chose:** `/arcs/<slug>` reads the persisted `reviewer:` block and shows PASS / FAIL (with the
  failed check names) / "not reviewed"; refreshing verdicts is `fw arc review-driver <arc> --all`.
- **Why:** a GET that mutates arc YAML is a worse bug than a stale verdict, and it would race
  every other writer of the same file. "Not reviewed" is an honest third state, not a gap.

### 2026-09-22 — ruamel reformats unrelated scalars when the reviewer writes
- **Chose:** accept it, and verify rather than assert. `closed_at: null` becomes `closed_at:` and
  long strings re-wrap on the first write to an arc YAML.
- **Why:** verified semantically identical (`yaml.safe_load` compare against `git show HEAD:`,
  both arcs) and one-shot — a second run changes only the `ts`. It is the same round-trip
  `lib/arc.sh:arc_approve_driver` has always used, so surgical text insertion would have made the
  reviewer's write behave *differently* from the approve path writing the same file.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-22T10:41:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3429-arc-scoped-value-drivers-are-created-and.md
- **Context:** Initial task creation

### 2026-09-22T15:44:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b479689b
- **Timestamp:** 2026-09-22T18:16:06Z
- **Catalogue:** v1.3-seed
- **Overall:** FAIL
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **skip-as-pass** (severe, deterministic) @ Verification:line 11
     - evidence: `bin/fw arc review-driver arc-020 identity-fidelity --dry-run > /tmp/.t3429six.out 2>&1; grep -q "(a) scorable       FAIL" /tmp/.t3429six.out`

### 2026-09-22T18:15:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
