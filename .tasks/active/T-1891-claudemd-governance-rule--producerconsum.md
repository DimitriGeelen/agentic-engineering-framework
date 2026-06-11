---
id: T-1891
name: "CLAUDE.md governance rule — producer/consumer parity for hook bypass contracts
  (L-399 codification)"
description: >
  CLAUDE.md governance rule — producer/consumer parity for hook bypass contracts (L-399
  codification)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [docs, governance, hook-ux, L-399, meta-rca:T-1890]
components: [CLAUDE.md]
related_tasks: [T-1890, T-1730, T-1559]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T06:17:32Z
last_update: '2026-06-11T22:23:26Z'
date_finished: 2026-05-18T06:21:26Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 4
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=4 
      (body/components:instruction-sync); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1891: CLAUDE.md governance rule — producer/consumer parity for hook bypass contracts (L-399 codification)

## Context

T-1890 fixed the focus-drift hook bypass producer/consumer split. L-399 captured the pattern in project memory. CLAUDE.md is the framework's normative governance document — future hook authors will read CLAUDE.md before they read L-399. This task codifies the L-399 rule into a `### Hook Bypass Contract Parity` section under §Agent Behavioral Rules, neighboring Consumer-Facing Command Hygiene (T-1633) which addresses a similar "works for the author, fails for everyone else" anti-pattern.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md gains a new `### Hook Bypass Contract Parity (T-1890, L-399)` sub-section under §Agent Behavioral Rules, placed adjacent to "Consumer-Facing Command Hygiene" (same family: end-to-end correctness vs author-local correctness).
- [x] The new section names the producer/consumer split explicitly, lists the 6-step authoring checklist, names both bypass mechanism shapes (`--flag` vs env-var prefix), and identifies the test pattern (end-to-end bats per mechanism per pattern).
- [x] The section cites T-1890 origin + L-399 reference for traceability.
- [x] `grep -c "Hook Bypass Contract Parity" CLAUDE.md` returns 1.
- [x] `grep -c "T-1890" CLAUDE.md` returns ≥1.

### Human
- [ ] [REVIEW] The new section reads cleanly and matches the surrounding §Agent Behavioral Rules tone
  **Steps:**
  1. Open `CLAUDE.md` and locate the new `### Hook Bypass Contract Parity` section.
  2. Read the section + its two flanking sections (Consumer-Facing Command Hygiene, Presenting Work for Human Review) as a sequence.
  **Expected:** Tone, formatting, and depth of detail match the neighbours. Authoring checklist is actionable for the next hook author.
  **If not:** Edit until it reads as a peer of its neighbours.

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# T-1891 verification:
test "$(grep -c 'Hook Bypass Contract Parity' CLAUDE.md)" -eq 1
test "$(grep -c 'T-1890' CLAUDE.md)" -ge 1
test "$(grep -c 'L-399' CLAUDE.md)" -ge 1

## RCA

(Filed against the tag-flagged bug-class detection — this task is a docs codification, not a bugfix, but captures the underlying RCA for completeness since the tags carry `meta-rca:T-1890`.)

**Symptom:** L-399 (the broader-class learning that the focus-drift bypass contract was missing consumer-side acceptance) lived only in `.context/project/learnings.yaml` and not in CLAUDE.md. Future hook authors who read CLAUDE.md but not learnings.yaml would have re-introduced the producer/consumer split.

**Root cause:** Knowledge-distribution gap. The framework has two normative surfaces — CLAUDE.md (loaded auto into every Claude Code session) and learnings.yaml (surfaced by `fw work-on` related-knowledge but otherwise not always read). When a learning has framework-author-facing relevance (vs project-operator-facing), it belongs in BOTH — the learning for episodic recall, the CLAUDE.md section for normative authority.

**Why structurally allowed:** No rule says "if a learning is framework-author-facing, also codify in CLAUDE.md." The bug-fix-learning-checkpoint rule (CLAUDE.md §Bug-Fix Learning Checkpoint) explicitly covers learnings.yaml capture but stops there.

**Prevention:** This task itself plus a future-candidate rule: "if a learning captures a framework-authoring pattern (vs an operational pattern), promote it to CLAUDE.md when the third instance lands." Not codifying that meta-rule yet — speculative, no evidence of repetition.

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

## Recommendation

**Recommendation:** GO

**Rationale:** Codifies L-399 (captured this session via dogfooded `fw context add-learning --switch-focus`) into CLAUDE.md as a peer of "Consumer-Facing Command Hygiene" — both are end-to-end correctness rules counter to author-local correctness. Future hook authors will read CLAUDE.md before they read learnings.yaml; placing the rule in the normative document closes the knowledge-distribution gap.

**Evidence:**
- `CLAUDE.md` — new `### Hook Bypass Contract Parity (T-1890, L-399)` section, placed after Consumer-Facing Command Hygiene, before Presenting Work for Human Review.
- Section contains: 6-step authoring checklist, both bypass mechanism shapes, end-to-end bats test requirement, block-message clarity rule.
- Cross-references T-1890 origin + L-399 reference.
- All 3 verification checks pass (grep counts confirm presence).

**Why no broader scope:** Adding an audit-time static-scan CTL-XXX check for "hook recommends `--flag` without consumer acceptance" would be the next step, but that's a separate deliverable. The proactive scan I ran this session (grep across all `agents/context/*.sh` hooks for "Append --" or "Bypass.*--" recommendations) confirmed no other producer/consumer splits currently exist — only the focus-drift gate had the pattern, and T-1890 fixed it. So an automated check would have zero hits today; building it now would be speculative tooling.



## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-18T06:17:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1891-claudemd-governance-rule--producerconsum.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-4e9de2ba
- **Timestamp:** 2026-05-18T09:31:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-18T06:21:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
