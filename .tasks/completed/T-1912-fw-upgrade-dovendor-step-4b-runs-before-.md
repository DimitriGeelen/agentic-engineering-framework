---
id: T-1912
name: "fw upgrade do_vendor step 4b runs BEFORE step 9 version-ahead check — runtime
  downgrade slips past T-1839 guard, creates split-brain (runtime older, pin newer)"
description: >
  fw upgrade do_vendor step 4b runs BEFORE step 9 version-ahead check — runtime downgrade
  slips past T-1839 guard, creates split-brain (runtime older, pin newer)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bug, upgrade, version-skew, structural-fix, T-1839-sibling]
components: [lib/upgrade.sh]
related_tasks: [T-1838, T-1839, T-1828, T-1542]
arc_id: arc-004
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T22:08:27Z
last_update: '2026-06-11T22:24:03Z'
date_finished: 2026-05-28T15:28:19Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 5
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=5 (body:class-neutral); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1912: fw upgrade do_vendor step 4b runs BEFORE step 9 version-ahead check — runtime downgrade slips past T-1839 guard, creates split-brain (runtime older, pin newer)

## Context

Field report from a consumer-project `fw upgrade` (2026-05-18, dimitri-mint-dev): consumer at v1.6.260, github at v1.6.225. Upgrade ran:

1. **Step [4b/9] `do_vendor`** — copied framework runtime (v1.6.225) over consumer's runtime (v1.6.260). **No version check.**
2. **Step [9/10] version tracking** — T-1839 silent-downgrade guard fired correctly, refused to rewrite `.framework.yaml` from v1.6.260 → v1.6.225.

Result: split-brain. Runtime files = v1.6.225, `.framework.yaml.version` = v1.6.260. The T-1839 guard closed half the door (config side) but missed the runtime that step 4b had already mutated 500 lines earlier.

Recovery: clone framework to `/tmp`, re-run `fw upgrade --source /tmp/...` with explicit target. Clean recovery confirms the bug is purely an ordering issue.

**Reference for the existing half-guard:**
- `lib/upgrade.sh:1093-1111` (T-1839): version-ahead refusal — protects `.framework.yaml`
- `lib/upgrade.sh:612-624`: `do_vendor` call in step 4b — no precheck
- `bin/fw:do_vendor()`: zero version-comparison logic (only T-680 self-reference guard)

## Acceptance Criteria

### Agent
- [x] Version-ahead precheck added to `do_upgrade()` (lib/upgrade.sh:370-396) BEFORE step 1, mirroring the step-9 T-1839 sort-V direction check — fires for ahead direction with same REFUSED + T-1828 reference + `--force-downgrade` advice
- [x] Precheck honors the same `--force-downgrade` escape hatch as T-1839 — verified via bats test "precheck honours --force-downgrade escape hatch"
- [x] Bats test in `tests/unit/test_upgrade_runtime_downgrade_guard.bats` (sibling to T-1839's): consumer at v1.6.260 against framework at v1.6.225, `do_upgrade` refuses with non-zero status AND the marker file inside `.agentic-framework/lib/` is unchanged (no step 4b mutation)
- [x] Bats test: with `--force-downgrade`, the T-1912 REFUSED block does NOT fire (precheck bypassed; downstream steps may still fail in the stub consumer but the runtime+pin downgrade is permitted together)
- [x] `fw doctor` post-fix: existing T-1839 guard tests (9/9 pass) and fresh-machine simulation (3/3 pass) confirm no regression on healthy upgrade paths
- [x] Learning entry filed: L-441 — "Half-guards manufacture split-brain instead of clean refusal" (see `fw learnings` or `.context/project/learnings.yaml`)

### Human
<!-- This task is purely structural — no UI surface, no subjective check. Agent ACs cover it fully. -->

## Verification

bash -n lib/upgrade.sh
grep -q 'T-1912: pre-step-1 version-ahead precheck' lib/upgrade.sh
bats tests/unit/test_upgrade_runtime_downgrade_guard.bats
bats tests/unit/test_upgrade_downgrade_guard.bats
bats tests/unit/upgrade_fresh_machine_simulation.bats

## RCA

**Symptom:** Consumer ran `fw upgrade` (2026-05-18, dimitri-mint-dev). Step 4b silently copied framework v1.6.225 runtime over consumer's v1.6.260 runtime. Step 9 refused to rewrite the version pin (correctly — T-1839). Final state: `.agentic-framework/` runtime at v1.6.225, `.framework.yaml.version: 1.6.260`. Subsequent CLI behavior was inconsistent — pin claimed newer, runtime was older.

**Root cause:** `do_upgrade()` in `lib/upgrade.sh` performs mutating steps (4b vendor copy) BEFORE the version-ahead validation step (9). The T-1839 guard is positioned at the *pin write* but ordering means runtime mutation has already happened. `do_vendor()` itself has zero version logic — it's a pure file-copier.

**Why structurally allowed:** T-1839 framed the silent-downgrade class as a *config-write* concern. The runtime copy step (4b) was added by T-1157 as a refactor of inline per-file syncs into the `do_vendor` call — at that time there was no downgrade-direction awareness. T-1839 closed the config door but didn't audit the upgrade sequence for prior mutations that would defeat the guard. Classic *half-fix* shape: the guard exists, it fires correctly on what it watches, but it watches the wrong checkpoint.

**Prevention:** This task's structural fix (precheck before step 4b) closes the immediate gap. The CLASS prevention is the new learning ("half-guards manufacture split-brain"). Bats simulation pins both halves (refusal-with-force AND no-mutation-on-refuse) so regression catches future re-introduction.

## Recommendation

**Recommendation:** SHIPPED 2026-05-28 — precheck implemented at `lib/upgrade.sh:370-396` (mirrors T-1839 step-9 logic but fires BEFORE step 1). 10 new bats tests in `tests/unit/test_upgrade_runtime_downgrade_guard.bats` pin source-level marker + REFUSED message + force-downgrade bypass + no-mutation-on-refuse + no-fire on behind/equal/no-pin. T-1839's 9 tests still green. Learning L-441 filed. Original implementation outline below kept for traceability.

**Recommendation (original — pre-implementation):** DEFER — task captured with full RCA, ACs, and verification. Implementation needs ~1 session focused on:

1. Refactor `do_upgrade()` to perform version-ahead check at preamble (single call, before any mutation)
2. Have step 9 collapse to a no-op when preamble already validated (or stay as defense-in-depth)
3. Bats test for both refuse and `--force-downgrade` paths
4. Learning entry

**Rationale:** Field-reported real incident (2026-05-18 dimitri-mint-dev). T-1839 left a half-guard, T-1912 closes the runtime side. Low blast-radius (purely additive precheck), high value (eliminates split-brain class).

**Evidence:**
- `lib/upgrade.sh:612-624` (step 4b mutation, no precheck)
- `lib/upgrade.sh:1093-1111` (step 9 T-1839 pin-side guard — works correctly, but too late)
- `bin/fw:do_vendor()` (no version logic)
- User field report 2026-05-18: split-brain confirmed (runtime 1.6.225 / pin 1.6.260)
- Recovery via clone-to-/tmp + explicit `--source` is clean — confirms bug is ordering, not logic

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

### 2026-05-28 — half-guard symmetry rule extracted as L-441

- **What changed:** Filing framed the bug as an ordering issue ("step 4b runs before step 9"). Implementation crystallised it as a *symmetry* issue: T-1839 added a direction-aware refusal at the LATEST validation site (pin write) when the EARLIEST mutation site (vendor copy) was the right checkpoint. Both halves are needed — but if you can only have one, the early one is more defensible because it leaves state untouched on refusal.
- **Plan impact:** The original AC #6 (file learning) was filed as a side-deliverable. Implementation made clear the learning is the most generalisable artifact — any direction-aware guard in the framework (downgrade, deletion, revert, schema-rollback) should be audited under the L-441 symmetry rule. Filed as L-441 with broader phrasing than just upgrade.
- **Triggered:** L-441 "Half-guards manufacture split-brain" — applies beyond `fw upgrade`. Future opportunity: audit `bin/fw task update --status work-completed`, `fw arc close`, and other multi-step refusal-bearing flows for the same shape.

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

### 2026-05-18T22:08:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1912-fw-upgrade-dovendor-step-4b-runs-before-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-17550ad3
- **Timestamp:** 2026-06-02T15:00:25Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#6 (Agent)** — Learning entry filed: L-441 — "Half-guards manufacture split-brain instead of clean refusal" (see `fw learnings` or `.context/project/learnings.yaml`)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/project/learnings.yaml in: Learning entry filed: L-441 — "Half-guards manufacture split-brain instead of clean refusal" (see `fw learnings` or `.context/project/learnings.yaml`)`
### 2026-05-28T15:28:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
