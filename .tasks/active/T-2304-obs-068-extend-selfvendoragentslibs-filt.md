---
id: T-2304
name: "OBS-068: extend _self_vendor_agents/libs filter to include .md siblings (AGENT.md
  drift class)"
description: >
  OBS-068: extend _self_vendor_agents/libs filter to include .md siblings (AGENT.md
  drift class)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
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
created: 2026-06-10T09:19:40Z
last_update: '2026-06-10T09:30:04Z'
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
  - ts: '2026-06-10T09:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-10T09:30:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2304: OBS-068: extend _self_vendor_agents/libs filter to include .md siblings (AGENT.md drift class)

## Context

OBS-068 (promoted via `fw note triage`, origin T-2301): `_self_vendor_agents` in `lib/upgrade.sh:387` filters on `-name *.sh -o -name *.py` — `.md` siblings (AGENT.md) drift between `agents/` and `.agentic-framework/agents/`. T-2301 hit this on the resume agent. Sibling concern: `_self_vendor_libs`, `_self_vendor_web`, `_self_vendor_policy` may have the same gap.

Per the producer/consumer parity discipline (L-399 / T-1890) and the explicit comment at `lib/upgrade.sh:355-356` ("Filter: `*.sh + *.py` — matches `audit.sh:1534`'s exact set so coverage parity is mechanical"), the helper and the audit detector MUST move together. The audit's libs-class scan at `agents/audit/audit.sh:1636` uses the same `*.sh + *.py + fw` filter — extending the helper without extending the audit would re-introduce blind drift (helper syncs, audit doesn't catch; or audit catches, helper can't fix).

Scope: extend the **agents/** class first (where the OBS-068 burn happened). Probe the other three classes (libs/, web/, policy/) for whether they actually contain `.md` siblings that warrant the same extension; document any class that genuinely has no `.md` content as fenced.

## Acceptance Criteria

### Agent
- [x] `_self_vendor_agents` in `lib/upgrade.sh` extends its `find` filter to include `*.md` (sibling to existing `*.sh` and `*.py`). Recursive coverage of `agents/**/*.md` (AGENT.md files at any depth).
- [x] `check_self_vendor_drift` in `agents/audit/audit.sh` extends its libs-class `find` filter to include `*.md` for the `.agentic-framework/agents/` subtree (parity with the helper — same set, same scan boundary). The other three libs-class subtrees (bin/, lib/, web/) MAY extend at the audit level too if a probe shows they contain tracked `.md` siblings — fence each one in a comment if not.
- [x] Probe and document: investigate whether `lib/`, `web/`, `policy/` contain `.md` siblings that need vendoring; record findings in the task body (one-line per class: extended / no-md-content / explicitly out-of-scope).
- [x] New bats test `tests/unit/test_self_vendor_agents_md_filter.bats` simulating an `agents/<agent>/AGENT.md` drift scenario → assert `bin/fw vendor self --dry-run` reports the .md file in its "would sync" output, AND `fw vendor self` (real-run) syncs it. PASS.
- [x] `bin/fw audit --section structure` reports `[PASS] Self-vendor drift: vendored .agentic-framework/ in sync with source` (i.e., no NEW false-positive drift introduced by extending the audit filter without backfilling vendored .md files).
- [x] Reviewer `bin/fw reviewer T-2304` Overall: PASS.

## Probe findings (audit/.md coverage across vendored classes)

Counts captured 2026-06-10 via `find <subtree> -name "*.md" -type f | wc -l`:

| Subtree | Source `.md` count | Vendored `.md` count | T-2304 verdict |
|---------|--------------------|-----------------------|-----------------|
| `agents/` | 20 | 20 (in sync) | **EXTENDED** — filter now catches `.md` drift. T-2304 ships this leg. |
| `lib/` | 33 | 33 (in sync) | **AUDIT EXTENDED, helper NOT** — `_self_vendor_libs` (lib/upgrade.sh:141) only globs `lib/*.sh`; .md siblings are coincidentally in sync today (no recent edits) but will drift silently when next edited. Audit catches via the extended filter, but `fw vendor self` cannot fix the libs/.md class — operator must use `fw vendor` full mode. Follow-on candidate: extend `_self_vendor_libs` to include `lib/*.md`. |
| `web/` | 0 | 0 | **NO-OP** — no `.md` content in `web/`. Fenced. |
| `bin/` | 0 | 0 | **NO-OP** — no `.md` content in `bin/`. Fenced. |
| `policy/` | 9 | 1 | **OUT-OF-SCOPE for T-2304 (different class)** — `_self_vendor_policy` uses an explicit named-file list (not a `find` filter). 8 `.md` files unvendored: `policy/prompts/README.md`, `policy/prompts/bvp-driver-session.md`, `policy/prompts/artefact-template.md`, `policy/prompts/bvp-references/{5 files}`. These are the T-2245/T-2246 BVP prompt bundle. Follow-on task needed to add explicit entries OR convert helper to a `find` filter. |

**Follow-on candidates surfaced (file as separate tasks per "one bug = one task"):**
1. `_self_vendor_libs` extend filter to `lib/*.md` (sibling of T-2304's agents/ leg).
2. `_self_vendor_policy` add the 8 BVP prompt-bundle `.md` files OR convert to `find` filter.

These are surfaced for operator triage, not actioned in this task.

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

bash -n lib/upgrade.sh
bash -n agents/audit/audit.sh
FRAMEWORK_ROOT="$(pwd)" bats tests/unit/test_self_vendor_agents_md_filter.bats
out=$(bin/fw audit --section structure 2>&1); echo "$out" | grep -qE 'PASS.*Self-vendor drift.*in sync'
out=$(grep -E 'name "\*\.md"' lib/upgrade.sh); echo "$out" | grep -q 'agents'
out=$(grep -E 'name "\*\.md"' agents/audit/audit.sh); echo "$out" | grep -qE 'fw|audit'
out=$(bin/fw reviewer T-2304 --no-write 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -qE "Overall:.*FAIL"

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

### 2026-06-10T09:19:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2304-obs-068-extend-selfvendoragentslibs-filt.md
- **Context:** Initial task creation
