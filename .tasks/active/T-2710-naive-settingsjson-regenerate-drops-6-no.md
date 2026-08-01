---
id: T-2710
name: "Naive settings.json regenerate drops 6 non-template hooks"
description: >
  generate_claude_code_config emits 19 hooks; this repo runs 25. The 6 extra (check-active-completed-dup,
  check-arc-id, check-heredoc-cmd-sub, check-inception-decisions, check-inception-schema
  PreToolUse; check-settings-edit PostToolUse) were added later via fw hook-enable
  and are not in the generator template. Any regenerate path — fw upgrade, or force=true
  generate_claude_code_config — silently DROPS all six, disabling six live gates with
  no warning. Pre-existing, but T-2709's A2 makes the regenerate trigger fire where
  it previously never did, so the hazard is now reachable on every consumer.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [hooks, upgrade, governance]
components: []
related_tasks: [T-2709, T-2704]
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
created: 2026-08-01T07:21:48Z
last_update: 2026-08-01T07:39:38Z
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

# T-2710: Naive settings.json regenerate drops 6 non-template hooks

## Context

`generate_claude_code_config` (`lib/init.sh:606`) writes `.claude/settings.json` from a
fixed heredoc template. When `force=true` it **overwrites unconditionally** — it never
reads what is already there. This repo runs 25 hooks; the template emits 19. The 6
difference were added post-init via `fw hook-enable` and exist only on disk:

| Event | Hook |
|-------|------|
| PreToolUse | `check-active-completed-dup` |
| PreToolUse | `check-arc-id` |
| PreToolUse | `check-heredoc-cmd-sub` |
| PreToolUse | `check-inception-decisions` |
| PreToolUse | `check-inception-schema` |
| PostToolUse | `check-settings-edit` |

Any forced regenerate — `lib/upgrade.sh:1407` and `:1482`, or `lib/init.sh:829` — silently
deletes all six. Six live governance gates go dark with no message, and the operator's only
signal is their absence.

Pre-existing, but **T-2709 changed its reachability**: A2 wired a shared portability
predicate into the upgrade regenerate trigger, so a consumer carrying pre-T-2709 hardcoded
paths now *takes* the regenerate branch on the next `fw upgrade`. The trap was dormant
because nothing walked into it; A2 built the path.

**Fix shape:** regenerate becomes a merge, not an overwrite. Template-defined hooks are
re-emitted from the template (so path fixes like T-2709's still propagate); hooks present
on disk whose name the template does not define are carried forward; the carry-forward is
reported, not silent. Adding the 6 to the template is *not* the fix — that leaves the same
hole open for the next `fw hook-enable`.

## Acceptance Criteria

### Agent
- [x] Forced regenerate preserves non-template hooks: given a settings.json containing all 6 hooks above, `force=true generate_claude_code_config` emits a file that still contains all 6, at their original events.
- [x] Forced regenerate still refreshes template-defined hooks: given a settings.json whose `check-active-task` command is a stale hardcoded absolute path, regenerate rewrites it to the `${CLAUDE_PROJECT_DIR}` form (T-2709's fix must keep propagating).
- [x] Carry-forward is reported, not silent: regenerate prints one line per preserved non-template hook (name + event) to stdout.
- [x] Regenerating this repo is hook-count-preserving: 25 hooks before, 25 after, 0 containing a hardcoded `/opt/` path (`lib/hook_portability.py` reports `25|0|0`).
- [x] Regression test `tests/unit/settings_regenerate_preserves_hooks.bats` pins all three behaviours above and is green, including a negative control that fails if the merge is removed.
- [x] `bin/fw doctor` reports no new hook or enforcement-baseline FAIL after regenerate.

**Evidence (live runs, 2026-08-01):**
- Real generator, `force=true`, against a copy of this repo's `.claude/`: `25 hook refs` in → 6 `CARRIED` lines → `25 hook refs` out, `diff` of hook-name sets **IDENTICAL**, `hook_portability.py` → `25|0|0`, JSON valid.
- Falsification (both directions): neutering the merge turns tests 1/2/5 red; making the merge *over-eager* (carry template-defined names too) turns test 4 red — so the template-wins half is genuinely pinned, not decorative.
- Foreign `vnx-guard` hook in the fixture is **not** carried → T-677's deliberate replacement of third-party hooks is preserved.

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

bats tests/unit/settings_regenerate_preserves_hooks.bats
out=$(python3 lib/hook_portability.py .claude/settings.json 2>&1); echo "$out" | grep -q '^25|0|0'
bin/fw enforcement baseline

## RCA

**Symptom:** `.claude/settings.json` regenerated by `fw upgrade` (or any `force=true`
generate) loses the 6 hooks added via `fw hook-enable`. Six PreToolUse/PostToolUse gates
stop firing. No error, no warning, no diff shown — the file is simply rewritten shorter.

**Root cause:** `generate_claude_code_config` is a *writer* with no *reader*. It emits a
fixed heredoc and has exactly one guard — `[ ! -f settings.json ] || force=true` — which
decides *whether* to write, never *what is already there*. The template is treated as the
complete description of the hook set, but `fw hook-enable` makes the on-disk file the real
source of truth. Two writers, one authority, no merge.

**Why structurally allowed:** the drop is invisible to every existing check. `fw doctor`
validates that the hooks *present* resolve — it has no expectation of which hooks *should*
be present, so 19 healthy hooks look identical to 25 healthy hooks. The enforcement
baseline (T-1886) hashes settings.json and would flag the change, but it is refreshed by
the same upgrade flow that caused it. Nothing anywhere holds "this project had 25 hooks
yesterday". This is the session's recurring class — **a check that reports success about
the wrong object** — third instance in T-2709/T-2710 alone.

**Prevention:** the merge is the fix; the *test* is the prevention. The bats regression
pins that a non-template hook survives a forced regenerate, with a negative control that
goes red if the merge is deleted. Without that control the merge could be refactored away
and the suite would stay green, which is exactly how this shipped the first time.

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

### 2026-08-01 — merge, not "add the 6 to the template"

- **Chose:** make regenerate a merge (snapshot → template → fold non-template hooks back).
- **Why:** the on-disk file, not the heredoc, is the real source of truth once `fw hook-enable`
  exists. Any fix that only reconciles today's difference re-opens the hole on the next
  `hook-enable`.
- **Rejected:** adding the 6 hooks to the template — closes this instance, leaves the class open.
- **Rejected:** preferring the on-disk copy wholesale — would have frozen every consumer at its
  init-time hook paths and stopped T-2709's `${CLAUDE_PROJECT_DIR}` fix from ever propagating.
  Test 4 exists specifically to keep this rejected.

### 2026-08-01 — carry non-`hooks` top-level keys too

- **Chose:** preserve top-level keys the template does not emit (`permissions`, `env`, …).
- **Why:** identical defect — the template was being treated as a complete description of the
  file. This repo only has `hooks`, so it changes nothing here, but a consumer with
  `permissions` would lose it to the same overwrite.
- **Note:** a deliberate small widening beyond the filed title; flagged here rather than done
  quietly.

### 2026-08-01 — foreign hooks still dropped

- **Chose:** carry forward only commands matching `fw hook <name>`.
- **Why:** T-677 deliberately replaces third-party hooks from other tooling ("not compatible,
  reference non-local paths"). Reversing that silently would be a second uninstructed change.
  Test 3 pins it.

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

### 2026-08-01T07:21:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2710-naive-settingsjson-regenerate-drops-6-no.md
- **Context:** Initial task creation

### 2026-08-01T07:39:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
