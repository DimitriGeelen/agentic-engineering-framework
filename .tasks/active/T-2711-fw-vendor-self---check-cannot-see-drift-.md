---
id: T-2711
name: "fw vendor self --check cannot see drift the audit reports"
description: >
  fw vendor self reported 'synced 1 file to .agentic-framework/bin/' and fw vendor
  self --check then reported in-sync, while .agentic-framework/bin/hook-enable.sh
  still differed from source. agents/audit/audit.sh:1752 scans .agentic-framework/{bin,lib,agents,web}
  for *.sh/*.py/fw/claude-fw/*.md and caught it, blocking push. So the verb recommended
  by the audit's own mitigation line cannot verify what the audit checks. Direct sibling
  of T-2502 (claude-fw missed by the same helper). L-399 producer/consumer parity:
  the pre-verifier and the gate must scan the same set.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [vendor, audit, parity]
components: []
related_tasks: [T-2709, T-2502, T-2244]
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
created: 2026-08-01T07:22:27Z
last_update: 2026-08-01T08:29:56Z
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

# T-2711: fw vendor self --check cannot see drift the audit reports

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Context

`agents/audit/audit.sh:1752` (the **gate**) scans
`.agentic-framework/{bin,lib,agents,web}` for
`*.sh -o *.py -o fw -o claude-fw -o *.md` and `cmp`s each against source.

Four helpers in `lib/upgrade.sh` are the **producers** meant to satisfy it:

| Helper | Covers | Selection |
|--------|--------|-----------|
| `_self_vendor_libs` | `lib/` | find + filter |
| `_self_vendor_agents` | `agents/` | find + filter |
| `_self_vendor_web` | `web/` | find + filter |
| `_self_vendor_shim` | `bin/` | **hardcoded `for _shim in fw claude-fw`** |

Three producers enumerate; the fourth names two files. So every other file in
`bin/` matching the audit filter — `bin/hook-enable.sh` is the observed case — is
**gated by audit but synced by nobody**. `fw vendor self` reports success, `--check`
reports in-sync, and the push gate still refuses, pointing at a verb that cannot
fix it.

This is the third instance of the same shape: T-2266 (`agents/` scanned, unsynced),
T-2502 (`claude-fw` scanned, unsynced), now `bin/*.sh`. Each was fixed by adding the
missing *name* rather than removing the naming. L-399: the pre-verifier and the gate
must derive their file set from one place.

## Acceptance Criteria

### Agent
- [x] `_self_vendor_shim` selects files by enumerating `bin/` with the same filter the audit uses, instead of a hardcoded name list; adding a new `bin/*.sh` requires no edit to the helper.
- [x] `bin/hook-enable.sh` (the observed miss) is synced by `fw vendor self` — verified by deliberately dirtying the vendored copy, running `fw vendor self`, and confirming `cmp` equality.
- [x] `fw vendor self --check` and `agents/audit/audit.sh check_self_vendor_drift` agree on every file in `bin/`: a scripted comparison of the two scan sets reports zero files present in one and absent from the other.
- [x] The sync-count message reports the real number: `_self_vendor_shim` currently prints a hardcoded `1 file(s)` regardless of how many it copied.
- [x] Regression test `tests/unit/self_vendor_parity.bats` green, including a negative control that adds a new `bin/*.sh` fixture and fails if the helper's set does not pick it up.
- [x] `bin/fw audit` reports no `Self-vendor drift` FAIL, and `git push` is not blocked by the T-2240 gate.

**Evidence (live, 2026-08-01):**
- Gated-but-unsynced set measured at **4 files**, not 1: `hook-enable.sh`, `integrate-go-live.sh`, `migrate-horizon-null-completed.sh`, `watchtower.sh`.
- Dirtied two vendored copies → `fw vendor self` → `synced 2 file(s) to .agentic-framework/bin/` (previously would have printed `1`, and synced neither), all four `cmp`-identical after.
- Falsification: restoring the name-list turns tests 1, 2 and **6** red. Tests 3 and 4 stay green — they compare the two *trees*, which were already equal, so they would have been decorative on their own. Test 6 (run the producer against real drift) is the one with teeth.
- `-maxdepth 1` was replaced with the audit's recursive traversal: `bin/` is flat today so both pass, but the first `bin/<subdir>/foo.sh` would have re-opened the identical hole.

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

bats tests/unit/self_vendor_parity.bats
out=$(bin/fw vendor self --check 2>&1); echo "$out" | grep -qv "would sync" || true
bash -n lib/upgrade.sh

## RCA

**Symptom:** `fw vendor self` reported success and `--check` reported in-sync while
`.agentic-framework/bin/hook-enable.sh` still differed from source. The T-2240 pre-push
gate refused the push and its remediation line named `fw vendor self` — the verb that
could not fix it.

**Root cause:** `_self_vendor_shim` selected files by a hardcoded list
(`for _shim in fw claude-fw`) while the audit gate enumerates all of
`.agentic-framework/bin` with a filter. Its three sibling helpers already enumerate. Four
files sat in the difference: `hook-enable.sh`, `integrate-go-live.sh`,
`migrate-horizon-null-completed.sh`, `watchtower.sh` — gated by the audit, synced by
nobody.

**Why structurally allowed:** this is the third instance of the shape — T-2266 (`agents/`
scanned, unsynced), T-2502 (`claude-fw` scanned, unsynced), now `bin/*.sh`. Each of the
first two was closed by **adding the missing name**, which left the mechanism that
generates the gap fully intact. A name list and a filter cannot stay in agreement by
maintenance; there had to be a third instance, and there would have been a fourth. The
recurrence is the finding, not the individual file.

**Prevention:** the helper now derives its set from the same traversal + filter the gate
uses, so parity is mechanical rather than remembered. `self_vendor_parity.bats` test 6
runs the producer against real drift — the only check here that distinguishes a working
helper from a broken one, since the set-equality tests pass either way.

## Decisions

### 2026-08-01 — enumerate rather than add the missing name

- **Chose:** replace the hardcoded list with a `find` matching the audit's filter.
- **Why:** the two prior instances were both closed by adding a name. That is what
  produced this instance. The gap is generated by having two independent definitions of
  "which files matter"; only removing one of them closes the class.
- **Rejected:** add `hook-enable.sh` to the list — would have shipped green today and
  re-opened on the next `bin/` script.

### 2026-08-01 — match the gate's traversal, not just its current results

- **Chose:** recursive `find`, though `bin/` is flat.
- **Why:** `-maxdepth 1` passes today purely because no one has made a subdirectory. That
  is a coincidence, and coincidences are what this task is about.

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

### 2026-08-01T07:22:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2711-fw-vendor-self---check-cannot-see-drift-.md
- **Context:** Initial task creation

### 2026-08-01T08:29:56Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
