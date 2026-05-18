---
id: T-1891
name: "CLAUDE.md governance rule — producer/consumer parity for hook bypass contracts (L-399 codification)"
description: >
  CLAUDE.md governance rule — producer/consumer parity for hook bypass contracts (L-399 codification)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [docs, governance, hook-ux, L-399, meta-rca:T-1890]
components: [CLAUDE.md]
related_tasks: [T-1890, T-1730, T-1559]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T06:17:32Z
last_update: 2026-05-18T06:17:32Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
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
