---
id: T-2263
name: "arc-006 Slice 2C — extend self-vendor to sync BVP policy templates"
description: >
  T-2229 Slice 2C: add `_self_vendor_policy()` to `lib/upgrade.sh` so the
  framework's own `.agentic-framework/policy/` mirror stays in lock-step with
  `$FRAMEWORK_ROOT/policy/value-drivers.yaml` + `policy/bvp-scoring-rubric.md`.
  Mirror of the existing `_self_vendor_libs` (T-2095) + `_self_vendor_templates`
  (T-2241) helpers. Same "would sync"/"synced" prefix so the T-2240 pre-push
  gate catches policy drift via the SAME regex as libs + templates — one gate,
  three classes.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [arc:value-prioritisation]
components: [lib-upgrade]
related_tasks: [T-2095, T-2240, T-2241, T-2261, T-2262]
arc_id: arc-006
created: 2026-06-08T14:09:23Z
last_update: '2026-06-11T22:24:13Z'
date_finished: 2026-06-08T14:13:37Z
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
  - ts: '2026-06-11T22:24:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2263: arc-006 Slice 2C — extend self-vendor to sync BVP policy templates

## Context

The T-2240 pre-push gate (`agents/git/pre-push`) refuses pushes when
`fw vendor self --dry-run` reports any "would sync N file(s)" line — the
gate's single regex catches drift in both `lib/` (T-2095 `_self_vendor_libs`)
and `.tasks/templates/` (T-2241 `_self_vendor_templates`). Slice 2C closes
the third class: `policy/` files that ship as framework-authored governance
templates (value-drivers.yaml, bvp-scoring-rubric.md). Without this, an
operator could edit `policy/value-drivers.yaml` in the framework repo and
push without ever refreshing `.agentic-framework/policy/`, leaving consumers
that vendor from origin to silently inherit the stale templates.

Same shape as the two siblings:
- explicit sync set (two files — NOT a wildcard over `policy/`, because the
  framework's `policy/` also contains arc-specific directories like
  `capability-overlay/` and `prompts/` that are not consumer templates)
- structural consumer-safety: skip when `$FRAMEWORK_ROOT/.agentic-framework/policy/`
  doesn't exist
- dry-run/real-run wording split: "would sync"/"synced" with identical prefix

One-time bootstrap: create `.agentic-framework/policy/` and seed with the
two templates so the structural guard kicks in for the helper's first run.

## Acceptance Criteria

### Agent
- [x] `.agentic-framework/policy/value-drivers.yaml` exists and is byte-identical to `policy/value-drivers.yaml`
- [x] `.agentic-framework/policy/bvp-scoring-rubric.md` exists and is byte-identical to `policy/bvp-scoring-rubric.md`
- [x] `lib/upgrade.sh` defines `_self_vendor_policy()` (sibling of `_self_vendor_libs` / `_self_vendor_templates`)
- [x] `_self_vendor_policy()` syncs both BVP-policy files when their vendored copy is missing or differs from `$FRAMEWORK_ROOT/policy/`
- [x] `_self_vendor_policy()` honours `dry_run`: dry-run emits `Self-vendor: would sync N file(s) to .agentic-framework/policy/`; real-run emits `Self-vendor: synced N ...`
- [x] `do_upgrade()` invokes `_self_vendor_policy "$dry_run"` near the existing libs/templates calls (around `lib/upgrade.sh` line 522-524)
- [x] After running `bin/fw vendor self` once, `bin/fw vendor self --dry-run` reports zero "would sync" lines (clean state)
- [x] Mutating `policy/value-drivers.yaml` (then reverting) causes `bin/fw vendor self --dry-run` to report exactly one "would sync 1 file(s)" line targeting `.agentic-framework/policy/` — proving the T-2240 pre-push gate sees policy drift
- [x] `fw reviewer T-2263` returns Overall PASS

### Human
<!-- No Human section: all ACs above are deterministic / shell-verifiable. -->

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

# --- T-2263 ACs ---
test -f .agentic-framework/policy/value-drivers.yaml && diff -q .agentic-framework/policy/value-drivers.yaml policy/value-drivers.yaml
test -f .agentic-framework/policy/bvp-scoring-rubric.md && diff -q .agentic-framework/policy/bvp-scoring-rubric.md policy/bvp-scoring-rubric.md
grep -q "_self_vendor_policy" lib/upgrade.sh
grep -q "would sync .* to .agentic-framework/policy/" lib/upgrade.sh
out=$(bin/fw vendor self --dry-run 2>&1); test "$(echo "$out" | grep -c "would sync" || true)" = "0"
TMP_FILE=$(mktemp -p /tmp fw-t2263-mutate-XXXXXX); cp policy/value-drivers.yaml "$TMP_FILE"; echo "# T-2263 smoke mutation" >> policy/value-drivers.yaml; out=$(bin/fw vendor self --dry-run 2>&1); cp "$TMP_FILE" policy/value-drivers.yaml; echo "$out" | grep -qE "would sync 1 file\(s\) to .agentic-framework/policy/"
out=$(bin/fw reviewer T-2263 --no-write 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

### 2026-06-08 — fw vendor self verb needs three-way wiring

- **What changed:** Slice 2C required wiring at three sites, not one. `lib/upgrade.sh` already had `_self_vendor_libs` (T-2095) + `_self_vendor_templates` (T-2241) calls in `do_upgrade` AND a separate explicit invocation chain in `bin/fw` under the `vendor)` case (line ~5921-5924). Initially missed the bin/fw call — only the upgrade-path was wired. Result: `bin/fw vendor self --dry-run` would silently miss policy drift because the verb dispatch only invoked libs+templates. Caught when smoke-testing AC#8 (mutate-then-revert returned empty output instead of the expected "would sync 1 file(s) to .agentic-framework/policy/").
- **Plan impact:** Added a third sibling call in bin/fw `vendor)` case AND updated the verb's `--help` text to list policy/ as a third sync class.
- **Triggered:** No new task — pattern for future sibling classes (Slice 2D etc.): three wiring sites must change in lock-step (`lib/upgrade.sh do_upgrade`, `bin/fw vendor)` case, `bin/fw vendor self --help` text).

### 2026-06-08 — reviewer L-387 SIGPIPE detector fires on NEGATIVE grep

- **What changed:** AC#7 used `! echo "$out" | grep -q "would sync"` to assert the dry-run output contains no "would sync" lines. The reviewer's L-387 SIGPIPE-risk heuristic flagged it CONCERN, even though the SIGPIPE class (grep closes stdin while upstream is writing) doesn't apply to the negated case — when grep matches nothing, it consumes all of stdin and exits 1, no SIGPIPE.
- **Plan impact:** Recasted per L-459 — switched to `test "$(echo "$out" | grep -c "would sync" || true)" = "0"`. Same semantic, grep-count-based assertion, no SIGPIPE pattern. Reviewer flips PASS.
- **Triggered:** Pattern for future verifications: `! grep -q PATTERN <captured>` is OK semantically but trips the heuristic; prefer `test "$(echo "$out" | grep -c PATTERN || true)" = "0"`.

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

### 2026-06-08T14:09:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2263-arc-006-slice-2c--extend-self-vendor-to-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3fd6cffe
- **Timestamp:** 2026-06-08T14:13:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-08T14:13:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
