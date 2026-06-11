---
id: T-2218
name: "T-2217 Slice 3 — anchor IW-N regex in update-task.sh disposition gate (RC5
  fix)"
description: >
  T-2217 Slice 3 — anchor IW-N regex in update-task.sh disposition gate (RC5 fix)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-05T20:17:36Z
last_update: '2026-06-11T22:24:11Z'
date_finished: 2026-06-05T20:24:21Z
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
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2218: T-2217 Slice 3 — anchor IW-N regex in update-task.sh disposition gate (RC5 fix)

## Context

T-2217 RCA §8 surfaced **RC5**: `agents/task-create/update-task.sh:770` regex `(IW-[0-9]+|^[[:space:]]*-[[:space:]]*Q-?[0-9]+)` has an **unanchored** `IW-[0-9]+` branch — it matches "IW-1" anywhere in prose. T-2217's own IW-4 rationale ("the missing IW-1/IW-2 dispositions") tripped the gate parser: the rationale line was misclassified as a new question marker, causing the previous IW-N's disposition+rationale to be flushed as "missing". Recursive symmetry — the very task RCA'ing the gate was blocked by it.

**Fix shape:** anchor the IW branch to start-of-line marker forms only (list-item `- **IW-N:**` / `- IW-N:` / header `### IW-N`), mirroring the Q-N branch's anchoring. Add bats coverage for the prose-mention case so the FP cannot recur.

This is T-2217 GO scope Slice 3 (F8 ≈ 0.5).

## Acceptance Criteria

### Agent
- [x] `agents/task-create/update-task.sh` line ~770 IW-N branch is anchored to start-of-line; the bare `IW-[0-9]+` alternation is removed/replaced.
- [x] `tests/unit/disposition_gate.bats` gains a regression test that exercises an Open Questions block where a fully-disposed IW-N's rationale text mentions "IW-1" / "IW-2" in prose — gate must PASS (not block).
- [x] All pre-existing bats tests in `tests/unit/disposition_gate.bats` still pass (7 tests + 1 new = 8 PASS).
- [x] T-2209's own ## Open Questions (which contains IW-N prose-mentions per the RC5 incident) no longer triggers FP on the disposition gate — verified via dry-run grep against the regex.
- [x] Reviewer static-scan PASS on this task (`bin/fw reviewer T-2218 2>&1 \| grep -q "Overall:.*PASS"`).

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

bats tests/unit/disposition_gate.bats
out=$(bin/fw reviewer T-2218 --no-write 2>&1); echo "$out" | grep -q "Overall:.*PASS"

## RCA

**Symptom:** T-2217 (the inception RCA'ing the Watchtower side-effect-warning truncation, itself filed as the 4th incident of G-068 META-class) could not reach `--status work-completed`. The T-2190 disposition gate refused close, naming IW-4 as missing disposition+rationale — yet IW-4 in the file had both, properly formatted. Recursive symmetry: the very task RCA'ing a parser gate was blocked by another parser gate.

**Root cause:** `agents/task-create/update-task.sh:770` regex for question-marker detection was `(IW-[0-9]+|^[[:space:]]*-[[:space:]]*Q-?[0-9]+)`. The `IW-[0-9]+` branch had **no line anchor** — it matched any occurrence of "IW-1", "IW-2", … anywhere in the file. IW-4's rationale text was `"the missing IW-1/IW-2 dispositions"`; that line was reclassified by the parser as a *new* question marker, which flushed the previous (IW-4's) accumulated `has_disposition=true`+`has_rationale=true` state as "missing dispositions". `current_q` reset to "IW-1" mid-block, no subsequent `disposition:`/`rationale:` lines were seen for that phantom IW-1, and the gate reported missing fields the file actually had.

**Why structurally allowed:** The `update-task.sh:770` regex grew by accretion — the Q-N branch was added later with proper line-anchoring (`^[[:space:]]*-[[:space:]]*Q-?[0-9]+`), but the original IW branch was never retro-fitted to match the same anchored shape. The bats coverage (7 tests at filing time) exercised valid marker shapes only — none of the test fixtures contained prose mentions of IW-N in rationale text, so the FP slot was untested. Adjacent class to L-396 (regex-by-accretion).

**Prevention:** Anchored regex (this fix) + bats fixture that exercises the prose-mention case explicitly (this fix). The bats fixture is named "prose mention of IW-N in rationale does NOT trigger a false flush (T-2218 RC5)" — pinned at `tests/unit/disposition_gate.bats:172`. Future additions to the question-marker regex must respect the anchor; a sibling Q-N branch is already the worked example.

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

### 2026-06-05T20:17:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2218-t-2217-slice-3--anchor-iw-n-regex-in-upd.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e21e823f
- **Timestamp:** 2026-06-05T20:24:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-05T20:24:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
