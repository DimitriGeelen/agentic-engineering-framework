---
id: T-2457
name: "fw fabric register/enrich write cards non-atomically — spurious unregistered drift FP (OBS-080)"
description: >
  fw fabric register/enrich write cards non-atomically — spurious unregistered drift FP (OBS-080)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/fabric/lib/register.sh, tests/unit/t2457_fabric_atomic_card_write.bats]
related_tasks: []
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
created: 2026-06-22T02:31:25Z
last_update: 2026-06-22T02:36:33Z
date_finished: 2026-06-22T02:36:33Z
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
---

# T-2457: fw fabric register/enrich write cards non-atomically — spurious unregistered drift FP (OBS-080)

## Context

OBS-080: `fw fabric drift` intermittently reports a spurious "unregistered" component
that clears on immediate re-run (observed 2× during T-2440, which was actively
registering cards). Root cause: both fabric card writers truncate-then-stream the
destination card (`register.sh:266` `cat > "$card_file"`, `enrich.py:34`
`open(path,"w")`), so a concurrent reader — drift's registered-set builder
`grep "^location:" "$COMPONENTS_DIR"/*.yaml` — can read a card after truncation but
before its `location:` line lands. Fix: atomic write (same-dir temp + `mv -f` /
`os.replace`) at both sites. See `## RCA`.

## Acceptance Criteria

### Agent
- [x] `register.sh` writes the skeleton card to a same-dir temp then `mv -f` onto the real path (atomic rename); no bare `cat > "$card_file"` truncate-write remains
- [x] `enrich.py` `save_card` writes to a same-dir temp then `os.replace` onto the real path; no bare `with open(path,"w")` truncate-write remains
- [x] Regression test `tests/unit/t2457_fabric_atomic_card_write.bats` (5 tests) pins both functional (fresh card carries `location:` + parses, no `.tmp` residue) and source (atomic-rename pattern present, bare-truncate absent) for both writers — all pass
- [x] No regression: existing `fabric_register_slug.bats`, `fabric_drift_data_artifact.bats`, and enrich py tests (`test_enrich_bats_parser.py`, `test_enrich_python_path_refs.py`) stay green; `register.sh` passes `bash -n`, `enrich.py` passes `py_compile`
- [x] Live verification: a real `fw fabric enrich <card>` writes via the new atomic path, the card still parses and carries `location:`, and no `.tmp` residue is left in `.fabric/components/`

### Human
None — internal tooling change (fabric card persistence). No rendering surface,
no external action, deterministic + reversible. All criteria are agent-verifiable.

## Verification

# New regression suite (TAP-robust: ok present, no not-ok)
out=$(bats tests/unit/t2457_fabric_atomic_card_write.bats 2>&1); echo "$out" | grep -qE "^ok 5 " && ! echo "$out" | grep -q "^not ok"
# Source pins: atomic-rename pattern present at both writers
grep -qE 'mv -f "\$tmp_card" "\$card_file"' agents/fabric/lib/register.sh
grep -q 'os.replace(tmp, path)' agents/fabric/lib/enrich.py
# Syntax/compile
bash -n agents/fabric/lib/register.sh
python3 -m py_compile agents/fabric/lib/enrich.py
# No regression in existing fabric register/drift suites
out=$(bats tests/unit/fabric_register_slug.bats tests/unit/fabric_drift_data_artifact.bats 2>&1); echo "$out" | grep -qE "^ok " && ! echo "$out" | grep -q "^not ok"

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

**Symptom:** `fw fabric drift` intermittently lists a component under "Unregistered
components" that is in fact registered; an immediate re-run shows it clean. Observed
2× during T-2440, which was registering 5 arc-013 cards (i.e. while cards were being
written).

**Root cause:** non-atomic card writes. Both writers truncate the destination card
first and stream the new content into it:
- `agents/fabric/lib/register.sh:266` — `cat > "$card_file" << EOF`
- `agents/fabric/lib/enrich.py:34` — `with open(path, "w") as f:`

`do_drift` builds its "registered" set with
`grep "^location:" "$COMPONENTS_DIR"/*.yaml`. If that grep reads a card during the
truncate→stream window (after truncation, before the `location:` line is written),
the card contributes no path to the registered set. Every watched source file whose
only card is mid-write then fails the `grep -qx "$rel_path"` membership test and is
reported "unregistered". Once the write completes, a re-run sees the full `location:`
line → the FP clears. This is a classic read-during-non-atomic-write TOCTOU; it only
surfaces under concurrency (a writer running while drift scans), which is exactly the
T-2440 condition.

**Why structurally allowed:** card persistence was treated as "just write the file"
with no atomicity contract, and no reader (drift, audit, query, enrich's own index
build) was hardened against partial cards — the readers assume any card on disk is
complete. Intermittent + self-clearing made it look like noise rather than a bug, so
it sat as an inbox observation rather than a tracked defect.

**Prevention:** (1) Both writers now write to a same-dir temp and atomically rename
(`mv -f` / `os.replace`) — a reader sees the complete old card or the complete new
one, never a partial, so the window cannot exist regardless of concurrency. (2)
`tests/unit/t2457_fabric_atomic_card_write.bats` pins the atomic-rename source pattern
at both sites (negative-greps the bare truncate-write) so a future edit can't silently
regress, plus functional checks that a fresh card always carries `location:` and leaves
no `.tmp` residue. (3) Learning captured on the read-during-non-atomic-write class for
the next writer added to the fabric agent.

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

### 2026-06-22T02:31:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2457-fw-fabric-registerenrich-write-cards-non.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9eb5419f
- **Timestamp:** 2026-06-22T02:36:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-22T02:36:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
