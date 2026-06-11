---
id: T-1913
name: "arc_membership slug↔NNN union — fw arc show <slug> misses tasks using NNN form,
  and vice versa (B-1 from arc-005 critical re-audit)"
description: >
  arc_membership slug↔NNN union — fw arc show <slug> misses tasks using NNN form,
  and vice versa (B-1 from arc-005 critical re-audit)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bug, arc-membership, silent-corpus, CLI-Watchtower-parity, T-1880-sibling]
components: [lib/arc_membership.sh, lib/arc.sh, 
      tests/unit/arc_membership_dual_id.bats]
related_tasks: [T-1880, T-1874, T-1875, T-1876, T-1879, T-1881]
arc_id: arc-005
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T22:14:02Z
last_update: '2026-06-11T22:24:03Z'
date_finished: 2026-05-20T14:23:47Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:36Z'
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
      D4: 2
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=1 
      (body:episodic-only); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1913: arc_membership slug↔NNN union — fw arc show <slug> misses tasks using NNN form, and vice versa (B-1 from arc-005 critical re-audit)

## Context

B-1 finding from arc-005 critical re-audit (2026-05-18 session): the CLI helper `lib/arc_membership.sh:arc_tasks_for(slug)` searches for tasks where `arc_id:` literally matches the input string. It does NOT resolve slug↔arc-NNN equivalence. Per CLAUDE.md §T-1849, both forms are spec-valid; tasks may carry either.

Concrete evidence from arc-005 (arc-grooming):
- 32 tasks: `arc_id: arc-grooming` (slug form — historical, filed before T-1848 sequential NNN allocation)
- 3 tasks: `arc_id: arc-005` (NNN form — T-1909/10/11, filed after)
- `fw arc show arc-grooming` → returns 32 (slug-form only)
- Watchtower `/arcs/arc-grooming` → returns 35 (Python helper `task_dict_in_arc()` accepts `arc_numeric_id` parameter, lines 134-166 of `lib/arc_membership.py`)

Asymmetry: Python helper has dual-identity logic (T-1848 dual identity, T-1880 extraction). Shell helper does not. Same class as the original silent-corpus pattern T-1880 was extracted to prevent — different surface, same blindness.

## Acceptance Criteria

### Agent
- [x] `lib/arc_membership.sh` adds `_arc_resolve_dual_id <input>` helper: takes slug OR NNN, emits `<slug>\t<nnn>` by reading `.context/arcs/`. Empty output if input doesn't resolve.
- [x] `arc_tasks_for <input>` modified to union matches across both forms (slug-form arc_id + NNN-form arc_id + legacy `arc:<slug>` tag).
- [x] Header comment updated to document the union-across-forms behavior.
- [x] Bats test `tests/unit/arc_membership_dual_id.bats`: 7 tests passing — fixture arc with slug-form + NNN-form + legacy-tag tasks; verifies `arc_tasks_for slug` and `arc_tasks_for nnn` both return the full union.
- [x] Live verification: `bin/fw arc show arc-grooming` returns 36 tasks (was 32 pre-fix; includes T-1913 itself + the 3 NNN-form active tasks T-1909/10/11 + 32 historical slug-form).
- [x] Live verification: `bin/fw arc show arc-005` returns the same 36 tasks (was 0 task entries pre-fix — only the arc card).
- [x] No regression: `bin/fw doctor` reports 18 warnings, 0 failures (all warnings pre-existing T-1828 class).
- [x] **Sibling discovery:** `lib/arc.sh` carries inline duplicates `_arc_tasks_for / _arc_tasks_with_arc_id / _arc_tasks_with_tag` that T-1880's extraction never consolidated. Applied the same dual-id fix to `lib/arc.sh:_arc_tasks_for` so `fw arc show` (which calls the lib/arc.sh local) gets the fix. Follow-up task should consolidate — see Evolution.

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

bats tests/unit/arc_membership_dual_id.bats
test "$(bin/fw arc show arc-grooming 2>&1 | grep -cE '^  T-[0-9]+')" -ge 35
test "$(bin/fw arc show arc-005 2>&1 | grep -cE '^  T-[0-9]+')" -ge 35

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

**Symptom:** `bin/fw arc show arc-005` returned 0 task entries (NNN form). `bin/fw arc show arc-grooming` returned 32 tasks but missed every task whose frontmatter used the NNN form `arc_id: arc-005` (slug-form callers were blind to NNN-form members and vice versa). CLI and Watchtower disagreed because Watchtower already happened to query both forms while the CLI did not — a CLI ↔ UI parity break of the worst class (silent miscount).

**Root cause:** `lib/arc_membership.sh:arc_tasks_for` matched only on the literal input string. When `arc_id:` admits two equivalent forms (slug `arc-grooming` and immutable NNN `arc-005`, both resolving to the same `.context/arcs/arc-grooming.yaml`), a single-form scan necessarily under-counts. The helper had no dual-id resolver to expand input into both forms before grepping.

**Why structurally allowed:** Two compounding gaps. (1) T-1880 extracted `arc_tasks_*` into a shared helper *specifically* to eliminate silent-corpus class for arc-membership scans — but the canonical form at extraction time was slug-only, so the dual-id case was never tested. The NNN form was added later (T-1849/T-1850 D-Immutability axiom) and the helper was never retro-fitted. (2) T-1880 left inline duplicates of `_arc_tasks_*` inside `lib/arc.sh` (line 933 et al) for a "follow-up cleanup"; the CLI dispatched into those duplicates, not the shared helper — so even if the shared helper had been fixed, the CLI bug would have persisted. This is the L-397 canonical-helper-with-residual-silent-corpus pattern repeating one rung down.

**Prevention:** `tests/unit/arc_membership_dual_id.bats` — 7 tests pinning the union behaviour: fixture arc with mixed slug-form + NNN-form + legacy `arc:<slug>` tag tasks; `arc_tasks_for slug` and `arc_tasks_for NNN` must return the same superset; unknown input must degrade to literal-only (no spurious resolution); `arc_tasks_with_arc_id` regression pin so the *single*-form helper stays single-form (not all callers want the union). Sibling cleanup T-1914 then consolidates `lib/arc.sh` duplicates to delegate to the shared helper, closing the rung-down silent-corpus structurally so this class can't recur in arc-membership land.

## Evolution

### 2026-05-18 — discovered sibling duplicate in lib/arc.sh

- **What changed:** The fix in `lib/arc_membership.sh` (the shared helper) worked when invoked directly via `bash -c` sourcing, but `bin/fw arc show` still returned 32. Tracing the call path revealed `lib/arc.sh` carries its OWN underscored copies (`_arc_tasks_for`, `_arc_tasks_with_arc_id`, `_arc_tasks_with_tag`) that never delegate to the shared helper. T-1880 (T-NEW-15) was supposed to extract these — but only the Python side (`lib/arc_membership.py`) and the consumers `lib/evolution_log.sh` / `agents/handover/handover.sh` were migrated. `lib/arc.sh`'s inline copies were left as duplicates.
- **Plan impact:** Fix had to land in BOTH `lib/arc_membership.sh` AND `lib/arc.sh`. Otherwise the CLI bug remains because the CLI consumer never reads the shared helper.
- **Triggered:** Follow-up task (not yet filed) — consolidate `lib/arc.sh:_arc_tasks_*` to source-and-delegate to `lib/arc_membership.sh`. That eliminates the duplication T-1880 was meant to remove. Risk: line 933 calls `_arc_tasks_with_tag "from-${anchor}"` for a different namespace; consolidation must preserve that caller. Low-priority cleanup, not urgent.

### 2026-05-18 — silent-corpus pattern at a different layer

- **What changed:** L-397 (origin: T-1874/75/76/77 + T-1879) framed the silent-corpus class as "consumer re-implements scan, misses migrated format." This case is the same class one level deeper: the SHARED helper exists, but it itself had blindness for the slug↔NNN duality that T-1848 introduced. The fix to T-1880 (extraction) was necessary but not sufficient — extraction without dual-identity awareness left a hole inside the shared code.
- **Plan impact:** None for this slice; the fix lands here. But the broader pattern (every storage-format dimension needs corresponding union logic in the canonical helper) deserves a learning entry.
- **Triggered:** Learning entry L-NEW: "Canonical helpers must encode every storage-format-dimensional equivalence the spec admits. Extracting a shared helper only covers the duplication dimension; dual-identity / dual-format consumers still produce silent corpora *inside* the canonical helper if equivalence logic isn't included." File at completion.

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

**Recommendation:** GO.

**Rationale:** B-1 from the critical re-audit was the worst structural item — the helper extracted in T-1880 (specifically to prevent silent-corpus class) had a residual silent-corpus inside it for the slug↔NNN dimension. Now fixed in both the shared helper (`lib/arc_membership.sh`) AND the inline-duplicate consumer (`lib/arc.sh`). `fw arc show` and Watchtower now agree (36/36). 7 bats tests pin the union behaviour. No regression in `fw doctor`.

**Evidence:**
- `lib/arc_membership.sh:_arc_resolve_dual_id` + `arc_tasks_for` — added dual-id resolution + union
- `lib/arc.sh:_arc_tasks_for` — inline duplicate also patched (T-1880 incompleteness discovery)
- `tests/unit/arc_membership_dual_id.bats` — 7 tests, all pass
- Live: `bin/fw arc show arc-grooming` returns 36 (was 32); `bin/fw arc show arc-005` returns 36 (was 0)
- `bin/fw doctor` — 18 warnings, 0 failures (all warnings pre-existing T-1828 class)

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

### 2026-05-18T22:14:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1913-arcmembership-slugnnn-union--fw-arc-show.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-63f93f9d
- **Timestamp:** 2026-06-02T15:00:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-20T14:23:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
