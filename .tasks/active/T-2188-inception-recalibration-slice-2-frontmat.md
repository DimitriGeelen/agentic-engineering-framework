---
id: T-2188
name: "Inception recalibration Slice 2: frontmatter schema — target_blast_radius +
  voi_score + PreToolUse validation"
description: >
  T-2186 Slice 2. Extend inception template (.tasks/templates/zzz-default.md or split-out
  inception template) with two new frontmatter fields: (1) target_blast_radius: 0|1|3|5|7|9
  (S/M/L/XL/XXL declaration, inherit-from-arc or human-set at filing); (2) voi_score:
  map with reach (0-9, = target_blast_radius), uncertainty (0-3, from open-question
  confidences), cost_of_wrong (0-9, = target_blast × (5-tier)/5), composite (weighted,
  formula in 040). Add PreToolUse hook validating both fields on Write/Edit to inception
  task files (FW_ALLOW_INCEPTION_SCHEMA_DRIFT=1 bypass per producer/consumer parity
  T-1890). Bats test pins. Verification: template diff, hook present in .claude/settings.json,
  bats green.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [inception, schema, T-2186-slice, frontmatter]
components: []
related_tasks: [T-2186, T-2187]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-02T22:03:56Z
last_update: 2026-06-02T22:45:17Z
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
bvp_scores_proposed:
  - ts: '2026-06-02T22:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-02T22:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2188: Inception recalibration Slice 2: frontmatter schema — target_blast_radius + voi_score + PreToolUse validation

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `.tasks/templates/inception.md` frontmatter carries `target_blast_radius:` (int 0..9, S/M/L/XL/XXL declaration) and `voi_score:` (float 0..1) fields with inline guidance comments
- [x] PreToolUse hook `agents/context/check-inception-schema.{sh,py}` validates both fields on Write/Edit to `.tasks/{active,completed}/T-*.md` inception files: blocks when `workflow_type: inception` AND either field missing/out-of-range, allows otherwise
- [x] Hook registered in `.claude/settings.json` PreToolUse Write/Edit matcher (via `bin/fw hook-enable`, the framework-sanctioned path through B-005)
- [x] Bypass env-var `FW_ALLOW_INCEPTION_SCHEMA_DRIFT=1` skips the check and logs Tier-2 to `.context/working/.gate-bypass-log.yaml` (T-1890 producer/consumer parity — env-var is the external-caller pattern)
- [x] Bats test `tests/unit/check_inception_schema.bats` covers: valid inception passes, missing fields blocks, out-of-range blocks, bypass works + logs — 10/10 PASS
- [x] `050-Inceptions.md` Scoring Exception section cites the implemented fields by exact name and references this hook
- [x] `bin/fw enforcement baseline` re-run (settings.json edit invalidates the hash per L-398) — hash 97f91170d418644f
- [x] Reviewer PASS (`bin/fw reviewer T-2188`) — R-4a381689 2026-06-02T22:53:07Z, Findings: none

## Verification

bash -n agents/context/check-inception-schema.sh
python3 -c "import ast; ast.parse(open('agents/context/check-inception-schema.py').read())"
out=$(cat .tasks/templates/inception.md); grep -q "target_blast_radius:" <<<"$out"
out=$(cat .tasks/templates/inception.md); grep -q "voi_score:" <<<"$out"
out=$(cat .claude/settings.json); grep -q "check-inception-schema" <<<"$out"
out=$(cat 050-Inceptions.md); grep -q "target_blast_radius" <<<"$out"
out=$(cat 050-Inceptions.md); grep -q "FW_ALLOW_INCEPTION_SCHEMA_DRIFT" <<<"$out"
bats tests/unit/check_inception_schema.bats
out=$(bin/fw reviewer T-2188 2>&1); grep -qE "Overall:.*PASS" <<<"$out"

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

## Updates

### 2026-06-02T22:03:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2188-inception-recalibration-slice-2-frontmat.md
- **Context:** Initial task creation

### 2026-06-02T22:45:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4a381689
- **Timestamp:** 2026-06-02T22:53:07Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
