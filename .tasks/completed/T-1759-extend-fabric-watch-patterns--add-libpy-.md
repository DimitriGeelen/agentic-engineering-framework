---
id: T-1759
name: "extend fabric watch-patterns — add lib/**/*.py + tools/*.py to close drift
  blindspot (T-1758 follow-up)"
description: >
  extend fabric watch-patterns — add lib/**/*.py + tools/*.py to close drift blindspot
  (T-1758 follow-up)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: ["fabric", "drift-defense"]
components: [".fabric/watch-patterns.yaml"]
related_tasks: ["T-1758"]
arc_id: orchestrator-rethink
created: 2026-05-06T05:44:44Z
last_update: '2026-08-16T22:24:43Z'
date_finished: 2026-05-06T06:02:22Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:43Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1759: extend fabric watch-patterns — add lib/**/*.py + tools/*.py to close drift blindspot (T-1758 follow-up)

## Context

T-1758 surfaced a silent fabric-drift blindspot: 8 `lib/reviewer/*.py` files had no fabric card, yet `fw audit` reported `Fabric: 545 registered, 0 unregistered`. Root cause: `.fabric/watch-patterns.yaml` only globs `lib/*.sh` and `bin/*` — Python sublibraries under `lib/<package>/*.py` are invisible to drift detection.

Same gap likely affects `tools/*.py` (one-off utilities) — `tools/reparse-historical-parsefails.py` was added in T-1756 with a fabric card, but only because we registered it manually; nothing structural would have caught its absence.

This task closes both gaps so future drift catches what T-1758 had to fix manually.

## Acceptance Criteria

### Agent
- [x] `.fabric/watch-patterns.yaml` includes a glob for `lib/**/*.py` (recursive Python sublibraries)
- [x] `.fabric/watch-patterns.yaml` includes a glob for `tools/*.py` (one-off utilities)
- [x] After adding patterns, drift correctly flags genuinely-missing cards — caught `lib/ask.py` (existed without card) and `tools/escalation-scan-v0.py` (existed without card); both registered. Final drift count: 0 unregistered.
- [x] Drift catches a synthetic missing card: confirmed by direct python check — moving `lib-reviewer-audit.yaml` aside surfaced `lib/reviewer/audit.py` in unregistered list; restored, no longer flagged

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

cd /opt/999-Agentic-Engineering-Framework && grep -q 'lib/\*\*/\*\.py' .fabric/watch-patterns.yaml || (echo "missing lib/**/*.py pattern"; exit 1)
cd /opt/999-Agentic-Engineering-Framework && grep -q 'tools/\*\.py' .fabric/watch-patterns.yaml || (echo "missing tools/*.py pattern"; exit 1)
cd /opt/999-Agentic-Engineering-Framework && python3 -c "import yaml; yaml.safe_load(open('.fabric/watch-patterns.yaml'))"

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

### 2026-05-06 — pattern extension surfaced two latent unregistered files
- **What changed:** Adding `lib/**/*.py` and `tools/*.py` patterns immediately surfaced `lib/ask.py` and `tools/escalation-scan-v0.py` as unregistered. Both existed on disk without cards. The drift detector had been blind to them under the old patterns. Confirms the gap was real, not theoretical — the drift detector had silently mis-reported "0 unregistered" for an unknown amount of time.
- **Plan impact:** No change. The expected outcome (catch genuine drift) materialised immediately on first run.
- **Triggered:** Inline registrations of `lib/ask.py` (manual card creation due to filename collision with existing `lib-ask.yaml` for `lib/ask.sh` — register CLI doesn't disambiguate by extension) and `tools/escalation-scan-v0.py`. Note: register-CLI extension-collision behavior is a separate observation worth filing if the pattern recurs.

## Recommendation

**Recommendation:** GO

**Rationale:** Two new globs added (`lib/**/*.py`, `tools/*.py`). Drift detector now actively catches the class of misses that hid `lib/reviewer/*.py` invisibly during T-1758. Synthetic test confirmed sensitivity (moving a card aside surfaces the file as unregistered). Two latent unregistered files surfaced and registered (`lib/ask.py`, `tools/escalation-scan-v0.py`). Final state: drift `unregistered_count=0`.

**Evidence:**
- `.fabric/watch-patterns.yaml` adds two new entries with `note:` referencing T-1759
- Direct drift check after additions: `unregistered_count=3` initially → 3 cards registered → `unregistered_count=0`
- Surfaced 2 genuinely-missing cards (`lib/ask.py`, `tools/escalation-scan-v0.py`) — proof that the prior watch patterns missed real coverage gaps
- Synthetic missing-card test passed (drift flagged on remove, cleared on restore)

## Decisions
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

## Updates

### 2026-05-06T05:44:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1759-extend-fabric-watch-patterns--add-libpy-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a8032e6b
- **Timestamp:** 2026-06-02T14:59:33Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#3 (Agent)** — After adding patterns, drift correctly flags genuinely-missing cards — caught `lib/ask.py` (existed without card) and `tools/escalation-scan-v0.py` (existed without card); both registered. Final drift
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/ask.py in: After adding patterns, drift correctly flags genuinely-missing cards — caught `lib/ask.py` (existed without card) and `tools/escalation-scan-v0.py` (e`
- **AC#4 (Agent)** — Drift catches a synthetic missing card: confirmed by direct python check — moving `lib-reviewer-audit.yaml` aside surfaced `lib/reviewer/audit.py` in unregistered list; restored, no longer flagged
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/reviewer/audit.py in: Drift catches a synthetic missing card: confirmed by direct python check — moving `lib-reviewer-audit.yaml` aside surfaced `lib/reviewer/audit.py` in `
### 2026-05-06T06:02:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
