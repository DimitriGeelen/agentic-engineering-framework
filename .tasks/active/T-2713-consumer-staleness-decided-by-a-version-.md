---
id: T-2713
name: "Consumer staleness decided by a VERSION counter that does not order"
description: >
  VERSION is a tag counter that resets: this repo went 1.6.354 (2026-07-07) then 1.6.121
  (2026-07-30), a 233-point regression. bin/fw:2001 compares consumer vs framework
  with sort -V and classifies ahead/behind. A consumer pinned 1.6.264 therefore reads
  as 'ahead' of a framework at 1.6.163 and the upgrade path is deliberately withheld
  (bin/fw:1994-1996, correctly, to avoid downgrading the pin) — so the consumer is
  frozen on old code while wearing a high number. Live instance: /home/mehdi/2026-AEF-demo.
  T-1828 defended the symptom (do not downgrade) rather than the cause (stop trusting
  the ordering). T-2290 already solved this shape once by replacing an mtime check
  with a content compare; same medicine applies.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [consumer, version, doctor, upgrade]
components: [bin/fw, lib/upgrade.sh, lib/version-relation.sh, tests/unit/version_relation.bats]
related_tasks: [T-1828, T-1838, T-2290]
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
created: 2026-08-01T07:23:44Z
last_update: 2026-08-01T08:26:06Z
date_finished: 2026-08-01T08:26:06Z
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
  - ts: '2026-08-01T07:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-01T07:30:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2713: Consumer staleness decided by a VERSION counter that does not order

## Context

Three sites decided "is this consumer ahead or behind?" by `sort -V` over the VERSION
string:

| Site | Guard | Origin |
|------|-------|--------|
| `bin/fw:2015` | doctor consumer-fleet badge | T-1838 |
| `lib/upgrade.sh:849` | pre-step-1 runtime downgrade guard | T-1912 |
| `lib/upgrade.sh:1742` | pin-rewrite downgrade guard | T-1839 |

VERSION is a **tag counter that resets**. Tags run `v1.6.763, v1.6.762, v1.6.761,
v1.6.10, v1.6.9`; VERSION went `1.6.354 → 1.6.121 → 1.6.176`. A resetting counter does
not order, so all three "ahead" verdicts were guesses shaped like comparisons.

The guards are not wrong — refusing to downgrade a consumer is right. They were handed an
ordering that does not exist. Measured blast radius: **23 of 27 consumers** in this fleet
carry a version with no corresponding tag, so every one of them was receiving a fabricated
direction, and any that sorted high were frozen out of upgrades entirely.

**Fix:** git ancestry, which cannot reset. `fw upgrade` now records `version_sha:` next to
`version:`; the relation is computed by `git merge-base --is-ancestor`. Where no commit is
resolvable the answer is `undecidable` — reported as such, never dressed up as `ahead`.
Same medicine as T-2290 (replace an untrustworthy proxy with the real object).

## Acceptance Criteria

### Agent
- [x] A single shared predicate `fw_version_relation` exists in one place and returns exactly one of `same|behind|ahead|diverged|undecidable`; all three decision sites (`bin/fw:2015`, `lib/upgrade.sh:849`, `lib/upgrade.sh:1742`) call it instead of open-coding `sort -V`.
- [x] The predicate never derives `ahead` or `behind` from version-string ordering. It uses git ancestry on the recorded SHA, falls back to ancestry on the version tag when that tag exists, and returns `undecidable` otherwise.
- [x] `fw upgrade` records `version_sha:` (framework HEAD SHA) in the consumer's `.framework.yaml` next to `version:`, so the next comparison is decidable. Verified by running upgrade against a scratch consumer and grepping the field.
- [x] `undecidable` never renders as `ahead`: with no `version_sha` and no matching tag, doctor's consumer line and both upgrade guards say the relation is undetermined and name the reason, rather than asserting a direction.
- [x] Empirical non-monotonicity is pinned as a test fixture: a case asserting `1.6.264` vs `1.6.163` does NOT resolve to `ahead` on version strings alone (this is the live freeze at `/home/mehdi/2026-AEF-demo`).
- [x] Regression suite `tests/unit/version_relation.bats` green, including a negative control that fails if the predicate silently falls back to `sort -V`.
- [x] `bats tests/unit/upgrade_fresh_machine_simulation.bats` stays green (consumer-facing command hygiene, T-1633).

### Human
- [ ] [REVIEW] Confirm the default for the `undecidable` case.
  **Steps:**
  1. Read the `## Decisions` entry "undecidable → warn and proceed" in this task file.
  2. Consider the two failure directions: refusing on a false `ahead` freezes a consumer indefinitely (observed: Mehdi's box, weeks stale, no governance/security fixes); proceeding could overwrite a consumer that genuinely does hold newer local runtime.
  3. Decide whether `undecidable` should proceed with a loud WARN (implemented default) or keep refusing.
  **Expected:** an explicit call on which direction the framework should fail toward for consumers whose pin predates SHA recording.
  **If not:** flip `FW_UNDECIDABLE_VERSION_PROCEED` default in the predicate and re-run `tests/unit/version_relation.bats`.

**Evidence (live, 2026-08-01):**
- Predicate: `1.6.264` vs `1.6.163` → `undecidable` (was `ahead` → refuse). `9.9.9` at framework HEAD → `same` (was `ahead` → refuse). Ancestor SHA at version `1.0.0` → `behind`.
- End-to-end `fw upgrade` (scoped `HOME`) wrote `version_sha: 54c702fcd42f…` = framework HEAD, alongside `version: 1.6.178`, `upgraded_from: 1.6.176`.
- Doctor fleet after the change: **23 consumers report `relation undetermined`, 4 report `behind`, 0 report `ahead`.** Every one of the 23 previously received a fabricated direction.
- Falsification: restoring the `sort -V` fallback turns tests 1 and 4 red.
- **The counter moved mid-measurement** — two doctor runs minutes apart reported framework `v1.6.177` then `v1.6.178`. The quantity these guards were ordering on is not stable across the length of a single verification.

<!-- Template Human-AC guidance retained below for reference.
     Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
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

bats tests/unit/version_relation.bats
bats tests/unit/upgrade_fresh_machine_simulation.bats
diff lib/version-relation.sh .agentic-framework/lib/version-relation.sh
diff lib/upgrade.sh .agentic-framework/lib/upgrade.sh
out=$(bash -n bin/fw && bash -n lib/upgrade.sh && bash -n lib/version-relation.sh && echo SYNTAXOK); echo "$out" | grep -q SYNTAXOK

## RCA

**Symptom:** consumers frozen out of `fw upgrade`. A project pinned `1.6.264` against a
framework at `1.6.163` was told it was AHEAD and that upgrading would downgrade it, so it
sat weeks without governance or security fixes. 23 of 27 consumers in this fleet were
being given a direction that had no basis.

**Root cause:** `sort -V` answers "which string sorts higher". Three call sites read that
answer as "which code is newer". Those are the same question only if the version number is
monotonic, and this one is not — it is a tag counter that resets, observed going
`1.6.354 → 1.6.121 → 1.6.176`, and observed moving `1.6.177 → 1.6.178` *between two doctor
runs during this task's own verification*.

**Why structurally allowed:** the pin recorded no fact capable of deciding the question.
`.framework.yaml` held `version:` and nothing else — no commit, no timestamp, no content
hash. So there was never a correct implementation available at those three sites; the only
data present was the counter, and the counter cannot answer. T-1828/T-1838/T-1839/T-1912
each hardened the *consequence* (do not downgrade) across four tasks without anyone asking
whether the input supported the inference. Four rounds of defending a conclusion drawn from
an unusable premise.

**Prevention:** three parts. (1) `version_sha:` is now written at upgrade time, so the
question becomes answerable at all. (2) The predicate returns `undecidable` rather than
guessing — the failure mode is now visible instead of confidently wrong. (3) `version_relation.bats`
test 9 greps the call sites for `sort -V`, so re-introducing a local copy of the bad
comparison fails the suite rather than silently re-splitting the logic (L-399).

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

### 2026-08-01 — undecidable → warn and proceed (operator-reviewable)

- **Chose:** when the relation cannot be computed, emit a loud WARN naming the reason and
  continue. Knob: `FW_UNDECIDABLE_VERSION_PROCEED` (default `1`).
- **Why:** the observed harm is the freeze. Refusing on `undecidable` reproduces exactly
  the behaviour that stranded 23 consumers, just with better wording. And it is
  self-healing: the upgrade that proceeds writes `version_sha`, so the case occurs at most
  once per consumer.
- **Rejected:** keep refusing — safest-sounding, but it makes the legacy-pin population
  permanently unupgradeable, since nothing else ever writes the SHA.
- **Flagged for human:** this flips a safety default and its blast radius is the whole
  consumer fleet. Raised as the `[REVIEW]` Human AC rather than settled by me.

### 2026-08-01 — record a SHA rather than fix the counter

- **Chose:** leave VERSION alone; add `version_sha:` beside it.
- **Why:** VERSION is used for display, release naming and consumer-visible identity.
  Making it monotonic is a separate, larger change with its own blast radius. The
  ordering question needs a commit, not a prettier number.
- **Rejected:** content-hashing the vendored tree — tells you files *differ*, not which is
  *newer*, so it cannot answer the ahead/behind question at all.

### 2026-08-01 — writer lives beside reader

- **Chose:** `fw_record_version_sha` sits in `lib/version-relation.sh`, not in `upgrade.sh`.
- **Why:** the pin format is a producer/consumer contract and L-399 is the standing lesson
  about shipping one half of one. Both halves are now in the same file and the same diff.

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

## Recommendation

**Recommendation:** GO — ship the ancestry predicate; confirm the `undecidable` default.

**Rationale:** the code change is not the open question — replacing an ordering that
provably does not order is unambiguous, and it is pinned by 9 tests that go red in both
directions (remove the ancestry → red; make it over-eager → red). The one thing I should
not decide alone is the `undecidable` default, because it flips a safety behaviour across
27 consumers. I recommend keeping `proceed-with-WARN` (the shipped default): refusing on
`undecidable` reproduces the exact freeze this task exists to fix, and since only an
upgrade writes `version_sha`, refusing would make the legacy population permanently
unupgradeable. It is also self-limiting — each consumer hits `undecidable` at most once.

**Evidence:**
- `1.6.264` vs `1.6.163` → `undecidable` (was `ahead` → refuse). The live freeze.
- `9.9.9` pinned at framework HEAD → `same` (was `ahead` → refuse).
- Doctor fleet, post-change: **23 `undetermined`, 4 `behind`, 0 `ahead`** — all 23 were
  previously handed a fabricated direction.
- End-to-end `fw upgrade` (scoped `HOME`) wrote `version_sha: 54c702fcd42f…` = framework
  HEAD, with `upgraded_from: 1.6.176`.
- `tests/unit/version_relation.bats` 9/9; `tests/unit/upgrade_fresh_machine_simulation.bats`
  7/7 on committed bytes; `bash -n` clean on all three edited files.
- Test 9 greps both call-site files for `sort -V`, so a local re-copy of the bad compare
  fails the suite (L-399).
- **VERSION moved `1.6.177 → 1.6.178` between two doctor runs inside this task.** The
  quantity these guards ordered on is not stable across one verification pass.

**What I am NOT claiming:** I did not re-run Mehdi's box at `/home/mehdi/2026-AEF-demo` —
that is a different host and outside this project's boundary. The fix is verified here on
this fleet; confirming it unblocks that specific machine is a separate step.

## Updates

### 2026-08-01T07:23:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2713-consumer-staleness-decided-by-a-version-.md
- **Context:** Initial task creation

### 2026-08-01T07:58:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4487c84f
- **Timestamp:** 2026-08-01T08:26:48Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `bats tests/unit/version_relation.bats`

### 2026-08-01T08:26:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
