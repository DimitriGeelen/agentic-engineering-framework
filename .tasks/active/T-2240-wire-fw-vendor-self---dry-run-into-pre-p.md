---
id: T-2240
name: "Wire 'fw vendor self --dry-run' into pre-push hook — close F2 N×M leg of durable
  upgrade-path chain"
description: >
  Follow-on to T-2095 (verb extraction) + T-2232 (sentinel) + T-2237 (discoverability)
  + T-2239 (dry-run wording split). The framework's own .agentic-framework/lib/ goes
  stale when the dev edits lib/*.sh without running fw vendor self. Pre-push does
  not catch it today — only fw upgrade does, and upgrade is not part of the push flow.
  Wire fw vendor self --dry-run into the pre-push hook (agents/git/lib/, source of
  truth for the installed .git/hooks/pre-push) so the dev sees 'Self-vendor: would
  sync N file(s)' AND the push is refused with a copy-pasteable fix command. Bypass:
  --no-verify (logged Tier 2) per existing pattern. Scope: 1 hook template + bats
  coverage + manual smoke. Risk: blocks all pushes if check is wrong — needs careful
  test + an opt-out env var (FW_SKIP_SELF_VENDOR_CHECK=1).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [agents/git/lib/hooks.sh]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-07T18:54:11Z
last_update: 2026-06-07T19:52:22Z
date_finished: 2026-06-07T19:52:22Z
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
  - ts: '2026-06-07T19:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-07T19:00:03Z'
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
---

# T-2240: Wire 'fw vendor self --dry-run' into pre-push hook — close F2 N×M leg of durable upgrade-path chain

## Context

Follow-on to the durable upgrade-path chain (T-2095 verb extraction → T-2232 sentinel → T-2237 discoverability → T-2239 dry-run wording split). The framework's own `.agentic-framework/lib/` goes stale every time the dev edits `lib/*.sh` without running `fw vendor self`. Today's session surfaced the drift: `fw vendor self --dry-run` reported `would sync 13 file(s)`. There is no structural gate for this class — `fw upgrade` is the only flow that calls `_self_vendor_libs`, and upgrade isn't part of the push flow. Wiring the dry-run check into pre-push closes the N×M leg: every dev push catches the drift before consumers receive the stale lib/.

The hook template lives at `agents/git/lib/hooks.sh:496-734` (heredoc body of `install-hooks` command). Consumer-safe by construction: `_self_vendor_libs` already early-returns when `$FRAMEWORK_ROOT/.agentic-framework/lib` doesn't exist (consumer case). Bypass shape: `FW_SKIP_SELF_VENDOR_CHECK=1` env-var (logged Tier-2 per L-399 producer/consumer parity discipline) OR `git push --no-verify` (Tier 0 protected, existing pattern).

Split into structural slices (filed slices below). This task's body covers the umbrella; each slice carries its own ACs once filed.

## Acceptance Criteria

### Agent
- [x] Slice 0 (refresh prep, this session): `bin/fw vendor self` real-run executed, 13 stale files synced to `.agentic-framework/lib/`, committed `d1154eabc` under T-2240. Verified: `bin/fw vendor self --dry-run` after the refresh prints no `would sync` line (empty stdout — drift cleared)
- [x] Slice 1 (hook insertion): `agents/git/lib/hooks.sh` heredoc gains a new pre-push step that calls `bin/fw vendor self --dry-run`, greps for `would sync`, BLOCKS push with a copy-pasteable fix command + bypass guidance. Insertion site: after the YAML well-formedness gate, before the audit script resolution (so stale lib/ can't corrupt the audit run). Consumer-safe: guarded on `[ -x "$PROJECT_ROOT/bin/fw" ]` so the check no-ops on consumer projects (no root-level `bin/fw`)
- [x] Slice 2 (bats coverage): `tests/unit/t2240_pre_push_self_vendor_gate.bats` covers: (a) clean state → push allowed, (b) drift state → push blocked with the canonical message, (c) `FW_SKIP_SELF_VENDOR_CHECK=1` → push allowed with Tier-2 log entry, (d) consumer-shape (`PROJECT_ROOT` without root `bin/fw`) → check skipped. Mocks `bin/fw vendor self` per L-464 contract (real argument shape enforced)
- [x] Slice 3 (install-hooks parity): `bin/fw git install-hooks --force` from the framework repo installs the new hook variant. After install, `head -200 .git/hooks/pre-push` includes the self-vendor block. The hook's `# VERSION=` marker bumps so existing consumers re-install on next `fw upgrade`
- [x] Slice 4 (smoke + reviewer): live smoke — touch a `lib/*.sh`, attempt `git push origin master`, verify the hook blocks with the canonical message. Restore the lib/ change. Reviewer scan: `bin/fw reviewer T-2240` → Overall PASS

### Human
- [ ] [REVIEW] Pre-push block message reads cleanly to the framework dev — message names the bypass mechanisms (`FW_SKIP_SELF_VENDOR_CHECK=1`, `git push --no-verify`) and the fix command (`bin/fw vendor self && git add .agentic-framework/lib/`) without jargon overload.
  **Steps:**
  1. Read the block-message text as printed by the hook when self-vendor drift is detected.
  2. Check: does the dev understand within 5 seconds what to do?
  3. Check: does the message mention both bypass mechanisms (env var + --no-verify)?
  **Expected:** Message reads actionable; bypass + fix paths both visible.
  **If not:** Note the wording that confused you; reviewer rewrites and re-spawns.

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

# Slice 1: source has the new T-2240 block, VERSION marker bumped to 1.5
grep -q "T-2240: Self-vendor drift gate" agents/git/lib/hooks.sh
grep -q "^# VERSION=1.5" agents/git/lib/hooks.sh
# Slice 1: bypass contract names both mechanisms (L-399 parity)
grep -q "FW_SKIP_SELF_VENDOR_CHECK" agents/git/lib/hooks.sh
# Slice 2: bats file exists
test -f tests/unit/t2240_pre_push_self_vendor_gate.bats
# Slice 2: all 5 bats cases pass (L-387 capture-then-grep, T-2090 single-pipe)
bats_out=$(bats tests/unit/t2240_pre_push_self_vendor_gate.bats 2>&1); echo "$bats_out" | grep -q "^1\.\.5$" && echo "$bats_out" | grep -q "^ok 5 " && ! echo "$bats_out" | grep -q "^not ok"
# Slice 3: installed hook contains the T-2240 block + VERSION=1.5 marker
grep -q "T-2240: Self-vendor drift gate" .git/hooks/pre-push
grep -q "^# VERSION=1.5" .git/hooks/pre-push
# Slice 4: reviewer overall PASS or CONCERN (no FAIL); markdown-bold regex aware
rev_out=$(bin/fw reviewer T-2240 2>&1); echo "$rev_out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$rev_out" | grep -q "Overall:.*FAIL"

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

## Recommendation

**Recommendation:** GO

**Rationale:** Slices 0-4 shipped end-to-end. The F2 N×M closure now has a structural gate at the dev push surface — the original failure mode (edit `lib/*.sh`, push, consumers inherit stale vendored libs) cannot recur without one of two explicit bypass paths. Both bypass paths are named in the block message per L-399 producer/consumer parity. Agent ACs verify mechanically; the open `[REVIEW]` is a human taste-call on whether the block-message prose reads cleanly in 5 seconds — readability, not correctness.

**Evidence:**
- Hook source: `agents/git/lib/hooks.sh` — new T-2240 block (between YAML gate and audit resolve), `# VERSION=1.4` → `1.5`
- Installed hook: `.git/hooks/pre-push:159+` carries the new block (verified by `grep -q "T-2240: Self-vendor drift gate"`)
- Bats: `tests/unit/t2240_pre_push_self_vendor_gate.bats` — 5/5 PASS, covers clean / drift / env-bypass / consumer-no-bin-fw / no-vendored-lib
- Live smoke: drift introduced via `lib/upgrade.sh` append → hook exit 1 with canonical message + both bypasses named → drift reverted → dry-run empty
- Reviewer: R-90f94a2e Overall PASS, 0 findings
- Commit: `fc369439d` (Slices 1-4) + `d1154eabc` (Slice 0 refresh)
- Verification gate: 8/8 PASS
- Sibling chain: T-2095 (verb) → T-2232 (sentinel) → T-2237 (doc) → T-2239 (wording) → **T-2240 (gate)** — full F2 N×M leg closed

## Updates

### 2026-06-07T18:54:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2240-wire-fw-vendor-self---dry-run-into-pre-p.md
- **Context:** Initial task creation

### 2026-06-07T19:05:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b17c27b2
- **Timestamp:** 2026-06-07T19:52:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-07T19:52:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
