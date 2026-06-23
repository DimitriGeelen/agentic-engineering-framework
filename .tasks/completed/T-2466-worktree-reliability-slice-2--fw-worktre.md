---
id: T-2466
name: "Worktree reliability slice 2 — fw worktree lifecycle (create/status/merge-back) + doctor coverage"
description: >
  Build fw worktree create|status|merge-back: branch convention + auto vendor-sync + +x preservation; status shows which worktrees exist, which branch main is on, per-worktree merged?/live? state, master-lock awareness; merge-back FF helper handling the master-locked case + live-check. Doctor coverage for worktree drift. T-2464 GO Candidate C slice 2.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/check-active-task.sh, agents/context/check-visual-verification.sh, bin/fw, lib/paths.sh, lib/worktree.sh, tests/unit/t2465_reanchor_from_cwd.bats]
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
created: 2026-06-23T13:08:59Z
last_update: 2026-06-23T17:59:22Z
date_finished: 2026-06-23T17:59:22Z
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

# T-2466: Worktree reliability slice 2 — fw worktree status (topology observability) + doctor coverage

## Context

T-2464 GO Candidate C, slice 2. RCA: `docs/reports/T-2464-worktree-reliability-rca.md`.

**Scope reconciled at build time (2026-06-23):** the task was filed as `fw worktree
create|status|merge-back`, but build-time investigation found the **merge-back leg already
has substrate** under arc-011's parallel-exec work: `fw integrate check|classify`
(`lib/integrate.py`, read-only FF/auto-resolvable/needs-human preflight), `fw write-set check`
(`lib/write_set.py`), and the G1 master-merge-only guard (T-2396) — with the mutating
`fw integrate run` already scoped there as a future slice. Building a `fw worktree merge-back`
from scratch would duplicate that surface. So T-2466 is re-scoped to the **genuinely-new,
non-overlapping, read-only** piece: `fw worktree status` (topology observability) + doctor
coverage. `merge-back` routes to `fw integrate run` (arc-011); `create` is split to a follow-up.

This directly removes the friction hit repeatedly this session: not knowing which branch the
main checkout is on, which worktree holds `master` (so `git checkout master` fails and you must
`git push origin <branch>:master`), and whether a fix is merged/live on this host yet.

**Peer-project alignment (P-047, termlink, framework:pickup):** termlink independently hit the
worktree-breaks-fw pain and shipped a local mitigation (`scripts/worktree-bootstrap.sh`, their
T-2255). Their three alignment questions are answered from AEF's shipped work — see Decisions.

## Acceptance Criteria

### Agent
- [x] `fw worktree status` exists (read-only) — shows: main-checkout path + current branch (flagged when main is NOT on master, i.e. "merge-to-master ≠ live here"); each linked worktree's path / branch / short HEAD; which worktree (if any) holds `master` checked out (master-lock awareness); per-worktree merged-into-master? and is-it-live? (branch == main's checked-out branch)
- [x] `fw worktree status --json` emits the same topology as machine-readable JSON
- [x] `fw worktree` / `fw worktree --help` documents the family: `status` available now; `create` (branch convention + vendor-sync + +x) and `merge-back` (→ delegates to `fw integrate`) documented as planned, so the surface doesn't duplicate arc-011's `fw integrate`
- [x] `fw doctor` surfaces a worktree-topology line when run inside a linked worktree (current branch + merged/live state), reusing the status logic
- [x] `tests/unit/t2466_worktree_status.bats` passes — synthetic `git worktree` fixture exercises: main-branch detection, master-lock holder, merged vs unmerged worktree, `--json` shape

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
bash -n lib/worktree.sh
bash -n bin/fw
bats tests/unit/t2466_worktree_status.bats
out=$(bin/fw worktree status 2>&1); echo "$out" | grep -q "Worktree topology"
bin/fw worktree status --json | python3 -c "import sys,json; d=json.load(sys.stdin); assert set(d)=={'main','master_holder','linked_worktrees'}"

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

### 2026-06-23 — Re-scope away from merge-back (avoid duplicating `fw integrate`)
- **Chose:** T-2466 ships only `fw worktree status` (+ doctor coverage). `merge-back` routes to `fw integrate` (arc-011); `create` is a separate follow-up.
- **Why:** build-time investigation found arc-011 already shipped the merge-back substrate — `fw integrate check|classify` (lib/integrate.py), `fw write-set check` (lib/write_set.py), G1 master-merge-only guard (T-2396) — with mutating `fw integrate run` already scoped there. A `fw worktree merge-back` would be a second, competing merge-back surface.
- **Rejected:** building the full `create|status|merge-back` as filed — would duplicate `fw integrate` and split the merge-back contract across two command families.

### 2026-06-23 — AEF answers to P-047 (termlink worktree-alignment, framework:pickup)
termlink (T-2255/T-2256) asked three alignment questions. AEF's authoritative answers, from shipped work this week:
- **Q1 — is AEF working on worktree-aware fw resolution? shape/timeline?** Yes, largely shipped: T-2464 (inception, GO), T-2465 (shared bash hook resolver `fw_reanchor_from_cwd`/`fw_reanchor_from_hook_stdin` in lib/paths.sh), T-2468 (python parity `lib/hook_paths.py:reanchor_project_root` for check-arc-id/check-inception-* hooks), T-2466 (this — `fw worktree status`). Shape: **re-anchor PROJECT_ROOT from the per-call hook stdin `cwd`**, walking up to the nearest `.framework.yaml`/`.tasks` marker. Timeline: fixed on branch; pending operator FF-merge to master + into MAIN's checked-out branch to go live host-wide.
- **Q2 — approach (a) git-common-dir→main resolution, or (b) absolute framework_path?** **Neither — AEF chose (c): per-call stdin `cwd` re-anchor.** Rejected (b) absolute framework_path: env-pinned roots are the T-2446 daemon-poison class — a long-lived parent bakes in a stale/wrong root that every child inherits; per-call stdin cwd is fresh each invocation → immune. (a) git-common-dir resolves to MAIN, which is *wrong* for a worktree session (you want the worktree's own root, not main's) — our cwd-walk resolves to the actual worktree root. NOTE: termlink's stated root cause (partially-tracked vendored `.agentic-framework/` → partial worktree framework) is a *consumer-vendoring* facet, distinct from AEF's *self-host hook misanchoring* facet; the cwd-reanchor principle helps both, but vendoring-completeness is separate (AEF `_self_vendor_libs` / T-2455 class).
- **Q3 — promote bootstrap into `fw worktree bootstrap` as interim?** Yes — strongly aligned. termlink's `scripts/worktree-bootstrap.sh` is prior art for the planned `fw worktree create` (branch convention + vendor-sync + +x). Recommend termlink keep the local script as interim; AEF folds the capability into `fw worktree create` (the deferred follow-up); termlink drops the local script once shipped.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-23T13:08:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2466-worktree-reliability-slice-2--fw-worktre.md
- **Context:** Initial task creation

### 2026-06-23T17:49:10Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7f5b324a
- **Timestamp:** 2026-06-23T17:59:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-23T17:59:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
