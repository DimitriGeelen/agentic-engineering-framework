---
id: T-2242
name: "Class-agnostic wording for T-2240 self-vendor drift block message"
description: >
  Class-agnostic wording for T-2240 self-vendor drift block message

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/git/lib/hooks.sh]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-07T20:06:57Z
last_update: '2026-06-11T22:24:12Z'
date_finished: 2026-06-07T20:10:37Z
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
  - ts: '2026-06-11T22:24:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2242: Class-agnostic wording for T-2240 self-vendor drift block message

## Context

T-2241 added templates as a second self-vendor class. The T-2240 pre-push gate fires on both classes (one regex catches both — `would sync`), but the *secondary* block-message line still hard-codes lib/-only language:

- `".agentic-framework/lib/ is stale relative to lib/. Consumers..."` (BLOCK)
- `git add .agentic-framework/lib/` (fix command)
- `"vendored .agentic-framework/lib/ may diverge from lib/"` (WARN class note)

When a template drifts (no lib/ drift), the message misdirects the reader to look at lib/. The per-class `would sync` lines above the secondary text already name the class — the secondary text just needs to be class-agnostic.

Three lines to flip: the BLOCK diagnostic, the BLOCK fix-command path, and the WARN class note. New shape uses `.agentic-framework/` (covers both subtrees idempotently with `git add`).

## Acceptance Criteria

### Agent
- [x] Slice 1 (hook source): `agents/git/lib/hooks.sh` — the BLOCK branch's diagnostic line and fix command, plus the WARN branch's class note, all read class-agnostically (no hard-coded "lib/" in the surface text). The strings "is stale relative to lib/" and "may diverge from lib/" no longer appear in the source; the `git add .agentic-framework/lib/` fix command becomes `git add .agentic-framework/`
- [x] Slice 2 (installed hook parity): after `bin/fw git install-hooks --force`, `.git/hooks/pre-push` contains the new class-agnostic strings; the lib-only strings no longer appear in the installed hook
- [x] Slice 3 (bats coverage updated): `tests/unit/t2240_pre_push_self_vendor_gate.bats:t2` asserts the class-agnostic `git add .agentic-framework/` plus the existing checks (canonical block sentence, both bypass mechanisms named, fix command copy-pasteable). 5/5 PASS
- [x] Slice 4 (live smoke + reviewer): touch a template-only drift (no lib/ drift); invoke the installed hook with synthetic stdin; verify the block message no longer hard-codes "lib/" but the `would sync N template(s)` line still names the class. Restore the template. Reviewer scan: `bin/fw reviewer T-2242` → Overall PASS

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

# Slice 1: hook source carries class-agnostic strings, no lib-only remnants
grep -q "Vendored .agentic-framework/ is stale" agents/git/lib/hooks.sh
grep -q "git add .agentic-framework/ &&" agents/git/lib/hooks.sh
! grep -q "is stale relative to lib/" agents/git/lib/hooks.sh
! grep -q "git add .agentic-framework/lib/" agents/git/lib/hooks.sh
! grep -q "may diverge from lib/" agents/git/lib/hooks.sh
# Slice 2: installed hook parity — same strings in .git/hooks/pre-push
grep -q "Vendored .agentic-framework/ is stale" .git/hooks/pre-push
grep -q "git add .agentic-framework/ &&" .git/hooks/pre-push
! grep -q "is stale relative to lib/" .git/hooks/pre-push
! grep -q "git add .agentic-framework/lib/" .git/hooks/pre-push
# Slice 3: t2240 bats still pass with new assertions (L-387 capture-then-grep)
bats_out=$(bats tests/unit/t2240_pre_push_self_vendor_gate.bats 2>&1); echo "$bats_out" | grep -q "^1\.\.5$" && echo "$bats_out" | grep -q "^ok 5 " && ! echo "$bats_out" | grep -q "^not ok"
# Slice 4: reviewer overall PASS or CONCERN (no FAIL); markdown-bold regex aware
rev_out=$(bin/fw reviewer T-2242 2>&1); echo "$rev_out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$rev_out" | grep -q "Overall:.*FAIL"

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

## Recommendation

**Recommendation:** GO

**Rationale:** Pure textual fix — no semantic change, no new tests beyond updating one assertion. Three lines flipped from lib-only language to class-agnostic phrasing; the per-class `would sync` line above the diagnostic already names which class drifted, so the secondary prose stays generic. Class is preserved (still named in the actual drift line); only the misdirection is removed. Fix command also gets simpler — `git add .agentic-framework/` covers both subtrees idempotently.

**Evidence:**
- Hook source: `agents/git/lib/hooks.sh` — 3 lines flipped (BLOCK diagnostic, BLOCK fix-command, WARN class note)
- Installed hook: `.git/hooks/pre-push` carries the new strings; lib-only strings absent (verified by negative-assertion greps in Verification)
- Bats: `tests/unit/t2240_pre_push_self_vendor_gate.bats:t2` updated — asserts `git add .agentic-framework/` (with trailing space-and-anchor to distinguish from `.agentic-framework/lib/`) + negative-asserts `is stale relative to lib/`. 5/5 PASS.
- Live smoke: template-only drift triggers the gate; block message shows "would sync 1 template(s)" (class named) + "Vendored .agentic-framework/ is stale" (class-agnostic prose) + `git add .agentic-framework/` (class-agnostic fix) — no "lib/" misdirection
- Reviewer: see ## Reviewer Verdict block

## Updates

### 2026-06-07T20:06:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2242-class-agnostic-wording-for-t-2240-self-v.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-043319c3
- **Timestamp:** 2026-06-07T20:10:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-07T20:10:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
